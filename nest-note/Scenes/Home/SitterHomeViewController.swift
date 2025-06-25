import UIKit
import Combine

// MARK: - Notification Names
extension Notification.Name {
    static let sessionDidChange = Notification.Name("SessionDidChange")
    static let sessionStatusDidChange = Notification.Name("SessionStatusDidChange")
}

final class SitterHomeViewController: NNViewController, HomeViewControllerType {
    // MARK: - Properties
    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<HomeSection, HomeItem>!
    private var cancellables = Set<AnyCancellable>()
    private let sitterViewService = SitterViewService.shared
    private var sessionEvents: [SessionEvent] = []
    private let maxVisibleEvents = 4
    
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
            subtitle: "Active session details will appear here.",
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
                // Full width item with fixed height of 200
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18)
                section.boundarySupplementaryItems = [header]
                return section
                
            case .quickAccess:
                // Two column grid with fixed height of 160
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(160))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 13, bottom: 20, trailing: 13)
                return section
                
            case .events:
                // Keep events section WITH separators
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.showsSeparators = true
                config.headerMode = .supplementary
                
                let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
                section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
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
        
        let eventsCellRegistration = UICollectionView.CellRegistration<EventsCell, HomeItem> { cell, indexPath, item in
            if case .events = item {
                // Filter upcoming events
                let upcomingEvents = self.getUpcomingEvents()
                
                // Configure with custom text showing only upcoming events
                cell.configureUpcoming(eventCount: upcomingEvents.count, showPlusButton: false)
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
                title = "In-progress session"
                headerView.configure(title: title)
            case .nest:
                title = "Session Nest"
                headerView.configure(title: title)
            case .events:
                // title = "Events"
                // headerView.configure(title: title)
                return
            case .quickAccess, .upcomingSessions:
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
            
            // Bring the empty state view to the front
            view.bringSubviewToFront(emptyStateView)
            
            // Ensure it's interactive
            emptyStateView.isUserInteractionEnabled = true
            
            print("Empty state view is now visible and interactive: \(emptyStateView.isUserInteractionEnabled)")
            print("Empty state view delegate: \(String(describing: emptyStateView.delegate))")
            print("Empty state view frame: \(emptyStateView.frame)")
            print("Empty state view is hidden: \(emptyStateView.isHidden)")
            
        case .error(let error):
            loadingSpinner.stopAnimating()
            collectionView.isHidden = true
            emptyStateView.isHidden = false
            handleError(error)
        }
    }
    
    private func fetchSessionEvents(session: SessionItem) {
        Task {
            do {
                let events = try await SessionService.shared.getSessionEvents(for: session.id, nestID: session.nestID)
                
                await MainActor.run {
                    // Update local events array
                    self.sessionEvents = events
                    
                    // Update the events section in the collection view
                    updateEventsSection(with: events)
                }
            } catch {
                Logger.log(level: .error, category: .sessionService, message: "Failed to fetch session events: \(error.localizedDescription)")
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
        
        // Remove any existing event items
        let existingItems = snapshot.itemIdentifiers(inSection: .events)
            .filter { if case .sessionEvent = $0 { return true } else { return false } }
        snapshot.deleteItems(existingItems)
        
        // Remove any existing "more events" items
        let existingMoreItems = snapshot.itemIdentifiers(inSection: .events)
            .filter { if case .moreEvents = $0 { return true } else { return false } }
        snapshot.deleteItems(existingMoreItems)
        
        // Filter events - only include events that haven't ended yet
        let currentDate = Date()
        let upcomingEvents = events.filter { $0.endDate > currentDate }
        
        // Sort events by start date (soonest first)
        let sortedEvents = upcomingEvents.sorted { $0.startDate < $1.startDate }
        
        // If we have events, show them and always add the "See All" button
        if !events.isEmpty {
            // Show upcoming events up to the max visible limit
            let visibleEvents = Array(sortedEvents.prefix(min(sortedEvents.count, maxVisibleEvents)))
            let eventItems = visibleEvents.map { HomeItem.sessionEvent($0) }
            snapshot.appendItems(eventItems, toSection: .events)
            
            // Always add the "See All" button when there are any events (upcoming or past)
            snapshot.appendItems([.moreEvents(events.count)], toSection: .events)
        }
        
        // Update the event count in the section header
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
        
        // Add quick access section with both items
        snapshot.appendSections([.quickAccess])
        snapshot.appendItems([
            .quickAccess(.sitterHousehold),
            .quickAccess(.sitterEmergency)
        ], toSection: .quickAccess)
        
        // Finally add events section
        snapshot.appendSections([.events])
        snapshot.appendItems([.events], toSection: .events)
        
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
    
    @objc private func emptyStateViewTapped() {
        print("Empty state view tapped directly from SitterHomeViewController")
        // Manually trigger the action button tap
        emptyStateViewDidTapActionButton(emptyStateView)
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
            
        case .events, .moreEvents:
            // Get the current session
            if let session = sitterViewService.currentSession {
                // Check if session duration is less than 24 hours
                let duration = Calendar.current.dateComponents([.hour], from: session.startDate, to: session.endDate)
                if let hours = duration.hour, hours < 24 {
                    // For sessions less than 24 hours, directly present SessionEventViewController
                    let eventVC = SessionEventViewController(sessionID: session.id, isReadOnly: true)
                    present(eventVC, animated: true)
                } else {
                    // For longer sessions, show the calendar view
                    let dateRange = DateInterval(start: session.startDate, end: session.endDate)
                    let calendarVC = SessionCalendarViewController(sessionID: session.id, nestID: session.nestID, dateRange: dateRange, events: sessionEvents, isSitter: true)
                    calendarVC.delegate = self
                    let nav = UINavigationController(rootViewController: calendarVC)
                    present(nav, animated: true)
                }
            }
            
        case .sessionEvent(let event):
            // Present event details
            if let session = sitterViewService.currentSession {
                let eventVC = SessionEventViewController(sessionID: session.id, event: event, isReadOnly: true)
                eventVC.eventDelegate = self
                present(eventVC, animated: true)
            }
            
        default:
            break
        }
    }
}

extension SitterHomeViewController: NNEmptyStateViewDelegate {
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
                    if sessionItem.status == .inProgress || sessionItem.status == .extended {
                        // If it's in progress, refresh the data to show it
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
