import UIKit
import MapKit
import Contacts
import RevenueCat
import RevenueCatUI

protocol PlaceSelectionDelegate: AnyObject {
    func didSelectPlace(_ place: PlaceItem)
}

protocol PlaceListViewControllerDelegate: AnyObject {
    func placeListViewController(didUpdatePlace place: PlaceItem)
    func placeListViewController(didDeletePlace place: PlaceItem)
}

protocol TemporaryPlaceSelectionDelegate: AnyObject {
    func didSelectTemporaryPlace(address: String, coordinate: CLLocationCoordinate2D)
}

final class PlaceListViewController: NNViewController, NNTippable {
    
    // MARK: - Properties
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, PlaceItem>!
    private var showTemporaryPlaces: Bool = false
    private var chooseOnMapButton: NNPrimaryLabeledButton?
    private var newPlaceButton: NNPrimaryLabeledButton?
    private var loadingIndicator: UIActivityIndicatorView!
    private var isLoading = false {
        didSet {
            updateLoadingState()
        }
    }
    
    enum LayoutStyle {
        case grid, list
    }
    
    private var currentLayout: LayoutStyle = UserDefaultsManager.shared.isPlacesListGridShowing ? .grid : .list {
        didSet {
            updateLayout()
            UserDefaultsManager.shared.isPlacesListGridShowing = currentLayout == .grid
        }
    }
    
    weak var delegate: PlaceListViewControllerDelegate?
    weak var selectionDelegate: PlaceSelectionDelegate?
    
    private var isSelecting: Bool = false
    var isReadOnly: Bool = false
    private var sitterViewService: SitterViewService?
    
    private var emptyStateView: NNEmptyStateView?
    
    // Replace PlacesService.shared.places dependency
    private var places: [PlaceItem] = []
    
    init(isSelecting: Bool = false, sitterViewService: SitterViewService? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.isSelecting = isSelecting
        self.sitterViewService = sitterViewService
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Enable large titles
        navigationController?.navigationBar.prefersLargeTitles = false
//        fetchPlaces()
    }
    
    // MARK: - Setup
    override func setup() {
        title = "Places"
        
        setupCollectionView()
        setupLoadingIndicator()
        configureDataSource()
        setupNavigationBarButtons()
        setupEmptyState()
        
        // Only show the "Choose on Map" button when in selection mode
        if isSelecting {
            setupChooseOnMapButton()
        } else if !isReadOnly {
            setupNewPlaceButton()
        }
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func updateLoadingState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.isLoading {
                self.loadingIndicator.startAnimating()
                self.collectionView.isHidden = true
                self.emptyStateView?.isHidden = true
            } else {
                self.loadingIndicator.stopAnimating()
                self.updateEmptyState()
            }
        }
    }
    
    override func setupNavigationBarButtons() {
        let layoutButton = UIBarButtonItem(
            image: UIImage(systemName: currentLayout == .grid ? "list.bullet" : "square.grid.2x2"),
            style: .plain,
            target: self,
            action: #selector(toggleLayout)
        )
        
        if !isReadOnly {
            let menuButton = UIBarButtonItem(
                image: UIImage(systemName: "ellipsis"),
                style: .plain,
                target: self,
                action: nil
            )
            
            if !isSelecting {
                let placeSuggestionsAction = UIAction(
                    title: "Place Suggestions",
                    image: UIImage(systemName: "sparkles")
                ) { _ in
                    self.placeSuggestionsTapped()
                }
                
                menuButton.menu = UIMenu(children: [placeSuggestionsAction])
                navigationItem.rightBarButtonItem = menuButton
            }
        }
        navigationItem.leftBarButtonItem = layoutButton
        navigationController?.navigationBar.tintColor = .label
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        
        // Adjust content inset to prevent button obstruction
        let buttonHeight: CGFloat = 50
        let buttonPadding: CGFloat = 10
        let totalInset = buttonHeight + buttonPadding * 2
        collectionView.contentInset.bottom = totalInset
        collectionView.verticalScrollIndicatorInsets.bottom = totalInset
        
        // Register cells
        collectionView.register(PlaceCell.self, forCellWithReuseIdentifier: PlaceCell.reuseIdentifier)
        collectionView.register(PlaceListCell.self, forCellWithReuseIdentifier: PlaceListCell.reuseIdentifier)
        
        if isSelecting {
            let insets = UIEdgeInsets(
                top: 0,
                left: 0,
                bottom: 100, // Increased to accommodate button height + padding
                right: 0
            )
            
            // Add bottom inset to accommodate the pinned button
            collectionView.contentInset = insets
            collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: insets.bottom - 30, right: 0)
        }
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func createLayout() -> UICollectionViewLayout {
        switch currentLayout {
        case .grid:
            return createGridLayout()
        case .list:
            return createListLayout()
        }
    }
    
    private func createListLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(80)  // Fixed height for list items
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
        
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: itemSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8  // Space between cells
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    private func createGridLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .fractionalWidth(0.6) // Fixed aspect ratio relative to width
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(0.6) // Match item height
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item, item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, PlaceItem>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, place in
            guard let self = self else { return UICollectionViewCell() }
            
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PlaceCell.reuseIdentifier,
                for: indexPath
            ) as! PlaceCell
            
            // Use the displayName property instead of alias
            // Force a layout pass after configuration
            cell.configure(with: place, isGridLayout: self.currentLayout == .grid)
            cell.layoutIfNeeded()
            
            return cell
        }
    }
    
    // MARK: - Data Loading
