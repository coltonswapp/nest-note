import UIKit
import Combine

final class OwnerHomeViewController: NNViewController, HomeViewControllerType {
    // MARK: - Properties
    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<HomeSection, HomeItem>!
    private var cancellables = Set<AnyCancellable>()
    private let nestService = NestService.shared
    private let sessionService = SessionService.shared
    private var currentSession: SessionItem?
    
    private lazy var loadingSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureDataSource()
        setupObservers()
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
        
        // Add loading spinner
        view.addSubview(loadingSpinner)
        NSLayoutConstraint.activate([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupObservers() {
        // Subscribe to nest changes
        NestService.shared.$currentNest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
            
        // Subscribe to session changes
        NotificationCenter.default.publisher(for: .sessionDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
            
        // Subscribe to user information updates
        NotificationCenter.default.publisher(for: .userInformationUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
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
        // Nest cell registration
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
        
        // Current session registration
        let currentSessionCellRegistration = UICollectionView.CellRegistration<CurrentSessionCell, HomeItem> { cell, indexPath, item in
            if case let .currentSession(session) = item {
                // Format duration with dates
                let formatter = DateIntervalFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                let duration = formatter.string(from: session.startDate, to: session.endDate) ?? ""
                
                // Get sitter name or email
                let sitterInfo = session.assignedSitter?.name ?? session.assignedSitter?.email ?? "No sitter assigned"
                
                cell.configure(title: sitterInfo, duration: duration)
                
                // Configure the cell's background
                var backgroundConfig = UIBackgroundConfiguration.listCell()
                backgroundConfig.backgroundColor = NNColors.primaryAlt
                backgroundConfig.cornerRadius = 12
                cell.backgroundConfiguration = backgroundConfig
            }
        }
        
        // Quick access registration
        let quickAccessCellRegistration = UICollectionView.CellRegistration<QuickAccessCell, HomeItem> { cell, indexPath, item in
            if case let .quickAccess(type) = item {
                let image: UIImage?
                let title: String
                
                switch type {
                case .ownerHousehold:
                    image = UIImage(systemName: "house")
                    title = "Household"
                case .ownerEmergency:
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
        
        // Configure data source
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .nest:
                return collectionView.dequeueConfiguredReusableCell(
                    using: nestCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .quickAccess:
                return collectionView.dequeueConfiguredReusableCell(
                    using: quickAccessCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .currentSession:
                return collectionView.dequeueConfiguredReusableCell(
                    using: currentSessionCellRegistration,
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
                title = "Your Nest"
                headerView.configure(title: title)
            case .quickAccess, .upcomingSessions, .events:
                return
            }
        }
        
        // Update the supplementaryViewProvider
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            if kind == UICollectionView.elementKindSectionHeader {
                return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            }
            return nil
        }
    }
    
    func applySnapshot(animatingDifferences: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<HomeSection, HomeItem>()
        
        // Current session section if available
        if let session = currentSession {
            snapshot.appendSections([.currentSession])
            snapshot.appendItems([.currentSession(session)], toSection: .currentSession)
        }
        
        // Nest section
        snapshot.appendSections([.nest])
        if let currentNest = nestService.currentNest {
            snapshot.appendItems([.nest(name: currentNest.name, address: currentNest.address)], toSection: .nest)
        } else {
            snapshot.appendItems([.nest(name: "No Nest Selected", address: "Please set up your nest")], toSection: .nest)
        }
        
        // Quick access section
        snapshot.appendSections([.quickAccess])
        snapshot.appendItems([
            .quickAccess(.ownerHousehold),
            .quickAccess(.ownerEmergency)
        ], toSection: .quickAccess)
        
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
    
    func refreshData() {
        guard let nestID = nestService.currentNest?.id else {
            applySnapshot(animatingDifferences: true)
            return
        }
        
        Task {
            do {
                loadingSpinner.startAnimating()
                let sessions = try await sessionService.fetchSessions(nestID: nestID)
                self.currentSession = sessions.inProgress.first
                
                DispatchQueue.main.async { [weak self] in
                    self?.loadingSpinner.stopAnimating()
                    self?.applySnapshot(animatingDifferences: true)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.loadingSpinner.stopAnimating()
                    self?.handleError(error)
                }
            }
        }
    }
    
    // MARK: - Navigation
    func presentHouseholdView() {
        guard let _ = nestService.currentNest else { return }
        navigationController?.pushViewController(NestViewController(entryRepository: NestService.shared), animated: true)
    }
    
    func presentCategoryView(category: String) {
        guard let _ = nestService.currentNest else { return }
        let categoryVC = NestCategoryViewController(category: category, entryRepository: NestService.shared)
        navigationController?.pushViewController(categoryVC, animated: true)
    }
    
    @objc private func settingsButtonTapped() {
        let settingsVC = SettingsViewController()
        let nav = UINavigationController(rootViewController: settingsVC)
        present(nav, animated: true)
    }
}

// MARK: - UICollectionViewDelegate
extension OwnerHomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch item {
        case .nest:
            presentHouseholdView()
        case .quickAccess(let type):
            switch type {
            case .ownerHousehold:
                presentCategoryView(category: "Household")
            case .ownerEmergency:
                presentCategoryView(category: "Emergency")
            default:
                break
            }
        case .currentSession(let session):
            let vc = EditSessionViewController(sessionItem: session)
            vc.modalPresentationStyle = .pageSheet
            present(vc, animated: true)
        default:
            break
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
} 
