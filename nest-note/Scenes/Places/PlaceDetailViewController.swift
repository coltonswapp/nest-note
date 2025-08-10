//
//  PlaceDetailViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 7/6/25.
//

import UIKit
import MapKit
import Contacts

final class PlaceDetailViewController: NNSheetViewController, NNTippable {
    
    weak var placeDelegate: PlaceAddressCellDelegate?
    weak var placeListDelegate: PlaceListViewControllerDelegate?
    
    // MARK: - Properties
    private var placemark: CLPlacemark
    private var placeAlias: String
    private var thumbnail: UIImage?
    private var thumbnailAsset: UIImageAsset?
    private var category: String
    
    var mapHeightConstraint: NSLayoutConstraint?
    
    // Define fixed heights to avoid cumulative growth when toggling keyboard
    private let collapsedMapHeight: CGFloat = 140
    private let expandedMapHeight: CGFloat = 260
    
    let addressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 2
        label.textAlignment = .left
        label.textColor = .label
        label.font = .bodyM
        label.isUserInteractionEnabled = true
        return label
    }()
    
    private let mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.isUserInteractionEnabled = false
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.layer.cornerRadius = 18
        return mapView
    }()
    
    private lazy var saveButton: NNLoadingButton = {
        let button = NNLoadingButton(
            title: isEditingPlace ? "Update" : "Create",
            titleColor: .white,
            fillStyle: .fill(.systemBlue)
        )
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var folderLabel: NNSmallLabel = {
        let label = NNSmallLabel()
        return label
    }()
    
    private let buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    
    private var existingPlace: PlaceItem?
    private var pendingLocationUpdate: (address: String, coordinate: CLLocationCoordinate2D, thumbnail: UIImage)?
    private var originalAlias: String?
    private let isEditingPlace: Bool
    var isReadOnly: Bool = false
    
    // Add property to track changes
    private var hasUnsavedChanges: Bool = false {
        didSet {
            updateSaveButtonState()
        }
    }
    
    // MARK: - Initialization
    init(placemark: CLPlacemark, alias: String, category: String = "Places", thumbnail: UIImage? = nil) {
        self.placemark = placemark
        self.placeAlias = alias
        self.category = category
        self.thumbnail = thumbnail
        self.thumbnailAsset = thumbnail?.imageAsset
        self.isEditingPlace = false
        super.init(sourceFrame: nil)
    }
    
    init(place: PlaceItem, thumbnail: UIImage? = nil, isReadOnly: Bool = false) {
        self.placemark = MKPlacemark(
            coordinate: place.locationCoordinate,
            addressDictionary: [CNPostalAddressStreetKey: place.address]
        )
        self.existingPlace = place
        self.placeAlias = place.alias ?? "Temporary Place"
        self.category = place.category
        self.thumbnail = thumbnail
        self.thumbnailAsset = thumbnail?.imageAsset
        self.isEditingPlace = true
        self.isReadOnly = isReadOnly
        super.init(sourceFrame: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = existingPlace == nil ? "New Place" : isReadOnly ? "View Place" : "Edit Place"
        originalAlias = existingPlace?.alias
        
        itemsHiddenDuringTransition = [buttonStackView]
        setupContent()
        setupMapView()
        updateSaveButtonState()
        configureFolderLabel()
        
        placeDelegate = self
        setupInfoButton()
        
        // Add target for titleField changes
        titleField.addTarget(self, action: #selector(titleFieldChanged), for: .editingChanged)
        titleField.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Auto-focus titleField for new places
        if !isEditingPlace {
            titleField.becomeFirstResponder()
        }
        
        if isReadOnly {
            titleField.isUserInteractionEnabled = false
            configureReadOnlyMode()
        }
        
        self.trackScreenVisit()
    }
    
    
    // MARK: - Setup Methods
    
    override func setupInfoButton() {
        // Configure the base class info button with place-specific menu
        infoButton.isHidden = false
        infoButton.menu = createMenu()
        infoButton.showsMenuAsPrimaryAction = true
    }
    
    override func addContentToContainer() {
        super.addContentToContainer()
        
        if !isReadOnly {
            buttonStackView.addArrangedSubview(saveButton)
        }
        
        containerView.addSubview(mapView)
        containerView.addSubview(addressLabel)
        containerView.addSubview(folderLabel)
        containerView.addSubview(buttonStackView)
        
        // Start slightly larger when keyboard is hidden
        mapHeightConstraint = mapView.heightAnchor.constraint(equalToConstant: expandedMapHeight)
        
        NSLayoutConstraint.activate([
            
            // Map view constraints
            mapView.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 16),
            mapView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            mapView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            mapHeightConstraint!,
            
            // Address label constraints
            addressLabel.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 16),
            addressLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            addressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Folder label constraints
            folderLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            folderLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16),
            folderLabel.heightAnchor.constraint(equalToConstant: 30),
            
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            buttonStackView.heightAnchor.constraint(equalToConstant: 46),
        ] + (isReadOnly ? [
            buttonStackView.topAnchor.constraint(equalTo: folderLabel.bottomAnchor, constant: 16),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16).with(priority: .defaultHigh),
        ] : [
            buttonStackView.topAnchor.constraint(equalTo: folderLabel.bottomAnchor, constant: 16),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            saveButton.widthAnchor.constraint(equalTo: buttonStackView.widthAnchor)
        ]))
    }
    
    @objc private func saveButtonTapped() {
        guard !placeAlias.isEmpty else {
            // Show error about missing alias
            let alert = UIAlertController(
                title: "Missing Name",
                message: "Please add a friendly name for this place",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        Task {
            do {
                saveButton.startLoading()
                
                if let existingPlace = existingPlace {
                    // Update existing place
                    var updatedPlace = PlaceItem(
                        id: existingPlace.id,
                        nestId: existingPlace.nestId,
                        category: existingPlace.category,
                        alias: placeAlias,
                        address: existingPlace.address,
                        coordinate: existingPlace.locationCoordinate,
                        thumbnailURLs: existingPlace.thumbnailURLs,
                        isTemporary: existingPlace.isTemporary,
                        createdAt: existingPlace.createdAt,
                        updatedAt: Date()
                    )
                    
                    // Apply pending location update if exists
                    if let locationUpdate = pendingLocationUpdate {
                        updatedPlace = PlaceItem(
                            id: existingPlace.id,
                            nestId: existingPlace.nestId,
                            category: existingPlace.category,
                            alias: placeAlias,
                            address: locationUpdate.address,
                            coordinate: locationUpdate.coordinate,
                            thumbnailURLs: existingPlace.thumbnailURLs,
                            isTemporary: existingPlace.isTemporary,
                            createdAt: existingPlace.createdAt,
                            updatedAt: Date()
                        )
                    }
                    
                    // Update using new method
                    try await NestService.shared.updatePlace(updatedPlace)
                    
                    await MainActor.run {
                        self.placeListDelegate?.placeListViewController(didUpdatePlace: updatedPlace)
                        self.saveButton.stopLoading(withSuccess: true)
                        
                        // Dismiss the sheet after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            self.dismiss(animated: true)
                        }
                    }
                } else {
                    // Create new place
                    let address = existingPlace?.address ?? formatAddress(from: placemark)
                    let coordinate = placemark.location?.coordinate ?? CLLocationCoordinate2D()
                    
                    // Generate thumbnail if not provided
                    let finalThumbnail: UIImage
                    if let thumbnail = thumbnail {
                        finalThumbnail = thumbnail
                    } else {
                        // Generate thumbnail from current map view
                        finalThumbnail = try await generateThumbnail(for: coordinate)
                    }
                    
                    Logger.log(level: .info, category: .nestService, message: "🖼️ PLACE DEBUG: self.thumbnailAsset is \(self.thumbnailAsset != nil ? "NOT NIL" : "NIL")")
                    Logger.log(level: .info, category: .nestService, message: "🖼️ PLACE DEBUG: finalThumbnail size: \(finalThumbnail.size)")
                    
                    let asset = thumbnailAsset ?? {
                        Logger.log(level: .info, category: .nestService, message: "🖼️ PLACE DEBUG: Creating new UIImageAsset with light/dark variants")
                        let asset = UIImageAsset()
                        asset.register(finalThumbnail, with: UITraitCollection(userInterfaceStyle: .light))
                        asset.register(finalThumbnail, with: UITraitCollection(userInterfaceStyle: .dark))
                        Logger.log(level: .info, category: .nestService, message: "🖼️ PLACE DEBUG: UIImageAsset created successfully")
                        return asset
                    }()
                    
                    Logger.log(level: .info, category: .nestService, message: "🖼️ PLACE DEBUG: About to call createPlace with asset: \(asset)")
                    
                    let newPlace = try await NestService.shared.createPlace(
                        alias: placeAlias,
                        address: address,
                        coordinate: coordinate,
                        category: category,
                        thumbnailAsset: asset
                    )
                    
                    await MainActor.run {
                        // Show success feedback
                        HapticsHelper.thwompHaptic()
                        self.saveButton.stopLoading(withSuccess: true)
                        
                        // Notify delegate and dismiss
                        self.placeListDelegate?.placeListViewController(didUpdatePlace: newPlace)
                        
                        NotificationCenter.default.post(name: .placeDidSave, object: nil)
                        
                        // Dismiss the sheet and pop to root after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            self.dismiss(animated: true) {
//                                onComplete()
                                //
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.saveButton.stopLoading()
                    HapticsHelper.failureHaptic()
                    self.showToast(text: "Failed to save place", sentiment: .negative)
                }
            }
        }
    }
    
    private func generateThumbnail(for coordinate: CLLocationCoordinate2D) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            MapThumbnailGenerator.shared.generateDynamicThumbnail(
                for: coordinate,
                visibleRegion: MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 300,
                    longitudinalMeters: 300
                )
            ) { thumbnail in
                if let thumbnail = thumbnail {
                    continuation.resume(returning: thumbnail)
                } else {
                    continuation.resume(throwing: NSError(domain: "ThumbnailError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate thumbnail"]))
                }
            }
        }
    }
    
    // MARK: - Setup Methods
    private func setupContent() {
        titleField.text = placeAlias
        titleField.isUserInteractionEnabled = !isReadOnly
        setupAddressLabel()
        setupAddressTapGesture()
    }
    
    private func setupAddressLabel() {
        let address = existingPlace?.address ?? formatAddress(from: placemark)
        let attributedString = NSAttributedString(
            string: address,
            attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: UIFont.bodyL
            ]
        )
        addressLabel.attributedText = attributedString
    }
    
    private func setupAddressTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(addressTapped))
        addressLabel.addGestureRecognizer(tapGesture)
    }
    
    private func configureFolderLabel() {
        let components = category.components(separatedBy: "/")
        if components.count >= 2 {
            folderLabel.text = components.joined(separator: " / ")
        } else if components.count == 1 {
            // Show single component
            folderLabel.text = components.first
        } else {
            // Fallback
            folderLabel.text = category
        }
    }
    
    @objc private func addressTapped() {
        placeDelegate?.placeAddressCellAddressTapped(addressLabel, place: existingPlace)
    }
    
    private func setupMapView() {
        guard let coordinate = placemark.location?.coordinate else { return }
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = placeAlias
        
        mapView.addAnnotation(annotation)
        
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 300,
            longitudinalMeters: 300
        )
        mapView.setRegion(region, animated: false)
    }
    
    override func onKeyboardShow() {
        mapHeightConstraint?.constant = collapsedMapHeight
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }
    
    override func onKeyboardHide() {
        mapHeightConstraint?.constant = expandedMapHeight
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Helper Methods
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let street = placemark.thoroughfare {
            var streetAddress = street
            if let number = placemark.subThoroughfare {
                streetAddress = "\(number) \(street)"
            }
            components.append(streetAddress)
        }
        
        if let city = placemark.locality {
            components.append(city)
        }
        
        if let state = placemark.administrativeArea {
            components.append(state)
        }
        
        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }
        
        return components.joined(separator: ", ")
    }
    
    private func createMenu() -> UIMenu {
        var actions: [UIAction] = []
        
        // Only show edit/delete if we have an existing place
        if existingPlace != nil {
            let editAction = UIAction(
                title: "Edit Location",
                image: UIImage(systemName: "mappin.and.ellipse")
            ) { [weak self] _ in
                self?.handleEditLocation()
            }
            
            let deleteAction = UIAction(
                title: "Delete Place",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.handleDelete()
            }
            
            actions = [editAction, deleteAction]
        }
        
        return UIMenu(children: actions)
    }
    
    private func handleEditLocation() {
        guard let place = existingPlace else { return }
        
        let selectPlaceVC = SelectPlaceViewController(placeToEdit: place)
        selectPlaceVC.locationDelegate = self
        
        present(UINavigationController(rootViewController: selectPlaceVC), animated: true)
    }
    
    private func handleDelete() {
        let alert = UIAlertController(
            title: "Delete Place",
            message: "Are you sure you want to delete this place? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDelete()
        })
        
        present(alert, animated: true)
    }
    
    private func performDelete() {
        guard let place = existingPlace else { return }
        
        saveButton.startLoading()
        
        Task {
            do {
                try await NestService.shared.deletePlace(place)
                
                await MainActor.run {
                    self.placeListDelegate?.placeListViewController(didDeletePlace: place)
                    // Show success feedback
                    HapticsHelper.thwompHaptic()
                    self.showToast(text: "Place deleted", sentiment: .positive)
                    
                    // Dismiss the sheet
                    self.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    // Show error feedback
                    HapticsHelper.failureHaptic()
                    saveButton.stopLoading(withSuccess: false)
                    self.showToast(text: "Failed to delete place", sentiment: .negative)
                    
                }
            }
        }
    }
    
    func showCopyFeedback() {
        HapticsHelper.lightHaptic()
        
        let copiedLabel = UILabel()
        copiedLabel.text = "Copied!"
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        copiedLabel.textAlignment = .center
        copiedLabel.layer.cornerRadius = 10
        copiedLabel.clipsToBounds = true
        copiedLabel.alpha = 0
        
        view.addSubview(copiedLabel)
        copiedLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            copiedLabel.centerXAnchor.constraint(equalTo: addressLabel.centerXAnchor),
            copiedLabel.centerYAnchor.constraint(equalTo: addressLabel.centerYAnchor),
            copiedLabel.widthAnchor.constraint(equalToConstant: 100),
            copiedLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        UIView.animate(withDuration: 0.2) {
            copiedLabel.alpha = 1
        }
        
        UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
            copiedLabel.alpha = 0
        }) { _ in
            copiedLabel.removeFromSuperview()
        }
    }
    
    
    private func configureReadOnlyMode() {
        // Disable editing
        titleField.isEnabled = false
    }
    
    func showTips() {
        guard existingPlace != nil && !isReadOnly else { return }
        
        trackScreenVisit()
        
        if NNTipManager.shared.shouldShowTip(PlaceDetailTips.editLocationTip) {
            NNTipManager.shared.showTip(
                PlaceDetailTips.editLocationTip,
                sourceView: infoButton,
                in: self,
                pinToEdge: .leading,
                offset: CGPoint(x: 8, y: 0)
            )
        }
    }
}