//    private func fetchPlaces() {
//        isLoading = true
//        
//        Task {
//            do {
//                // Check if we're in sitter mode and need visibility filtering
//                if let sitterService = sitterViewService {
//                    // Use SitterViewService to get filtered places
//                    self.places = try await sitterService.fetchNestPlaces()
//                } else {
//                    // Owner mode - fetch all places including temporary ones using NestService
//                    self.places = try await NestService.shared.fetchPlacesWithFilter(includeTemporary: true)
//                }
//                applySnapshot()
//            } catch {
//                Logger.log(level: .error, category: .placesService, 
//                    message: "Failed to fetch places: \(error.localizedDescription)")
//                
//                // Show error state in the UI
//                DispatchQueue.main.async { [weak self] in
//                    self?.showToast(text: "Failed to load places", sentiment: .negative)
//                }
//            }
//            
//            isLoading = false
//        }
//    }
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, PlaceItem>()
        snapshot.appendSections([.main])
        
        // Only show non-temporary places in the list view
        let placesToShow = places.filter { !$0.isTemporary }
        snapshot.appendItems(placesToShow)
        
        Task { @MainActor in
            await dataSource.apply(snapshot, animatingDifferences: true)
            updateEmptyState()
        }
    }
    
    // MARK: - Actions
    @objc private func addButtonTapped() {
        Task {
            let hasUnlimitedPlaces = await SubscriptionService.shared.isFeatureAvailable(.unlimitedPlaces)
            if !hasUnlimitedPlaces {
                let currentPlaceCount = places.filter { !$0.isTemporary }.count
                if currentPlaceCount >= 3 {
                    await MainActor.run {
                        self.showPlaceLimitAlert()
                    }
                    return
                }
            }
            
            await MainActor.run {
                let selectPlaceVC = SelectPlaceViewController()
                self.navigationController?.pushViewController(selectPlaceVC, animated: true)
            }
        }
    }
    
    private func placeSuggestionsTapped() {
        let commonPlacesVC = CommonPlacesViewController()
        commonPlacesVC.delegate = self
        let navController = UINavigationController(rootViewController: commonPlacesVC)
        present(navController, animated: true)
    }
    
    @objc private func toggleLayout() {
        currentLayout = currentLayout == .grid ? .list : .grid
        navigationItem.leftBarButtonItem?.image = UIImage(systemName: currentLayout == .grid ? "list.bullet" : "square.grid.2x2")
    }
    
    private func updateLayout() {
        // Only update the layout, don't reload data
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.setCollectionViewLayout(createLayout(), animated: true)
        collectionView.reloadData()
    }
    
    private func setupEmptyState() {
        emptyStateView = NNEmptyStateView(
            icon: UIImage(systemName: "mappin.and.ellipse"),
            title: "No Places Yet",
            subtitle: "Add your first place to get started",
            actionButtonTitle: "Add a Place"
        )
        emptyStateView?.isHidden = true
        
        emptyStateView?.delegate = self
        
        if let emptyStateView = emptyStateView {
            view.addSubview(emptyStateView)
            emptyStateView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
            ])
        }
    }
    
    private func updateEmptyState() {
        if isLoading {
            emptyStateView?.isHidden = true
            collectionView.isHidden = true
            newPlaceButton?.isHidden = true
            return
        }
        
        let isEmpty = places.isEmpty
        emptyStateView?.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
        
        // Show new place button only when there are places and we're not in selection mode
        if !isSelecting && !isReadOnly {
            newPlaceButton?.isHidden = isEmpty
        }
    }
    
    private func setupChooseOnMapButton() {
        chooseOnMapButton = NNPrimaryLabeledButton(title: "Choose on Map")
        chooseOnMapButton?.addTarget(self, action: #selector(chooseOnMapButtonTapped), for: .touchUpInside)
        
        if let button = chooseOnMapButton {
            button.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        }
    }
    
    private func setupNewPlaceButton() {
        newPlaceButton = NNPrimaryLabeledButton(title: "New Place", image: UIImage(systemName: "plus"))
        newPlaceButton?.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        newPlaceButton?.isHidden = true // Initially hidden
        
        if let button = newPlaceButton {
            button.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        }
    }
    
    @objc private func chooseOnMapButtonTapped() {
        // Dismiss the tip when the button is tapped
        NNTipManager.shared.dismissTip(PlaceListTips.chooseOnMapTip)
        
        let selectPlaceVC = SelectPlaceViewController()
        selectPlaceVC.isTemporarySelection = true
        selectPlaceVC.temporaryPlaceDelegate = self
        navigationController?.pushViewController(selectPlaceVC, animated: true)
    }
    
    private func flashCell(for place: PlaceItem) {
        guard let indexPath = dataSource?.indexPath(for: place),
              let cell = collectionView.cellForItem(at: indexPath) as? PlaceCell else { return }
        
        cell.flash()
    }
    
    func showTips() {
        trackScreenVisit()
        
        if isSelecting {
            // Show Quick Add tip for the Choose on Map button when in selection mode
            if let chooseOnMapButton = chooseOnMapButton,
               NNTipManager.shared.shouldShowTip(PlaceListTips.chooseOnMapTip) {
                NNTipManager.shared.showTip(
                    PlaceListTips.chooseOnMapTip,
                    sourceView: chooseOnMapButton,
                    in: self,
                    pinToEdge: .top,
                    offset: CGPoint(x: 0, y: -8)
                )
            }
        } else if !isReadOnly {
            // Show place suggestion tip for the menu button in normal mode
            guard let menuButton = navigationItem.rightBarButtonItems?.first else { return }
            
            if NNTipManager.shared.shouldShowTip(PlaceListTips.placeSuggestionTip) {
                if let buttonView = menuButton.value(forKey: "view") as? UIView {
                    NNTipManager.shared.showTip(
                        PlaceListTips.placeSuggestionTip,
                        sourceView: buttonView,
                        in: self,
                        pinToEdge: .bottom,
                        offset: CGPoint(x: -8, y: 0)
                    )
                }
            }
        }
    }
}

