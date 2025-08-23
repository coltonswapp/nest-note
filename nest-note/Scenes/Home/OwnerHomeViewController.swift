import UIKit
import Combine
import FirebaseMessaging
import TipKit

final class OwnerHomeViewController: NNViewController, HomeViewControllerType, NNTippable {
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
    
    // Track whether we've already shown the your nest tip in this session
    private var hasShownYourNestTip = false
    
    // Track whether we've already shown the happening now tip in this session
    private var hasShownHappeningNowTip = false
    
    private var nestCreationCoordinator: NestCreationCoordinator?
    
    // Track if we're currently switching modes to avoid showing nest setup during transition
    private var isSwitchingModes = false
    
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
        
        // Check if nest setup is required (for cases where mode already changed)
        checkNestSetupRequirement()
        
//        setFCMToken()
    }
    
    override func setup() {
        super.setup()
        configureCollectionView()
        navigationItem.title = "NestNote"
        navigationItem.weeTitle = "Welcome to"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.tintColor = NNColors.primary
        
        // Add loading spinner
        view.addSubview(loadingSpinner)
        NSLayoutConstraint.activate([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    override func setupNavigationBarButtons() {
        let menuButton = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal"),
            style: .plain,
            target: self,
            action: #selector(settingsButtonTapped)
        )
        menuButton.tintColor = .label
        navigationItem.rightBarButtonItem = menuButton
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
            
        // Subscribe to mode changes to check for nest setup requirement
        NotificationCenter.default.publisher(for: .modeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkNestSetupRequirement()
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
                
                // Get sitter name or email, but only if they're not empty strings
                let sitterName = session.assignedSitter?.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let sitterEmail = session.assignedSitter?.email.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let sitterInfo: String? = {
                    if let name = sitterName, !name.isEmpty {
                        return name
                    } else if let email = sitterEmail, !email.isEmpty {
                        return email
                    } else {
                        return nil
                    }
                }()
                
                let durationText: String = sitterInfo == nil ? duration : "\(sitterInfo!) • \(duration)"
                
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
                title = "Pinned Folders"
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
                        updatedSnapshot.appendItems([.setupProgress(current: setupProgress, total: 6)], toSection: .setupProgress)
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
            
            let categoryItems = pinnedCategories.map { categoryName in
                // For categories with "/", extract the display name from the last component
                let displayName = categoryName.components(separatedBy: "/").last ?? categoryName
                let iconName = iconForCategory(categoryName)
                
                return HomeItem.pinnedCategory(name: displayName, icon: iconName)
            }
            
            updatedSnapshot.appendItems(categoryItems, toSection: .quickAccess)
        }
        
        dataSource.apply(updatedSnapshot, animatingDifferences: animatingDifferences)
        
        // Show tips if current session, setup progress, or nest cell is visible
        if updatedSnapshot.sectionIdentifiers.contains(.currentSession) || 
           updatedSnapshot.sectionIdentifiers.contains(.setupProgress) ||
           updatedSnapshot.sectionIdentifiers.contains(.nest) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showTips()
                if updatedSnapshot.sectionIdentifiers.contains(.setupProgress) {
                    self.hasShownSetupTip = true
                }
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
        
        Task {
            do {
                // Use efficient combined fetch to get both entries and places
                let (_, places) = try await nestService.fetchEntriesAndPlaces()
                
                await MainActor.run {
                    let categoryVC = NestCategoryViewController(
                        category: category,
                        places: places,
                        entryRepository: nestService
                    )
                    navigationController?.pushViewController(categoryVC, animated: true)
                }
            } catch {
                Logger.log(level: .error, category: .general, message: "Failed to fetch places for category view: \(error)")
                // Fallback to empty places if fetch fails
                await MainActor.run {
                    let categoryVC = NestCategoryViewController(
                        category: category,
                        places: [],
                        entryRepository: nestService
                    )
                    navigationController?.pushViewController(categoryVC, animated: true)
                }
            }
        }
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
    
    // MARK: - Nest Setup Methods
    
    private func checkNestSetupRequirement() {
        // Don't show nest setup if we're currently switching modes
        guard !isSwitchingModes else {
            return
        }
        
        // Only check if we're in owner mode and signed in
        guard ModeManager.shared.isNestOwnerMode && UserService.shared.isSignedIn else {
            return
        }
        
        // Check if user has a nest setup
        if NestService.shared.currentNest == nil {
            // User switched to owner mode but doesn't have a nest - show ATF flow
            showNestSetup()
        }
    }
    
    private func showNestSetup() {
        let alert = UIAlertController(
            title: "Nest Setup Required",
            message: "You'll need to create your nest before you can access owner features. Would you like to set up your nest now?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Back to Sitter Mode", style: .cancel) { [weak self] _ in
            self?.switchBackToSitterMode()
        })
        alert.addAction(UIAlertAction(title: "Create Nest", style: .default) { [weak self] _ in
            self?.presentNestCreationFlow()
        })
        
        present(alert, animated: true)
    }
    
    private func presentNestCreationFlow() {
        nestCreationCoordinator = NestCreationCoordinator()
        guard let nestCreationCoordinator else { 
            return 
        }
        
        present(nestCreationCoordinator.start(), animated: true)
    }
    
    private func switchBackToSitterMode() {
        guard let launchCoordinator = LaunchCoordinator.shared else {
            return
        }
        
        // Dismiss any presented view controllers first to avoid the detached view controller warning
        if presentedViewController != nil {
            dismiss(animated: true) {
                self.performModeSwitch(launchCoordinator: launchCoordinator)
            }
        } else {
            performModeSwitch(launchCoordinator: launchCoordinator)
        }
    }
    
    private func performModeSwitch(launchCoordinator: LaunchCoordinator) {
        isSwitchingModes = true
        
        Task {
            do {
                // Set the mode first
                ModeManager.shared.currentMode = .sitter
                
                // Then reconfigure with LaunchCoordinator
                try await launchCoordinator.switchMode(to: .sitter)
                
                // The LaunchCoordinator should handle the view controller transition
            } catch {
                // Only show error feedback if we're still in the view hierarchy
                await MainActor.run {
                    if self.view.window != nil {
                        self.showToast(text: "Failed to switch modes. Please try again.")
                    }
                }
            }
            
            // Reset the flag after a delay to allow the transition to complete
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.isSwitchingModes = false
                }
            }
        }
    }
    
    
    // MARK: - Tooltip Methods
    
    func showTips() {
        trackScreenVisit()
        
        // Priority 1: Setup tip (highest priority)
        if let setupSection = dataSource.snapshot().sectionIdentifiers.firstIndex(of: .setupProgress),
           let _ = dataSource.snapshot().itemIdentifiers(inSection: .setupProgress).first,
           NNTipManager.shared.shouldShowTip(OwnerHomeTips.finishSetupTip),
           !hasShownSetupTip {
            
            let setupIndexPath = IndexPath(item: 0, section: setupSection)
            
            // Make sure the cell is visible
            if let setupCell = collectionView.cellForItem(at: setupIndexPath) {
                hasShownSetupTip = true
                
                // Show the tip anchored to the bottom of the setup cell
                NNTipManager.shared.showTip(
                    OwnerHomeTips.finishSetupTip,
                    sourceView: setupCell,
                    in: self,
                    pinToEdge: .bottom,
                    offset: CGPoint(x: 0, y: 8)
                )
            }
            return // Always return after attempting to show this highest priority tip
        }
        
        // Priority 2: Your Nest tip (second priority)
        if let nestSection = dataSource.snapshot().sectionIdentifiers.firstIndex(of: .nest),
           let _ = dataSource.snapshot().itemIdentifiers(inSection: .nest).first,
           NNTipManager.shared.shouldShowTip(OwnerHomeTips.yourNestTip),
           !hasShownYourNestTip {
            
            let nestIndexPath = IndexPath(item: 0, section: nestSection)
            
            // Make sure the cell is visible
            if let nestCell = collectionView.cellForItem(at: nestIndexPath) {
                hasShownYourNestTip = true
                
                // Show the tip anchored to the bottom of the nest cell
                NNTipManager.shared.showTip(
                    OwnerHomeTips.yourNestTip,
                    sourceView: nestCell,
                    in: self,
                    pinToEdge: .bottom,
                    offset: CGPoint(x: 0, y: 8)
                )
            }
            return // Always return after attempting to show this tip
        }
        
        // Priority 3: Current session tip (lower priority)
        if let currentSessionSection = dataSource.snapshot().sectionIdentifiers.firstIndex(of: .currentSession),
           let _ = dataSource.snapshot().itemIdentifiers(inSection: .currentSession).first,
           NNTipManager.shared.shouldShowTip(HomeTips.happeningNowTip),
           !hasShownHappeningNowTip {
            
            let currentSessionIndexPath = IndexPath(item: 0, section: currentSessionSection)
            
            // Make sure the cell is visible
            if let currentSessionCell = collectionView.cellForItem(at: currentSessionIndexPath) {
                hasShownHappeningNowTip = true
                
                // Show the tip anchored to the bottom of the current session cell
                NNTipManager.shared.showTip(
                    HomeTips.happeningNowTip,
                    sourceView: currentSessionCell,
                    in: self,
                    pinToEdge: .bottom,
                    offset: CGPoint(x: 0, y: 8)
                )
            }
        }
    }
}

// MARK: - UICollectionViewDelegate
extension OwnerHomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch item {
        case .nest:
            // Dismiss the your nest tip when the nest cell is tapped
            NNTipManager.shared.dismissTip(OwnerHomeTips.yourNestTip)
            
            // If no current nest, show nest setup flow instead of household view
            if NestService.shared.currentNest == nil {
                showNestSetup()
            } else {
                presentHouseholdView()
            }
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
                // Find the full path for this display name in pinnedCategories
                let fullPath = pinnedCategories.first { categoryName in
                    let displayName = categoryName.components(separatedBy: "/").last ?? categoryName
                    return displayName == name
                } ?? name
                presentCategoryView(category: fullPath)
            }
        case .currentSession(let session):
            // Dismiss the happening now tip when the current session cell is tapped
            NNTipManager.shared.dismissTip(HomeTips.happeningNowTip)
            
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

