import UIKit
import Combine

// MARK: - Notification Names
extension Notification.Name {
    static let sessionDidChange = Notification.Name("SessionDidChange")
    static let sessionStatusDidChange = Notification.Name("SessionStatusDidChange")
}

final class SitterHomeViewController: NNViewController, HomeViewControllerType, NNTippable {
    // MARK: - Properties
    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<HomeSection, HomeItem>!
    private var cancellables = Set<AnyCancellable>()
    private let sitterViewService = SitterViewService.shared
    private var sessionEvents: [SessionEvent] = []
    private let maxVisibleEvents = 4
    private var isLoadingEvents = false
    private var pinnedCategories: [String] = []
    private var categories: [NestCategory] = []
    
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
            subtitle: "Active session details will appear here. View all sessions via the menu.",
            actionButtonTitle: "Join a Session"
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.isUserInteractionEnabled = true
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
        
        // Add loading spinner and empty state view
        view.addSubview(loadingSpinner)
        view.addSubview(emptyStateView)
        
        // Ensure the empty state view is on top of other views
        view.bringSubviewToFront(emptyStateView)
        
        // Update constraints to ensure the empty state view covers the entire view
        NSLayoutConstraint.activate([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
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
    
    // MARK: - HomeViewControllerType Implementation
    func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        view.addSubview(collectionView)
    }
    
    func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnvironment in
            guard let self = self else { return nil }
            
            // Configure header size for all sections
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(16)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            
            let verticalSpacing: CGFloat = 4
            
            switch self.dataSource.snapshot().sectionIdentifiers[sectionIndex] {
            case .currentSession:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(60))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(60))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 18, bottom: 20, trailing: 18)
                section.boundarySupplementaryItems = [header]
                return section
                
            case .nest:
                // Full width item with fixed height of 220
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: verticalSpacing + 4, leading: 18, bottom: 20, trailing: 18)
                section.boundarySupplementaryItems = [header]
                return section
                
            case .quickAccess:
                // Two column grid with fixed height of 180
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(100))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(100))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
                group.interItemSpacing = .fixed(8)
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 8
                section.contentInsets = NSDirectionalEdgeInsets(top: verticalSpacing + 4, leading: 18, bottom: 20, trailing: 18)
                section.boundarySupplementaryItems = [header]
                return section
                
            case .events:
                // Keep events section WITH separators
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.showsSeparators = true
                config.headerMode = .supplementary
                
                let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
                section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 16)
                return section
                
            default:
                return nil
            }
        }
        return layout
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
                var title = ""
                var image: UIImage?
                
                switch type {
                case .sitterHousehold:
                    title = "Household"
                    image = UIImage(systemName: "house")
                case .sitterEmergency:
                    title = "Emergency"
                    image = UIImage(systemName: "light.beacon.max")
                default:
                    break
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
        
        
        let currentSessionCellRegistration = UICollectionView.CellRegistration<CurrentSessionCell, HomeItem> { cell, indexPath, item in
            if case let .currentSession(session) = item {
                if session.status == .earlyAccess {
                    // Format session start time
                    let sessionStartTime = self.formatSessionStartTime(session.startDate)
                    cell.configureForEarlyAccess(title: session.title, sessionStartTime: sessionStartTime)
                } else {
                    // Format duration manually since we can't access formattedDuration
                    let formatter = DateIntervalFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .none
                    let duration = formatter.string(from: session.startDate, to: session.endDate)
                    
                    cell.configure(title: session.title, duration: duration)
                }
                
                // Configure the cell's background
                var backgroundConfig = UIBackgroundConfiguration.listCell()
                backgroundConfig.backgroundColor = NNColors.primaryAlt
                backgroundConfig.cornerRadius = 12
                cell.backgroundConfiguration = backgroundConfig
            }
        }
        
        let eventsCellRegistration = UICollectionView.CellRegistration<EventsCell, HomeItem> { cell, indexPath, item in
            if case .events = item {
                // If we're still loading events, show loading indicator
                if self.sessionEvents.isEmpty && self.isLoadingEvents {
                    cell.showLoading()
                } else {
                    cell.configure(eventCount: self.sessionEvents.count)
                }
            }
        }
        
        let sessionEventRegistration = UICollectionView.CellRegistration<SessionEventCell, HomeItem> { cell, indexPath, item in
            if case let .sessionEvent(event) = item {
                cell.includeDate = true
                cell.configure(with: event)
            }
        }
        
        let moreEventsRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, HomeItem> { cell, indexPath, item in
            if case let .moreEvents(count) = item {
                var content = cell.defaultContentConfiguration()
                
                // Use the count parameter passed directly to moreEvents
                let text = "See all (\(count))"
                
                // Create attributed string with underline
                let attributedString = NSAttributedString(
                    string: text,
                    attributes: [
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .foregroundColor: UIColor.secondaryLabel
                    ]
                )
                
                content.attributedText = attributedString
                content.textProperties.alignment = .center
                cell.contentConfiguration = content
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
            case .events:
                return collectionView.dequeueConfiguredReusableCell(
                    using: eventsCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .sessionEvent:
                return collectionView.dequeueConfiguredReusableCell(
                    using: sessionEventRegistration,
                    for: indexPath,
                    item: item
                )
            case .moreEvents:
                return collectionView.dequeueConfiguredReusableCell(
                    using: moreEventsRegistration,
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
                // Check if we have a current session to determine the title
                if let currentSessionItems = self?.dataSource.snapshot().itemIdentifiers(inSection: .currentSession),
                   let firstItem = currentSessionItems.first,
                   case let .currentSession(session) = firstItem {
                    title = session.status == .earlyAccess ? "Early Access" : "In-progress session"
                } else {
                    title = "In-progress session"
                }
                headerView.configure(title: title)
            case .nest:
                title = "Session Nest"
                headerView.configure(title: title)
            case .events:
                // title = "Events"
                // headerView.configure(title: title)
                return
            case .quickAccess:
                title = "Pinned Folders"
                headerView.configure(title: title)
            case .upcomingSessions:
                return
            case .setupProgress:
                return
            }
        }
        
        // Footer registration
        let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { supplementaryView, elementKind, indexPath in
            var configuration = supplementaryView.defaultContentConfiguration()
            
            // Configure footer based on section
            // if case .events = self.dataSource.sectionIdentifier(for: indexPath.section) {
            //     configuration.text = "Add Nest-related events for this session."
            //     configuration.textProperties.numberOfLines = 0
            //     configuration.textProperties.font = .preferredFont(forTextStyle: .footnote)
            //     configuration.textProperties.color = .tertiaryLabel
            //     configuration.textProperties.alignment = .center
            // }
            
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
                self?.refreshData()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .sessionStatusDidChange)
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
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
            // Fetch events for the current session
            fetchSessionEvents(session: session)
            
        case .noSession:
            loadingSpinner.stopAnimating()
            collectionView.isHidden = true
            emptyStateView.isHidden = false
            
            // Animate the empty state into view
            emptyStateView.animateIn()
            
            // Ensure it's interactive
            emptyStateView.isUserInteractionEnabled = true
            
            print("Empty state view is now visible and interactive: \(emptyStateView.isUserInteractionEnabled)")
            print("Empty state view delegate: \(String(describing: emptyStateView.delegate))")
            print("Empty state view frame: \(emptyStateView.frame)")
            print("Empty state view is hidden: \(emptyStateView.isHidden)")
            
        case .error(let error):
            loadingSpinner.stopAnimating()
            collectionView.isHidden = true
            emptyStateView.animateIn()
            handleError(error)
        }
    }
    
    private func fetchSessionEvents(session: SessionItem) {
        // Set loading state
        isLoadingEvents = true
        
        // Show loading indicator in the events cell
        if let eventsItem = dataSource.snapshot().itemIdentifiers(inSection: .events).first,
           let indexPath = dataSource.indexPath(for: eventsItem),
           let eventsCell = collectionView.cellForItem(at: indexPath) as? EventsCell {
            eventsCell.showLoading()
        }
        
        Task {
            do {
                let events = try await SessionService.shared.getSessionEvents(for: session.id, nestID: session.nestID)
                
                await MainActor.run {
                    // Reset loading state
                    self.isLoadingEvents = false
                    
                    // Update local events array
                    self.sessionEvents = events
                    
                    // Update the events section in the collection view
                    updateEventsSection(with: events)
                }
            } catch {
                Logger.log(level: .error, category: .sessionService, message: "Failed to fetch session events: \(error.localizedDescription)")
                
                await MainActor.run {
                    // Reset loading state
                    self.isLoadingEvents = false
                    
                    // Configure the events cell to show zero events
                    if let eventsItem = dataSource.snapshot().itemIdentifiers(inSection: .events).first,
                       let indexPath = dataSource.indexPath(for: eventsItem),
                       let eventsCell = collectionView.cellForItem(at: indexPath) as? EventsCell {
                        eventsCell.configure(eventCount: 0)
                    }
                }
            }
        }
    }
    
    // Helper method to get upcoming events
    private func getUpcomingEvents() -> [SessionEvent] {
        let currentDate = Date()
        return sessionEvents.filter { $0.endDate > currentDate }
    }
    
    private func updateEventsSection(with events: [SessionEvent]) {
        var snapshot = dataSource.snapshot()
        
        // Skip if events section doesn't exist
        if !snapshot.sectionIdentifiers.contains(.events) {
            return
        }
        
        // Remove any existing event items
        let existingItems = snapshot.itemIdentifiers(inSection: .events)
            .filter { if case .sessionEvent = $0 { return true } else { return false } }
        snapshot.deleteItems(existingItems)
        
        // Remove any existing "more events" items
        let existingMoreItems = snapshot.itemIdentifiers(inSection: .events)
            .filter { if case .moreEvents = $0 { return true } else { return false } }
        snapshot.deleteItems(existingMoreItems)
        
        // Add new event items
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        
        // If we have more than maxVisibleEvents, only show the first few
        if sortedEvents.count > maxVisibleEvents {
            let visibleEvents = Array(sortedEvents.prefix(maxVisibleEvents))
            let remainingCount = sortedEvents.count - maxVisibleEvents
            
            let eventItems = visibleEvents.map { HomeItem.sessionEvent($0) }
            snapshot.appendItems(eventItems, toSection: .events)
            snapshot.appendItems([.moreEvents(remainingCount)], toSection: .events)
        } else {
            let eventItems = sortedEvents.map { HomeItem.sessionEvent($0) }
            snapshot.appendItems(eventItems, toSection: .events)
        }
        
        snapshot.reconfigureItems([.events])
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func applySnapshot(session: SessionItem, nest: NestItem) {
        var snapshot = NSDiffableDataSourceSnapshot<HomeSection, HomeItem>()
        
        // Add current session section first
        snapshot.appendSections([.currentSession])
        snapshot.appendItems([.currentSession(session)], toSection: .currentSession)
        
        // Add nest section
        snapshot.appendSections([.nest])
        snapshot.appendItems([.nest(name: nest.name, address: nest.address)], toSection: .nest)
        
        // Store pinned categories and categories from nest
        self.pinnedCategories = nest.pinnedCategories ?? []
        self.categories = nest.categories ?? []
        
        // Add quick access section with pinned categories
        if !pinnedCategories.isEmpty {
            snapshot.appendSections([.quickAccess])
            
            let categoryItems = pinnedCategories.map { categoryName in
                // For categories with "/", extract the display name from the last component
                let displayName = categoryName.components(separatedBy: "/").last ?? categoryName
                let iconName = iconForCategory(categoryName)
                
                return HomeItem.pinnedCategory(name: displayName, icon: iconName)
            }
            
            snapshot.appendItems(categoryItems, toSection: .quickAccess)
        }
        
        // Finally add events section
        snapshot.appendSections([.events])
        snapshot.appendItems([.events], toSection: .events)
        
        dataSource.apply(snapshot, animatingDifferences: true)
        
        // Show tips after snapshot is applied if there's a current session
        if snapshot.sectionIdentifiers.contains(.currentSession) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showTips()
            }
        }
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
    
    // MARK: - Animation Methods
    
    
    private func hideEmptyState() {
        emptyStateView.hideImmediately()
    }
    
    // MARK: - Helper Methods
    
    private func formatSessionStartTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            // Today: show "today at 2:30 PM"
            formatter.dateFormat = "'today at' h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            // Tomorrow: show "tomorrow at 2:30 PM"  
            formatter.dateFormat = "'tomorrow at' h:mm a"
        } else {
            // Other days: show "Mon, Aug 15 at 2:30 PM"
            formatter.dateFormat = "E, MMM d 'at' h:mm a"
        }
        
        return formatter.string(from: date)
    }
    
    // MARK: - Layout
    // Remove custom layout implementation to use the default one from HomeViewControllerType
    
    // Add this method to conform to HomeViewControllerType
    func applySnapshot(animatingDifferences: Bool) {
        // This is required for protocol conformance but we're using our own snapshot methods
        // Our view state handling takes care of applying snapshots
    }
    
    @objc private func emptyStateViewTapped() {
        print("Empty state view tapped directly from SitterHomeViewController")
        // Manually trigger the action button tap
        emptyStateViewDidTapActionButton(emptyStateView)
    }
    
    func showTips() {
        trackScreenVisit()
        
        // Only show tip when there's a current session
        guard let currentSessionSection = dataSource.snapshot().sectionIdentifiers.firstIndex(of: .currentSession),
              let _ = dataSource.snapshot().itemIdentifiers(inSection: .currentSession).first,
              NNTipManager.shared.shouldShowTip(HomeTips.happeningNowTip) else {
            return
        }
        
        let currentSessionIndexPath = IndexPath(item: 0, section: currentSessionSection)
        
        // Make sure the cell is visible
        guard let currentSessionCell = collectionView.cellForItem(at: currentSessionIndexPath) else {
            return
        }
        
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
            
        case .pinnedCategory(let name, _):
            if name == "Places" {
                let sitterService = SitterViewService.shared
                let placesVC = PlaceListViewController(isSelecting: false, sitterViewService: sitterService)
                placesVC.isReadOnly = true
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
            if let nestName = sitterViewService.currentNestName {
                let detailVC = SitterSessionDetailViewController(session: session, nestName: nestName)
                present(detailVC, animated: true)
            }
            
        case .events, .moreEvents:
            // Skip handling events if we're still loading them
            if isLoadingEvents { return }
            
            // Get the current session
            if let session = sitterViewService.currentSession {
                // Present calendar view
                let dateRange = DateInterval(start: session.startDate, end: session.endDate)
                let calendarVC = SessionCalendarViewController(sessionID: session.id, nestID: session.nestID, dateRange: dateRange, events: sessionEvents)
                let nav = UINavigationController(rootViewController: calendarVC)
                present(nav, animated: true)
            }
            
        case .sessionEvent(let event):
            // Present event details
            if let session = sitterViewService.currentSession {
                let eventVC = SessionEventViewController(sessionID: session.id, event: event, isReadOnly: false, entryRepository: SitterViewService.shared)
                eventVC.eventDelegate = self
                present(eventVC, animated: true)
            }
            
        default:
            break
        }
    }
}

