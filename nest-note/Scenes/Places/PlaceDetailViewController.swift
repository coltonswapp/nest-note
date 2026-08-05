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

    private lazy var attachmentStackView: AttachmentStackView = {
        let stack = AttachmentStackView(stackSize: 80, expansionDirection: .left)
        stack.delegate = self
        return stack
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

    /// Working attachment IDs (pending until save).
    private var pendingAttachmentIds: [String] = []
    private var resolvedAttachments: [any BaseItem] = []
    private var originalAttachmentIds: [String] = []
    private var hasCompletedInitialAttachmentLoad = false
    
    override var allowsMinimizedSheetDetent: Bool { !isReadOnly }
    
    override var hasDiscardableContent: Bool {
        guard !isReadOnly else { return false }
        // New places already have a selected location; edits warn only when changed.
        return !isEditingPlace || hasUnsavedChanges
    }
    
    // Add property to track changes
    private var hasUnsavedChanges: Bool = false {
        didSet {
            updateSaveButtonState()
        }
    }
    
    // MARK: - Initialization
    init(placemark: CLPlacemark, alias: String, category: String = "Places", thumbnail: UIImage? = nil, sourceFrame: CGRect? = nil) {
        self.placemark = placemark
        self.placeAlias = alias
        self.category = category
        self.thumbnail = thumbnail
        self.thumbnailAsset = thumbnail?.imageAsset
        self.isEditingPlace = false
        super.init(sourceFrame: sourceFrame)
    }
    
    init(place: PlaceItem, thumbnail: UIImage? = nil, isReadOnly: Bool = false, sourceFrame: CGRect? = nil) {
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
        super.init(sourceFrame: sourceFrame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = existingPlace == nil ? "New Place" : isReadOnly ? "View Place" : "Edit Place"
        originalAlias = existingPlace?.alias
        pendingAttachmentIds = existingPlace?.attachmentIds ?? []
        originalAttachmentIds = pendingAttachmentIds
        
        itemsHiddenDuringTransition = isReadOnly
            ? [attachmentStackView]
            : [buttonStackView, attachmentStackView]
        setupContent()
        setupMapView()
        updateSaveButtonState()
        configureFolderLabel()
        refreshAttachmentStack()
        loadResolvedAttachments()
        
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
        let menu = createMenu()
        let hasActions = !menu.children.isEmpty
        setLeadingBarButtonHidden(!hasActions)
        if hasActions {
            setLeadingBarButtonMenu(menu)
        }
    }
    
    override func addContentToContainer() {
        super.addContentToContainer()
        
        if !isReadOnly {
            buttonStackView.addArrangedSubview(saveButton)
        }
        
        containerView.addSubview(mapView)
        containerView.addSubview(addressLabel)
        containerView.addSubview(folderLabel)
        containerView.addSubview(attachmentStackView)
        containerView.addSubview(buttonStackView)

        folderLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        folderLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        attachmentStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        attachmentStackView.setContentHuggingPriority(.required, for: .horizontal)
        
        // Start slightly larger when keyboard is hidden
        mapHeightConstraint = mapView.heightAnchor.constraint(equalToConstant: expandedMapHeight)

        var constraints: [NSLayoutConstraint] = [
            // Map view constraints
            mapView.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 16),
            mapView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            mapView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            mapHeightConstraint!,
            
            // Address label constraints
            addressLabel.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 16),
            addressLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            addressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Same row above CTA: folder left, attachments right
            folderLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            folderLabel.trailingAnchor.constraint(lessThanOrEqualTo: attachmentStackView.leadingAnchor, constant: -12),
            folderLabel.heightAnchor.constraint(equalToConstant: 30),

            attachmentStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            buttonStackView.heightAnchor.constraint(equalToConstant: 46),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Self.ctaBottomPadding),
        ]

        if !isReadOnly {
            constraints.append(contentsOf: [
                folderLabel.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -12),
                attachmentStackView.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -12),
                addressLabel.bottomAnchor.constraint(lessThanOrEqualTo: attachmentStackView.topAnchor, constant: -16),
                saveButton.widthAnchor.constraint(equalTo: buttonStackView.widthAnchor),
            ])
        } else {
            constraints.append(contentsOf: [
                folderLabel.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -12),
                attachmentStackView.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -12),
                addressLabel.bottomAnchor.constraint(lessThanOrEqualTo: attachmentStackView.topAnchor, constant: -16),
            ])
        }

        NSLayoutConstraint.activate(constraints)

        attachmentStackView.pinVariableBlur(to: containerView, direction: .bottom, blurRadius: 20, height: 140)
        containerView.bringSubviewToFront(folderLabel)
        containerView.bringSubviewToFront(attachmentStackView)
        containerView.bringSubviewToFront(buttonStackView)
        containerView.clipsToBounds = true
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

                let allItems = try await NestService.shared.fetchAllItems()
                let prunedAttachmentIds = AttachmentResolver.prune(
                    ids: pendingAttachmentIds,
                    against: allItems,
                    excludingHostId: existingPlace?.id
                )
                
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
                        updatedAt: Date(),
                        attachmentIds: prunedAttachmentIds
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
                            thumbnailURLs: existingPlace.thumbnailURLs, // Will be replaced by new method
                            isTemporary: existingPlace.isTemporary,
                            createdAt: existingPlace.createdAt,
                            updatedAt: Date(),
                            attachmentIds: prunedAttachmentIds
                        )

                        // Use enhanced update method with thumbnail regeneration
                        updatedPlace = try await NestService.shared.updatePlace(
                            updatedPlace,
                            shouldRegenerateThumbnails: true,
                            newCoordinate: locationUpdate.coordinate
                        )
                    } else {
                        // No location change - use standard update
                        try await NestService.shared.updatePlace(updatedPlace)
                    }
                    
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
                        thumbnailAsset: asset,
                        attachmentIds: prunedAttachmentIds
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
        collapseAttachmentsIfNeeded()
        placeDelegate?.placeAddressCellAddressTapped(addressLabel, place: existingPlace)
    }

    override func leadingMenuWillPresent() {
        collapseAttachmentsIfNeeded()
    }

    override func prepareForCompactDraftMode() {
        collapseAttachmentsIfNeeded()
    }

    private func collapseAttachmentsIfNeeded() {
        attachmentStackView.collapseIfNeeded()
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
        var menuChildren: [UIMenuElement] = []
        var topActions: [UIAction] = []

        if !isReadOnly {
            let attachTitle = pendingAttachmentIds.isEmpty ? "Add Attachment" : "Manage Attachments"
            let attachAction = UIAction(
                title: attachTitle,
                image: UIImage(systemName: "paperclip")
            ) { [weak self] _ in
                self?.presentAttachmentPicker()
            }
            topActions.append(attachAction)
        }
        
        // Only show edit/delete if we have an existing place
        if existingPlace != nil {
            if !isReadOnly {
                let editAction = UIAction(
                    title: "Edit Location",
                    image: UIImage(systemName: "mappin.and.ellipse")
                ) { [weak self] _ in
                    self?.handleEditLocation()
                }
                topActions.append(editAction)
            }

            if !topActions.isEmpty {
                menuChildren.append(UIMenu(title: "", options: .displayInline, children: topActions))
            }
            
            if !isReadOnly {
                let deleteAction = UIAction(
                    title: "Delete Place",
                    image: UIImage(systemName: "trash"),
                    attributes: .destructive
                ) { [weak self] _ in
                    self?.handleDelete()
                }
                menuChildren.append(deleteAction)
            }
        } else if !topActions.isEmpty {
            menuChildren.append(UIMenu(title: "", options: .displayInline, children: topActions))
        }
        
        return UIMenu(children: menuChildren)
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
        guard !isReadOnly else { return }

        trackScreenVisit()

        if existingPlace != nil,
           NNTipManager.shared.shouldShowTip(PlaceDetailTips.editLocationTip) {
            NNTipManager.shared.showTip(
                PlaceDetailTips.editLocationTip,
                sourceView: navigationBar,
                in: self,
                pinToEdge: .leading,
                offset: CGPoint(x: 8, y: 0)
            )
            return
        }

        if NNTipManager.shared.shouldShowTip(AttachmentTips.attachItemsTip) {
            NNTipManager.shared.showTip(
                AttachmentTips.attachItemsTip,
                sourceView: attachmentStackView,
                in: self,
                pinToEdge: .top,
                offset: CGPoint(x: 0, y: -8)
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
        collapseAttachmentsIfNeeded()
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
        collapseAttachmentsIfNeeded()
        placeAlias = titleField.text ?? ""
        checkForUnsavedChanges()
    }
    
    func checkForUnsavedChanges() {
        let aliasChanged = placeAlias != originalAlias
        let locationChanged = pendingLocationUpdate != nil
        let attachmentsChanged = pendingAttachmentIds != originalAttachmentIds
        
        hasUnsavedChanges = aliasChanged || locationChanged || attachmentsChanged
    }

    // MARK: - Attachments

    func refreshAttachmentStack() {
        attachmentStackView.configure(
            items: resolvedAttachments,
            showsPlus: !isReadOnly,
            allowsRemoval: !isReadOnly
        )
        loadPlaceThumbnailsForAttachments()
        if !isReadOnly {
            setupInfoButton()
        }
    }

    func loadResolvedAttachments() {
        guard !pendingAttachmentIds.isEmpty else {
            hasCompletedInitialAttachmentLoad = true
            resolvedAttachments = []
            refreshAttachmentStack()
            return
        }

        Task {
            do {
                let items = try await fetchItemsForAttachmentResolution()
                let resolved = AttachmentResolver.resolve(
                    ids: pendingAttachmentIds,
                    from: items,
                    excludingHostId: existingPlace?.id
                )
                await MainActor.run {
                    self.resolvedAttachments = resolved
                    self.pendingAttachmentIds = resolved.map(\.id)
                    if !self.hasCompletedInitialAttachmentLoad {
                        self.originalAttachmentIds = self.pendingAttachmentIds
                        self.hasCompletedInitialAttachmentLoad = true
                    }
                    self.refreshAttachmentStack()
                    self.checkForUnsavedChanges()
                }
            } catch {
                Logger.log(
                    level: .error,
                    category: .general,
                    message: "Failed to resolve place attachments: \(error.localizedDescription)"
                )
            }
        }
    }

    func fetchItemsForAttachmentResolution() async throws -> [BaseItem] {
        if isReadOnly {
            return try await SitterViewService.shared.itemsForAttachmentResolution()
        }
        return try await NestService.shared.itemsForAttachmentResolution()
    }

    func loadPlaceThumbnailsForAttachments() {
        for item in resolvedAttachments {
            guard let place = item as? PlaceItem else { continue }
            Task {
                do {
                    let image: UIImage
                    if isReadOnly {
                        image = try await SitterViewService.shared.loadImages(for: place)
                    } else {
                        image = try await NestService.shared.loadImages(for: place)
                    }
                    await MainActor.run {
                        self.attachmentStackView.setPreviewImage(image, forItemId: place.id)
                    }
                } catch {
                    // Keep icon fallback
                }
            }
        }
    }

    func presentAttachmentPicker() {
        collapseAttachmentsIfNeeded()
        NNTipManager.shared.dismissTip(AttachmentTips.attachItemsTip)
        AttachmentPickerPresenter.present(
            from: self,
            selectedIds: pendingAttachmentIds,
            excludingHostId: existingPlace?.id
        ) { [weak self] ids in
            guard let self else { return }
            self.pendingAttachmentIds = ids
            self.loadResolvedAttachments()
            self.checkForUnsavedChanges()
        }
    }
    
    func updateSaveButtonState() {
        defer { refreshCompactDetentAvailability() }

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
    func textFieldDidBeginEditing(_ textField: UITextField) {
        collapseAttachmentsIfNeeded()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - AttachmentStackViewDelegate
extension PlaceDetailViewController: AttachmentStackViewDelegate {
    func attachmentStackView(_ stackView: AttachmentStackView, didTapItem item: any BaseItem) {
        NestItemDetailRouter.presentDetail(
            for: item,
            from: self,
            nestItemRepository: isReadOnly ? SitterViewService.shared : NestService.shared,
            category: item.category,
            sourceFrame: stackView.convert(stackView.bounds, to: nil),
            placeListDelegate: nil,
            noteDelegate: nil,
            routineDelegate: nil,
            contactDelegate: nil
        )
    }

    func attachmentStackViewDidTapPlus(_ stackView: AttachmentStackView) {
        presentAttachmentPicker()
    }

    func attachmentStackView(_ stackView: AttachmentStackView, didChangeExpanded isExpanded: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.folderLabel.alpha = isExpanded ? 0 : 1
        }
        folderLabel.isUserInteractionEnabled = !isExpanded
    }

    func attachmentStackView(_ stackView: AttachmentStackView, didRequestRemoveItem item: any BaseItem) {
        pendingAttachmentIds.removeAll { $0 == item.id }
        resolvedAttachments.removeAll { $0.id == item.id }
        // Stack already animated the drop; keep local state in sync without rebuilding.
        checkForUnsavedChanges()
        if !isReadOnly {
            setupInfoButton()
        }
    }
}
