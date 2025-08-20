//
//  SelectPlaceViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 2/15/25.
//

import UIKit
import MapKit
import CoreLocation
import RevenueCat
import RevenueCatUI

protocol SelectPlaceLocationDelegate: AnyObject {
    func didUpdatePlaceLocation(
        _ place: PlaceItem,
        newAddress: String,
        newCoordinate: CLLocationCoordinate2D,
        newThumbnail: UIImage
    )
}

class SelectPlaceViewController: NNViewController, UISearchResultsUpdating, SearchResultsDelegate {
    
    weak var locationDelegate: SelectPlaceLocationDelegate?
    weak var temporaryPlaceDelegate: TemporaryPlaceSelectionDelegate?
    
    // Property to store initial location if available
    var initialLocation: CLLocation?
    
    // Replace NNSearchBarView with UISearchController
    private var searchController: UISearchController!
    private var searchResultsController: SearchResultsViewController!
    
    private var mapView: MKMapView!
    private var addPlaceButton: NNPrimaryLabeledButton!
    
    private var instructionLabel: BlurBackgroundLabel!
    
    // Add new property for the pin view
    private let centerPinView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Create pin image view
        let pinImage = UIImageView()
        pinImage.translatesAutoresizingMaskIntoConstraints = false
        pinImage.image = UIImage(systemName: "mappin")?.withRenderingMode(.alwaysTemplate)
        pinImage.tintColor = .systemBlue
        pinImage.contentMode = .scaleAspectFit
        
        // Create circular background
        let backgroundView = UIView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.backgroundColor = .systemBlue.withAlphaComponent(0.3)
        backgroundView.layer.cornerRadius = 23
        
        view.addSubview(backgroundView)
        view.addSubview(pinImage)
        
