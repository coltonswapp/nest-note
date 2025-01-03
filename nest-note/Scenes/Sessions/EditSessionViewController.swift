import UIKit

protocol DatePresentationDelegate: AnyObject {
    func presentDatePicker(for type: NNDateTimePickerSheet.PickerType, initialDate: Date)
    func didToggleMultiDay(_ isMultiDay: Bool, startDate: Date, endDate: Date)
}

protocol VisibilityCellDelegate: AnyObject {
    func didChangeVisibilityLevel(_ level: VisibilityLevel)
}

final class EditSessionViewController: NNViewController {
    // MARK: - Properties
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    // 4 day, multi-day session by default
    private var initialDate: (startDate: Date, endDate: Date, isMultiDay: Bool) = (startDate: Date().roundedToNextHour(), endDate: Date().addingTimeInterval(60 * 60 * 96).roundedToNextHour(), isMultiDay: true)
    
    private let titleTextField: UITextField = {
        let field = UITextField()
        field.placeholder = "Session Title"
        field.font = .systemFont(ofSize: 20, weight: .semibold)
        field.borderStyle = .none
        field.returnKeyType = .done
        field.placeholder = "Session Title"
        return field
    }()
    
    private var visibilityLevel: VisibilityLevel = .standard
    
    private var sessionItem: SessionItem
    
    private var visibilityMenu: UIMenu {
        let standard = UIAction(title: "Standard", image: UIImage(systemName: "eye")) { [weak self] _ in
            self?.updateVisibilityLevel(.standard)
        }
        
        let essential = UIAction(title: "Essential", image: UIImage(systemName: "eye.slash")) { [weak self] _ in
            self?.updateVisibilityLevel(.essential)
        }
        
        let extended = UIAction(title: "Extended", image: UIImage(systemName: "eye.fill")) { [weak self] _ in
            self?.updateVisibilityLevel(.extended)
        }
        
        let comprehensive = UIAction(title: "Comprehensive", image: UIImage(systemName: "eye.circle.fill")) { [weak self] _ in
            self?.updateVisibilityLevel(.comprehensive)
        }
        
        return UIMenu(title: "Select Visibility Level", children: [standard, essential, extended, comprehensive])
    }
    
    private var sessionEvents: [SessionEvent] = []
    private let maxVisibleEvents = 4
    
