import UIKit
import FirebaseFirestore

final class SitterSessionDetailViewController: NNViewController {
    
    // MARK: - Properties
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    private let session: SessionItem
    private let nestName: String
    private var sessionEvents: [SessionEvent] = []
    private let maxVisibleEvents = 4
    private var isLoadingEvents = false
    private var isArchivedSession: Bool = false
    
    // MARK: - Enums
    enum Section: Int {
        case name
        case date
        case visibility
        case events
        case expenses
    }
    
    enum Item: Hashable {
        case nestName(name: String)
        case dateSelection(startDate: Date, endDate: Date, isMultiDay: Bool)
        case earlyAccess(EarlyAccessDuration)
        case visibilityLevel(VisibilityLevel)
        case events
        case sessionEvent(SessionEvent)
        case moreEvents(Int)
        case expenses
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .nestName(name: let name):
                hasher.combine(0)
                hasher.combine(name)
            case .dateSelection(let start, let end, let isMultiDay):
                hasher.combine(1)
                hasher.combine(start)
                hasher.combine(end)
                hasher.combine(isMultiDay)
            case .earlyAccess(let duration):
                hasher.combine(2)
                hasher.combine(duration)
            case .visibilityLevel(let level):
                hasher.combine(3)
                hasher.combine(level)
            case .events:
                hasher.combine(4)
            case .sessionEvent(let event):
                hasher.combine(5)
                hasher.combine(event)
            case .moreEvents(let count):
                hasher.combine(6)
                hasher.combine(count)
            case .expenses:
                hasher.combine(7)
            }
        }
        
        static func == (lhs: Item, rhs: Item) -> Bool {
            switch (lhs, rhs) {
                case let (.nestName(n1), .nestName(n2)):
                return n1 == n2
            case let (.dateSelection(s1, e1, m1), .dateSelection(s2, e2, m2)):
                return s1 == s2 && e1 == e2 && m1 == m2
            case let (.earlyAccess(d1), .earlyAccess(d2)):
                return d1 == d2
            case let (.visibilityLevel(l1), .visibilityLevel(l2)):
                return l1 == l2
            case (.events, .events):
                return true
            case let (.sessionEvent(e1), .sessionEvent(e2)):
                return e1 == e2
            case let (.moreEvents(c1), .moreEvents(c2)):
                return c1 == c2
            case (.expenses, .expenses):
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    init(session: SessionItem, nestName: String) {
        self.session = session
        self.nestName = nestName
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }
    
    // Initializer for archived sitter sessions
    init(archivedSession: ArchivedSitterSession) {
        // Convert archived session to SessionItem
        let sessionItem = SessionItem(
            id: archivedSession.id,
            title: "Session at \(archivedSession.nestName)",
            startDate: archivedSession.inviteAcceptedAt,
            endDate: archivedSession.parentSessionCompletedDate ?? archivedSession.archivedDate,
            isMultiDay: false,
            events: [],
            visibilityLevel: .halfDay,
            status: .completed,
            assignedSitter: nil,
            nestID: archivedSession.nestID,
            ownerID: nil
        )
        
        self.session = sessionItem
        self.nestName = archivedSession.nestName
        self.isArchivedSession = true
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.delegate = self
        collectionView.delaysContentTouches = false
        
        if let sheetPresentationController = sheetPresentationController {
            sheetPresentationController.detents = [.large()]
            sheetPresentationController.prefersGrabberVisible = false
        }
        
        // Fetch events for all sessions except archived ones
        if !isArchivedSession {
            fetchSessionEvents()
        }
        
        // Add observer for session status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionStatusChange),
            name: .sessionStatusDidChange,
            object: nil
        )
        
        // Add observer for session changes to refresh data
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionChange),
            name: .sessionDidChange,
            object: nil
        )
    }
    
    override func setup() {
        super.setup()
        
        configureCollectionView()
        setupNavigationBar()
        configureDataSource()
        applyInitialSnapshots()
    }
    
    // MARK: - Setup Methods
    private func setupNavigationBar() {
        // Create custom navigation bar
        let customNavBar = UIView()
        customNavBar.backgroundColor = .tertiarySystemGroupedBackground
        customNavBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customNavBar)
        
        // Create vertical stack for title and subtitle
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure title label
        let titleLabel = UILabel()
        titleLabel.text = session.title
        titleLabel.font = .h3
        titleLabel.textAlignment = .left
        
        // Add labels to stack view
        stackView.addArrangedSubview(titleLabel)
        
        customNavBar.addSubview(stackView)
        
        // Add close button
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .systemGray
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        customNavBar.addSubview(closeButton)
        
        // Add separator view
        let separatorView = UIView()
        separatorView.backgroundColor = .separator
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        customNavBar.addSubview(separatorView)
        
        NSLayoutConstraint.activate([
            customNavBar.topAnchor.constraint(equalTo: view.topAnchor),
            customNavBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customNavBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customNavBar.heightAnchor.constraint(equalToConstant: 66),
            
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            closeButton.trailingAnchor.constraint(equalTo: customNavBar.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Separator constraints
            separatorView.leadingAnchor.constraint(equalTo: customNavBar.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: customNavBar.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: customNavBar.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        
        // Update collection view constraints
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: customNavBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc override func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    private func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let insets = UIEdgeInsets(
            top: 20,
            left: 0,
            bottom: 100, // Increased to accommodate button height + padding
            right: 0
        )
        
        // Add bottom inset to accommodate the pinned button
        collectionView.contentInset = insets
        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: insets.bottom - 30, right: 0)
        
        view.addSubview(collectionView)
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
    
    private func configureDataSource() {
        let nestNameRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, indexPath, item in
            if case let .nestName(name: nestName) = item {
                var content = cell.defaultContentConfiguration()
                content.text = nestName
                let image = NNImage.primaryLogo
                content.image = image
                
                content.imageProperties.tintColor = NNColors.primary
                content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
                content.imageToTextPadding = 8
                
                content.directionalLayoutMargins.top = 17
                content.directionalLayoutMargins.bottom = 17
                
                content.textProperties.font = .preferredFont(forTextStyle: .body)
                
                // Only show disclosure indicator for non-archived sessions
                if let self = self, !self.isArchivedSession {
                    cell.accessories = [.disclosureIndicator()]
                } else {
                    cell.accessories = []
                }
                cell.contentConfiguration = content
            }
        }
        
        let dateRegistration = UICollectionView.CellRegistration<SitterDetailDateCell, Item> { cell, indexPath, item in
            if case let .dateSelection(startDate, endDate, _) = item {
                cell.configure(startDate: startDate, endDate: endDate)
            }
        }
        
        let earlyAccessRegistration = UICollectionView.CellRegistration<AccessCell, Item> { cell, indexPath, item in
            if case let .earlyAccess(duration) = item {
                cell.configure(with: duration)
            }
        }
        
        let visibilityRegistration = UICollectionView.CellRegistration<VisibilityCell, Item> { cell, indexPath, item in
            if case let .visibilityLevel(level) = item {
                cell.configure(with: level, isReadOnly: true)
            }
        }
        
        let eventsCellRegistration = UICollectionView.CellRegistration<EventsCell, Item> { cell, indexPath, item in
            if case .events = item {
                // If we're still loading events, show loading indicator
                if self.sessionEvents.isEmpty && self.isLoadingEvents {
                    cell.showLoading()
                } else {
                    cell.configure(eventCount: self.sessionEvents.count)
                }
            }
        }
        
        let sessionEventRegistration = UICollectionView.CellRegistration<SessionEventCell, Item> { cell, indexPath, item in
            if case let .sessionEvent(event) = item {
                cell.includeDate = true
                cell.configure(with: event)
            }
        }

        let moreEventsRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, indexPath, item in
            if case let .moreEvents(count) = item {
                var content = cell.defaultContentConfiguration()
                let text = "+\(count) more"
                
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
        
        let expensesRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, indexPath, item in
            if case .expenses = item {
                var content = cell.defaultContentConfiguration()
                content.text = "Expenses"
                let symbolConfiguration = UIImage.SymbolConfiguration(weight: .semibold)
                let image = UIImage(systemName: "dollarsign.square.fill", withConfiguration: symbolConfiguration)?
                    .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
                content.image = image
                
                content.imageProperties.tintColor = NNColors.primary
                content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
                content.imageToTextPadding = 8
                
                content.directionalLayoutMargins.top = 17
                content.directionalLayoutMargins.bottom = 17
                
                content.textProperties.font = .preferredFont(forTextStyle: .body)
                
                content.secondaryTextProperties.font = .bodyM
                content.secondaryTextProperties.color = .secondaryLabel
                
                cell.accessories = [.disclosureIndicator()]
                cell.contentConfiguration = content
            }
        }
        
        // Add footer registration
        let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { supplementaryView, elementKind, indexPath in
            var configuration = supplementaryView.defaultContentConfiguration()
            
            // Configure footer based on section
            if self.dataSource.sectionIdentifier(for: indexPath.section) == .events {
                configuration.text = "Tap for event details"
                configuration.textProperties.font = .preferredFont(forTextStyle: .footnote)
                configuration.textProperties.color = .tertiaryLabel
                configuration.textProperties.alignment = .center
            } else if false {
                configuration.text = "You can explore the nest during the early access period before your session starts"
                configuration.textProperties.font = .preferredFont(forTextStyle: .footnote)
                configuration.textProperties.color = .tertiaryLabel
                configuration.textProperties.alignment = .center
                configuration.textProperties.numberOfLines = 0
            } else if self.dataSource.sectionIdentifier(for: indexPath.section) == .visibility && self.isArchivedSession {
                configuration.text = "This session has been archived, as such, it cannot be edited."
                configuration.textProperties.font = .preferredFont(forTextStyle: .footnote)
                configuration.textProperties.color = .tertiaryLabel
                configuration.textProperties.alignment = .center
                configuration.textProperties.numberOfLines = 0
            }
            
            supplementaryView.contentConfiguration = configuration
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: collectionView
        ) {
            [weak self] collectionView,
            indexPath,
            item in
            guard let self = self else { return UICollectionViewCell() }
            
            switch item {
            case .nestName:
                return collectionView
                    .dequeueConfiguredReusableCell(
                        using: nestNameRegistration,
                        for: indexPath,
                        item: item
                    )
            case .dateSelection:
                return collectionView.dequeueConfiguredReusableCell(
                    using: dateRegistration,
                    for: indexPath,
                    item: item
                )
                
            case .earlyAccess:
                return collectionView.dequeueConfiguredReusableCell(
                    using: earlyAccessRegistration,
                    for: indexPath,
                    item: item
                )
                
            case .visibilityLevel:
                return collectionView.dequeueConfiguredReusableCell(
                    using: visibilityRegistration,
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
                
            case .expenses:
                return collectionView.dequeueConfiguredReusableCell(
                    using: expensesRegistration,
                    for: indexPath,
                    item: item
                )
            }
        }
        
        // Add supplementary view provider
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            return collectionView.dequeueConfiguredReusableSupplementary(
                using: footerRegistration,
                for: indexPath
            )
        }
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        
        // Add sections based on session type
        if isArchivedSession {
            snapshot.appendSections([.name, .date, .visibility])
        } else {
            snapshot.appendSections([.name, .date, .visibility, .expenses, .events])
        }
        
        // Add nest name and early access to name section
        var nameItems: [Item] = [.nestName(name: nestName)]
        if !isArchivedSession && session.earlyAccessDuration != .none {
            nameItems.append(.earlyAccess(session.earlyAccessDuration))
        }
        snapshot.appendItems(nameItems, toSection: .name)
        
        // Add date selection with initial date
        snapshot.appendItems([.dateSelection(
            startDate: session.startDate,
            endDate: session.endDate,
            isMultiDay: session.isMultiDay
        )], toSection: .date)
        
        // Add visibility level
        snapshot.appendItems([.visibilityLevel(session.visibilityLevel)], toSection: .visibility)

        // Add expenses section only for non-archived sessions
        if !isArchivedSession {
            snapshot.appendItems([.expenses], toSection: .expenses)
        }
        
        // Add events section only for non-archived sessions
        if !isArchivedSession {
            snapshot.appendItems([.events], toSection: .events)
        }
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    private func fetchSessionEvents() {
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
    
    @MainActor
    private func updateEventsSection(with events: [SessionEvent]) {
        var snapshot = dataSource.snapshot()
        
        // Skip if events section doesn't exist (for completed sessions)
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
            
            let eventItems = visibleEvents.map { Item.sessionEvent($0) }
            snapshot.appendItems(eventItems, toSection: .events)
            snapshot.appendItems([.moreEvents(remainingCount)], toSection: .events)
        } else {
            let eventItems = sortedEvents.map { Item.sessionEvent($0) }
            snapshot.appendItems(eventItems, toSection: .events)
        }
        
        snapshot.reconfigureItems([.events])
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    @objc private func handleSessionStatusChange(_ notification: Notification) {
        // Extract session ID and new status from notification
        guard let userInfo = notification.userInfo,
              let sessionId = userInfo["sessionId"] as? String,
              let newStatusString = userInfo["newStatus"] as? String,
              sessionId == session.id else {
            return
        }
        
        // Convert string to SessionStatus enum
        let newStatus = SessionStatus(rawValue: newStatusString) ?? .upcoming
        
        // Update the session item
        session.status = newStatus
        
        // Keep events section visible for all session statuses including completed
        
        // Log the status change
        Logger.log(
            level: .info,
            category: .sessionService,
            message: "Session status updated to \(newStatus.displayName) via notification"
        )
    }
    
    @objc private func handleSessionChange(_ notification: Notification) {
        // Refresh session data and events when app resumes or notification is received
        dismiss(animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Helper Methods
    
    /// Determines if a sitter can access the nest for the given session
    private func canSitterAccessNest(for session: SessionItem) -> Bool {
        let now = Date()
        
        Logger.log(level: .info, category: .sessionService, message: "Checking nest access for session: \(session.id)")
        Logger.log(level: .info, category: .sessionService, message: "Session status: \(session.status.rawValue)")
        Logger.log(level: .info, category: .sessionService, message: "Early access duration: \(session.earlyAccessDuration.displayName)")
        
        // Allow access during active session states
        if session.status == .inProgress || session.status == .extended {
            Logger.log(level: .info, category: .sessionService, message: "Access granted: Active session")
            return true
        }
        
        // Allow access during early access (post-session)
        if session.status == .earlyAccess && session.isInEarlyAccess {
            Logger.log(level: .info, category: .sessionService, message: "Access granted: Post-session early access")
            return true
        }
        
        // Allow access during pre-session early access window
        if session.status == .upcoming && session.earlyAccessDuration != .none {
            let earlyAccessStartTime = session.startDate.addingTimeInterval(-session.earlyAccessDuration.timeInterval)
            let isWithinEarlyAccess = now >= earlyAccessStartTime
            
            Logger.log(level: .info, category: .sessionService, message: "Session start date: \(session.startDate)")
            Logger.log(level: .info, category: .sessionService, message: "Early access start time: \(earlyAccessStartTime)")
            Logger.log(level: .info, category: .sessionService, message: "Current time: \(now)")
            Logger.log(level: .info, category: .sessionService, message: "Within pre-session early access: \(isWithinEarlyAccess)")
            
            if isWithinEarlyAccess {
                Logger.log(level: .info, category: .sessionService, message: "Access granted: Pre-session early access")
            }
            
            return isWithinEarlyAccess
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Access denied: Outside allowed windows")
        return false
    }
}

// MARK: - UICollectionViewDelegate
extension SitterSessionDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return false }
        switch item {
        case .nestName:
            // Only allow highlighting nest cell for non-archived sessions
            return !isArchivedSession
        case .sessionEvent, .expenses:
            return true
        case .events, .moreEvents:
            // Don't allow highlighting events if they are currently loading
            return !isLoadingEvents
        default:
            return false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch item {
        case .nestName:
            // Don't allow nest access for archived sessions
            guard !isArchivedSession else { return }
            
            // Check if session allows nest exploration
            let hasNestAccess = canSitterAccessNest(for: session)
            guard hasNestAccess else {
                let alert = UIAlertController(
                    title: "Nest Access Unavailable",
                    message: "You can explore the nest during an active session, early access period, or within the early access window before the session starts.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
            
            // Configure the sitter view service for this specific session
            let sitterService = SitterViewService.shared
            
            // Create a temporary session-specific state for this context
            Task {
                do {
                    // Fetch the nest information for this session
                    let nestRef = Firestore.firestore().collection("nests").document(session.nestID)
                    let nestDoc = try await nestRef.getDocument()
                    var nest = try nestDoc.data(as: NestItem.self)
                    
                    // Fetch categories for the nest
                    let categoriesRef = nestRef.collection("nestCategories")
                    let categoriesSnapshot = try await categoriesRef.getDocuments()
                    let categories = try categoriesSnapshot.documents.map { try $0.data(as: NestCategory.self) }
                    nest.categories = categories
                    
                    await MainActor.run {
                        // Temporarily set the view state for this session context
                        sitterService.setTemporarySessionContext(session: self.session, nest: nest)
                        
                        let nestViewController = NestViewController(entryRepository: sitterService)
                        let navigationController = UINavigationController(rootViewController: nestViewController)
                        
                        // Configure the presentation style
                        navigationController.modalPresentationStyle = .pageSheet
                        if let sheet = navigationController.sheetPresentationController {
                            sheet.detents = [.large()]
                            sheet.prefersGrabberVisible = true
                        }
                        
                        self.present(navigationController, animated: true)
                    }
                } catch {
                    await MainActor.run {
                        let alert = UIAlertController(
                            title: "Error",
                            message: "Unable to load nest information: \(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
            
        case .sessionEvent(let event):
            // Present event details in read-only mode
            let eventVC = SessionEventViewController(sessionID: session.id, event: event, isReadOnly: true)
            present(eventVC, animated: true)
            
        case .events, .moreEvents:
            // Skip handling events if we're still loading them
            if isLoadingEvents { return }
            
            // Get the current date range from the date cell
            guard let dateItem = dataSource.snapshot().itemIdentifiers(inSection: .date).first,
                  case let .dateSelection(startDate, endDate, _) = dateItem else {
                return
            }
            
            // Present calendar view
            let dateRange = DateInterval(start: startDate, end: endDate)
            let calendarVC = SessionCalendarViewController(sessionID: session.id, nestID: session.nestID, dateRange: dateRange, events: sessionEvents)
            let nav = UINavigationController(rootViewController: calendarVC)
            present(nav, animated: true)
            
        case .expenses:
            let vc = NNFeaturePreviewViewController(feature: .expenses)
            present(vc, animated: true)
            
        default:
            break
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// Add this class before the UICollectionViewDelegate extension
final class SitterDetailDateCell: UICollectionViewListCell {
    private let startLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .label
        label.text = "Starts"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let startDateLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let endLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .label
        label.text = "Ends"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let endDateLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let verticalDividerLine: UIView = {
        let view = UIView()
        view.backgroundColor = NNColors.primary
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let horizontalDividerLine: UIView = {
        let view = UIView()
        view.backgroundColor = NNColors.NNSystemBackground4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let startImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = NNColors.primary
        imageView.image = UIImage(systemName: "circle.fill")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let endImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = NNColors.primary
        imageView.image = UIImage(systemName: "circle.dashed")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Add all views to content view
        [startLabel, startDateLabel, endLabel, endDateLabel, verticalDividerLine, horizontalDividerLine, startImageView, endImageView].forEach {
            contentView.addSubview($0)
        }
        
        // Constants for layout
        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 16
        let labelSpacing: CGFloat = 8
        let dividerWidth: CGFloat = 1
        let imageHeight: CGFloat = 20
        let imageWidth: CGFloat = 26
        
        
        NSLayoutConstraint.activate([
            startImageView.centerYAnchor.constraint(equalTo: startLabel.centerYAnchor),
            startImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            startImageView.heightAnchor.constraint(equalToConstant: imageHeight),
            startImageView.widthAnchor.constraint(equalToConstant: imageWidth),
            
            // Vertical divider constraints
            verticalDividerLine.centerXAnchor.constraint(equalTo: startImageView.centerXAnchor),
            verticalDividerLine.topAnchor.constraint(equalTo: startImageView.bottomAnchor),
            verticalDividerLine.bottomAnchor.constraint(equalTo: endImageView.topAnchor),
            verticalDividerLine.widthAnchor.constraint(equalToConstant: dividerWidth),
            
            endImageView.centerYAnchor.constraint(equalTo: endLabel.centerYAnchor),
            endImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            endImageView.heightAnchor.constraint(equalToConstant: imageHeight),
            endImageView.widthAnchor.constraint(equalToConstant: imageWidth),
            
            // Start label constraints
            startLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: verticalPadding),
            startLabel.leadingAnchor.constraint(equalTo: startImageView.trailingAnchor, constant: labelSpacing),
            startLabel.trailingAnchor.constraint(lessThanOrEqualTo: startDateLabel.leadingAnchor, constant: -8).with(priority: .defaultLow),
            
            // Start date label constraints
            startDateLabel.centerYAnchor.constraint(equalTo: startLabel.centerYAnchor),
            startDateLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -horizontalPadding).with(priority: .defaultHigh),
            
            // End label constraints
            endLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -verticalPadding),
            endLabel.leadingAnchor.constraint(equalTo: startImageView.trailingAnchor, constant: labelSpacing),
            endLabel.trailingAnchor.constraint(lessThanOrEqualTo: endDateLabel.leadingAnchor, constant: -8).with(priority: .defaultLow),
            
            // End date label constraints
            endDateLabel.centerYAnchor.constraint(equalTo: endLabel.centerYAnchor),
            endDateLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -horizontalPadding).with(priority: .defaultHigh),
            
            // Vertical spacing between start and end
            endLabel.topAnchor.constraint(equalTo: startLabel.bottomAnchor, constant: 24),

            // Horizontal divider constraints
            horizontalDividerLine.leadingAnchor.constraint(equalTo: startLabel.leadingAnchor),
            horizontalDividerLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalPadding),
            horizontalDividerLine.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            horizontalDividerLine.heightAnchor.constraint(equalToConstant: dividerWidth)
        ])
    }
    
    func configure(startDate: Date, endDate: Date) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, MMM d"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        
        let calendar = Calendar.current
        let sameDay = calendar.isDate(startDate, inSameDayAs: endDate)
        
        // Start date and time
        let startDateString = dateFormatter.string(from: startDate)
        let startTimeString = timeFormatter.string(from: startDate)
        startDateLabel.text = "\(startDateString) at \(startTimeString)"
        
        // End date and time
        if sameDay {
            // If same day, just show the time
            endDateLabel.text = timeFormatter.string(from: endDate)
        } else {
            // If different days, show full date and time
            let endDateString = dateFormatter.string(from: endDate)
            let endTimeString = timeFormatter.string(from: endDate)
            endDateLabel.text = "\(endDateString) at \(endTimeString)"
        }
    }
} 