extension SitterHomeViewController: NNEmptyStateViewDelegate {
    func emptyStateView(_ emptyStateView: NNEmptyStateView, didTapActionWithTag tag: Int) {
        //
    }
    
    func emptyStateViewDidTapActionButton(_ emptyStateView: NNEmptyStateView) {
        let joinVC = JoinSessionViewController()
        joinVC.delegate = self
        let nav = UINavigationController(rootViewController: joinVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }
}

extension SitterHomeViewController: JoinSessionViewControllerDelegate {
    func joinSessionViewController(didAcceptInvite session: SitterSession) {
        // Check if the accepted session is in progress
        Task {
            do {
                // Fetch the session to check its status
                if let sessionItem = try await SessionService.shared.getSession(nestID: session.nestID, sessionID: session.id) {
                    if sessionItem.status == .inProgress || sessionItem.status == .extended || sessionItem.status == .earlyAccess {
                        // If it's in progress or in early access, refresh the data to show it
                        await MainActor.run {
                            self.refreshData()
                        }
                    }
                }
            } catch {
                print("Error checking session status: \(error)")
            }
        }
    }
}

// Add SessionEventViewControllerDelegate conformance
extension SitterHomeViewController: SessionEventViewControllerDelegate {
    func sessionEventViewController(_ controller: SessionEventViewController, didDeleteEvent event: SessionEvent) {
        // do nothing, sitter cannot delete events
    }
    
    func sessionEventViewController(_ controller: SessionEventViewController, didCreateEvent event: SessionEvent?) {
        guard let event = event else { return }
        
        // Update local events array
        if let existingIndex = sessionEvents.firstIndex(where: { $0.id == event.id }) {
            sessionEvents[existingIndex] = event
        } else {
            sessionEvents.append(event)
        }
        
        // Sort events by start time
        sessionEvents.sort { $0.startDate < $1.startDate }
        
        // Update events section
        updateEventsSection(with: sessionEvents)
    }
}

// Add SessionCalendarViewControllerDelegate conformance
extension SitterHomeViewController: SessionCalendarViewControllerDelegate {
    func calendarViewController(_ controller: SessionCalendarViewController, didUpdateEvents events: [SessionEvent]) {
        // Update local events array
        sessionEvents = events
        
        // Update events section
        updateEventsSection(with: events)
    }
} 
