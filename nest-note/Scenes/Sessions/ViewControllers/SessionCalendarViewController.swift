import UIKit

// Add protocol for event updates
protocol SessionCalendarViewControllerDelegate: AnyObject {
    func calendarViewController(_ controller: SessionCalendarViewController, didUpdateEvents events: [SessionEvent])
}

final class SessionCalendarViewController: NNViewController {
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
    
    private let blurView: UIVisualEffectView = {
        let view = UIVisualEffectView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.effect = UIBlurEffect.variableBlurEffect(radius: 16, maskImage: UIImage(named: "testBG5")!)
        view.transform = CGAffineTransform(rotationAngle: .pi)
        return view
    }()
    
    private let calendarStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 20
        return stack
    }()
    
    private let compactCalendarView: NNCompactCalendarView
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Date, SessionEvent>!
    
    private var eventsByDate: [Date: [SessionEvent]] = [:]
    
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
    
    // MARK: - Initialization
    init(dateRange: DateInterval, events: [SessionEvent] = []) {
        let calendar = Calendar.current
        
        // Strip time components and get start of day for both dates
        let startOfStartDay = calendar.startOfDay(for: dateRange.start)
        let startOfEndDay = calendar.startOfDay(for: dateRange.end)
        
        // Create new DateInterval with clean dates
        let cleanDateRange = DateInterval(start: startOfStartDay, end: startOfEndDay)
        
        self.dateRange = cleanDateRange
        self.compactCalendarView = NNCompactCalendarView(dateRange: cleanDateRange)
        
        // Group provided events by date
        if !events.isEmpty {
            self.eventsByDate = Dictionary(grouping: events) { event in
                calendar.startOfDay(for: event.startDate)
            }
        }
        
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
        view.backgroundColor = .systemGroupedBackground
        
        setupCollectionView()
        
        // Add subviews in correct order
        view.addSubview(collectionView)
        view.addSubview(compactCalendarView)
        
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
        
        loadEvents()
        applySnapshot()
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
        
        navigationItem.rightBarButtonItems = [addButton, debugButton]
    }
    
    @objc private func addEventTapped() {
        let eventVC = SessionEventViewController()
        
        // If we have a selected date, we could potentially configure the event VC with it
        if let selectedDate = selectedDate {
            // Configure the event VC with the selected date
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: selectedDate)
            eventVC.startControl.date = startOfDay
            eventVC.endControl.date = calendar.date(byAdding: .hour, value: 1, to: startOfDay) ?? startOfDay
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
        let cellRegistration = UICollectionView.CellRegistration<SessionEventCell, SessionEvent> { cell, indexPath, event in
            cell.configure(with: event)
            
            var backgroundConfig = UIBackgroundConfiguration.listCell()
            backgroundConfig.backgroundColor = .secondarySystemGroupedBackground
            cell.backgroundConfiguration = backgroundConfig
        }
        
        let headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] headerView, elementKind, indexPath in
            guard let self = self else { return }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE, MMM d"
            
            let sectionDate = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            headerView.configure(title: dateFormatter.string(from: sectionDate))
        }
        
        dataSource = UICollectionViewDiffableDataSource<Date, SessionEvent>(collectionView: collectionView) { [weak self] collectionView, indexPath, event in
            let cell = collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: event) as! SessionEventCell
            
            let sectionDate = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section] ?? event.startDate
            let hasEvents = (self?.eventsByDate[sectionDate]?.isEmpty ?? true) == false
            
            cell.configure(with: event)
            
            return cell
        }
        
        // Update the data source to handle empty sections
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self = self else { return nil }
            
            if kind == UICollectionView.elementKindSectionHeader {
                let headerView = collectionView.dequeueConfiguredReusableSupplementary(
                    using: headerRegistration,
                    for: indexPath
                )
                
                let sectionDate = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "EEEE, MMM d"
                headerView.configure(title: dateFormatter.string(from: sectionDate))
                
                return headerView
            }
            return nil
        }
        
        collectionView.delegate = self
    }
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Date, SessionEvent>()
        
        // Sort dates for consistent ordering
        let sortedDates = eventsByDate.keys.sorted()
        
        for date in sortedDates {
            if let events = eventsByDate[date], !events.isEmpty {
                snapshot.appendSections([date])
                snapshot.appendItems(events, toSection: date)
            }
        }
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    private func loadEvents() {
        // Only generate random events if we don't have any
//        if eventsByDate.isEmpty {
//            let generatedEvents = SessionEventGenerator.generateRandomEvents(in: dateRange)
//            
//            // Group events by date
//            let calendar = Calendar.current
//            eventsByDate = Dictionary(grouping: generatedEvents) { event in
//                calendar.startOfDay(for: event.startDate)
//            }
//        }
//        
//        // Update calendar view with events
//        compactCalendarView.updateEvents(eventsByDate)
    }
    
    private func reloadEvents() {
        if let selectedDate = selectedDate {
            
            // ensure there are events for selected date before reloading
            guard eventsByDate[selectedDate] != nil else { return }
            
            let startOfDay = Calendar.current.startOfDay(for: selectedDate)
            var snapshot = dataSource.snapshot()
            snapshot.reloadSections([startOfDay])
            dataSource.apply(snapshot, animatingDifferences: true)
            
            // Update calendar view with new events
            compactCalendarView.updateEvents(eventsByDate)
        }
    }
    
    // Update scrollToDate method
    private func scrollToDate(_ date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Get all section identifiers (dates) from the data source
        let sections = dataSource.snapshot().sectionIdentifiers
        
        // Find the index of the section that matches our date
        if let sectionIndex = sections.firstIndex(of: startOfDay) {
            let numberOfItemsInSection = dataSource.snapshot().numberOfItems(inSection: startOfDay)
            
            if let headerAttributes = collectionView.layoutAttributesForSupplementaryElement(
                ofKind: UICollectionView.elementKindSectionHeader,
                at: IndexPath(item: 0, section: sectionIndex)
            ),
               let lastItemAttributes = collectionView.layoutAttributesForItem(
                at: IndexPath(item: numberOfItemsInSection - 1, section: sectionIndex)
               ) {
                // Create a rect that encompasses both header and section content
                let sectionRect = headerAttributes.frame.union(lastItemAttributes.frame)
                collectionView.scrollRectToVisible(sectionRect, animated: true)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.highlightEventsFor(date)
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
}

// MARK: - UICalendarSelectionSingleDateDelegate
extension SessionCalendarViewController: UICalendarSelectionSingleDateDelegate {
    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        guard let date = dateComponents?.date else { return }
        selectedDate = date
        // Reload events and scroll to the selected date
        reloadEvents()
        scrollToDate(date)
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

// MARK: - Models
struct SessionEvent: Hashable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var eventColor: NNColors.NNColorPair
    
    init(id: UUID = UUID(), title: String, startDate: Date, endDate: Date? = nil, eventColor: NNColors.NNColorPair) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate ?? Calendar.current.date(byAdding: .minute, value: 30, to: startDate)!
        self.eventColor = eventColor
    }
}

// MARK: - NNCompactCalendarViewDelegate
extension SessionCalendarViewController: NNCompactCalendarViewDelegate {
    func calendarView(_ calendarView: NNCompactCalendarView, didSelectDate date: Date) {
        selectedDate = date
        scrollToDate(date)
    }
    
    func highlightEventsFor(_ date: Date) {
        // Find and highlight cells for the selected date
        if let sectionIndex = dataSource.snapshot().sectionIdentifiers.firstIndex(of: date) {
            let itemCount = dataSource.snapshot().numberOfItems(inSection: date)
            
            // Highlight all cells in the section
            for item in 0..<itemCount {
                let indexPath = IndexPath(item: item, section: sectionIndex)
                if let cell = collectionView.cellForItem(at: indexPath) as? SessionEventCell {
                    cell.setHighlighted(true)
                }
            }
            
            // Remove highlights after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                for item in 0..<itemCount {
                    let indexPath = IndexPath(item: item, section: sectionIndex)
                    if let cell = collectionView.cellForItem(at: indexPath) as? SessionEventCell {
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
        
        let sectionDate = dataSource.snapshot().sectionIdentifiers[indexPath.section]
        let hasEvents = eventsByDate[sectionDate]?.isEmpty == false
        
        if !hasEvents {
            // Present SessionEventViewController with the section date
            let eventVC = SessionEventViewController()
            
            // Configure the event VC with the section date
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: sectionDate)
            let defaultStartTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay) ?? startOfDay
            let defaultEndTime = calendar.date(byAdding: .hour, value: 1, to: defaultStartTime) ?? defaultStartTime
            
            eventVC.startControl.date = defaultStartTime
            eventVC.endControl.date = defaultEndTime
            
            present(eventVC, animated: true)
        } else {
            // Handle tapping on an existing event if needed
            guard let event = dataSource.itemIdentifier(for: indexPath) else { return }
            // You could present event details here
        }
    }
}
