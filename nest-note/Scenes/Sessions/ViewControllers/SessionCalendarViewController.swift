import UIKit

// Add protocol for event updates
protocol SessionCalendarViewControllerDelegate: AnyObject {
    func calendarViewController(_ controller: SessionCalendarViewController, didUpdateEvents events: [SessionEvent])
}

// Add an enum to represent section content
enum CalendarSection: Hashable {
    case events(date: Date)  // Section with events
    case emptyDays(dateRange: DateInterval)  // Section for consecutive empty days
}

final class SessionCalendarViewController: NNViewController, CollectionViewLoadable {
    // MARK: - Properties
    private let footnoteLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let calendarStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 20
        return stack
    }()
    
    private let compactCalendarView: NNCompactCalendarView
    
    var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<CalendarSection, AnyHashable>!
    
    private var eventsByDate: [Date: [SessionEvent]] = [:]
    
    private let sessionID: String?
    private let dateRange: DateInterval
    private var selectedDate: Date?
    private var events: [SessionEvent] = []
    
    private var hasSetInitialOffset = false
    
    // Add a property to store the menu button
    private var menuButton: UIButton!
    
    // Add this property to track highlighted cells
    private var highlightedCells: [IndexPath] = []
    
    // Add delegate property
    weak var delegate: SessionCalendarViewControllerDelegate?
    
    private lazy var emptyStateView: NNEmptyStateView = {
        let view = NNEmptyStateView(
            icon: UIImage(systemName: "calendar.badge.plus"),
            title: "No events",
            subtitle: "Tap anywhere on the calendar to add an event."
        )
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Add required properties
    var loadingIndicator: UIActivityIndicatorView!
    var refreshControl: UIRefreshControl!
    
    // Add a cell type for empty days
    struct EmptyDaysItem: Hashable {
        let dateRange: DateInterval
    }
    
    // MARK: - Initialization
    init(sessionID: String? = nil, dateRange: DateInterval, events: [SessionEvent] = []) {
        self.sessionID = sessionID
        let calendar = Calendar.current
        
        // Strip time components and get start of day for both dates
        let startOfStartDay = calendar.startOfDay(for: dateRange.start)
        let startOfEndDay = calendar.startOfDay(for: dateRange.end)
        
        // Create new DateInterval with clean dates
        let cleanDateRange = DateInterval(start: startOfStartDay, end: startOfEndDay)
        
        self.dateRange = cleanDateRange
        
        // Group provided events by date
        if !events.isEmpty {
            self.eventsByDate = Dictionary(grouping: events) { event in
                calendar.startOfDay(for: event.startDate)
            }
        }

        self.compactCalendarView = NNCompactCalendarView(dateRange: cleanDateRange, events: events)
        
        super.init(nibName: nil, bundle: nil)
        self.compactCalendarView.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupPaletteCalendar()
        
        // Set content insets after everything is set up
        updateCollectionViewInsets()
    }
    
    func setupPaletteCalendar() {
        let compactCalendar = compactCalendarView
        compactCalendar.frame.size.height = 70
        
        addNavigationBarPalette(compactCalendar)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !hasSetInitialOffset {
            updateCollectionViewInsets()
            let topInset = collectionView.contentInset.top
            collectionView.setContentOffset(CGPoint(x: 0, y: -topInset), animated: false)
            hasSetInitialOffset = true
        }
    }
    
    override func setup() {
        super.setup()
        
        view.backgroundColor = .systemGroupedBackground
        
        setupLoadingIndicator()
        setupCollectionView()
        setupRefreshControl()
        setupNavigationBar()
        
        // Add subviews in correct order
        view.addSubview(collectionView)
        view.addSubview(compactCalendarView)
        
        setupEmptyStateView()
        
        // Configure footnote text
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let startDateString = dateFormatter.string(from: dateRange.start)
        let endDateString = dateFormatter.string(from: dateRange.end)
        footnoteLabel.text = "Tap a date to add a session event (\(startDateString)-\(endDateString))"
        
        NSLayoutConstraint.activate([
            compactCalendarView.heightAnchor.constraint(equalToConstant: 50),
            compactCalendarView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            compactCalendarView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // Initial load
        Task {
            await loadData()
        }
    }
    
    func setupNavigationBar() {
        navigationItem.title = "Session Events"
        
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.standardAppearance = appearance
        
        // Create debug button
        let debugButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            style: .plain,
            target: self,
            action: #selector(debugButtonTapped)
        )
        
        // Create add button
        let addButton = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addEventTapped)
        )
        
        navigationItem.rightBarButtonItems = [addButton]
        if sessionID == nil {
            navigationItem.rightBarButtonItems?.append(debugButton)
        }
    }
    
    @objc private func addEventTapped() {
        let eventVC = SessionEventViewController(sessionID: sessionID)
        
        eventVC.eventDelegate = self
        
        // If we have a selected date, we could potentially configure the event VC with it
        if let selectedDate = selectedDate {
            // Configure the event VC with the selected date
            let calendar = Calendar.current
            let startOfDay = calendar.middleOfDay(for: selectedDate)
            eventVC.startControl.date = startOfDay
            eventVC.endControl.date = calendar.date(byAdding: .hour, value: 1, to: startOfDay) ?? startOfDay
        } else {
            let calendar = Calendar.current
            let firstDayOfSession = dateRange.start
            eventVC.startControl.date = firstDayOfSession
            eventVC.endControl.date = calendar.date(byAdding: .hour, value: 1, to: firstDayOfSession) ?? firstDayOfSession
        }
        
        present(eventVC, animated: true)
    }
    
    @objc private func debugButtonTapped() {
        // Generate new random events
        let newEvents = SessionEventGenerator.generateRandomEvents(in: dateRange)
        
        // Group events by date
        let calendar = Calendar.current
        eventsByDate = Dictionary(grouping: newEvents) { event in
            calendar.startOfDay(for: event.startDate)
        }
        
        // Update both views
        compactCalendarView.updateEvents(eventsByDate)
        applySnapshot()
        
        // Notify delegate of new events
        delegate?.calendarViewController(self, didUpdateEvents: newEvents)
    }
    
    private func setupCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup data source
        let eventCellRegistration = UICollectionView.CellRegistration<SessionEventCell, SessionEvent> { cell, indexPath, event in
            cell.configure(with: event)
            
            var backgroundConfig = UIBackgroundConfiguration.listCell()
            backgroundConfig.backgroundColor = .secondarySystemGroupedBackground
            cell.backgroundConfiguration = backgroundConfig
        }
        
        let emptyDaysCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, EmptyDaysItem> { cell, indexPath, item in
            var config = cell.defaultContentConfiguration()
            config.text = "No Events"
            config.textProperties.color = .secondaryLabel
            config.textProperties.alignment = .justified
            cell.contentConfiguration = config
            
            var backgroundConfig = UIBackgroundConfiguration.listPlainCell()
            backgroundConfig.backgroundColor = .secondarySystemGroupedBackground
            cell.backgroundConfiguration = backgroundConfig
        }
        
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            if let event = item as? SessionEvent {
                return collectionView.dequeueConfiguredReusableCell(using: eventCellRegistration, for: indexPath, item: event)
            } else if let emptyItem = item as? EmptyDaysItem {
                return collectionView.dequeueConfiguredReusableCell(using: emptyDaysCellRegistration, for: indexPath, item: emptyItem)
            }
            return nil
        }
        
        let headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] headerView, elementKind, indexPath in
            guard let section = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section] else { return }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE, MMM d"
            
            switch section {
            case .events(let date):
                headerView.configure(title: dateFormatter.string(from: date))
            case .emptyDays(let dateRange):
                let startStr = dateFormatter.string(from: dateRange.start)
                let endStr = dateFormatter.string(from: dateRange.end)
                headerView.configure(title: "\(startStr) - \(endStr)")
            }
        }
        
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self = self else { return nil }
            
            if kind == UICollectionView.elementKindSectionHeader {
                return collectionView.dequeueConfiguredReusableSupplementary(
                    using: headerRegistration,
                    for: indexPath
                )
            }
            return nil
        }
        
        collectionView.delegate = self
        
        // Add refresh control
        collectionView.refreshControl = refreshControl
    }
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<CalendarSection, AnyHashable>()
        
        // Get all dates in the range
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: dateRange.start)
        let endDate = calendar.startOfDay(for: dateRange.end)
        
        var emptyDaysStart: Date?
        
        while currentDate <= endDate {
            if let events = eventsByDate[currentDate], !events.isEmpty {
                // If we had empty days, add them as a section
                if let start = emptyDaysStart {
                    let emptyRange = DateInterval(start: start, end: currentDate)
                    snapshot.appendSections([.emptyDays(dateRange: emptyRange)])
                    snapshot.appendItems([EmptyDaysItem(dateRange: emptyRange)])
                    emptyDaysStart = nil
                }
                
                // Add events section
                let section = CalendarSection.events(date: currentDate)
                snapshot.appendSections([section])
                snapshot.appendItems(events, toSection: section)
            } else {
                // Track start of empty days if not already tracking
                if emptyDaysStart == nil {
                    emptyDaysStart = currentDate
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Add any remaining empty days
        if let start = emptyDaysStart {
            let emptyRange = DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: endDate)!)
            snapshot.appendSections([.emptyDays(dateRange: emptyRange)])
            snapshot.appendItems([EmptyDaysItem(dateRange: emptyRange)])
        }
        
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    func loadData(showLoadingIndicator: Bool = true) async {
        guard let sessionID = sessionID else { return }
        
        do {
            if showLoadingIndicator {
                await MainActor.run {
                    loadingIndicator.startAnimating()
                }
            }
            
            let events = try await SessionService.shared.getSessionEvents(sessionID: sessionID)
            
            await MainActor.run {
                let calendar = Calendar.current
                eventsByDate = Dictionary(grouping: events) { event in
                    calendar.startOfDay(for: event.startDate)
                }
                
                handleLoadedData()
                loadingIndicator.stopAnimating()
            }
        } catch {
            await MainActor.run {
                loadingIndicator.stopAnimating()
                Logger.log(level: .error, category: .sessionService, message: "Error loading events: \(error.localizedDescription)")
                
                let alert = UIAlertController(
                    title: "Error",
                    message: "Failed to load events. Please try again.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
    
    // Implement required methods
    func handleLoadedData() {
        compactCalendarView.updateEvents(eventsByDate)
        applySnapshot()
        updateEmptyState()
    }
    
    // Update scrollToDate method
    private func scrollToDate(_ date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let sections = dataSource.snapshot().sectionIdentifiers
        
        // Find the matching section
        if let section = sections.first(where: { section in
            switch section {
            case .events(let sectionDate):
                return calendar.isDate(sectionDate, inSameDayAs: startOfDay)
            case .emptyDays(let dateRange):
                return dateRange.contains(startOfDay)
            }
        }), let sectionIndex = sections.firstIndex(of: section) {
            let numberOfItemsInSection = dataSource.snapshot().numberOfItems(inSection: section)
            
            if let headerAttributes = collectionView.layoutAttributesForSupplementaryElement(
                ofKind: UICollectionView.elementKindSectionHeader,
                at: IndexPath(item: 0, section: sectionIndex)
            ),
               let lastItemAttributes = collectionView.layoutAttributesForItem(
                at: IndexPath(item: numberOfItemsInSection - 1, section: sectionIndex)
               ) {
                let sectionRect = headerAttributes.frame.union(lastItemAttributes.frame)
                collectionView.scrollRectToVisible(sectionRect, animated: true)
            }
        }
    }
    
    private func updateCollectionViewInsets() {
        
        collectionView.contentInset = UIEdgeInsets(
            top: 20,
            left: 0,
            bottom: 0,
            right: 0
        )
        
        collectionView.scrollIndicatorInsets = collectionView.contentInset
        
        // Set initial offset
        if !hasSetInitialOffset {
            collectionView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
            hasSetInitialOffset = true
        }
    }
    
    private func setupEmptyStateView() {
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: collectionView.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: collectionView.trailingAnchor, constant: -32)
        ])
    }
    
    private func updateEmptyState() {
        let hasEvents = !eventsByDate.isEmpty
        emptyStateView.isHidden = hasEvents
        
        if !hasEvents {
            let (title, subtitle, icon) = emptyStateConfig(for: dateRange)
            emptyStateView.configure(icon: icon, title: title, subtitle: subtitle)
        }
    }
    
    private func emptyStateConfig(for dateRange: DateInterval) -> (title: String, subtitle: String, icon: UIImage?) {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 0
        
        if days <= 1 {
            return (
                "No events today",
                "Tap anywhere to add an event.",
                UIImage(systemName: "calendar.badge.plus")
            )
        } else if days <= 7 {
            return (
                "No events this week",
                "Tap any day to add events.",
                UIImage(systemName: "calendar.badge.plus")
            )
        } else {
            return (
                "No events in this period",
                "Tap any day to start adding events.",
                UIImage(systemName: "calendar.badge.plus")
            )
        }
    }
    
    @objc private func refreshEvents() {
        Task {
            await loadData(showLoadingIndicator: false)
            refreshControl.endRefreshing()
        }
    }
}

// MARK: - UICalendarSelectionSingleDateDelegate
extension SessionCalendarViewController: UICalendarSelectionSingleDateDelegate {
    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        guard let date = dateComponents?.date else { return }
        selectedDate = date
        // Instead of reloadEvents(), just scroll and highlight
        scrollToDate(date)
        highlightEventsFor(date)
    }
    
    func dateSelection(_ selection: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool {
        guard let date = dateComponents?.date else { return false }
        return dateRange.contains(date)
    }
}

// MARK: - SessionEventCell
class SessionEventCell: UICollectionViewListCell {
    var includeDate: Bool = false
    
    private let colorIndicator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        contentView.addSubview(colorIndicator)
        contentView.addSubview(titleLabel)
        contentView.addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            colorIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            colorIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            colorIndicator.widthAnchor.constraint(equalToConstant: 16),
            colorIndicator.heightAnchor.constraint(equalToConstant: 16),
            
            titleLabel.leadingAnchor.constraint(equalTo: colorIndicator.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    
    func configure(with event: SessionEvent) {
        titleLabel.text = event.title
        titleLabel.textAlignment = .left
        titleLabel.textColor = .label
        
        let hourMinuteFormat: String = "h:mma"
        let hourFormat: String = "ha"
        let monthDayPrefixFormat: String = "MMM d"
        
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let minutes = calendar.component(.minute, from: event.startDate)
        
        // Determine format based on whether we include date and if time is on the hour
        formatter.dateFormat = if minutes == 0 {
            includeDate ? "\(monthDayPrefixFormat), \(hourFormat)" : hourFormat
        } else {
            includeDate ? "\(monthDayPrefixFormat), \(hourMinuteFormat)" : hourMinuteFormat
        }
        
        timeLabel.text = formatter.string(from: event.startDate)
        
        colorIndicator.backgroundColor = event.eventColor.fill
        colorIndicator.layer.borderWidth = 2
        colorIndicator.layer.borderColor = event.eventColor.border.cgColor
        colorIndicator.isHidden = false
        
        timeLabel.isHidden = false
    }
    
    func setHighlighted(_ highlighted: Bool) {
        
        UIView.animate(withDuration: 0.2) {
            self.contentView.backgroundColor = highlighted ? 
                .systemGray3 :
                .secondarySystemGroupedBackground
        }
    }
}


// MARK: - NNCompactCalendarViewDelegate
extension SessionCalendarViewController: NNCompactCalendarViewDelegate {
    func calendarView(_ calendarView: NNCompactCalendarView, didSelectDate date: Date) {
        selectedDate = date
        scrollToDate(date)
        highlightEventsFor(date)
    }
    
    func highlightEventsFor(_ date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Find the events section for this date
        if let section = dataSource.snapshot().sectionIdentifiers.first(where: { section in
            if case .events(let sectionDate) = section {
                return calendar.isDate(sectionDate, inSameDayAs: startOfDay)
            }
            return false
        }), let sectionIndex = dataSource.snapshot().sectionIdentifiers.firstIndex(of: section) {
            let itemCount = dataSource.snapshot().numberOfItems(inSection: section)
            
            // Highlight all cells in the section
            for item in 0..<itemCount {
                let indexPath = IndexPath(item: item, section: sectionIndex)
                if let cell = collectionView.cellForItem(at: indexPath) as? SessionEventCell {
                    cell.setHighlighted(true)
                    
                    // Remove highlight after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        cell.setHighlighted(false)
                    }
                }
            }
        }
    }
}

// Add UICollectionViewDelegate extension
extension SessionCalendarViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
        
        // Get the selected event if it exists
        if let item = dataSource.itemIdentifier(for: indexPath) as? SessionEvent,
           let cell = collectionView.cellForItem(at: indexPath) {
            // Get cell's frame in window coordinates
            let sourceFrame = cell.convert(cell.bounds, to: nil)
            
            // Present event editing with source frame
            let eventVC = SessionEventViewController(
                sessionID: sessionID,
                event: item,
                sourceFrame: sourceFrame
            )
            eventVC.eventDelegate = self
            present(eventVC, animated: true)
        } else {
            // Present new event creation
            let eventVC = SessionEventViewController(sessionID: sessionID)
            eventVC.eventDelegate = self
            
            // Configure with the section date
            if case .events(let date) = section {
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: date)
                let defaultStartTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay) ?? startOfDay
                let defaultEndTime = calendar.date(byAdding: .hour, value: 1, to: defaultStartTime) ?? defaultStartTime
                
                eventVC.startControl.date = defaultStartTime
                eventVC.endControl.date = defaultEndTime
            }
            
            present(eventVC, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        // Only show context menu for event cells
        guard let event = dataSource.itemIdentifier(for: indexPath) as? SessionEvent else { return nil }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.deleteEvent(event)
            }
            
            let duplicateAction = UIAction(
                title: "Duplicate",
                image: UIImage(systemName: "plus.square.on.square")
            ) { [weak self] _ in
                self?.duplicateEvent(event)
            }
            
            return UIMenu(children: [duplicateAction, deleteAction])
        }
    }
    
    private func deleteEvent(_ event: SessionEvent) {
        guard let sessionID = sessionID else { return }
        
        Task {
            do {
                try await SessionService.shared.deleteSessionEvent(event.id, sessionID: sessionID)
                
                await MainActor.run {
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: event.startDate)
                    
                    // Remove from events dictionary
                    if var events = eventsByDate[startOfDay] {
                        events.removeAll { $0.id == event.id }
                        if events.isEmpty {
                            eventsByDate.removeValue(forKey: startOfDay)
                            
                            // Instead of just deleting the item, recreate the snapshot
                            // to properly handle empty sections
                            applySnapshot()
                        } else {
                            eventsByDate[startOfDay] = events
                            
                            // If we still have events in the section, just delete the item
                            var snapshot = dataSource.snapshot()
                            snapshot.deleteItems([event])
                            dataSource.apply(snapshot, animatingDifferences: true)
                        }
                    }
                    
                    // Update other views
                    compactCalendarView.updateEvents(eventsByDate)
                    updateEmptyState()
                    
                    // Notify delegate
                    let allEvents = eventsByDate.values.flatMap { $0 }
                    delegate?.calendarViewController(self, didUpdateEvents: allEvents)
                }
            } catch {
                Logger.log(level: .error, category: .sessionService, message: "Failed to delete event: \(error.localizedDescription)")
                
                await MainActor.run {
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to delete event. Please try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    private func duplicateEvent(_ event: SessionEvent) {
        // Create new event with same properties but new ID
        let duplicatedEvent = SessionEvent(
            id: UUID().uuidString,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            eventColor: .blue
        )
        
        guard let sessionID = sessionID else { return }
        
        Task {
            do {
                try await SessionService.shared.updateSessionEvent(duplicatedEvent, sessionID: sessionID)
                
                await MainActor.run {
                    // Add to local storage
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: duplicatedEvent.startDate)
                    
                    if var events = eventsByDate[startOfDay] {
                        events.append(duplicatedEvent)
                        events.sort { $0.startDate < $1.startDate }
                        eventsByDate[startOfDay] = events
                    } else {
                        eventsByDate[startOfDay] = [duplicatedEvent]
                    }
                    
                    // Update views
                    compactCalendarView.updateEvents(eventsByDate)
                    applySnapshot()
                    
                    // Notify delegate
                    let allEvents = eventsByDate.values.flatMap { $0 }
                    delegate?.calendarViewController(self, didUpdateEvents: allEvents)
                }
            } catch {
                Logger.log(level: .error, category: .sessionService, message: "Failed to duplicate event: \(error.localizedDescription)")
                
                await MainActor.run {
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to duplicate event. Please try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

extension SessionCalendarViewController: SessionEventViewControllerDelegate {
    func sessionEventViewController(_ controller: SessionEventViewController, didCreateEvent event: SessionEvent?) {
        guard let event = event else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: event.startDate)
        
        // Update or add the event
        if var existingEvents = eventsByDate[startOfDay] {
            // If this event already exists (has same ID), replace it
            if let existingIndex = existingEvents.firstIndex(where: { $0.id == event.id }) {
                existingEvents[existingIndex] = event
            } else {
                // If it's a new event, append it
                existingEvents.append(event)
            }
            // Sort events by start time
            existingEvents.sort { $0.startDate < $1.startDate }
            eventsByDate[startOfDay] = existingEvents
        } else {
            eventsByDate[startOfDay] = [event]
        }
        
        // Update calendar view with new events
        compactCalendarView.updateEvents(eventsByDate)
        
        // Update collection view and empty state
        applySnapshot()
        updateEmptyState()
        
        // After the snapshot is applied, scroll to and highlight the new event
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            self.selectedDate = startOfDay
            self.scrollToDate(startOfDay)
            
            // Find the events section for this date and highlight only the specific event
            if let section = self.dataSource.snapshot().sectionIdentifiers.first(where: { section in
                if case .events(let sectionDate) = section {
                    return calendar.isDate(sectionDate, inSameDayAs: startOfDay)
                }
                return false
            }),
               let sectionIndex = self.dataSource.snapshot().sectionIdentifiers.firstIndex(of: section),
               let events = self.eventsByDate[startOfDay],
               let itemIndex = events.firstIndex(where: { $0.id == event.id }) {
                
                let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                if let cell = self.collectionView.cellForItem(at: indexPath) as? SessionEventCell {
                    cell.setHighlighted(true)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        cell.setHighlighted(false)
                    }
                }
            }
        }
        
        // Notify delegate of updated events
        let allEvents = eventsByDate.values.flatMap { $0 }
        delegate?.calendarViewController(self, didUpdateEvents: allEvents)
    }
}