extension PlaceDetailViewController: PlaceAddressCellDelegate {
    func placeAddressCell(didTapThumbnail viewController: ImageViewerController) {
        //
    }
    
    func placeAddressCellAddressTapped(_ view: UIView, place: PlaceItem?) {
        let address = formatAddress(from: placemark)
        var coordinate: CLLocationCoordinate2D?
        if let existingPlace {
            coordinate = existingPlace.locationCoordinate
        }
        
        if let view = view as? UILabel {
            AddressActionHandler.presentAddressOptions(
                from: self,
                sourceView: addressLabel,
                address: address,
                coordinate: coordinate,
                onCopy: {
                    self.showCopyFeedback()
                }
            )
        }
    }
}

// MARK: - SelectPlaceLocationDelegate
extension PlaceDetailViewController: SelectPlaceLocationDelegate {
    func didUpdatePlaceLocation(
        _ place: PlaceItem,
        newAddress: String,
        newCoordinate: CLLocationCoordinate2D,
        newThumbnail: UIImage
    ) {
        // Store the pending changes
        pendingLocationUpdate = (newAddress, newCoordinate, newThumbnail)
        
        // Update UI with new location
        placemark = MKPlacemark(coordinate: newCoordinate)
        
        // Update the address label
        let attributedString = NSAttributedString(
            string: newAddress,
            attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: UIFont.bodyL
            ]
        )
        addressLabel.attributedText = attributedString
        
