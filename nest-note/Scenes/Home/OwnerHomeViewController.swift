import UIKit
import Combine
import FirebaseMessaging
import TipKit

final class OwnerHomeViewController: NNViewController, HomeViewControllerType {
    // MARK: - Properties
    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<HomeSection, HomeItem>!
    private var cancellables = Set<AnyCancellable>()
    private let nestService = NestService.shared
    private let sessionService = SessionService.shared
    private let setupService = SetupService.shared
    private var currentSession: SessionItem?
    private var pinnedCategories: [String] = []
    private var categories: [NestCategory] = []
    
    // Track whether we've checked if setup should be shown
    private var hasCheckedSetupStatus = false
    
    // Track whether we've already shown the setup tip in this session
    private var hasShownSetupTip = false
    
    private var hasCompletedSetup: Bool {
        return setupService.hasCompletedSetup
    }
    
    private var setupProgress: Int {
        // Count the number of completed steps
        return SetupStepType.allCases.filter { setupService.isStepComplete($0) }.count
    }
    
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
        Logger.log(level: .info, category: .general, message: "Setup completion status: \(hasCompletedSetup ? "Completed" : "Not Completed"), Steps completed: \(setupProgress)/\(SetupStepType.allCases.count)")
        
        // Check setup status when the view loads
        checkSetupStatus()
        
//        setFCMToken()
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
        