// MARK: - Section
extension PlaceListViewController {
    enum Section {
        case main
    }
}

// MARK: - UICollectionViewDelegate
extension PlaceListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let place = dataSource.itemIdentifier(for: indexPath),
              let cell = collectionView.cellForItem(at: indexPath) as? PlaceCell,
              let image = cell.thumbnailImageView.image else { return }
        
        if let selectionDelegate {
            selectionDelegate.didSelectPlace(place)
            dismiss(animated: true)
            return
        }
        
        let detailVC = PlaceDetailViewController(place: place, isReadOnly: isReadOnly)
        detailVC.placeListDelegate = self
        present(detailVC, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
}

// MARK: - PlaceListViewControllerDelegate
extension PlaceListViewController: PlaceListViewControllerDelegate {
    func placeListViewController(didUpdatePlace place: PlaceItem) {
        print("Attempting to update place: \(place.alias ?? "")")
        
        if navigationController?.viewControllers.count != 1 {
            navigationController?.popToRootViewController(animated: true)
        }
        
        // Check if this is a new place being added or an existing place being updated
        let isNewPlace = !places.contains { $0.id == place.id }
        
        // Create a fresh snapshot with the updated data
        var snapshot = NSDiffableDataSourceSnapshot<Section, PlaceItem>()
        snapshot.appendSections([.main])
        
        // Only show non-temporary places in the list view
        let placesToShow = places.filter { !$0.isTemporary }
        snapshot.appendItems(placesToShow)
        
        // Apply the snapshot on the main actor
        Task { @MainActor in
            await dataSource.apply(snapshot, animatingDifferences: true)
            updateEmptyState()
            
            // Flash the cell after the snapshot is applied
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.flashCell(for: place)
            }
        }
    }
    
    func placeListViewController(didDeletePlace place: PlaceItem) {
        var snapshot = dataSource.snapshot()
        snapshot.deleteItems([place])
        dataSource.apply(snapshot, animatingDifferences: true)
        showToast(text: "Place deleted", sentiment: .positive)
        updateEmptyState()
    }
}

// Add extension to implement the delegate
extension PlaceListViewController: TemporaryPlaceSelectionDelegate {
    func didSelectTemporaryPlace(address: String, coordinate: CLLocationCoordinate2D) {
        // Create a temporary place in memory only (not saved to Firestore yet)
        let temporaryPlace = NestService.shared.createTemporaryPlaceInMemory(
            address: address,
            coordinate: coordinate
        )
        
        // Notify the selection delegate
        DispatchQueue.main.async { [weak self] in
            self?.selectionDelegate?.didSelectPlace(temporaryPlace)
            self?.dismiss(animated: true)
        }
    }
}

extension PlaceListViewController: NNEmptyStateViewDelegate {
    func emptyStateViewDidTapActionButton(_ emptyStateView: NNEmptyStateView) {
        
        // Use the same action as the add button
        addButtonTapped()
    }
}

extension PlaceListViewController: CommonPlacesViewControllerDelegate {
    func commonPlacesViewController(_ controller: CommonPlacesViewController, didSelectPlace commonPlace: CommonPlace) {
        // Create and push the SelectPlaceViewController with the suggested place name
        let selectPlaceVC = SelectPlaceViewController()
        selectPlaceVC.suggestedPlaceName = commonPlace.name
        navigationController?.pushViewController(selectPlaceVC, animated: true)
    }
}
