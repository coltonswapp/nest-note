import UIKit
import MapKit
import Contacts

final class PlaceDetailViewController: NNViewController {
    
    // MARK: - Properties
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    private var saveButton: NNLoadingButton!
    
    private var existingPlace: Place?
    private var placemark: CLPlacemark
    private var alias: String = ""
    private var thumbnailAsset: UIImageAsset?
    private var thumbnail: UIImage?
    
    // Add property to track changes
    private var hasUnsavedChanges: Bool = false {
        didSet {
            updateSaveButtonState()
        }
    }
    
    private let isEditingPlace: Bool
    
    private var originalAlias: String?
    
    private var pendingLocationUpdate: (address: String, coordinate: CLLocationCoordinate2D, thumbnail: UIImage)?
    
    weak var delegate: PlaceListViewControllerDelegate?
    
    // MARK: - Initialization
    init(placemark: CLPlacemark, thumbnail: UIImage) {
        self.placemark = placemark
        self.thumbnail = thumbnail
        self.thumbnailAsset = thumbnail.imageAsset
        self.isEditingPlace = false
        super.init(nibName: nil, bundle: nil)
    }
    
    init(place: Place, thumbnail: UIImage) {
        self.existingPlace = place
        self.placemark = MKPlacemark(
            coordinate: place.locationCoordinate,
            addressDictionary: [CNPostalAddressStreetKey: place.address]
        )
        self.alias = place.alias ?? "Temporary Place"
        self.thumbnail = thumbnail
        self.thumbnailAsset = thumbnail.imageAsset
        
        self.isEditingPlace = true
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        originalAlias = existingPlace?.alias
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    override func setup() {
        title = "Place Details"
        configureCollectionView()
        configureDataSource()
        applyInitialSnapshots()
        setupNavigationBarButtons()
        setupSaveButton()
        updateSaveButtonState()
    }
    
    // MARK: - Collection View Setup
    private func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        
        let insets = UIEdgeInsets(
            top: 20,
            left: 0,
            bottom: 100,
            right: 0
        )
        
        collectionView.contentInset = insets
        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: insets.bottom - 30, right: 0)
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            config.footerMode = .supplementary
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
            section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18)
            return section
        }
        return layout
    }
    
    // MARK: - Data Source
    private enum Section {
        case name
        case address
    }
    
    enum Item: Hashable {
        case name(String)
        case address(String)
    }
    
    private func configureDataSource() {
        let nameRegistration = UICollectionView.CellRegistration<PlaceNameCell, Item> { [weak self] cell, indexPath, item in
            if case .name = item {
                cell.configure(with: item)
                cell.delegate = self
            }
        }
        
        let addressRegistration = UICollectionView.CellRegistration<PlaceAddressCell, Item> { [weak self] cell, indexPath, item in
            if case let .address(address) = item {
                cell.configure(with: address, thumbnail: self?.thumbnail)
                cell.delegate = self
            }
        }
        
        let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] supplementaryView, elementKind, indexPath in
            guard let self = self else { return }
            var configuration = supplementaryView.defaultContentConfiguration()
            
            switch self.dataSource.sectionIdentifier(for: indexPath.section) {
            case .name:
                configuration.text = "Add a friendly name for your place"
            case .address:
                configuration.text = "Tap thumbnail to enlarge"
            default:
                break
            }
            
            configuration.textProperties.font = .preferredFont(forTextStyle: .footnote)
            configuration.textProperties.color = .tertiaryLabel
            configuration.textProperties.alignment = .center
            
            supplementaryView.contentConfiguration = configuration
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .name:
                return collectionView.dequeueConfiguredReusableCell(using: nameRegistration, for: indexPath, item: item)
            case .address:
                return collectionView.dequeueConfiguredReusableCell(using: addressRegistration, for: indexPath, item: item)
            }
        }
        
        dataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
            return collectionView.dequeueConfiguredReusableSupplementary(
                using: footerRegistration,
                for: indexPath
            )
        }
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.name, .address])
        
        // Use existing place's alias or empty string for new places
        snapshot.appendItems([.name(alias)], toSection: .name)
        snapshot.appendItems([.address(formatAddress(from: placemark))], toSection: .address)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    // MARK: - Actions
    private func setupSaveButton() {
        saveButton = NNLoadingButton(
            title: existingPlace != nil ? "Update Place" : "Save Place",
            titleColor: .white,
            fillStyle: .fill(NNColors.primary)
        )
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        saveButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        saveButton.isEnabled = !isEditingPlace
    }
    
    @objc private func saveButtonTapped() {
        guard !alias.isEmpty else {
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
                    var updatedPlace = existingPlace
                    updatedPlace.alias = alias
                    
                    // Apply pending location update if exists
                    if let locationUpdate = pendingLocationUpdate {
                        updatedPlace.address = locationUpdate.address
                        updatedPlace.coordinate = .init(
                            latitude: locationUpdate.coordinate.latitude,
                            longitude: locationUpdate.coordinate.longitude
                        )
                        
                        // Update with new thumbnail
                        try await PlacesService.shared.updatePlace(
                            updatedPlace,
                            thumbnailAsset: thumbnailAsset
                        )
                    } else {
                        // Just update the alias
                        try await PlacesService.shared.updatePlace(updatedPlace)
                    }
                    
                    Task {
                        delegate?.placeListViewController(didUpdatePlace: updatedPlace)
                        saveButton.stopLoading(withSuccess: true)
                        try await Task.sleep(nanoseconds: 400_000_000)
                        
                        await MainActor.run {
                            navigationController?.popToRootViewController(animated: true)
                        }
                    }
                } else {
                    // Create new place
                    guard let thumbnail = thumbnail else { return }
                    
                    let address = formatAddress(from: placemark)
                    let coordinate = placemark.location?.coordinate ?? CLLocationCoordinate2D()
                    
                    let asset = thumbnailAsset ?? {
                        Logger.log(level: .error, category: .placesService,
                            message: "No thumbnail asset available, falling back to single image")
                        let asset = UIImageAsset()
                        asset.register(thumbnail, with: UITraitCollection(userInterfaceStyle: .light))
                        asset.register(thumbnail, with: UITraitCollection(userInterfaceStyle: .dark))
                        return asset
                    }()
                    
                    let newPlace = try await PlacesService.shared.createPlace(
                        alias: alias,
                        address: address,
                        coordinate: coordinate,
                        thumbnailAsset: asset
                    )
                    
                    await MainActor.run {
                        // Show success feedback
                        HapticsHelper.thwompHaptic()
                        showToast(text: "Place saved", sentiment: .positive)
                        
                        // Pop to root and notify delegate to refresh
                        if let placeListVC = navigationController?.viewControllers.first as? PlaceListViewController {
                            placeListVC.placeListViewController(didUpdatePlace: newPlace)
                        }
                        navigationController?.popToRootViewController(animated: true)
                    }
                }
            } catch {
                Logger.log(level: .error, category: .placesService, 
                    message: "Failed to save place: \(error.localizedDescription)")
                
                await MainActor.run {
                    saveButton.stopLoading()
                    HapticsHelper.failureHaptic()
                    showToast(text: "Failed to save changes", sentiment: .negative)
                }
            }
        }
    }
    
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
    
    override func setupNavigationBarButtons() {
        // Only show edit/delete menu if we're editing an existing place
        if existingPlace != nil {
            let menuButton = UIBarButtonItem(
                image: UIImage(systemName: "ellipsis"),
                menu: createMenu()
            )
            navigationItem.rightBarButtonItem = menuButton
        }
        
        navigationController?.navigationBar.tintColor = .label
    }
    
    private func createMenu() -> UIMenu {
        let editAction = UIAction(
            title: "Edit Location",
            image: UIImage(systemName: "mappin.and.ellipse")
        ) { [weak self] _ in
            guard let self = self,
                  let place = self.existingPlace else { return }
            
            let selectPlaceVC = SelectPlaceViewController(placeToEdit: place)
            selectPlaceVC.locationDelegate = self
            self.navigationController?.pushViewController(selectPlaceVC, animated: true)
        }
        
        let deleteAction = UIAction(
            title: "Delete Place",
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.handleDelete()
        }
        
        return UIMenu(children: [editAction, deleteAction])
    }
    
    private func updateSaveButtonState() {
        saveButton.isEnabled = !isEditingPlace || hasUnsavedChanges
        
        // Update button title to show state
        let baseTitle = isEditingPlace ? "Update Place" : "Save Place"
        saveButton.titleLabel.text = hasUnsavedChanges ? baseTitle : baseTitle
        
        // Optionally animate the button if there are changes
        if hasUnsavedChanges {
            saveButton.transform = .identity
            UIView.animate(withDuration: 0.3, delay: 0, options: [.allowUserInteraction]) {
                self.saveButton.transform = .identity
            }
        }
    }
    
    @objc private func dismissTapped() {
        closeButtonTapped()
    }
    
    @objc private func actionsButtonTapped() {
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
        
        Task {
            do {
                try await PlacesService.shared.deletePlace(place)
                
                await MainActor.run {
                    delegate?.placeListViewController(didDeletePlace: place)
                    // Show success feedback
                    HapticsHelper.thwompHaptic()
                    showToast(text: "Place deleted", sentiment: .positive)
                    
                    // Dismiss or pop based on presentation style
                    if navigationController?.viewControllers.count ?? 0 <= 1 {
                        dismiss(animated: true)
                    } else {
                        navigationController?.popViewController(animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    // Show error feedback
                    HapticsHelper.failureHaptic()
                    showToast(text: "Failed to delete place", sentiment: .negative)
                }
            }
        }
    }
}

// MARK: - PlaceNameCellDelegate
extension PlaceDetailViewController: PlaceNameCellDelegate {
    func placeNameCell(_ cell: PlaceNameCell, didUpdateAlias alias: String) {
        self.alias = alias
        hasUnsavedChanges = alias != originalAlias
    }
}

// MARK: - PlaceAddressCellDelegate
extension PlaceDetailViewController: PlaceAddressCellDelegate {
    func placeAddressCell(didTapThumbnail viewController: ImageViewerController) {
        present(viewController, animated: true)
    }
    
    func placeAddressCellAddressTapped(_ view: UIView, place: Place?) {
        let address = formatAddress(from: placemark)
        var coordinate: CLLocationCoordinate2D?
        if let existingPlace {
            coordinate = CLLocationCoordinate2D(latitude: self.existingPlace!.coordinate.latitude, longitude: self.existingPlace!.coordinate.longitude)
        }
        
        if let view = view as? PlaceAddressCell {
            AddressActionHandler.presentAddressOptions(
                from: self,
                sourceView: view.addressLabel,
                address: address,
                coordinate: coordinate,
                onCopy: {
                    view.showCopyFeedback()
                }
            )
        }
    }
}

extension PlaceDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return false
    }
}

// MARK: - SelectPlaceLocationDelegate
extension PlaceDetailViewController: SelectPlaceLocationDelegate {
    func didUpdatePlaceLocation(
        _ place: Place,
        newAddress: String,
        newCoordinate: CLLocationCoordinate2D,
        newThumbnail: UIImage
    ) {
        // Store the pending changes
        pendingLocationUpdate = (newAddress, newCoordinate, newThumbnail)
        
        self.thumbnail = newThumbnail
        self.thumbnailAsset = newThumbnail.imageAsset
        
        // Update UI with new location
        placemark = MKPlacemark(coordinate: newCoordinate)
        
        // Create a new snapshot instead of reconfiguring
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.name, .address])
        
        // Keep the existing name
        snapshot.appendItems([.name(alias)], toSection: .name)
        
        // Add the new address
        snapshot.appendItems([.address(newAddress)], toSection: .address)
        
        // Apply the new snapshot
        dataSource.apply(snapshot, animatingDifferences: true)
        
        // Enable save button
        hasUnsavedChanges = true
    }
}