    init(sessionItem: SessionItem = SessionItem()) {
        self.sessionItem = sessionItem
        super.init(nibName: nil, bundle: nil)
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func setup() {
        configureCollectionView()
        setupNavigationBar()
        configureDataSource()
        applyInitialSnapshots()
        
        // Generate exactly 6 test events
//        if let dateItem = dataSource.snapshot().itemIdentifiers(inSection: .date).first,
//           case let .dateSelection(startDate, endDate, _) = dateItem {
//            let dateInterval = DateInterval(start: startDate, end: endDate)
//            sessionEvents = SessionEventGenerator.generateRandomEvents(in: dateInterval, count: 6)
//            updateEventsSection(with: sessionEvents)
//        }
    }
    
    private func setupNavigationBar() {
        // Create custom navigation bar
        let customNavBar = UIView()
        customNavBar.backgroundColor = .tertiarySystemGroupedBackground
        customNavBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customNavBar)
        
        // Add title text field
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        customNavBar.addSubview(titleTextField)
        
        // Add close button
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .systemGray2
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
            
            titleTextField.leadingAnchor.constraint(equalTo: customNavBar.leadingAnchor, constant: 16),
            titleTextField.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor, constant: 0),
            titleTextField.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -16),
            
            closeButton.trailingAnchor.constraint(equalTo: customNavBar.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor, constant: 0),
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
        
        // Setup text field delegate
        titleTextField.delegate = self
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Collection View Setup
    private func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 40, right: 0)
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            
            // Enable footer
            config.footerMode = .supplementary
            
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
            section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18)
            return section
        }
        return layout
    }
    
    private func configureDataSource() {
        let overviewRegistration = UICollectionView.CellRegistration<SessionOverviewCell, Item> { cell, indexPath, item in
            if case .overview = item {
                cell.updateProgress(to: 0) // Start at first step
            }
        }
        
        let inviteSitterRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, indexPath, item in
            var content = cell.defaultContentConfiguration()
            
            switch item {
            case .inviteSitter:
                if let sitter = self?.sessionItem.sitter {
                    // Show selected sitter
                    content.text = sitter.name
                    
                    let image = UIImage(systemName: "person.badge.shield.checkmark.fill")?
                        .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
                    content.image = image
                } else {
                    // Show default state
                    content.text = "Add a sitter"
                    
                    let symbolConfiguration = UIImage.SymbolConfiguration(weight: .semibold)
                    let image = UIImage(systemName: "person.badge.plus", withConfiguration: symbolConfiguration)?
                        .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
                    content.image = image
                }
                
                content.imageProperties.tintColor = NNColors.primary
                content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
                content.imageToTextPadding = 8
                
                content.directionalLayoutMargins.top = 16
                content.directionalLayoutMargins.bottom = 16
                
                cell.accessories = [.disclosureIndicator()]
            default:
                break
            }
            
            cell.contentConfiguration = content
        }
        
        let visibilityRegistration = UICollectionView.CellRegistration<VisibilityCell, Item> { [weak self] cell, indexPath, item in
            if case let .visibilityLevel(level) = item {
                cell.configure(with: level)
                cell.delegate = self
            }
        }
        
        let nestReviewRegistration = UICollectionView.CellRegistration<NestReviewCell, Item> { cell, indexPath, item in
            if case .nestReview = item {
                cell.configure(itemCount: 12) // You can make this dynamic later
            }
        }
        
        let dateRegistration = UICollectionView.CellRegistration<DateCell, Item> { cell, indexPath, item in
            if case let .dateSelection(startDate, endDate, isMultiDay) = item {
                cell.configure(startDate: startDate, endDate: endDate, isMultiDay: isMultiDay)
                cell.delegate = self
            }
        }
        
        let eventsRegistration = UICollectionView.CellRegistration<EventsCell, Item> { [weak self] cell, indexPath, item in
            if case .events = item {
                cell.configure(eventCount: self?.sessionEvents.count ?? 0)
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
        
        // Register footer
        let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { supplementaryView, elementKind, indexPath in
            var configuration = supplementaryView.defaultContentConfiguration()
            
            // Configure footer based on section
            switch self.dataSource.sectionIdentifier(for: indexPath.section) {
            case .nestReview:
                configuration.text = "Review items to ensure your Nest is up to date."
            case .events:
                configuration.text = "Add Nest-related events for this session."
                configuration.textProperties.numberOfLines = 0
            default:
                break
            }
            
            configuration.textProperties.font = .preferredFont(forTextStyle: .footnote)
            configuration.textProperties.color = .tertiaryLabel
            configuration.textProperties.alignment = .center
            
            supplementaryView.contentConfiguration = configuration
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .overview:
                return collectionView.dequeueConfiguredReusableCell(using: overviewRegistration, for: indexPath, item: item)
            case .inviteSitter:
                return collectionView.dequeueConfiguredReusableCell(using: inviteSitterRegistration, for: indexPath, item: item)
            case .visibilityLevel(let level):
                return collectionView.dequeueConfiguredReusableCell(using: visibilityRegistration, for: indexPath, item: item)
            case .nestReview:
                return collectionView.dequeueConfiguredReusableCell(using: nestReviewRegistration, for: indexPath, item: item)
            case .dateSelection:
                return collectionView.dequeueConfiguredReusableCell(using: dateRegistration, for: indexPath, item: item)
            case .events:
                return collectionView.dequeueConfiguredReusableCell(using: eventsRegistration, for: indexPath, item: item)
            case .sessionEvent(let event):
                return collectionView.dequeueConfiguredReusableCell(using: sessionEventRegistration, for: indexPath, item: item)
            case .moreEvents(let count):
                return collectionView.dequeueConfiguredReusableCell(using: moreEventsRegistration, for: indexPath, item: item)
            }
        }
        
        // Add supplementary view provider to data source
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            return collectionView.dequeueConfiguredReusableSupplementary(
                using: footerRegistration, 
                for: indexPath
            )
        }
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.sitter, .date, .visibility, .nestReview, .events])
        snapshot.appendItems([.inviteSitter], toSection: .sitter)
        snapshot.appendItems([.visibilityLevel(visibilityLevel)], toSection: .visibility)
        snapshot.appendItems([.nestReview], toSection: .nestReview)
        snapshot.appendItems([.dateSelection(startDate: initialDate.0, endDate: initialDate.1, isMultiDay: initialDate.2)], toSection: .date)
        snapshot.appendItems([.events], toSection: .events)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    private func showVisibilityLevelInfo() {
        let alert = UIAlertController(
            title: "Visibility Levels",
            message: "Essential: Basic information\nStandard: Normal visibility\nExtended: More details\nComprehensive: Full information",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // Add this method to present the SessionEventViewController
    private func presentSessionEventViewController() {
        let eventVC = SessionEventViewController()
        present(eventVC, animated: true)
    }
    
    @objc private func inviteSitterButtonTapped() {
        let inviteSitterVC = InviteSitterViewController()
        inviteSitterVC.delegate = self
        let nav = UINavigationController(rootViewController: inviteSitterVC)
        nav.modalPresentationStyle = .formSheet
        
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        
        present(nav, animated: true)
    }
    
    private func updateVisibilityLevel(_ level: VisibilityLevel) {
        // Update the session item
        sessionItem.visibilityLevel = level
        
        // Update the UI
        var snapshot = dataSource.snapshot()
        
        // Find the existing visibility item in the snapshot
        if let existingItem = snapshot.itemIdentifiers(inSection: .visibility).first {
            // Remove the old item
            snapshot.deleteItems([existingItem])
            // Insert the new item
            snapshot.appendItems([.visibilityLevel(level)], toSection: .visibility)
            
            dataSource.apply(snapshot, animatingDifferences: true)
        }
    }
    
    private func updateEventsSection(with events: [SessionEvent]) {
        var snapshot = dataSource.snapshot()
        
        let currentItems = snapshot.itemIdentifiers(inSection: .events)
        let itemsToRemove = currentItems.filter { item in
            if case .events = item { return false }
            return true
        }
        snapshot.deleteItems(itemsToRemove)
        
        let visibleEvents = events.prefix(maxVisibleEvents)
        let eventItems = visibleEvents.map { Item.sessionEvent($0) }
        snapshot.appendItems(eventItems, toSection: .events)
        
        if events.count > maxVisibleEvents {
            let remainingCount = events.count - maxVisibleEvents
            snapshot.appendItems([.moreEvents(remainingCount)], toSection: .events)
        }
        
        snapshot.reconfigureItems([.events])
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func presentSessionCalendarViewController() {
        guard let dateItem = dataSource.snapshot().itemIdentifiers(inSection: .date).first,
              case let .dateSelection(startDate, endDate, _) = dateItem else {
            return
        }
        
        let dateRange = DateInterval(start: startDate, end: endDate)
        let calendarVC = SessionCalendarViewController(dateRange: dateRange, events: sessionEvents)
        calendarVC.delegate = self
        let nav = UINavigationController(rootViewController: calendarVC)
        present(nav, animated: true)
    }
}

// MARK: - Types
extension EditSessionViewController {
    enum Section: Int {
        case overview
        case sitter
        case visibility
        case nestReview
        case date
        case events
        case time
        case notes
    }
    
    enum Item: Hashable {
        case overview
        case inviteSitter
        case visibilityLevel(VisibilityLevel)
        case nestReview
        case dateSelection(startDate: Date, endDate: Date, isMultiDay: Bool)
        case events
        case sessionEvent(SessionEvent)
        case moreEvents(Int)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .overview:
                hasher.combine(0)
            case .inviteSitter:
                hasher.combine(1)
            case .visibilityLevel(let level):
                hasher.combine(2)
                hasher.combine(level)
            case .nestReview:
                hasher.combine(3)
            case .dateSelection(let start, let end, let isMultiDay):
                hasher.combine(4)
                hasher.combine(start)
                hasher.combine(end)
                hasher.combine(isMultiDay)
            case .events:
                hasher.combine(5)
            case .sessionEvent(let event):
                hasher.combine(6)
                hasher.combine(event)
            case .moreEvents(let count):
                hasher.combine(7)
                hasher.combine(count)
            }
        }
        
        static func == (lhs: Item, rhs: Item) -> Bool {
            switch (lhs, rhs) {
            case (.overview, .overview),
                 (.inviteSitter, .inviteSitter),
                 (.nestReview, .nestReview),
                 (.events, .events):
                return true
            case let (.visibilityLevel(l1), .visibilityLevel(l2)):
                return l1 == l2
            case let (.dateSelection(s1, e1, m1), .dateSelection(s2, e2, m2)):
                return s1 == s2 && e1 == e2 && m1 == m2
            case let (.sessionEvent(e1), .sessionEvent(e2)):
                return e1 == e2
            case let (.moreEvents(c1), .moreEvents(c2)):
                return c1 == c2
            default:
                return false
            }
        }
    }
}

