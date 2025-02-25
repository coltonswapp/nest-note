import UIKit
import MapKit
import Contacts

protocol PlaceSelectionDelegate: AnyObject {
    func didSelectPlace(_ place: Place)
}

protocol PlaceListViewControllerDelegate: AnyObject {
    func placeListViewController(didUpdatePlace place: Place)
    func placeListViewController(didDeletePlace place: Place)
}

final class PlaceListViewController: NNViewController {
    
    // MARK: - Properties
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Place>!
    
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
    
    private var emptyStateView: NNEmptyStateView?
    
    init(isSelecting: Bool = false) {
        super.init(nibName: nil, bundle: nil)
        self.isSelecting = isSelecting
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Enable large titles
        navigationController?.navigationBar.prefersLargeTitles = false
        fetchPlaces()
    }
    
    // MARK: - Setup
    override func setup() {
        title = "Places"
        
        setupCollectionView()
        configureDataSource()
        setupNavigationBarButtons()
        setupEmptyState()
    }
    
    override func setupNavigationBarButtons() {
        let layoutButton = UIBarButtonItem(
            image: UIImage(systemName: currentLayout == .grid ? "list.bullet" : "square.grid.2x2"),
            style: .plain,
            target: self,
            action: #selector(toggleLayout)
        )
        
        let addButton = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addButtonTapped)
        )
        
        navigationItem.rightBarButtonItem = addButton
        navigationItem.leftBarButtonItem = layoutButton
        navigationController?.navigationBar.tintColor = .label
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        
        // Adjust content inset to prevent button obstruction
        let bottomInset: CGFloat = view.safeAreaInsets.bottom + 20
        collectionView.contentInset.bottom = bottomInset
        collectionView.verticalScrollIndicatorInsets.bottom = bottomInset
        
        // Register cells
        collectionView.register(PlaceCell.self, forCellWithReuseIdentifier: PlaceCell.reuseIdentifier)
        collectionView.register(PlaceListCell.self, forCellWithReuseIdentifier: PlaceListCell.reuseIdentifier)
        
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
        dataSource = UICollectionViewDiffableDataSource<Section, Place>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, place in
            guard let self = self else { return UICollectionViewCell() }
            
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PlaceCell.reuseIdentifier,
                for: indexPath
            ) as! PlaceCell
            
            // Force a layout pass after configuration
            cell.configure(with: place, isGridLayout: self.currentLayout == .grid)
            cell.layoutIfNeeded()
            
            return cell
        }
    }
    
    // MARK: - Data Loading
    private func fetchPlaces() {
        Task {
            do {
                // Just fetch and apply - no need to store locally
                _ = try await PlacesService.shared.fetchPlaces()
                applySnapshot()
            } catch {
                Logger.log(level: .error, category: .placesService, 
                    message: "Failed to fetch places: \(error.localizedDescription)")
            }
        }
    }
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Place>()
        snapshot.appendSections([.main])
        snapshot.appendItems(PlacesService.shared.places)
        
        Task { @MainActor in
            await dataSource.apply(snapshot, animatingDifferences: true)
            updateEmptyState()
        }
    }
    
    // MARK: - Actions
    @objc private func addButtonTapped() {
        let selectPlaceVC = SelectPlaceViewController()
        navigationController?.pushViewController(selectPlaceVC, animated: true)
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
            subtitle: "Add your first place by tapping the + button"
        )
        emptyStateView?.isHidden = true
        
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
        emptyStateView?.isHidden = !PlacesService.shared.places.isEmpty
        collectionView.isHidden = PlacesService.shared.places.isEmpty
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
        
        let detailVC = PlaceDetailViewController(place: place, thumbnail: image)
        detailVC.delegate = self
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
}

// MARK: - PlaceListViewControllerDelegate
extension PlaceListViewController: PlaceListViewControllerDelegate {
    func placeListViewController(didUpdatePlace place: Place) {
        print("Attempting to update place: \(place.alias)")
        
        // Create a fresh snapshot with the latest data
        var snapshot = NSDiffableDataSourceSnapshot<Section, Place>()
        snapshot.appendSections([.main])
        let places = PlacesService.shared.places
        snapshot.appendItems(places)
        
        // Find the updated place in the service's array
        if let updatedPlace = places.first(where: { $0.id == place.id }) {
            // Reconfigure just this item
            snapshot.reconfigureItems([updatedPlace])
        }
        
        dataSource.apply(snapshot, animatingDifferences: false)

        showToast(text: "Place updated", sentiment: .positive)
    }
    
    func placeListViewController(didDeletePlace place: Place) {
        var snapshot = dataSource.snapshot()
        snapshot.deleteItems([place])
        dataSource.apply(snapshot, animatingDifferences: true)
        showToast(text: "Place deleted", sentiment: .positive)
        updateEmptyState()
    }
}
