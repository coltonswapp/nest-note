import UIKit
import MapKit
import CoreLocation

final class PlacesMapViewController: NNViewController {
    
    // MARK: - Properties
    private var mapView: MKMapView!
    private var addPlaceButton: NNPrimaryLabeledButton!
    private var clearButton: UIButton!
    private var currentPlacemark: CLPlacemark?
    private var selectedAnnotation: MKPointAnnotation?
    private let geocoder = CLGeocoder()
    private let locationManager = CLLocationManager()
    private var hasRequestedLocation = false
    
    // Remove timer and movement tracking properties
    private var hasSelectedPlace = false
    
    private var clearButtonBottomConstraint: NSLayoutConstraint?
    private var placesListVC: PlaceListViewController?
    
    // MARK: - Gestures
    private lazy var mapLongPressGesture: UILongPressGestureRecognizer = {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleMapLongPress(_:)))
        gesture.minimumPressDuration = 0.5
        return gesture
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        showPlacesList() // Show places list immediately
        title = "Places"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Only request location once when the view appears
        if !hasRequestedLocation {
            setupLocationManager()
            hasRequestedLocation = true
        }
    }
    
    override func setup() {
        setupMap()
        setupAddPlaceButton()
        setupClearButton()
        setupNavigationBarButtons()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // Rough accuracy is fine
        
        // Check current authorization status and request if needed
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            // User has denied or restricted location access, use default region
            break
        }
    }
    
    override func setupNavigationBarButtons() {
        // Map type menu button
        let mapTypeButton = UIBarButtonItem(
            image: UIImage(systemName: "map"),
            menu: createMapTypeMenu()
        )
        navigationItem.rightBarButtonItem = mapTypeButton
        navigationController?.navigationBar.tintColor = .label
    }
    
    private func setupMap() {
        mapView = MKMapView(frame: .zero)
        mapView.delegate = self
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        
        mapView.pointOfInterestFilter = .includingAll
        mapView.addGestureRecognizer(mapLongPressGesture)
        
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Set initial region to Salt Lake City (will be updated with user location if available)
        setDefaultRegion()
    }
    
    private func setDefaultRegion() {
        // Set initial region to Salt Lake City
        let saltLakeCity = CLLocationCoordinate2D(latitude: 40.7608, longitude: -111.8910)
        let region = MKCoordinateRegion(
            center: saltLakeCity,
            latitudinalMeters: 10000,
            longitudinalMeters: 10000
        )
        mapView.setRegion(region, animated: false)
    }
    
    private func setRegionToUserLocation(_ location: CLLocation) {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 10000,
            longitudinalMeters: 10000
        )
        mapView.setRegion(region, animated: true)
    }
    
    private func setupAddPlaceButton() {
        addPlaceButton = NNPrimaryLabeledButton(title: "Select Place")
        addPlaceButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        addPlaceButton.addTarget(self, action: #selector(addPlaceButtonTapped), for: .touchUpInside)
    }
    
    private func setupClearButton() {
        clearButton = UIButton(type: .system)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure button appearance
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = UIImage(systemName: "xmark.circle.fill", withConfiguration: config)
        clearButton.setImage(image, for: .normal)
        clearButton.setTitle("Clear Selection", for: .normal)
        clearButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        
        // Add spacing between image and text
        clearButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
        clearButton.tintColor = .secondaryLabel
        
        // Match the blur background style
        clearButton.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
        clearButton.layer.cornerRadius = 12
        clearButton.clipsToBounds = true
        
        // Add padding
        clearButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        
        clearButton.alpha = 0
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        view.addSubview(clearButton)
        
        let bottomConstraint = clearButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -120)
        clearButtonBottomConstraint = bottomConstraint
        
        NSLayoutConstraint.activate([
            clearButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomConstraint
        ])
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "map"),
            menu: createMapTypeMenu()
        )
    }
    
    // MARK: - Actions
    @objc private func addPlaceButtonTapped() {
        let selectPlaceVC = SelectPlaceViewController()
        
        // Pass user's current location if available
        selectPlaceVC.initialLocation = locationManager.location
        
        let nav = UINavigationController(rootViewController: selectPlaceVC)
        present(nav, animated: true)
    }
    
    @objc private func handleMapLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        selectPlace(at: coordinate)
    }
    
    @objc private func clearButtonTapped() {
//        clearSelection()
    }
    
    private func showPlacesList() {
        let placesVC = PlaceListViewController()
        placesListVC = placesVC
        let nav = UINavigationController(rootViewController: placesVC)
        
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [
                .custom { _ in return 100 },
                .medium(),
                .large()
            ]
            sheet.prefersGrabberVisible = true
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.largestUndimmedDetentIdentifier = .large
            sheet.selectedDetentIdentifier = .medium
        }
        
        nav.isModalInPresentation = true
        present(nav, animated: true)
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
//                self.centerPinView.isHidden = true
                self.hasSelectedPlace = true
                self.addPlaceButton.setTitle("Add Place")
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
    
    private func showFoundPlace(_ address: String) {
        // If the button is already visible, just return
        guard clearButton.alpha == 0 else { return }
        
        // Animate button appearing
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.clearButton.alpha = 1
            self.clearButton.transform = .identity
        }
    }
    
    private func clearSelection() {
        hasSelectedPlace = false
        addPlaceButton.setTitle("Select Place")
        
        // Animate button disappearing
        UIView.animate(withDuration: 0.3) {
            self.clearButton.alpha = 0
        }
        
//        centerPinView.isHidden = false
        
        // Remove annotation
        if let annotation = selectedAnnotation {
            mapView.removeAnnotation(annotation)
            selectedAnnotation = nil
        }
        
        HapticsHelper.thwompHaptic()
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
}

// MARK: - MKMapViewDelegate
extension PlacesMapViewController: MKMapViewDelegate {
    // ... Map delegate methods from SelectPlaceViewController ...
}

// MARK: - CLLocationManagerDelegate
extension PlacesMapViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Use the most recent location
        guard let location = locations.last else { return }
        
        // Set the map region to the user's location
        setRegionToUserLocation(location)
        
        // Stop updating location since we only need it once
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        // Fall back to default region if there's an error getting location
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            // User denied location access, use default region
            break
        default:
            break
        }
    }
}