// MARK: - UICollectionViewDelegate
extension EditSessionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return false }
        switch item {
        case .inviteSitter, .events, .visibilityLevel, .moreEvents, .sessionEvent:
            return true
        default:
            return false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch item {
        case .inviteSitter:
            inviteSitterButtonTapped()
        case .visibilityLevel:
            // Present the menu
            if let cell = collectionView.cellForItem(at: indexPath) {
                presentVisibilityMenu(from: cell)
            }
        case .dateSelection:
            break
        case .nestReview:
            print("Tapped nest review")
        case .overview:
            break
        case .events, .moreEvents:
            // Get the current date range from the date cell
            guard let dateItem = dataSource.snapshot().itemIdentifiers(inSection: .date).first,
                  case let .dateSelection(startDate, endDate, _) = dateItem else {
                return
            }
            
            // Check if session duration is less than 24 hours
            let duration = Calendar.current.dateComponents([.hour], from: startDate, to: endDate)
            if let hours = duration.hour, hours < 24 {
                // For sessions less than 24 hours, directly present SessionEventViewController
                presentSessionEventViewController()
            } else {
                // For longer sessions, show the calendar view
                presentSessionCalendarViewController()
            }
        case .sessionEvent(let event):
            // Present event details
            let eventVC = SessionEventViewController()
            present(eventVC, animated: true)
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    
    private func presentVisibilityMenu(from cell: UICollectionViewCell) {
        // Create a UIButton just for presenting the menu
        let button = UIButton(frame: cell.bounds)
        cell.addSubview(button)
        button.menu = visibilityMenu
        button.showsMenuAsPrimaryAction = true
        button.sendActions(for: .touchUpInside)
        button.removeFromSuperview()
    }
}

// MARK: - UITextFieldDelegate
extension EditSessionViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - DatePresentationDelegate
extension EditSessionViewController: DatePresentationDelegate {
    func presentDatePicker(for type: NNDateTimePickerSheet.PickerType, initialDate: Date) {
        let mode: UIDatePicker.Mode = type == .startDate || type == .endDate ? .date : .time
        
        let pickerVC = NNDateTimePickerSheet(
            mode: mode,
            type: type,
            initialDate: initialDate
        )
        pickerVC.delegate = self
        
        let nav = UINavigationController(rootViewController: pickerVC)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.custom(resolver: { context in
                    return 280
            })]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        
        present(nav, animated: true)
    }
    
    func didToggleMultiDay(_ isMultiDay: Bool, startDate: Date, endDate: Date) {
        // Update the data source with the new multi-day state
        guard let snapshot = dataSource.snapshot().itemIdentifiers(inSection: .date).first else { return }
        
        var newSnapshot = dataSource.snapshot()
        newSnapshot.deleteItems([snapshot])
        newSnapshot.appendItems([.dateSelection(startDate: startDate,
                                              endDate: endDate,
                                              isMultiDay: isMultiDay)],
                              toSection: .date)
        dataSource.apply(newSnapshot, animatingDifferences: false)
    }
}

