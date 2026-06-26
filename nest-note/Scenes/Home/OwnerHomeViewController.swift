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
    private var currentSession: SessionItem?
    private var pinnedCategories: [String] = []
    private var categories: [NestCategory] = []
    
    // Track whether we've already shown the your nest tip in this session
    private var hasShownYourNestTip = false
    
    // Track whether we've already shown the happening now tip in this session
    private var hasShownHappeningNowTip = false
    
    private var nestCreationCoordinator: NestCreationCoordinator?

    // Track if we're currently switching modes to avoid showing nest setup during transition
    private var isSwitchingModes = false

    // Premium promo — default to subscribed to avoid a flash before the first check completes
    private var hasProSubscription = true
    private var isFreeTrialEligible = false

    private var readinessResult: NestReadinessResult?
    private var previousReadinessScore: Int?
    private var hasAppearedBefore = false
    private var isRefreshingData = false
    private var pendingRefreshForceFlag = false

    private var isNestReadinessEnabled: Bool {
        FeatureFlagService.shared.isEnabled(.nestReadinessScoreEnabled)
    }

    // Create Session button
    private lazy var createSessionButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(
            title: "Create Session",
            image: UIImage(systemName: "plus"),
            backgroundColor: NNColors.primaryAlt,
            foregroundColor: .white
        )
        button.addTarget(self, action: #selector(createSessionButtonTapped), for: .touchUpInside)
        button.isHidden = true // Initially hidden
        return button
    }()
    
    private lazy var loadingSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        return refreshControl
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureDataSource()
        setupObservers()
        
        checkSubscriptionStatus()
        
        // Check if nest setup is required (for cases where mode already changed)
        checkNestSetupRequirement()
        
        refreshData()
        
        DispatchQueue.main.async { [weak self] in
            self?.applyHomeScreenNavigationAppearance(appMode: .nestOwner)
        }
        
        setFCMToken()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkSubscriptionStatus()
        if hasAppearedBefore {
            reloadReadinessScoreIfNeeded()
        }
        hasAppearedBefore = true
    }

    private func reloadReadinessScoreIfNeeded() {
        guard isNestReadinessEnabled else { return }

        Task {
            let result = try? await NestReadinessService.shared.calculateReadiness(forceRefresh: false)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.updateReadinessResult(result)
                self.applySnapshot(animatingDifferences: true)
            }
        }
    }
    
    override func setup() {
        super.setup()
        configureCollectionView()
        applyHomeScreenNavigationAppearance(appMode: .nestOwner)
        
        // Add loading spinner
        view.addSubview(loadingSpinner)
        NSLayoutConstraint.activate([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Setup and pin the create session button
        createSessionButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
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
        // Only refresh when the active nest changes — not when metadata (categories, pins) updates
        NestService.shared.$currentNest
            .map { $0?.id }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] nestID in
                guard nestID != nil else { return }
                self?.refreshData()
            }
            .store(in: &cancellables)
            
        // Subscribe to session changes
        NotificationCenter.default.publisher(for: .sessionDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData(forceRefresh: true)
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
                self?.refreshData(forceRefresh: true)
            }
            .store(in: &cancellables)
            
        // Subscribe to user information updates
        NotificationCenter.default.publisher(for: .userInformationUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
        
        // Subscribe to mode changes to check for nest setup requirement
        NotificationCenter.default.publisher(for: .modeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkNestSetupRequirement()
            }
            .store(in: &cancellables)
        
        // Subscribe to app returning from long background
        NotificationCenter.default.publisher(for: .appReturnedFromLongBackground)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAutoRefresh()
            }
            .store(in: &cancellables)

        #if DEBUG
        NotificationCenter.default.publisher(for: .premiumPromoVariantDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.collectionView.collectionViewLayout.invalidateLayout()
                var snapshot = self.dataSource.snapshot()
                guard snapshot.itemIdentifiers.contains(.premiumPromo) else { return }
                snapshot.reconfigureItems([.premiumPromo])
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &cancellables)
        #endif
    }
    
    // MARK: - HomeViewControllerType Implementation
    func configureCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        collectionView.refreshControl = refreshControl
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
        
        // Pinned category registration using FolderCollectionViewCell
        let pinnedCategoryCellRegistration = UICollectionView.CellRegistration<FolderCollectionViewCell, HomeItem> { [weak self] cell, indexPath, item in
            if case let .pinnedCategory(name, icon) = item {
                // Create FolderData for the pinned category
                let image = UIImage(systemName: icon) ?? UIImage(systemName: "folder")

                // Find the full path for this display name
                let fullPath = self?.pinnedCategories.first { categoryName in
                    let displayName = categoryName.components(separatedBy: "/").last ?? categoryName
                    return displayName == name
                } ?? name

                let folderData = FolderData(
                    title: name,
                    image: image,
                    itemCount: 3, // Always show 3 pieces of paper
                    fullPath: fullPath,
                    category: nil // We don't need the category object for display
                )

                cell.configure(with: folderData)
                // Hide the count label for home view pinned folders
                cell.subtitleLabel.isHidden = true
            }
        }

        let premiumPromoCellRegistration = UICollectionView.CellRegistration<PremiumPromoCell, HomeItem> { [weak self] cell, indexPath, item in
            if case .premiumPromo = item {
                cell.configure(
                    variant: PremiumPromoVariant.active,
                    ctaTitle: PremiumPromoCopy.ctaTitle(
                        isFreeTrialEligible: self?.isFreeTrialEligible ?? false
                    ),
                    showsDismissButton: true
                )
                cell.onUpgradeTapped = { [weak self] in
                    self?.presentPremiumPaywall()
                }
                cell.onDismissTapped = { [weak self] in
                    self?.dismissPremiumPromoBanner()
                }
            }
        }

        let readinessBannerCellRegistration = UICollectionView.CellRegistration<NestReadinessBannerCell, HomeItem> { [weak self] cell, indexPath, item in
            if case .readinessScore = item, let result = self?.readinessResult {
                cell.configure(result: result, animated: true)
                cell.onDismiss = { [weak self] in
                    self?.dismissReadinessBanner()
                }
            }
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
            case .premiumPromo:
                return collectionView.dequeueConfiguredReusableCell(
                    using: premiumPromoCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .readinessScore:
                return collectionView.dequeueConfiguredReusableCell(
                    using: readinessBannerCellRegistration,
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
            case .readinessScore, .upcomingSessions, .events, .sitterInfoBanner, .premiumPromo:
                headerView.configure(title: "")
                headerView.isHidden = true
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
        continueSnapshot(snapshot: snapshot, animatingDifferences: animatingDifferences)
    }
    
    private func continueSnapshot(snapshot: NSDiffableDataSourceSnapshot<HomeSection, HomeItem>, animatingDifferences: Bool) {
        var updatedSnapshot = snapshot

        insertPremiumPromoSection(into: &updatedSnapshot)
        insertReadinessScoreSection(into: &updatedSnapshot)
        
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

        // Show/hide create session button based on current session state
        let hasCurrentSession = updatedSnapshot.sectionIdentifiers.contains(.currentSession)
        createSessionButton.isHidden = hasCurrentSession

        // Show tips if current session or nest cell is visible
        if updatedSnapshot.sectionIdentifiers.contains(.currentSession) ||
           updatedSnapshot.sectionIdentifiers.contains(.nest) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showTips()
            }
        }
    }
    
    func refreshData(forceRefresh: Bool = false) {
        if isRefreshingData {
            if forceRefresh {
                pendingRefreshForceFlag = true
            }
            return
        }

        isRefreshingData = true
        let shouldForceRefresh = forceRefresh || pendingRefreshForceFlag
        pendingRefreshForceFlag = false

        guard let nestID = nestService.currentNest?.id else {
            // No current nest, clear current session and update UI
            currentSession = nil
            isRefreshingData = false
            applySnapshot(animatingDifferences: true)
            return
        }
        
        Task {
            do {
                loadingSpinner.startAnimating()
                
                // Fetch sessions, pinned categories, and categories concurrently
                async let sessionsTask = sessionService.fetchSessions(nestID: nestID, forceRefresh: shouldForceRefresh)
                async let pinnedCategoriesTask = nestService.fetchPinnedCategories()
                async let categoriesTask = nestService.fetchCategories()
                async let readinessTask: NestReadinessResult? = {
                    guard self.isNestReadinessEnabled else { return nil }
                    return try? await NestReadinessService.shared.calculateReadiness(forceRefresh: false)
                }()
                
                let (sessions, pinnedCategoryNames, categories, readiness) = try await (sessionsTask, pinnedCategoriesTask, categoriesTask, readinessTask)
                
                // Update the current session based on freshly fetched data
                // Only show sessions with inProgress status in the current session section
                self.currentSession = sessions.inProgress.first
                self.pinnedCategories = pinnedCategoryNames
                self.categories = categories
                self.updateReadinessResult(readiness)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.isRefreshingData = false
                    if self.pendingRefreshForceFlag {
                        self.refreshData(forceRefresh: true)
                    }
                    self.loadingSpinner.stopAnimating()
                    self.applySnapshot(animatingDifferences: true)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.isRefreshingData = false
                    if self.pendingRefreshForceFlag {
                        self.refreshData(forceRefresh: true)
                    }
                    self.loadingSpinner.stopAnimating()
                    self.currentSession = nil // Clear on error
                    self.pinnedCategories = []
                    self.categories = []
                    self.applySnapshot(animatingDifferences: true)
                    self.handleError(error)
                }
            }
        }
    }
    
    @objc private func handlePullToRefresh() {
        Task {
            await MainActor.run {
                self.refreshData(forceRefresh: true)
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    private func handleAutoRefresh() {
        // Show loading indicator for auto-refresh
        loadingSpinner.startAnimating()
        
        // Force refresh to bypass any cached data when returning from long background
        refreshData(forceRefresh: true)
        
        // Note: loadingSpinner.stopAnimating() is called in refreshData() completion
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

    @objc private func createSessionButtonTapped() {
        let editSessionVC = EditSessionViewController()
        let navController = UINavigationController(rootViewController: editSessionVC)
        navController.modalPresentationStyle = .pageSheet
        present(navController, animated: true)
    }
    
    private func checkSubscriptionStatus() {
        Task {
            async let hasPro = SubscriptionService.shared.hasProSubscription()
            async let trialEligible = SubscriptionService.shared.isEligibleForFreeTrial()
            let (pro, trial) = await (hasPro, trialEligible)
            await MainActor.run {
                let subscriptionChanged = hasProSubscription != pro
                let trialChanged = isFreeTrialEligible != trial
                hasProSubscription = pro
                isFreeTrialEligible = trial

                if subscriptionChanged || trialChanged {
                    applySnapshot(animatingDifferences: true)
                }
            }
        }
    }

    private func insertPremiumPromoSection(into snapshot: inout NSDiffableDataSourceSnapshot<HomeSection, HomeItem>) {
        guard !hasProSubscription else { return }
        guard PremiumPromoBannerStore.shouldShowHomeBanner else { return }
        guard !shouldDeferPremiumPromoForReadiness() else { return }

        if let firstSection = snapshot.sectionIdentifiers.first {
            snapshot.insertSections([.premiumPromo], beforeSection: firstSection)
        } else {
            snapshot.appendSections([.premiumPromo])
        }
        snapshot.appendItems([.premiumPromo], toSection: .premiumPromo)
    }

    private func shouldDeferPremiumPromoForReadiness() -> Bool {
        guard isNestReadinessEnabled,
              let nestID = nestService.currentNest?.id,
              !NestReadinessBannerStore.isHomeBannerDismissed(for: nestID) else {
            return false
        }
        // While readiness is loading, defer promo so the score banner owns first landing.
        guard let score = readinessResult?.totalScore else { return true }
        return score < 20
    }

    private func insertReadinessScoreSection(into snapshot: inout NSDiffableDataSourceSnapshot<HomeSection, HomeItem>) {
        guard isNestReadinessEnabled, let result = readinessResult else { return }
        guard let nestID = nestService.currentNest?.id,
              !NestReadinessBannerStore.isHomeBannerDismissed(for: nestID) else { return }

        let item = HomeItem.readinessScore(score: result.totalScore, tierLabel: result.tierLabel)

        if let sessionIndex = snapshot.sectionIdentifiers.firstIndex(of: .currentSession) {
            snapshot.insertSections([.readinessScore], beforeSection: snapshot.sectionIdentifiers[sessionIndex])
        } else if let nestIndex = snapshot.sectionIdentifiers.firstIndex(of: .nest) {
            snapshot.insertSections([.readinessScore], beforeSection: snapshot.sectionIdentifiers[nestIndex])
        } else {
            snapshot.appendSections([.readinessScore])
        }

        snapshot.appendItems([item], toSection: .readinessScore)
    }

    private func dismissReadinessBanner() {
        guard let nestID = nestService.currentNest?.id else { return }
        NestReadinessBannerStore.dismissHomeBanner(for: nestID)
        applySnapshot(animatingDifferences: true)
    }

    private func updateReadinessResult(_ result: NestReadinessResult?) {
        guard let result else {
            readinessResult = nil
            return
        }

        if let previousReadinessScore, result.totalScore > previousReadinessScore {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                NestReadinessPointsAnimator.showGain(result.totalScore - previousReadinessScore, in: self.view)
            }
        }

        previousReadinessScore = result.totalScore
        readinessResult = result
    }

    private func presentReadinessDetail() {
        let detailVC = NestReadinessDetailViewController()
        detailVC.delegate = self
        detailVC.modalPresentationStyle = .pageSheet
        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(detailVC, animated: true)
    }

    private func dismissPremiumPromoBanner() {
        PremiumPromoBannerStore.dismissHomeBanner()
        applySnapshot(animatingDifferences: true)
    }

    private func presentPremiumPaywall() {
        let paywall = FeatureInfoPaywallViewController()
        paywall.modalPresentationStyle = .pageSheet
        if let sheet = paywall.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(paywall, animated: true)
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
        
        // Priority 1: Your Nest tip
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
                return // Return after successfully showing the tip
            }
            return // Always return after attempting to show this tip, even if cell not visible
        }
        
        // Priority 2: Current session tip
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
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .pageSheet
            present(navController, animated: true)
        case .premiumPromo:
            presentPremiumPaywall()
        case .readinessScore:
            presentReadinessDetail()
        default:
            break
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - Nest Readiness Detail
extension OwnerHomeViewController: NestReadinessDetailViewControllerDelegate {
    func readinessDetailViewController(_ controller: NestReadinessDetailViewController, didSelectCategory category: String) {
        controller.dismiss(animated: true) { [weak self] in
            self?.presentCategoryView(category: category)
        }
    }
}