        // Update the map - remove old annotations and add new one
        mapView.removeAnnotations(mapView.annotations)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = newCoordinate
        annotation.title = placeAlias
        mapView.addAnnotation(annotation)
        
        let region = MKCoordinateRegion(
            center: newCoordinate,
            latitudinalMeters: 300,
            longitudinalMeters: 300
        )
        mapView.setRegion(region, animated: true)
        
        // Enable save button since location was updated
        hasUnsavedChanges = true
    }
}

// MARK: - Private Methods
private extension PlaceDetailViewController {
    @objc func titleFieldChanged() {
        placeAlias = titleField.text ?? ""
        checkForUnsavedChanges()
    }
    
    func checkForUnsavedChanges() {
        let aliasChanged = placeAlias != originalAlias
        let locationChanged = pendingLocationUpdate != nil
        
        hasUnsavedChanges = aliasChanged || locationChanged
    }
    
    func updateSaveButtonState() {
        if isReadOnly {
            saveButton.isHidden = true
            return
        }
        
        let hasChanges = hasUnsavedChanges || !isEditingPlace
        saveButton.isEnabled = hasChanges
        
        // Update button title
        let baseTitle = isEditingPlace ? "Update" : "Create"
        saveButton.setTitle(baseTitle)
    }
}

extension PlaceDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