// Add NNDateTimePickerSheetDelegate conformance
extension EditSessionViewController: NNDateTimePickerSheetDelegate {
    func dateTimePickerSheet(_ sheet: NNDateTimePickerSheet, didSelectDate date: Date) {
        // Find the date cell and update it
        guard let snapshot = dataSource.snapshot().itemIdentifiers(inSection: .date).first,
              case let .dateSelection(startDate, endDate, isMultiDay) = snapshot else { return }
        
        var newStartDate = startDate
        var newEndDate = endDate
        let currentMultiDayState = isMultiDay
        
        switch sheet.pickerType {
        case .startDate, .startTime:
            newStartDate = date
            if !isMultiDay {
                // Sync end date with start date while preserving end time
                let calendar = Calendar.current
                let startComponents = calendar.dateComponents([.year, .month, .day], from: date)
                let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endDate)
                
                var newComponents = DateComponents()
                newComponents.year = startComponents.year
                newComponents.month = startComponents.month
                newComponents.day = startComponents.day
                newComponents.hour = endTimeComponents.hour
                newComponents.minute = endTimeComponents.minute
                
                if let syncedEndDate = calendar.date(from: newComponents) {
                    newEndDate = syncedEndDate
                }
            }
        case .endDate, .endTime:
            newEndDate = date
        }
        
