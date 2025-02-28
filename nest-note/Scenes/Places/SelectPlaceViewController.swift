//
//  SelectPlaceViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 2/15/25.
//

import UIKit
import MapKit
import CoreLocation

protocol SelectPlaceLocationDelegate: AnyObject {
    func didUpdatePlaceLocation(
        _ place: Place,
        newAddress: String,
        newCoordinate: CLLocationCoordinate2D,
        newThumbnail: UIImage
    )
}

class SelectPlaceViewController: NNViewController {
    
    weak var locationDelegate: SelectPlaceLocationDelegate?
    weak var temporaryPlaceDelegate: TemporaryPlaceSelectionDelegate?
    
    private let searchBarView: NNSearchBarView = {
        let view = NNSearchBarView(placeholder: "1 Infinite Loop, Cupertino, CA",
                                   keyboardType: .default)
        return view
    }()
    
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
    
    // Add new property for the found place label
    private var foundPlaceLabel: BlurBackgroundLabel!
    
    // Remove timer and movement tracking properties
    private var hasSelectedPlace = false
    
    // Add property to track current annotation
    private var selectedAnnotation: MKPointAnnotation?
    
    // Add property to track if instructions have been shown
    private var hasShownInstructions = true
    
    // Add property for clear button
    private lazy var clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure button appearance
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = UIImage(systemName: "xmark.circle.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.setTitle("Clear Selection", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        
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
    private var existingPlace: Place?
    private var isEditingLocation: Bool = false
    
    // Add state tracking
    private enum SelectionState {
        case initial        // No selection yet
        case pinDropped    // Pin has been dropped, ready to add/update
    }
    
    private var currentState: SelectionState = .initial
    
    // Add properties for temporary place selection
    var isTemporarySelection = false
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    init(placeToEdit: Place) {
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
        
        searchBarView.searchBar.delegate = self
        mapView.delegate = self
        setupNavigationBarButtons()
        
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
        setupPaletteSearch()
        setupMap()
        setupAddPlaceButton()
        setupInstructionLabel()
        setupFoundPlaceLabel()
        
        // Add the center pin view
        view.addSubview(centerPinView)
        NSLayoutConstraint.activate([
            centerPinView.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),
            centerPinView.centerYAnchor.constraint(equalTo: mapView.centerYAnchor)
        ])
    }
    
    func setupPaletteSearch() {
        searchBarView.frame.size.height = 50
        addNavigationBarPalette(searchBarView)
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
        
        // Set initial region to Salt Lake City
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
                        
                        self.navigationController?.popViewController(animated: true)
                    } else {
                        // Create new place
                        let detailVC = PlaceDetailViewController(
                            placemark: placemark,
                            thumbnail: thumbnail
                        )
                        self.navigationController?.pushViewController(detailVC, animated: true)
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
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
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
        instructionLabel.font = .systemFont(ofSize: 16, weight: .regular)
        instructionLabel.textColor = .secondaryLabel
        
        view.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)
        ])
    }
    
    deinit {
        // No need to invalidate any timers in the new implementation
    }
    
    private func setupExistingLocation(for place: Place) {
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

// Add UISearchBarDelegate
extension SelectPlaceViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Optional: Implement real-time search suggestions
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text, !searchText.isEmpty else { return }
        searchBar.resignFirstResponder()
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchText
        searchRequest.region = mapView.region
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { [weak self] (response, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Search error: \(error.localizedDescription)")
                return
            }
            
            guard let firstMatch = response?.mapItems.first else {
                print("No matches found")
                return
            }
            
            // Clear any existing selection
            self.clearSelection()
            
            // Animate to the found location
            let region = MKCoordinateRegion(
                center: firstMatch.placemark.coordinate,
                latitudinalMeters: 750,
                longitudinalMeters: 750
            )
            self.mapView.setRegion(region, animated: true)
            self.selectPlace(at: firstMatch.placemark.coordinate)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        searchBar.showsCancelButton = false
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = true
    }
}

// Update the MapKit delegate
extension SelectPlaceViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        // Only handle instruction label fade out
        if hasShownInstructions {
            hasShownInstructions = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                UIView.animate(withDuration: 0.3) {
                    self.instructionLabel.alpha = 0
                }
            }
        }
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