        NSLayoutConstraint.activate([
            backgroundView.widthAnchor.constraint(equalToConstant: 46),
            backgroundView.heightAnchor.constraint(equalToConstant: 46),
            backgroundView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backgroundView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -23.0),
            
            pinImage.widthAnchor.constraint(equalToConstant: 30),
            pinImage.heightAnchor.constraint(equalToConstant: 30),
            pinImage.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
            pinImage.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor)
        ])
        
        return view
    }()
    
    private let geocoder = CLGeocoder()
    private var currentPlacemark: CLPlacemark?
    private let addressGeocoder = CLGeocoder() // Separate geocoder for address updates
    
    // Add new property for the found place label
    private var foundPlaceLabel: BlurBackgroundLabel!
    
    // Add property for current address label
    private var currentAddressLabel: BlurBackgroundLabel!
    
    // Add properties for search
    private var searchTask: Task<Void, Never>?
    
    // Remove timer and movement tracking properties
    private var hasSelectedPlace = false
    
    // Add property to track current annotation
    private var selectedAnnotation: MKPointAnnotation?
    
    // Add property to track if instructions have been shown
    private var hasShownInstructions = true
    private var shouldShowAddressLabel = false
    
    // Add property for clear button
    private lazy var clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure button appearance
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = UIImage(systemName: "xmark.circle.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.setTitle("Clear Selection", for: .normal)
        button.titleLabel?.font = .h4
        
        // Add spacing between image and text
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
        button.tintColor = .secondaryLabel
        
        // Match the blur background style
        button.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        
        // Add padding
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        
        button.alpha = 0
        button.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // Replace tap gesture with long press
    private lazy var mapLongPressGesture: UILongPressGestureRecognizer = {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleMapLongPress(_:)))
        gesture.minimumPressDuration = 0.5 // Half second press
        return gesture
    }()
    
    
    // For Editing an existing Place location
    private var existingPlace: PlaceItem?
    private var isEditingLocation: Bool = false
    
    // Add state tracking
    private enum SelectionState {
        case initial        // No selection yet
        case pinDropped    // Pin has been dropped, ready to add/update
    }
    
    private var currentState: SelectionState = .initial
    
    // Add properties for temporary place selection
    var isTemporarySelection = false
    var suggestedPlaceName: String?
    var category: String = "Places"
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    init(placeToEdit: PlaceItem) {
        self.existingPlace = placeToEdit
        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func setup() {
        // Update title based on selection mode
        if isTemporarySelection {
            title = "Select Location"
        } else {
            title = existingPlace == nil ? "Add a Place" : "Update Location"
        }
        
        setupSearchController()
        mapView.delegate = self
        setupNavigationBarButtons()
        
        // Listen for place save notifications to dismiss this view controller
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(placeDidSave),
            name: .placeDidSave,
            object: nil
        )
        
        if let existingPlace {
            setupExistingLocation(for: existingPlace)
        }
    }
    
    override func setupNavigationBarButtons() {
        // Setup dismiss button
        let dismissButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(dismissTapped)
        )
        
        // Setup map type menu button
        let mapTypeButton = UIBarButtonItem(
            image: UIImage(systemName: "map"),
            menu: createMapTypeMenu()
        )
        
        navigationItem.rightBarButtonItems = [dismissButton, mapTypeButton]
        navigationController?.navigationBar.tintColor = .label
    }
    
    private func createMapTypeMenu() -> UIMenu {
        let defaultAction = UIAction(
            title: "Default",
            state: mapView.mapType == .standard ? .on : .off
        ) { [weak self] _ in
            self?.mapView.mapType = .standard
            self?.updateMapTypeMenu()
        }
        
        let satelliteAction = UIAction(
            title: "Satellite",
            state: mapView.mapType == .satellite ? .on : .off
        ) { [weak self] _ in
            self?.mapView.mapType = .satellite
            self?.updateMapTypeMenu()
        }
        
        let hybridAction = UIAction(
            title: "Hybrid",
            state: mapView.mapType == .hybrid ? .on : .off
        ) { [weak self] _ in
            self?.mapView.mapType = .hybrid
            self?.updateMapTypeMenu()
        }
        
        return UIMenu(title: "Map Type", children: [defaultAction, satelliteAction, hybridAction])
    }
    
    private func updateMapTypeMenu() {
        // Update the menu to reflect the new selection
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "map"),
            menu: createMapTypeMenu()
        )
    }
    
    @objc private func dismissTapped() {
        closeButtonTapped()
    }
    
    @objc private func placeDidSave() {
        // Only dismiss if we're creating a new place (not editing an existing one)
        // Editing existing places already have their own dismissal logic
        guard existingPlace == nil else { return }
        
        // Dismiss this view controller when a new place is successfully saved
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dismiss(animated: true)
        }
    }
    
    @objc private func showPlacesList() {
        let placesVC = PlaceListViewController()
        
        if let sheet = placesVC.sheetPresentationController {
            // Configure sheet presentation
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.selectedDetentIdentifier = .medium
            
            // Add corner radius to match system sheets
            placesVC.view.layer.cornerRadius = 10
            placesVC.view.clipsToBounds = true
        }
        
        present(placesVC, animated: true)
    }
    
    override func addSubviews() {
        setupMap()
        setupAddPlaceButton()
        setupInstructionLabel()
        setupFoundPlaceLabel()
        setupCurrentAddressLabel()
        
        // Add the center pin view
        view.addSubview(centerPinView)
        NSLayoutConstraint.activate([
            centerPinView.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),
            centerPinView.centerYAnchor.constraint(equalTo: mapView.centerYAnchor)
        ])
        
    }
    
    private func setupSearchController() {
        // Create search results controller
        searchResultsController = SearchResultsViewController()
        searchResultsController.searchDelegate = self
        
        // Create search controller with results controller
        searchController = UISearchController(searchResultsController: searchResultsController)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search for places"
        
        // Configure search bar appearance
        searchController.searchBar.searchBarStyle = .minimal
        
        // Set the search controller to the navigation item
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        
        // Define which content is searched
        definesPresentationContext = true
    }
    
    // MARK: - UISearchResultsUpdating
    
    func updateSearchResults(for searchController: UISearchController) {
        // Cancel any existing search task
        searchTask?.cancel()
        
        guard let searchText = searchController.searchBar.text, !searchText.isEmpty else {
            // Clear results if search text is empty
            searchResultsController.updateSearchResults([])
            return
        }
        
        // Start new search task with debouncing
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            guard !Task.isCancelled else { return }
            
            await performSearchForController(searchText: searchText)
        }
    }
    
    private func setupMap() {
        mapView = MKMapView(frame: .zero)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        
        // Enable points of interest
        mapView.pointOfInterestFilter = .includingAll
        
        // Add long press gesture instead of tap
        mapView.addGestureRecognizer(mapLongPressGesture)
        
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Set initial region based on priority:
        // 1. Existing place being edited
        // 2. User's current location
        // 3. Current Nest address
        // 4. Default Salt Lake City
        if let existingPlace = existingPlace {
            // If editing an existing place, center on that place's location
            let region = MKCoordinateRegion(
                center: existingPlace.locationCoordinate,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
            mapView.setRegion(region, animated: false)
        } else if let initialLocation = initialLocation {
            // If we have an initial location (from user's location), use that
            let region = MKCoordinateRegion(
                center: initialLocation.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: false)
        } else if let nestAddress = NestService.shared.currentNest?.address, !nestAddress.isEmpty {
            // Try using the Nest address as fallback
            geocodeNestAddress(nestAddress)
        } else {
            // Default to Salt Lake City
            setDefaultRegion()
        }
    }
    
    private func geocodeNestAddress(_ address: String) {
        geocoder.geocodeAddressString(address) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error geocoding Nest address: \(error.localizedDescription)")
                self.setDefaultRegion()
                return
            }
            
            if let location = placemarks?.first?.location {
                let region = MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                )
                self.mapView.setRegion(region, animated: false)
            } else {
                // Fall back to default if geocoding failed
                self.setDefaultRegion()
            }
        }
    }
    
    private func setDefaultRegion() {
        // Default to Salt Lake City
        let saltLakeCity = CLLocationCoordinate2D(latitude: 40.7608, longitude: -111.8910)
        let region = MKCoordinateRegion(
            center: saltLakeCity,
            latitudinalMeters: 10000,
            longitudinalMeters: 10000
        )
        mapView.setRegion(region, animated: false)
    }
    
    private func setupAddPlaceButton() {
        let buttonTitle: String
        
        if let _ = existingPlace {
            buttonTitle = "Update Location"
        } else {
            buttonTitle = "Select Place"
        }
        
        addPlaceButton = NNPrimaryLabeledButton(title: buttonTitle)
        addPlaceButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        addPlaceButton.addTarget(self, action: #selector(addPlaceButtonTapped), for: .touchUpInside)
    }
    
    private func setupFoundPlaceLabel() {
        view.addSubview(clearButton)
        
        NSLayoutConstraint.activate([
            clearButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            clearButton.bottomAnchor.constraint(equalTo: addPlaceButton.topAnchor, constant: -16)
        ])
    }
    
    @objc private func addPlaceButtonTapped() {
        switch currentState {
        case .initial:
            // First tap - Drop pin at center
            let coordinate = mapView.centerCoordinate
            selectPlace(at: coordinate)
            
            // Update button for next state
            if isTemporarySelection {
                addPlaceButton.setTitle("Use This Location")
            } else {
                addPlaceButton.setTitle(existingPlace == nil ? "Add Place" : "Update Location")
            }
            currentState = .pinDropped
            
        case .pinDropped:
            // Second tap - Generate thumbnail and proceed
            guard let placemark = currentPlacemark else { return }
            
            if isTemporarySelection {
                // For temporary places, just pass back the location data
                let address = formatAddress(from: placemark)
                let coordinate = placemark.location?.coordinate ?? mapView.centerCoordinate
                
                temporaryPlaceDelegate?.didSelectTemporaryPlace(
                    address: address,
                    coordinate: coordinate
                )
                
                navigationController?.popViewController(animated: true)
                return
            }
            
            // For permanent places, continue with thumbnail generation
            MapThumbnailGenerator.shared.generateDynamicThumbnail(
                for: placemark.location?.coordinate ?? mapView.centerCoordinate,
                visibleRegion: mapView.region
            ) { [weak self] thumbnail in
                guard let self = self,
                      let thumbnail = thumbnail else { return }
                
                DispatchQueue.main.async {
                    if let existingPlace = self.existingPlace {
                        // Update existing place
                        let address = self.formatAddress(from: placemark)
                        let coordinate = placemark.location?.coordinate ?? existingPlace.locationCoordinate
                        
                        self.locationDelegate?.didUpdatePlaceLocation(
                            existingPlace,
                            newAddress: address,
                            newCoordinate: coordinate,
                            newThumbnail: thumbnail
                        )
                        
                        self.dismiss(animated: true)
                    } else {
                        // Create new place
                        let newPlaceVC = PlaceDetailViewController(
                            placemark: placemark,
                            alias: self.suggestedPlaceName ?? "",
                            category: self.category,
                            thumbnail: thumbnail
                        )
                        
                        let placeListViewController = self.navigationController?.viewControllers.first as? PlaceListViewController
                        
                        newPlaceVC.placeListDelegate = placeListViewController
                        self.present(newPlaceVC, animated: true)
                    }
                }
            }
        }
    }
    
    @objc private func clearButtonTapped() {
        clearSelection()
    }
    
    // Replace tap handler with long press handler
    @objc private func handleMapLongPress(_ gesture: UILongPressGestureRecognizer) {
        // Only trigger on the start of the long press
        guard gesture.state == .began else { return }
        
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        
        // First check if we pressed on a point of interest
        let mapPoint = MKMapPoint(coordinate)
        let adjustedRect = mapView.visibleMapRect.intersection(MKMapRect(origin: mapPoint, size: MKMapSize(width: 10, height: 10)))
        
        if let selectedAnnotation = mapView.annotations(in: adjustedRect).first as? MKAnnotation {
            // We pressed on an existing annotation or POI
            mapView.setCenter(selectedAnnotation.coordinate, animated: true)
            selectPlace(at: selectedAnnotation.coordinate)
        } else {
            // We pressed on an empty spot - center the map there
            mapView.setCenter(coordinate, animated: true)
            selectPlace(at: coordinate)
        }
    }
    
    private func selectPlace(at coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Reverse geocoding error: \(error.localizedDescription)")
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    print("No address found")
                    return
                }
                
                self.currentPlacemark = placemark
                let address = self.formatAddress(from: placemark)
                
                self.showFoundPlace(address)
                self.addAnnotation(at: coordinate, with: address)
                self.centerPinView.isHidden = true
                self.hasSelectedPlace = true
                HapticsHelper.lightHaptic()
            }
        }
    }
    
    private func addAnnotation(at coordinate: CLLocationCoordinate2D, with title: String) {
        // Remove existing annotation if any
        if let existing = selectedAnnotation {
            mapView.removeAnnotation(existing)
        }
        
        // Create and add new annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = title
        mapView.addAnnotation(annotation)
        selectedAnnotation = annotation
    }
    
    private func clearSelection() {
        hasSelectedPlace = false
        addPlaceButton.setTitle("Select Place")
        
        // Animate button disappearing
        UIView.animate(withDuration: 0.3) {
            self.clearButton.alpha = 0
        }
        
        centerPinView.isHidden = false
        
        // Remove annotation
        if let annotation = selectedAnnotation {
            mapView.removeAnnotation(annotation)
            selectedAnnotation = nil
        }
        
        HapticsHelper.thwompHaptic()
        
        // Reset state
        currentState = .initial
        addPlaceButton.setTitle("Select Place")
    }
    
    private func saveCurrentPlace() {
        guard let placemark = currentPlacemark else { return }
        
        // Here you would save the place to your data model
        // You have access to:
        // - address: String
        // - placemark.coordinate: CLLocationCoordinate2D
        // - placemark: CLPlacemark (contains additional metadata)
        
        // Example properties you might want to save:
        let coordinate = placemark.location?.coordinate
        let latitude = coordinate?.latitude
        let longitude = coordinate?.longitude
        let name = placemark.name
        let postalCode = placemark.postalCode
        let locality = placemark.locality // city
        let administrativeArea = placemark.administrativeArea // state
        
        // TODO: Save place to your data model
        
        // Dismiss the view controller
        dismiss(animated: true)
    }
    
    func formatAddress(from placemark: CLPlacemark) -> String {
        var addressComponents: [String] = []
        
        // Add street address
        if let street = placemark.thoroughfare {
            var streetAddress = street
            if let number = placemark.subThoroughfare {
                streetAddress = "\(number) \(street)"
            }
            addressComponents.append(streetAddress)
        }
        
        // Add city
        if let city = placemark.locality {
            addressComponents.append(city)
        }
        
        // Add state
        if let state = placemark.administrativeArea {
            addressComponents.append(state)
        }
        
        // Add postal code
        if let postalCode = placemark.postalCode {
            addressComponents.append(postalCode)
        }
        
        return addressComponents.joined(separator: ", ")
    }
    
    func formatDistance(_ distanceInMeters: Double) -> String {
        let distanceInMiles = distanceInMeters * 0.000621371 // Convert meters to miles
        
        if distanceInMiles < 0.1 {
            return "< 0.1 mi"
        } else if distanceInMiles < 1.0 {
            return String(format: "%.1f mi", distanceInMiles)
        } else {
            return String(format: "%.1f mi", distanceInMiles)
        }
    }
    
    private func showFoundPlace(_ address: String) {
        // If the button is already visible, just return
        guard clearButton.alpha == 0 else { return }
        
        // Ensure button is positioned below screen
//        clearButton.transform = CGAffineTransform(translationX: 0, y: 100)
        
        // Animate button appearing
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.clearButton.alpha = 1
            self.clearButton.transform = .identity
        }
    }
    
    private func setupInstructionLabel() {
        instructionLabel = BlurBackgroundLabel()
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.text = "Drag & Zoom the map to set\nthe pin for your place"
        instructionLabel.font = .bodyL
        instructionLabel.textColor = .secondaryLabel
        
        view.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)
        ])
    }
    
    private func setupCurrentAddressLabel() {
        currentAddressLabel = BlurBackgroundLabel()
        currentAddressLabel.translatesAutoresizingMaskIntoConstraints = false
        currentAddressLabel.text = "Loading address..."
        currentAddressLabel.font = .bodyL
        currentAddressLabel.textColor = .label
        currentAddressLabel.alpha = 0
        
        view.addSubview(currentAddressLabel)
        
        // Use the same constraints as instruction label
        NSLayoutConstraint.activate([
            currentAddressLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            currentAddressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            currentAddressLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)
        ])
    }
    
    
    private func updateCurrentAddress() {
        let centerCoordinate = mapView.centerCoordinate
        let location = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
        
        addressGeocoder.cancelGeocode() // Cancel any previous requests
        addressGeocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Address geocoding error: \(error.localizedDescription)")
                    self.currentAddressLabel.text = "Unable to load address"
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    self.currentAddressLabel.text = "No address found"
                    return
                }
                
                let address = self.formatAddress(from: placemark)
                self.currentAddressLabel.text = address
                
                // Only show the label if we should show address label
                if self.shouldShowAddressLabel && self.currentAddressLabel.alpha == 0 {
                    UIView.animate(withDuration: 0.3) {
                        self.currentAddressLabel.alpha = 1
                    }
                }
            }
        }
    }
    
    @MainActor
    private func performSearchForController(searchText: String) async {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchText
        searchRequest.region = mapView.region
        
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            
            guard !Task.isCancelled else { return }
            
            // Sort results by distance from current map center
            let currentLocation = CLLocation(
                latitude: mapView.centerCoordinate.latitude,
                longitude: mapView.centerCoordinate.longitude
            )
            
            let sortedResults = response.mapItems.sorted { item1, item2 in
                let location1 = CLLocation(
                    latitude: item1.placemark.coordinate.latitude,
                    longitude: item1.placemark.coordinate.longitude
                )
                let location2 = CLLocation(
                    latitude: item2.placemark.coordinate.latitude,
                    longitude: item2.placemark.coordinate.longitude
                )
                
                let distance1 = currentLocation.distance(from: location1)
                let distance2 = currentLocation.distance(from: location2)
                
                return distance1 < distance2
            }
            
            let limitedResults = Array(sortedResults.prefix(10)) // Limit to 10 results
            searchResultsController.updateSearchResults(limitedResults)
        } catch {
            print("Search error: \(error.localizedDescription)")
            searchResultsController.updateSearchResults([])
        }
    }
    
    
    // MARK: - SearchResultsDelegate
    
    func searchResults(_ controller: SearchResultsViewController, didSelectMapItem mapItem: MKMapItem) {
        // Dismiss search controller (but keep search text)
        searchController.isActive = false
        
        // Clear any existing selection
        clearSelection()
        
        // Animate to the selected location
        let region = MKCoordinateRegion(
            center: mapItem.placemark.coordinate,
            latitudinalMeters: 750,
            longitudinalMeters: 750
        )
        mapView.setRegion(region, animated: true)
        selectPlace(at: mapItem.placemark.coordinate)
        
        // Update state and button since user has selected a place from search
        currentState = .pinDropped
        if isTemporarySelection {
            addPlaceButton.setTitle("Use This Location")
        } else {
            addPlaceButton.setTitle(existingPlace == nil ? "Add Place" : "Update Location")
        }
    }
    
    func getCurrentLocation() -> CLLocation {
        return CLLocation(
            latitude: mapView.centerCoordinate.latitude,
            longitude: mapView.centerCoordinate.longitude
        )
    }
    
    deinit {
        addressGeocoder.cancelGeocode()
        searchTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupExistingLocation(for place: PlaceItem) {
        // Hide the center pin since we're showing a draggable pin
        centerPinView.isHidden = true
        
        // Add draggable annotation for the place
        let annotation = MKPointAnnotation()
        annotation.coordinate = place.locationCoordinate
        annotation.title = place.alias
        mapView.addAnnotation(annotation)
        selectedAnnotation = annotation
        
        // Center map on the place with appropriate zoom
        let region = MKCoordinateRegion(
            center: place.locationCoordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        mapView.setRegion(region, animated: false)
        
        // Update button title
        addPlaceButton.setTitle("Update Location")
        
        // Show the clear button since we have a selection
        hasSelectedPlace = true
        showFoundPlace(place.address)
        
        // Reverse geocode to get placemark
        geocoder.reverseGeocodeLocation(
            CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        ) { [weak self] placemarks, error in
            guard let self = self,
                  let placemark = placemarks?.first else { return }
            self.currentPlacemark = placemark
        }
    }
}


// Update the MapKit delegate
extension SelectPlaceViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        // Only handle instruction label fade out
        if hasShownInstructions {
            hasShownInstructions = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                UIView.animate(withDuration: 0.3) {
                    self.instructionLabel.alpha = 0
                } completion: { _ in
                    // Enable address label showing and show it
                    self.shouldShowAddressLabel = true
                    UIView.animate(withDuration: 0.3) {
                        self.currentAddressLabel.alpha = 1
                    }
                }
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // Update the current address when the map region changes
        updateCurrentAddress()
    }
    
    // Customize annotation appearance
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let identifier = "PlacePin"
        
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        }
        
        annotationView?.isDraggable = existingPlace != nil
        annotationView?.canShowCallout = true
        annotationView?.markerTintColor = .systemBlue
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
        switch newState {
        case .ending:
            if let coordinate = view.annotation?.coordinate {
                selectPlace(at: coordinate)
            }
        default:
            break
        }
    }
}