        // Update the data source
        var newSnapshot = dataSource.snapshot()
        newSnapshot.deleteItems([snapshot])
        newSnapshot.appendItems([.dateSelection(startDate: newStartDate,
                                              endDate: newEndDate,
                                              isMultiDay: currentMultiDayState)],
                              toSection: .date)
        dataSource.apply(newSnapshot, animatingDifferences: false)
    }
}

final class SessionOverviewCell: UICollectionViewListCell {
    private lazy var progressView: NNStepProgressView = {
        let view = NNStepProgressView(steps: ["Setup", "Start", "In progress", "Finish"])
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        contentView.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            progressView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    func updateProgress(to step: Int) {
        // Mark previous steps as complete
        for i in 0..<step {
            progressView.updateState(.complete, forStep: i)
        }
        
        // Mark current step as in progress
        progressView.updateState(.inProgress(progress: 0.33), forStep: step)
        
        // Mark remaining steps as incomplete
        for i in (step + 1)..<4 {
            progressView.updateState(.incomplete, forStep: i)
        }
    }
}

final class EventsCell: UICollectionViewListCell {
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        
        let symbolConfig = UIImage.SymbolConfiguration(weight: .semibold)
            .applying(UIImage.SymbolConfiguration(hierarchicalColor: NNColors.primary))
        
        let image = UIImage(systemName: "calendar.badge.plus", withConfiguration: symbolConfig)
        
        imageView.image = image
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Events"
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let plusButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let symbolConfig = UIImage.SymbolConfiguration(weight: .regular)
        let image = UIImage(systemName: "plus", withConfiguration: symbolConfig)?
            .withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
        
        button.setImage(image, for: .normal)
        return button
    }()
    
    private let eventCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
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
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(plusButton)
        contentView.addSubview(eventCountLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            plusButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            plusButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: 28),
            plusButton.heightAnchor.constraint(equalToConstant: 28),
            
            eventCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            eventCountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    
    func configure(eventCount: Int) {
        plusButton.isHidden = eventCount > 0
        eventCountLabel.isHidden = eventCount == 0
        
        if eventCount > 0 {
            eventCountLabel.text = "\(eventCount) events"
        }
    }
} 

// Add delegate conformance
extension EditSessionViewController: InviteSitterViewControllerDelegate {
    func inviteSitterViewController(_ controller: InviteSitterViewController, didSelectSitter sitter: SitterItem) {
        // Update the session with the selected sitter
        sessionItem.sitter = sitter
        
        // Update the UI to show the selected sitter
        var snapshot = dataSource.snapshot()
        if let sitterItem = snapshot.itemIdentifiers(inSection: .sitter).first {
            snapshot.reloadItems([sitterItem])
            dataSource.apply(snapshot, animatingDifferences: true)
        }
    }
} 

// Add delegate conformance
extension EditSessionViewController: VisibilityCellDelegate {
    func didChangeVisibilityLevel(_ level: VisibilityLevel) {
        updateVisibilityLevel(level)
    }
} 

// Add delegate conformance
extension EditSessionViewController: SessionCalendarViewControllerDelegate {
    func calendarViewController(_ controller: SessionCalendarViewController, didUpdateEvents events: [SessionEvent]) {
        // Update local events
        sessionEvents = events
        
        // Update events section
        updateEventsSection(with: events)
    }
} 