        // Handle session status changes specifically
        NotificationCenter.default.publisher(for: .sessionStatusDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                // Check if the status change affects the current session
                if let sessionId = notification.userInfo?["sessionId"] as? String,
                   let newStatus = notification.userInfo?["newStatus"] as? String,
                   let currentSessionId = self?.currentSession?.id,
                   sessionId == currentSessionId {
                    Logger.log(level: .info, category: .sessionService, message: "Current session status changed to: \(newStatus)")
                    
                    // If the session is no longer in progress, immediately refresh
                    if newStatus != SessionStatus.inProgress.rawValue {
                        self?.currentSession = nil
                        self?.applySnapshot(animatingDifferences: true)
                    }
                }
                
                // Refresh data from server to ensure UI is up-to-date
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
        
        // Subscribe to setup step completion updates
        NotificationCenter.default.publisher(for: .setupStepDidComplete)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Update the setup progress immediately
                self?.applySnapshot(animatingDifferences: true)
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
                let duration = formatter.string(from: session.startDate, to: session.endDate)
                
                // Get sitter name or email
                let sitterInfo: String? = session.assignedSitter?.name ?? session.assignedSitter?.email
                
                let durationText: String = sitterInfo == nil ? "No sitter assigned • \(duration)" : "\(sitterInfo!) • \(duration)"
                
                cell.configure(title: session.title, duration: durationText)
                
                // Configure the cell's background
                var backgroundConfig = UIBackgroundConfiguration.listCell()
                backgroundConfig.backgroundColor = NNColors.primaryAlt
                backgroundConfig.cornerRadius = 12
                cell.backgroundConfiguration = backgroundConfig
            }
        }
        
        // Setup progress registration
        let setupProgressCellRegistration = UICollectionView.CellRegistration<SetupProgressCell, HomeItem> { cell, indexPath, item in
            if case let .setupProgress(current, total) = item {
                cell.configure(title: "Finish Setting Up", current: current, total: total)
                
                // Configure the cell's background
                var backgroundConfig = UIBackgroundConfiguration.listCell()
                backgroundConfig.backgroundColor = NNColors.EventColors.blue.border
                backgroundConfig.cornerRadius = 12
                cell.subtitleLabel.textColor = NNColors.EventColors.blue.fill
                cell.progressLabel.textColor = .white
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
            }
            
            cell.backgroundColor = .secondarySystemGroupedBackground
            cell.layer.cornerRadius = 12
            cell.layer.masksToBounds = true
        }
        
        // Pinned category registration
        let pinnedCategoryCellRegistration = UICollectionView.CellRegistration<QuickAccessCell, HomeItem> { cell, indexPath, item in
            if case let .pinnedCategory(name, icon) = item {
                let image = UIImage(systemName: icon)
                cell.configure(with: name, image: image)
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
            case .pinnedCategory:
                return collectionView.dequeueConfiguredReusableCell(
                    using: pinnedCategoryCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .currentSession:
                return collectionView.dequeueConfiguredReusableCell(
                    using: currentSessionCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .setupProgress:
                return collectionView.dequeueConfiguredReusableCell(
                    using: setupProgressCellRegistration,
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
            case .quickAccess:
                title = "Pinned Categories"
                headerView.configure(title: title)
            case .setupProgress:
                // No header for setup progress section
                headerView.configure(title: "")
                headerView.isHidden = true
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
        
        // Only check if setup flow should be shown if we've already checked the setup status
        if hasCheckedSetupStatus && !hasCompletedSetup {
            Task {
                // Determine if setup flow should be shown based on entry count
                let shouldShowSetup = await setupService.shouldShowSetupFlow()
                
                await MainActor.run {
                    if shouldShowSetup {
                        // Add the setup progress section only if we should show setup
                        var updatedSnapshot = snapshot
                        updatedSnapshot.appendSections([.setupProgress])
                        updatedSnapshot.appendItems([.setupProgress(current: setupProgress, total: 7)], toSection: .setupProgress)
                        snapshot = updatedSnapshot
                    }
                    
                    // Continue with the rest of the snapshot
                    continueSnapshot(snapshot: snapshot, animatingDifferences: animatingDifferences)
                }
            }
        } else {
            // Continue with snapshot without checking setup status
            continueSnapshot(snapshot: snapshot, animatingDifferences: animatingDifferences)
        }
    }
    
    private func continueSnapshot(snapshot: NSDiffableDataSourceSnapshot<HomeSection, HomeItem>, animatingDifferences: Bool) {
        var updatedSnapshot = snapshot
        
        // Current session section if available
        if let session = currentSession {
            updatedSnapshot.appendSections([.currentSession])
            updatedSnapshot.appendItems([.currentSession(session)], toSection: .currentSession)
        }
        
        // Nest section
        updatedSnapshot.appendSections([.nest])
        if let currentNest = nestService.currentNest {
            updatedSnapshot.appendItems([.nest(name: currentNest.name, address: currentNest.address)], toSection: .nest)
        } else {
            updatedSnapshot.appendItems([.nest(name: "No Nest Selected", address: "Please set up your nest")], toSection: .nest)
        }
        
        // Quick access section - use pinned categories
        if !pinnedCategories.isEmpty {
            updatedSnapshot.appendSections([.quickAccess])
            
            let pinnedCategoryItems = pinnedCategories.map { categoryName in
                HomeItem.pinnedCategory(name: categoryName, icon: iconForCategory(categoryName))
            }
            
            updatedSnapshot.appendItems(pinnedCategoryItems, toSection: .quickAccess)
        }
        
        dataSource.apply(updatedSnapshot, animatingDifferences: animatingDifferences)
        
        // Show setup tip if setup progress cell is visible
        if updatedSnapshot.sectionIdentifiers.contains(.setupProgress) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showTips()
                self.hasShownSetupTip = true
            }
        }
    }
    
    func refreshData() {
        guard let nestID = nestService.currentNest?.id else {
            // No current nest, clear current session and update UI
            currentSession = nil
            applySnapshot(animatingDifferences: true)
            return
        }
        
        Task {
            do {
                loadingSpinner.startAnimating()
                
                // Fetch sessions, pinned categories, and categories concurrently
                async let sessionsTask = sessionService.fetchSessions(nestID: nestID)
                async let pinnedCategoriesTask = nestService.fetchPinnedCategories()
                async let categoriesTask = nestService.fetchCategories()
                
                let (sessions, pinnedCategoryNames, categories) = try await (sessionsTask, pinnedCategoriesTask, categoriesTask)
                
                // Update the current session based on freshly fetched data
                // Only show sessions with inProgress status in the current session section
                self.currentSession = sessions.inProgress.first
                self.pinnedCategories = pinnedCategoryNames
                self.categories = categories
                
                DispatchQueue.main.async { [weak self] in
                    self?.loadingSpinner.stopAnimating()
                    self?.applySnapshot(animatingDifferences: true)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.loadingSpinner.stopAnimating()
                    self?.currentSession = nil // Clear on error
                    self?.pinnedCategories = []
                    self?.categories = []
                    self?.applySnapshot(animatingDifferences: true)
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
    
    private func checkSetupStatus() {
        Task {
            let shouldShow = await setupService.shouldShowSetupFlow()
            await MainActor.run {
                hasCheckedSetupStatus = true
                applySnapshot(animatingDifferences: true)
            }
        }
    }
    
    private func iconForCategory(_ categoryName: String) -> String {
        // Handle special case for "Places" which isn't a regular category
        if categoryName == "Places" {
            return "map.fill"
        }
        
        // Find the category in our categories array
        if let category = categories.first(where: { $0.name == categoryName }) {
            return category.symbolName
        }
        
        // Fallback to folder icon if category not found
        return "folder.fill"
    }
    
    // MARK: - Tooltip Methods
    
    override func showTips() {
        // Check if we should show the setup tip
        guard NNTipManager.shared.shouldShowTip(OwnerHomeTips.finishSetupTip),
              !hasShownSetupTip else { return }
        
        hasShownSetupTip = true
        
        // Find the setup progress cell
        guard let setupSection = dataSource.snapshot().sectionIdentifiers.firstIndex(of: .setupProgress),
              let _ = dataSource.snapshot().itemIdentifiers(inSection: .setupProgress).first else {
            return
        }
        
        let setupIndexPath = IndexPath(item: 0, section: setupSection)
        
        // Make sure the cell is visible
        guard let setupCell = collectionView.cellForItem(at: setupIndexPath) else {
            return
        }
        
        // Show the tooltip anchored to the bottom of the setup cell
        NNTipManager.shared.showTip(
            OwnerHomeTips.finishSetupTip,
            sourceView: setupCell,
            in: self,
            pinToEdge: .bottom,
            offset: CGPoint(x: 0, y: 8)
        )
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
        case .pinnedCategory(let name, _):
            if name == "Places" {
                let isReadOnly = false
                let placesVC = PlaceListViewController(isSelecting: false, sitterViewService: nil)
                placesVC.isReadOnly = isReadOnly
                let nav = UINavigationController(rootViewController: placesVC)
                present(nav, animated: true)
            } else {
                presentCategoryView(category: name)
            }
        case .currentSession(let session):
            let vc = EditSessionViewController(sessionItem: session)
            vc.modalPresentationStyle = .pageSheet
            present(vc, animated: true)
        case .setupProgress:
            // Mark the setup tip as dismissed when user taps on it
            NNTipManager.shared.dismissTip(OwnerHomeTips.finishSetupTip)
            presentSetupFlow()
        default:
            break
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - Setup Flow
extension OwnerHomeViewController {
    private func presentSetupFlow() {
        Task {
            // Check if we should show the setup flow based on entries
            let shouldShowSetup = await setupService.shouldShowSetupFlow()
            
            if shouldShowSetup {
                // Present the setup flow view controller
                await MainActor.run {
                    let setupVC = StickyOwnerSetupFlowViewController()
                    setupVC.delegate = self
                    let navController = UINavigationController(rootViewController: setupVC)
                    present(navController, animated: true)
                }
            } else {
                // If the user already has entries, just mark setup as complete
                setupService.hasCompletedSetup = true
                refreshData()
                
                await MainActor.run {
                    showToast(text: "Setup already completed")
                }
            }
        }
    }
}

// MARK: - SetupFlowDelegate
extension OwnerHomeViewController: SetupFlowDelegate {
    func setupFlowDidComplete() {
        // Log completion
        Logger.log(level: .info, category: .general, message: "Setup flow completed by user")
        
        // Mark setup as completed
        setupService.hasCompletedSetup = true
        refreshData()
    }
    
    func setupFlowDidUpdateStepStatus() {
        // Log step update
        let completedSteps = SetupStepType.allCases.filter { setupService.isStepComplete($0) }
        Logger.log(level: .info, category: .general, message: "Setup step status updated - \(completedSteps.count)/\(SetupStepType.allCases.count) steps completed")
        
        // Refresh the UI to reflect updated step status
        refreshData()
    }
} 
