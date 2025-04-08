import UIKit
import Combine

// MARK: - Notification Names
extension Notification.Name {
    static let sessionDidChange = Notification.Name("SessionDidChange")
}

final class SitterHomeViewController: NNViewController, HomeViewControllerType {
    // MARK: - Properties
    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<HomeSection, HomeItem>!
    private var cancellables = Set<AnyCancellable>()
    private let sitterViewService = SitterViewService.shared
    
    private lazy var loadingSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    private lazy var emptyStateView: NNEmptyStateView = {
        let view = NNEmptyStateView(
            icon: nil,
            title: "No Active Session",
            subtitle: "Your next session details will appear here",
            actionButtonTitle: "Join a Session"
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.delegate = self
        return view
    }()
    
    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureDataSource()
        setupObservers()
        refreshData()
    }
    
    override func setup() {
        super.setup()
        configureCollectionView()
        navigationItem.title = "NestNote"
        navigationItem.weeTitle = "Welcome to"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.tintColor = NNColors.primary
        
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsButtonTapped)
        )
        settingsButton.tintColor = .label
        navigationItem.rightBarButtonItem = settingsButton
        
        // Add loading spinner and empty state view
        view.addSubview(loadingSpinner)
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
    
    // MARK: - HomeViewControllerType Implementation
    func configureCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        view.addSubview(collectionView)
    }
    
    func configureDataSource() {
        // Cell registrations
        let nestCellRegistration = UICollectionView.CellRegistration<NestCell, HomeItem> { cell, indexPath, item in
            if case let .nest(name, address) = item {
                let image = UIImage(systemName: "house.lodge.fill")
                cell.configure(with: name, subtitle: address, image: image)
                cell.imageView.tintColor = .label
            }
            
            cell.backgroundColor = .secondarySystemGroupedBackground
            cell.layer.cornerRadius = 12
            cell.layer.masksToBounds = true
        }
        
        let quickAccessCellRegistration = UICollectionView.CellRegistration<QuickAccessCell, HomeItem> { cell, indexPath, item in
            if case let .quickAccess(type) = item {
                let image: UIImage?
                let title: String
                
                switch type {
                case .sitterHousehold:
                    image = UIImage(systemName: "house")
                    title = "Household"
                case .sitterEmergency:
                    image = UIImage(systemName: "light.beacon.max")
                    title = "Emergency"
                default:
                    return
                }
                
                cell.configure(with: title, image: image)
                cell.imageView.tintColor = .label
            }
            
            cell.backgroundColor = .secondarySystemGroupedBackground
            cell.layer.cornerRadius = 12
            cell.layer.masksToBounds = true
        }
        
        let currentSessionCellRegistration = UICollectionView.CellRegistration<CurrentSessionCell, HomeItem> { cell, indexPath, item in
            if case let .currentSession(session) = item {
                // Format duration manually since we can't access formattedDuration
                let formatter = DateIntervalFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                let duration = formatter.string(from: session.startDate, to: session.endDate) ?? ""
                
                cell.configure(title: session.title, duration: duration)
                
                // Configure the cell's background
                var backgroundConfig = UIBackgroundConfiguration.listCell()
                backgroundConfig.backgroundColor = NNColors.primaryAlt
                backgroundConfig.cornerRadius = 12
                cell.backgroundConfiguration = backgroundConfig
            }
        }
        
        // DataSource
        dataSource = UICollectionViewDiffableDataSource<HomeSection, HomeItem>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .nest:
                return collectionView.dequeueConfiguredReusableCell(
                    using: nestCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .currentSession:
                return collectionView.dequeueConfiguredReusableCell(
                    using: currentSessionCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .quickAccess:
                return collectionView.dequeueConfiguredReusableCell(
                    using: quickAccessCellRegistration,
                    for: indexPath,
                    item: item
                )
            default:
                fatalError("Unexpected item type")
            }
        }
        
        // Header registration
        let headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] headerView, elementKind, indexPath in
            guard let section = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section] else { return }
            
            let title: String
            switch section {
            case .currentSession:
                title = "In-progress session"
                headerView.configure(title: title)
            case .nest:
                title = "Session Nest"
                headerView.configure(title: title)
            case .quickAccess, .upcomingSessions, .events:
                return
            }
        }
        
        // Footer registration
        let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { supplementaryView, elementKind, indexPath in
            var configuration = supplementaryView.defaultContentConfiguration()
            
            // Configure footer based on section
//            if case .currentSession = self.dataSource.snapshot().sectionIdentifiers[indexPath.section] {
//                configuration.text = "Tap for session details"
//                configuration.textProperties.font = .preferredFont(forTextStyle: .footnote)
//                configuration.textProperties.color = .tertiaryLabel
//                configuration.textProperties.alignment = .center
//            }
            
            supplementaryView.contentConfiguration = configuration
        }
        
        // Update the supplementaryViewProvider
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            if kind == UICollectionView.elementKindSectionHeader {
                return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            } else {
                return collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
            }
        }
    }
    
    private func setupObservers() {
        // Subscribe to session changes
        NotificationCenter.default.publisher(for: .sessionDidChange)
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
//                self?.refreshData()
            }
            .store(in: &cancellables)
        
        // Subscribe to viewState changes
        sitterViewService.$viewState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleViewState(state)
            }
            .store(in: &cancellables)
    }
    
    private func handleViewState(_ state: SitterViewService.ViewState) {
        switch state {
        case .loading:
            collectionView.isHidden = true
            emptyStateView.isHidden = true
            loadingSpinner.startAnimating()
            
        case .ready(let session, let nest):
            loadingSpinner.stopAnimating()
            collectionView.isHidden = false
            emptyStateView.isHidden = true
            applySnapshot(session: session, nest: nest)
            
        case .noSession:
            loadingSpinner.stopAnimating()
            collectionView.isHidden = true
            emptyStateView.isHidden = false
            
        case .error(let error):
            loadingSpinner.stopAnimating()
            collectionView.isHidden = true
            emptyStateView.isHidden = false
            handleError(error)
        }
    }
    
    private func applySnapshot(session: SessionItem, nest: NestItem) {
        var snapshot = NSDiffableDataSourceSnapshot<HomeSection, HomeItem>()
        
        // Add current session section first
        snapshot.appendSections([.currentSession])
        snapshot.appendItems([.currentSession(session)], toSection: .currentSession)
        
        // Then add nest section with complete information
        snapshot.appendSections([.nest])
        snapshot.appendItems([.nest(name: nest.name, address: nest.address)], toSection: .nest)
        
        // Finally add quick access section
        snapshot.appendSections([.quickAccess])
        snapshot.appendItems([
            .quickAccess(.sitterHousehold),
            .quickAccess(.sitterEmergency)
        ], toSection: .quickAccess)
        
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func applyEmptySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<HomeSection, HomeItem>()
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    func refreshData() {
        Task {
            do {
                try await sitterViewService.fetchCurrentSession()
            } catch {
                handleError(error)
            }
        }
    }
    
    func handleError(_ error: Error) {
        // Handle errors appropriately
        print("Error: \(error.localizedDescription)")
    }
    
    // MARK: - Actions
    @objc private func settingsButtonTapped() {
        let settingsVC = SettingsViewController()
        let nav = UINavigationController(rootViewController: settingsVC)
        present(nav, animated: true)
    }
    
    func presentCategoryView(category: String) {
        guard sitterViewService.hasActiveSession else {
            // Show an alert that this is only available during an active session
            let alert = UIAlertController(
                title: "No Active Session",
                message: "Household information is only available during an active session.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let categoryVC = NestCategoryViewController(category: category, entryRepository: SitterViewService.shared)
        navigationController?.pushViewController(categoryVC, animated: true)
    }
    
    func presentHouseholdView() {
        navigationController?.pushViewController(NestViewController(entryRepository: SitterViewService.shared), animated: true)
    }
    
    // MARK: - Layout
    // Remove custom layout implementation to use the default one from HomeViewControllerType
    
    // Add this method to conform to HomeViewControllerType
    func applySnapshot(animatingDifferences: Bool) {
        // This is required for protocol conformance but we're using our own snapshot methods
        // Our view state handling takes care of applying snapshots
    }
}

// MARK: - UICollectionViewDelegate
extension SitterHomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch item {
        case .nest:
            // Navigate to NestViewController when tapping the nest cell
            presentHouseholdView()
            
        case .quickAccess(let type):
            switch type {
            case .sitterHousehold:
                presentCategoryView(category: "Household")
            case .sitterEmergency:
                presentCategoryView(category: "Emergency")
            default:
                break
            }
            
        case .currentSession(let session):
            if let nestName = sitterViewService.currentNestName {
                let detailVC = SitterSessionDetailViewController(session: session, nestName: nestName)
                present(detailVC, animated: true)
            }
            
        default:
            break
        }
    }
}

extension SitterHomeViewController: NNEmptyStateViewDelegate {
    func emptyStateViewDidTapActionButton(_ emptyStateView: NNEmptyStateView) {
        let joinVC = JoinSessionViewController()
        let nav = UINavigationController(rootViewController: joinVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }
} 
