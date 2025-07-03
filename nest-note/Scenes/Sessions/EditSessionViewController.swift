import UIKit
import Foundation
import RevenueCat
import RevenueCatUI

// MARK: - Protocols
protocol DatePresentationDelegate: AnyObject {
    func presentDatePicker(for type: NNDateTimePickerSheet.PickerType, initialDate: Date)
    func didToggleMultiDay(_ isMultiDay: Bool, startDate: Date, endDate: Date)
}

protocol VisibilityCellDelegate: AnyObject {
    func didChangeVisibilityLevel(_ level: VisibilityLevel)
    func didRequestVisibilityLevelInfo()
}

protocol EntryReviewCellDelegate: AnyObject {
    func didTapReview()
}

protocol EditSessionViewControllerDelegate: AnyObject {
    func editSessionViewController(_ controller: EditSessionViewController, didCreateSession session: SessionItem)
    func editSessionViewController(_ controller: EditSessionViewController, didUpdateSession session: SessionItem)
}

protocol StatusCellDelegate: AnyObject {
    func didChangeSessionStatus(_ status: SessionStatus)
    func didRequestSessionStatusInfo()
}

protocol InviteSitterViewControllerDelegate: AnyObject {
    func inviteSitterViewControllerDidSendInvite(to sitter: SitterItem)
    func inviteSitterViewControllerDidCancel(_ controller: InviteSitterViewController)
    func inviteDetailViewControllerDidDeleteInvite()
}

protocol InviteStatusCellDelegate: AnyObject {
    func inviteStatusCell(_ cell: InviteStatusCell, didTapViewInviteWithCode code: String)
    func inviteStatusCellDidTapSendInvite(_ cell: InviteStatusCell)
}

// MARK: - EditSessionViewController
class EditSessionViewController: NNViewController, PaywallPresentable, PaywallViewControllerDelegate {
    // MARK: - Properties
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    // 4 day, multi-day session by default
    private var initialDate: (startDate: Date, endDate: Date, isMultiDay: Bool) = (startDate: Date().roundedToNextHour(), endDate: Date().addingTimeInterval(60 * 60 * 96).roundedToNextHour(), isMultiDay: true)
    
    private let titleTextField: UITextField = {
        let field = UITextField()
        field.placeholder = "Session Title"
        field.font = .h2
        field.borderStyle = .none
        field.returnKeyType = .done
        field.placeholder = "Session Title"
        return field
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(refresh), for: .valueChanged)
        return control
    }()
    
    private var visibilityLevel: VisibilityLevel = .standard
    
    private var sessionItem: SessionItem
    private var hasUnsavedChanges: Bool = false {
        didSet {
            updateSaveButtonState()
        }
    }
    
    // Keep a copy of the original session for comparison
    private let originalSession: SessionItem
    
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
    
    // Add property for save button
    private lazy var saveButton: NNLoadingButton = {
        let buttonTitle = isEditingSession ? "Save Changes" : "Create Session"
        let button = NNLoadingButton(title: buttonTitle, titleColor: .white, fillStyle: .fill(NNColors.primary))
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // Add property to track if this is an archived session
    var isArchivedSession: Bool = false {
        didSet {
            if isArchivedSession {
                // Disable editing for archived sessions
                titleTextField.isEnabled = false
                saveButton.isEnabled = false
                saveButton.isHidden = true
            }
        }
    }
    
    // Add selectedSitter property
    private var selectedSitter: SitterItem? {
        didSet {
            // Update the UI when sitter changes
            if let snapshot = dataSource.snapshot().itemIdentifiers(inSection: .sitter).first {
                var newSnapshot = dataSource.snapshot()
                newSnapshot.reloadItems([snapshot])
                dataSource.apply(newSnapshot, animatingDifferences: true)
            }
        }
    }
    
    weak var delegate: EditSessionViewControllerDelegate?
    
    // MARK: - PaywallPresentable
    var proFeature: ProFeature {
        return .multiDaySessions  // Default to multi-day, but this will be context-specific
    }
    
    private let isEditingSession: Bool
    
    // Computed properties to access current date values
    private var currentDateSelection: (startDate: Date, endDate: Date, isMultiDay: Bool)? {
        guard let dateItem = dataSource.snapshot().itemIdentifiers(inSection: .date).first,
              case let .dateSelection(start, end, multiDay) = dateItem else {
            return nil
        }
        return (start, end, multiDay)
    }
    
    private var currentStartDate: Date {
        return currentDateSelection?.startDate ?? Date()
    }
    
    private var currentEndDate: Date {
        return currentDateSelection?.endDate ?? Date().addingTimeInterval(60 * 60 * 2)
    }
    
    private var currentIsMultiDay: Bool {
        return currentDateSelection?.isMultiDay ?? false
    }
    
    // Add dateRange property for consistency
    private let dateRange: DateInterval
    
    // Add a property to track if events are loading
    private var isLoadingEvents = false
    
    // Add property for EntryRepository
    private var entryRepository: EntryRepository {
        return NestService.shared
    }
    
    // Add property to track if we should show the nest review section
    private var shouldShowNestReview: Bool = false
    
    // Add property to track when we last fetched entries to avoid duplicate calls
    private var lastFetchTime: Date?
    private let minimumFetchInterval: TimeInterval = 1.0 // Minimum time between fetches in seconds
    
    // Add property to store the last known outdated entries count
    private var lastOutdatedCount: Int = 0
    
    // Update init to handle single vs multi-day
    init(sessionItem: SessionItem = SessionItem()) {
        self.sessionItem = sessionItem
        self.originalSession = sessionItem.copy() // Create a copy to preserve original state
        
        // A session is considered "new" if it doesn't exist in the SessionService's cache
        self.isEditingSession = SessionService.shared.sessionExists(sessionId: sessionItem.id)
        
        // Create date range using actual session start and end times
        self.dateRange = DateInterval(start: sessionItem.startDate, end: sessionItem.endDate)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    // Add initializer for ArchivedSession
    init(archivedSession: ArchivedSession) {
        // Convert ArchivedSession to SessionItem
        let sessionItem = SessionItem()
        sessionItem.id = archivedSession.id
        sessionItem.title = archivedSession.title
        sessionItem.startDate = archivedSession.startDate
        sessionItem.endDate = archivedSession.endDate
        sessionItem.isMultiDay = Calendar.current.dateComponents([.day], from: archivedSession.startDate, to: archivedSession.endDate).day ?? 0 > 0
        sessionItem.visibilityLevel = archivedSession.visibilityLevel
        sessionItem.status = archivedSession.status
        
        // Set assigned sitter if available
        if let assignedSitter = archivedSession.assignedSitter {
            sessionItem.assignedSitter = AssignedSitter(
                id: assignedSitter.id,
                name: assignedSitter.name,
                email: assignedSitter.email,
                userID: nil,
                inviteStatus: .none,
                inviteID: nil
            )
        }
        
        // Set nest and owner IDs
        sessionItem.nestID = archivedSession.nestID
        sessionItem.ownerID = archivedSession.ownerID
        
        self.sessionItem = sessionItem
        self.originalSession = sessionItem.copy()
        
        // Archived sessions are always considered "existing"
        self.isEditingSession = true
        
        // Create date range using actual session start and end times
        self.dateRange = DateInterval(start: sessionItem.startDate, end: sessionItem.endDate)
        
        super.init(nibName: nil, bundle: nil)
        
        // Mark as archived session
        self.isArchivedSession = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.delegate = self
        collectionView.delaysContentTouches = false
        
        collectionView.refreshControl = refreshControl
        
        // Prevent accidental dismissal by swipe or other gestures
        isModalInPresentation = true
        
        if let sheetPresentationController = sheetPresentationController {
            sheetPresentationController.detents = [.large()]
            sheetPresentationController.prefersGrabberVisible = false
        }
        
        // Fetch events if we're editing an existing session and it's not archived
        if isEditingSession && !isArchivedSession {
            fetchSessionEvents()
        }
        
        // Add observer for session status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionStatusChange),
            name: .sessionStatusDidChange,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Refresh outdated entries count each time the view appears
        if !isArchivedSession {
            fetchOutdatedEntries()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func setup() {
        super.setup()
        
        configureCollectionView()
        setupNavigationBar()
        configureDataSource()
        applyInitialSnapshots()
        
        if !isArchivedSession {
            saveButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        } else {
            titleTextField.isEnabled = false
            saveButton.isHidden = true
        }
        
        // Update UI based on editing state
        titleTextField.text = sessionItem.title
        updateSaveButtonState()
        
        // If editing, pre-populate the date selection
        if let dateItem = dataSource.snapshot().itemIdentifiers(inSection: .date).first,
           case .dateSelection = dateItem {
            var newSnapshot = dataSource.snapshot()
            newSnapshot.deleteItems([dateItem])
            newSnapshot.appendItems([.dateSelection(
                startDate: sessionItem.startDate,
                endDate: sessionItem.endDate,
                isMultiDay: sessionItem.isMultiDay
            )], toSection: .date)
            dataSource.apply(newSnapshot, animatingDifferences: false)
        }
        
        // Pre-populate other fields if editing
        visibilityLevel = sessionItem.visibilityLevel
        
        // Fetch sitter if we have an ID
        if let sitterId = sessionItem.assignedSitter?.userID {
            Task {
                do {
                    if let savedSitter = try await NestService.shared.fetchSavedSitterById(sitterId) {
                        await MainActor.run {
                            self.selectedSitter = SitterItem(id: savedSitter.id, name: savedSitter.name, email: savedSitter.email)
                        }
                    }
                } catch {
                    Logger.log(level: .error, category: .sessionService, message: "Error fetching sitter: \(error.localizedDescription)")
                }
            }
        }
        
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
    
    @objc func refresh() {
        Task { await refreshSession() }
    }
    
    func refreshSession() async {
        // Only refresh if we're editing an existing session
        guard isEditingSession else { collectionView.refreshControl?.endRefreshing(); return }
        
        do {
            Logger.log(level: .debug, category: .sessionService, message: "Refreshing session: \(sessionItem.id)")
            
            // Fetch the latest session data
            let refreshedSession = try await SessionService.shared.getSession(nestID: sessionItem.nestID, sessionID: sessionItem.id)
            
            guard let refreshedSession else { collectionView.refreshControl?.endRefreshing(); return }
            
            await MainActor.run {
                // Update session item with fresh data
                self.sessionItem = refreshedSession
                
                // Update UI elements that depend on session data
                self.titleTextField.text = refreshedSession.title
                self.visibilityLevel = refreshedSession.visibilityLevel
                
                // Update selected sitter if it exists
                if let assignedSitter = refreshedSession.assignedSitter {
                    self.selectedSitter = assignedSitter.asSitterItem()
                }
                
                // Update data source with refreshed session data
                self.updateDataSourceAfterRefresh()
                
                // Check for changes after refresh
                self.checkForChanges()
                
                // Refresh session events if needed
                if !self.isArchivedSession {
                    self.fetchSessionEvents()
                }
                
                Logger.log(level: .debug, category: .sessionService, message: "Session refreshed successfully")
                collectionView.refreshControl?.endRefreshing()
            }
            
        } catch {
            Logger.log(level: .error, category: .sessionService, message: "Failed to refresh session: \(error.localizedDescription)")
            collectionView.refreshControl?.endRefreshing()
            
            await MainActor.run {
                // Show error to user
                let alert = UIAlertController(
                    title: "Refresh Failed",
                    message: "Could not refresh session data. Please try again.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateDataSourceAfterRefresh() {
        var snapshot = dataSource.snapshot()
        
        // Update visibility level item
        if let existingVisibilityItem = snapshot.itemIdentifiers(inSection: .visibility).first {
            snapshot.deleteItems([existingVisibilityItem])
            snapshot.appendItems([.visibilityLevel(sessionItem.visibilityLevel)], toSection: .visibility)
        }
        
        // Update status item
        if let existingStatusItem = snapshot.itemIdentifiers(inSection: .status).first {
            snapshot.deleteItems([existingStatusItem])
            snapshot.appendItems([.sessionStatus(sessionItem.status)], toSection: .status)
        }
        
        // Update date selection item
        if let existingDateItem = snapshot.itemIdentifiers(inSection: .date).first {
            snapshot.deleteItems([existingDateItem])
            snapshot.appendItems([.dateSelection(startDate: sessionItem.startDate, endDate: sessionItem.endDate, isMultiDay: sessionItem.isMultiDay)], toSection: .date)
        }
        
        // Update sitter item
        if let existingSitterItem = snapshot.itemIdentifiers(inSection: .sitter).first {
            snapshot.deleteItems([existingSitterItem])
            snapshot.appendItems([.inviteSitter], toSection: .sitter)
        }
        
        // Apply the changes
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    @objc override func closeButtonTapped() {
        // Check for unsaved changes before dismissing
        if hasUnsavedChanges {
            let alert = UIAlertController(
                title: "Discard Changes?",
                message: "You have unsaved changes. Are you sure you want to discard them?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(
                title: "Keep Editing",
                style: .cancel
            ))
            
            alert.addAction(UIAlertAction(
                title: "Discard Changes",
                style: .destructive
            ) { [weak self] _ in
                self?.dismiss(animated: true)
            })
            
            present(alert, animated: true)
        } else {
            dismiss(animated: true)
        }
    }
    
    @objc private func shareButtonTapped() {
        // Create alert with PDF export warning
        let alert = UIAlertController(
            title: "Export Session as PDF",
            message: "All entries associated with the \(sessionItem.visibilityLevel.title) visibility level and session events will be included in the PDF export.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Export PDF", style: .default) { [weak self] _ in
            self?.exportToPDF()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func exportToPDF() {
        Task {
            do {
                // Get the current nest
                guard let nest = NestService.shared.currentNest else {
                    await showError(message: "Unable to access nest data")
                    return
                }
                
                // Generate PDF
                guard let pdfData = await PDFExportService.generateSessionPDF(
                    session: sessionItem,
                    nestItem: nest,
                    visibilityLevel: sessionItem.visibilityLevel,
                    events: sessionEvents
                ) else {
                    await showError(message: "Failed to generate PDF")
                    return
                }
                
                // Create temporary file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(sessionItem.title)_session_details.pdf")
                
                try pdfData.write(to: tempURL)
                
                // Present share sheet
                await MainActor.run {
                    let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                    
                    // Configure for iPad
                    if let popover = activityVC.popoverPresentationController {
                        popover.sourceView = view
                        popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    
                    present(activityVC, animated: true)
                }
                
            } catch {
                await showError(message: "Failed to export PDF: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func showError(message: String) {
        let alert = UIAlertController(title: "Export Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func saveButtonTapped() {
        Task {
            do {
                // Validate required fields
                guard let title = titleTextField.text, !title.isEmpty else {
                    showToast(text: "Please enter a session title", sentiment: .negative)
                    return
                }
                
                guard let dateItem = dataSource.snapshot().itemIdentifiers(inSection: .date).first,
                      case let .dateSelection(startDate, endDate, isMultiDay) = dateItem else {
                    showToast(text: "Invalid date selection", sentiment: .negative)
                    return
                }
                
                // Validate date range logic (same as SessionEventViewController)
                guard validateDateRange(startDate: startDate, endDate: endDate) else {
                    return
                }
                
                // Update existing sessionItem with new values
                sessionItem.title = title
                if let selectedSitter = selectedSitter {
                    if let existingAssignedSitter = sessionItem.assignedSitter,
                       existingAssignedSitter.email == selectedSitter.email {
                        // Keep existing assigned sitter if it's the same person
                        // (preserves invite status and invite ID)
                    } else {
                        // Only create new assigned sitter if it's a different person
                        sessionItem.assignedSitter = AssignedSitter(
                            id: selectedSitter.id,
                            name: selectedSitter.name,
                            email: selectedSitter.email,
                            userID: nil,
                            inviteStatus: .none,
                            inviteID: nil
                        )
                    }
                }
                sessionItem.startDate = startDate
                sessionItem.endDate = endDate
                sessionItem.isMultiDay = isMultiDay
                sessionItem.visibilityLevel = visibilityLevel
                sessionItem.ownerID = NestService.shared.currentNest?.ownerId
                
                if isEditingSession {
                    try await updateSession()
                } else {
                    let newSession = try await SessionService.shared.createSession(sessionItem)
                    delegate?.editSessionViewController(self, didCreateSession: newSession)
                }
                
                dismiss(animated: true)
                
            } catch ServiceError.noCurrentNest {
                showToast(text: "Something went wrong", sentiment: .negative)
            } catch {
                showToast(text: "Failed to \(isEditingSession ? "update" : "create") session")
                Logger.log(level: .error, category: .sessionService, message: "Error saving session: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Collection View Setup
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
            
            guard let self else { return }
            
            switch item {
            case .inviteSitter:
                // Determine the sitter to display (selected or assigned)
                let displaySitter = self.selectedSitter ?? (self.sessionItem.assignedSitter?.asSitterItem() ?? nil)
                
                if let sitter = displaySitter {
                    // Show sitter information
                    content.text = sitter.name
                    content.secondaryText = self.sessionItem.assignedSitter?.inviteStatus.displayName ?? SessionInviteStatus.none.displayName
                    
                    let image = UIImage(systemName: "person.badge.shield.checkmark.fill")?
                        .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
                    content.image = image
                } else {
                    // Show default state
                    content.text = isArchivedSession ? "No sitter" : "Add a sitter"
                    content.secondaryText = nil
                    
                    let symbolConfiguration = UIImage.SymbolConfiguration(weight: .semibold)
                    let image = UIImage(systemName: "person.badge.plus", withConfiguration: symbolConfiguration)?
                        .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
                    content.image = image
                }
                
                // Common styling
                content.imageProperties.tintColor = NNColors.primary
                content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
                content.imageToTextPadding = 8
                content.directionalLayoutMargins.top = 16
                content.directionalLayoutMargins.bottom = 16
                content.textProperties.font = .bodyL
                
                // Handle archived session styling
                if isArchivedSession {
                    content.textProperties.color = .secondaryLabel
                    content.secondaryText = nil
                }
                
                content.secondaryTextProperties.font = .bodyM
                content.secondaryTextProperties.color = .secondaryLabel
                
                // Add disclosure indicator for non-archived sessions
                if !self.isArchivedSession {
                    cell.accessories = [.disclosureIndicator()]
                }
                
            default:
                break
            }
            
            cell.contentConfiguration = content
        }
        
        let expensesRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, indexPath, item in
            
            guard let self else { return }
            
            var content = cell.defaultContentConfiguration()
            
            switch item {
            case .expenses:
                content.text = "Expenses"
                let symbolConfiguration = UIImage.SymbolConfiguration(weight: .semibold)
                let image = UIImage(systemName: "dollarsign.square.fill", withConfiguration: symbolConfiguration)?
                    .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
                content.image = image
                
                content.imageProperties.tintColor = NNColors.primary
                content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
                content.imageToTextPadding = 8
                
                content.directionalLayoutMargins.top = 16
                content.directionalLayoutMargins.bottom = 16
                
                content.textProperties.font = .preferredFont(forTextStyle: .body)
                
                // Set secondary text color to secondaryLabel
                content.secondaryTextProperties.font = .bodyM
                content.secondaryTextProperties.color = .secondaryLabel
                
                cell.accessories = [.disclosureIndicator()]
            default:
                break
            }
            
            cell.contentConfiguration = content
        }
        
        let exportPDFRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, indexPath, item in
            
            guard let self else { return }
            
            var content = cell.defaultContentConfiguration()
            
            switch item {
            case .exportPDF:
                content.text = "Export Session Info"
                let symbolConfiguration = UIImage.SymbolConfiguration(weight: .semibold)
                let image = UIImage(systemName: "document.badge.arrow.up.fill", withConfiguration: symbolConfiguration)?
                    .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
                content.image = image
                
                content.imageProperties.tintColor = NNColors.primary
                content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
                content.imageToTextPadding = 8
                
                content.directionalLayoutMargins.top = 16
                content.directionalLayoutMargins.bottom = 16
                
                content.textProperties.font = .preferredFont(forTextStyle: .body)
                
                // Set secondary text color to secondaryLabel
                content.secondaryTextProperties.font = .bodyM
                content.secondaryTextProperties.color = .secondaryLabel
                
                cell.accessories = [.disclosureIndicator()]
            default:
                break
            }
            
            cell.contentConfiguration = content
        }
        
        let visibilityRegistration = UICollectionView.CellRegistration<VisibilityCell, Item> { [weak self] cell, indexPath, item in
            guard let self else { return }
            if case let .visibilityLevel(level) = item {
                cell.configure(with: level, isReadOnly: isArchivedSession)
                cell.delegate = self
            }
        }
        
        let statusRegistration = UICollectionView.CellRegistration<StatusCell, Item> { [weak self] cell, indexPath, item in
            guard let self else { return }
            if case let .sessionStatus(status) = item {
                cell.configure(with: status, isReadOnly: isArchivedSession)
                cell.delegate = self
            }
        }
        
        let nestReviewRegistration = UICollectionView.CellRegistration<NestReviewCell, Item> { [weak self] cell, indexPath, item in
            guard let self = self else { return }
            if case let .nestReview(count) = item {
                cell.configure(itemCount: count)
                cell.delegate = self
            }
        }
        
        let dateRegistration = UICollectionView.CellRegistration<DateCell, Item> { [weak self] cell, indexPath, item in
            guard let self else { return }
            if case let .dateSelection(startDate, endDate, isMultiDay) = item {
                cell.configure(startDate: startDate, endDate: endDate, isMultiDay: isMultiDay, isReadOnly: isArchivedSession)
                cell.delegate = self
            }
        }
        
        let eventsCellRegistration = UICollectionView.CellRegistration<EventsCell, Item> { [weak self] cell, indexPath, item in
            guard let self = self else { return }
            if case .events = item {
                cell.delegate = self
                // If we're still loading events and this is an existing session, show loading indicator
                if self.sessionEvents.isEmpty && self.isEditingSession && !self.isArchivedSession {
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
            case .exportPDF:
                configuration.text = "Old school backup for new school parents"
                configuration.textProperties.numberOfLines = 0
            case .status:
                if self.isArchivedSession {
                    configuration.text = "This session has been archived, as such, it cannot be edited."
                    configuration.textProperties.numberOfLines = 0
                }
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
            case .sessionStatus(let status):
                return collectionView.dequeueConfiguredReusableCell(using: statusRegistration, for: indexPath, item: item)
            case .nestReview:
                return collectionView.dequeueConfiguredReusableCell(using: nestReviewRegistration, for: indexPath, item: item)
            case .expenses:
                return collectionView.dequeueConfiguredReusableCell(using: expensesRegistration, for: indexPath, item: item)
            case .exportPDF:
                return collectionView.dequeueConfiguredReusableCell(using: exportPDFRegistration, for: indexPath, item: item)
            case .dateSelection:
                return collectionView.dequeueConfiguredReusableCell(using: dateRegistration, for: indexPath, item: item)
            case .events:
                return collectionView.dequeueConfiguredReusableCell(using: eventsCellRegistration, for: indexPath, item: item)
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
        
        if !isArchivedSession {
            snapshot.appendSections([.sitter, .date, .visibility, .status, .expenses, .events])
            snapshot.appendItems([.inviteSitter], toSection: .sitter)
            snapshot.appendItems([.visibilityLevel(sessionItem.visibilityLevel)], toSection: .visibility)
            snapshot.appendItems([.sessionStatus(sessionItem.status)], toSection: .status)
            snapshot.appendItems([.expenses], toSection: .expenses)
            snapshot.appendItems([.dateSelection(startDate: dateRange.start, endDate: dateRange.end, isMultiDay: sessionItem.isMultiDay)], toSection: .date)
            snapshot.appendItems([.events], toSection: .events)
            
            if isEditingSession && sessionItem.status != .archived {
                snapshot.appendSections([.exportPDF])
                snapshot.appendItems([.exportPDF], toSection: .exportPDF)
            }
            
            // We'll add the nest review section later after checking if entries need review
        } else {
            snapshot.appendSections([.sitter, .date, .visibility, .status])
            snapshot.appendItems([.inviteSitter], toSection: .sitter)
            snapshot.appendItems([.visibilityLevel(sessionItem.visibilityLevel)], toSection: .visibility)
            snapshot.appendItems([.sessionStatus(sessionItem.status)], toSection: .status)
            snapshot.appendItems([.dateSelection(startDate: dateRange.start, endDate: dateRange.end, isMultiDay: sessionItem.isMultiDay)], toSection: .date)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
        
        // The fetchOutdatedEntries will be called from viewWillAppear
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
        let selectedDate = sessionItem.isMultiDay ? nil : sessionItem.startDate
        let eventVC = SessionEventViewController(sessionID: sessionItem.id, selectedDate: selectedDate)
        eventVC.eventDelegate = self
        present(eventVC, animated: true)
    }
    
    private func inviteSitterButtonTapped() {
        let inviteSitterVC = SitterListViewController(displayMode: .selectSitter, selectedSitter: selectedSitter, session: sessionItem, isEditingSession: isEditingSession)
        inviteSitterVC.delegate = self
        let nav = UINavigationController(rootViewController: inviteSitterVC)
        present(nav, animated: true)
    }
    
    private func expenseButtonTapped() {
        let vc = NNFeaturePreviewViewController(feature: .expenses)
        present(vc, animated: true)
    }
    
    private func exportPDFButtonTapped() {
        // Create alert with PDF export warning
        let alert = UIAlertController(
            title: "Export Session as PDF",
            message: "All entries associated with the \(sessionItem.visibilityLevel.title) visibility level and session events will be included in the PDF export.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Export PDF", style: .default) { [weak self] _ in
            self?.exportToPDF()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
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
        let calendarVC = SessionCalendarViewController(sessionID: sessionItem.id, nestID: sessionItem.nestID, dateRange: dateRange, events: sessionEvents)
        calendarVC.delegate = self
        let nav = UINavigationController(rootViewController: calendarVC)
        present(nav, animated: true)
    }
    
    private func presentEntryReview() {
        // Create EntryReviewViewController with our entryRepository
        let reviewVC = EntryReviewViewController(entryRepository: entryRepository)
        
        // Set ourselves as the delegate
        reviewVC.reviewDelegate = self
        
        let nav = UINavigationController(rootViewController: reviewVC)
        
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        
        reviewVC.modalPresentationStyle = .formSheet
        reviewVC.isModalInPresentation = true
        
        present(nav, animated: true)
    }
    
    private func updateSaveButtonState() {
        saveButton.isEnabled = !isEditingSession || hasUnsavedChanges
        
        // Update button title to show state
        let baseTitle = isEditingSession ? "Save Changes" : "Create Session"
        saveButton.titleLabel.text = baseTitle
        
        // Optionally animate the button if there are changes
        if hasUnsavedChanges {
            saveButton.transform = .identity
            UIView.animate(withDuration: 0.3, delay: 0, options: [.allowUserInteraction]) {
                self.saveButton.transform = .identity
            }
        }
    }
    
    private func checkForChanges() {
        let hasChanges =
        titleTextField.text != originalSession.title ||
        selectedSitter?.id != originalSession.assignedSitter?.id ||
        currentStartDate != originalSession.startDate ||
        currentEndDate != originalSession.endDate ||
        currentIsMultiDay != originalSession.isMultiDay ||
        visibilityLevel != originalSession.visibilityLevel ||
        sessionItem.status != originalSession.status ||
        !sessionEventsMatch()
        
        hasUnsavedChanges = hasChanges
    }
    
    // Helper method to compare session events for changes
    private func sessionEventsMatch() -> Bool {
        // For new sessions, check if any events have been added
        if !isEditingSession {
            return sessionEvents.isEmpty
        }
        
        // For existing sessions, compare current events with original events
        let originalEvents = originalSession.events ?? []
        
        // Quick check: if counts differ, definitely changed
        if sessionEvents.count != originalEvents.count {
            return false
        }
        
        // Check if all events match (by ID and key properties)
        for event in sessionEvents {
            guard let originalEvent = originalEvents.first(where: { $0.id == event.id }) else {
                return false // New event found
            }
            
            // Compare key properties that matter for changes
            if event.title != originalEvent.title ||
               event.startDate != originalEvent.startDate ||
               event.endDate != originalEvent.endDate ||
               event.placeID != originalEvent.placeID ||
               event.eventColor != originalEvent.eventColor {
                return false
            }
        }
        
        return true
    }
    
    private func fetchSessionEvents() {
        // Only fetch events if we're editing an existing session and it's not archived
        guard isEditingSession && !isArchivedSession else { return }
        
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
                guard sessionItem.nestID != nil else { 
                    await MainActor.run {
                        isLoadingEvents = false
                        if let eventsCell = collectionView.cellForItem(at: dataSource.indexPath(for: .events)!) as? EventsCell {
                            eventsCell.configure(eventCount: 0)
                        }
                    }
                    return 
                }
                
                let events = try await SessionService.shared.getSessionEvents(for: sessionItem.id, nestID: sessionItem.nestID)
                
                await MainActor.run {
                    // Reset loading state
                    isLoadingEvents = false
                    
                    // Update local events array
                    self.sessionEvents = events
                    
                    // Store events in sessionItem for change tracking
                    self.sessionItem.events = events
                    
                    // Update the events section in the collection view
                    if events.isEmpty {
                        // If no events, just show the add button
                        var snapshot = dataSource.snapshot()
                        let currentItems = snapshot.itemIdentifiers(inSection: .events)
                        let itemsToRemove = currentItems.filter { item in
                            if case .events = item { return false }
                            return true
                        }
                        snapshot.deleteItems(itemsToRemove)
                        snapshot.reconfigureItems([.events])
                        dataSource.apply(snapshot, animatingDifferences: true)
                        
                        // Configure the events cell to show zero events
                        if let eventsCell = collectionView.cellForItem(at: dataSource.indexPath(for: .events)!) as? EventsCell {
                            eventsCell.configure(eventCount: 0)
                        }
                    } else {
                        updateEventsSection(with: events)
                    }
                }
            } catch {
                Logger.log(level: .error, category: .sessionService, message: "Failed to fetch session events: \(error.localizedDescription)")
                
                await MainActor.run {
                    // Reset loading state
                    isLoadingEvents = false
                    
                    // Show error to user
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to load session events. Please try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                    
                    // Update events section with empty state
                    var snapshot = dataSource.snapshot()
                    let currentItems = snapshot.itemIdentifiers(inSection: .events)
                    let itemsToRemove = currentItems.filter { item in
                        if case .events = item { return false }
                        return true
                    }
                    snapshot.deleteItems(itemsToRemove)
                    snapshot.reconfigureItems([.events])
                    dataSource.apply(snapshot, animatingDifferences: true)
                    
                    // Configure the events cell to show zero events
                    if let eventsCell = collectionView.cellForItem(at: dataSource.indexPath(for: .events)!) as? EventsCell {
                        eventsCell.configure(eventCount: 0)
                    }
                }
            }
        }
    }
    
    // Add a method to refresh events (useful after calendar updates)
    func refreshEvents() {
        if isEditingSession && !isArchivedSession {
            fetchSessionEvents()
        }
    }
    
    // Update calendar presentation
    private func presentCalendarViewController() {
        let calendarVC = SessionCalendarViewController(
            sessionID: sessionItem.id,
            nestID: sessionItem.nestID,
            dateRange: dateRange,
            events: sessionEvents
        )
        calendarVC.delegate = self
        let nav = UINavigationController(rootViewController: calendarVC)
        present(nav, animated: true)
    }
    
    private var statusMenu: UIMenu {
        let actions = [
            UIAction(title: "Upcoming", image: UIImage(systemName: SessionStatus.upcoming.icon)) { [weak self] _ in
                self?.updateSessionStatus(.upcoming)
            },
            UIAction(title: "In-progress", image: UIImage(systemName: SessionStatus.inProgress.icon)) { [weak self] _ in
                self?.updateSessionStatus(.inProgress)
            },
            UIAction(title: "Extended", image: UIImage(systemName: SessionStatus.extended.icon)) { [weak self] _ in
                self?.updateSessionStatus(.extended)
            },
            UIAction(title: "Completed", image: UIImage(systemName: SessionStatus.completed.icon)) { [weak self] _ in
                self?.updateSessionStatus(.completed)
            }
        ]
        
        return UIMenu(title: "Select Session Status", children: actions)
    }
    
    private func updateSessionStatus(_ status: SessionStatus) {
        // If we're marking a session as completed, show a warning alert
        if status == .completed {
            let alert = UIAlertController(
                title: "Complete Session",
                message: "When a session is marked as completed, any invited sitters will need to be reinvited to access the session again. Are you sure you want to continue?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(
                title: "Cancel",
                style: .cancel
            ))
            
            alert.addAction(UIAlertAction(
                title: "Complete Session",
                style: .destructive
            ) { [weak self] _ in
                guard let self = self else { return }
                self.sessionItem.status = status
                
                var snapshot = self.dataSource.snapshot()
                if let existingItem = snapshot.itemIdentifiers(inSection: .status).first {
                    snapshot.deleteItems([existingItem])
                    snapshot.appendItems([.sessionStatus(status)], toSection: .status)
                    self.dataSource.apply(snapshot, animatingDifferences: true)
                }
                
                self.checkForChanges()
                
                // Post notification for status change to update the home screen
                NotificationCenter.default.post(
                    name: .sessionStatusDidChange,
                    object: nil,
                    userInfo: ["sessionId": self.sessionItem.id, "newStatus": status.rawValue]
                )
            })
            
            present(alert, animated: true)
            return
        }
        
        // For non-completed status changes, proceed as normal
        sessionItem.status = status
        
        var snapshot = dataSource.snapshot()
        if let existingItem = snapshot.itemIdentifiers(inSection: .status).first {
            snapshot.deleteItems([existingItem])
            snapshot.appendItems([.sessionStatus(status)], toSection: .status)
            dataSource.apply(snapshot, animatingDifferences: true)
        }
        
        checkForChanges()
        
        // Post notification for status change to update the home screen
        NotificationCenter.default.post(
            name: .sessionStatusDidChange,
            object: nil,
            userInfo: ["sessionId": sessionItem.id, "newStatus": status.rawValue]
        )
    }
    
    @objc private func showStatusInfo() {
        let viewController = SessionStatusInfoViewController()
        present(viewController, animated: true)
        HapticsHelper.lightHaptic()
    }
    
    private func validateDateRange(startDate: Date, endDate: Date) -> Bool {
        let calendar = Calendar.current
        
        // Check if start date is after end date
        if calendar.compare(startDate, to: endDate, toGranularity: .minute) == .orderedDescending {
            let alert = UIAlertController(
                title: "Invalid Time Range",
                message: "The start time cannot be after the end time.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return false
        }
        
        // Check if start and end times are the same
        if calendar.compare(startDate, to: endDate, toGranularity: .minute) == .orderedSame {
            let alert = UIAlertController(
                title: "Invalid Time Range",
                message: "The start and end times cannot be the same.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return false
        }
        
        return true
    }
    
    private func validateSession() -> Bool {
        var isValid = true
        var errors: [String] = []
        
        // Check if title is empty
        if sessionItem.title.isEmpty {
            errors.append("Please add a title")
            isValid = false
        }
        
        // Check if dates are valid using the same logic as validateDateRange
        if !validateDateRange(startDate: sessionItem.startDate, endDate: sessionItem.endDate) {
            return false
        }
        
        if !isValid {
            let alert = UIAlertController(
                title: "Missing Information",
                message: errors.joined(separator: "\n"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
        
        return isValid
    }
    
    private func updateSession() async throws {
        // Validate session before updating
        guard validateSession() else { return }
        
        saveButton.startLoading()
        
        // Update session in Firestore
        try await SessionService.shared.updateSession(sessionItem)
        
        // Post notification that session was updated with status change
        NotificationCenter.default.post(
            name: .sessionStatusDidChange,
            object: nil,
            userInfo: ["sessionId": sessionItem.id, "newStatus": sessionItem.status.rawValue]
        )
        
        // Show success animation after delay
        try await Task.sleep(for: .seconds(1))
        saveButton.stopLoading(withSuccess: true)
        
        // Wait briefly to show success state before dismissing
        try await Task.sleep(for: .seconds(0.5))
        
        delegate?.editSessionViewController(self, didUpdateSession: sessionItem)
        dismiss(animated: true)
    }
    
    @objc private func handleSessionStatusChange(_ notification: Notification) {
        // Extract session ID and new status from notification
        guard let userInfo = notification.userInfo,
              let sessionId = userInfo["sessionId"] as? String,
              let newStatusString = userInfo["newStatus"] as? String,
              sessionId == sessionItem.id else {
            return
        }
        
        // Convert string to SessionStatus enum
        let newStatus = SessionStatus(rawValue: newStatusString) ?? .upcoming
        
        // Update the session item
        sessionItem.status = newStatus
        
        // Update the UI
        var snapshot = dataSource.snapshot()
        if let existingItem = snapshot.itemIdentifiers(inSection: .status).first {
            snapshot.deleteItems([existingItem])
            snapshot.appendItems([.sessionStatus(newStatus)], toSection: .status)
            dataSource.apply(snapshot, animatingDifferences: true)
        }
        
        // Log the status change
        Logger.log(
            level: .info,
            category: .sessionService,
            message: "Session status updated to \(newStatus.displayName) via notification"
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Update this method to use entryRepository and hide section if no entries need review
    private func fetchOutdatedEntries() {
        // Only fetch if we need to (not for archived sessions)
        guard !isArchivedSession else { return }
        
        // Only show nest review for upcoming sessions
        guard sessionItem.status == .upcoming else { 
            // For non-upcoming sessions, make sure the review section is removed
            if shouldShowNestReview {
                shouldShowNestReview = false
                var snapshot = dataSource.snapshot()
                if snapshot.sectionIdentifiers.contains(.nestReview) {
                    snapshot.deleteSections([.nestReview])
                    dataSource.apply(snapshot, animatingDifferences: true)
                }
            }
            return
        }
        
        // Check if we've fetched recently to avoid duplicate calls
        if let lastFetch = lastFetchTime, Date().timeIntervalSince(lastFetch) < minimumFetchInterval {
            Logger.log(level: .debug, category: .nestService, message: "Skipping fetchOutdatedEntries - called too soon")
            return
        }
        
        // Update last fetch time
        lastFetchTime = Date()
        
        // Add the nest review section with loading state if it doesn't exist yet
        if !shouldShowNestReview {
            shouldShowNestReview = true
            var snapshot = dataSource.snapshot()
            if !snapshot.sectionIdentifiers.contains(.nestReview) {
                snapshot.appendSections([.nestReview])
                snapshot.appendItems([.nestReview(count: nil)], toSection: .nestReview) // nil = loading
                dataSource.apply(snapshot, animatingDifferences: true)
            }
        }
        
        Task {
            do {
                Logger.log(level: .debug, category: .nestService, message: "Fetching outdated entries...")
                
                // Use the entry repository to fetch outdated entries directly via the protocol
                let outdatedEntries = try await entryRepository.fetchOutdatedEntries(olderThan: 90)
                
                // Add this additional logging to be explicit
                if outdatedEntries.isEmpty {
                    Logger.log(level: .debug, category: .nestService, message: "No outdated entries found")
                } else {
                    Logger.log(level: .debug, category: .nestService, message: "Fetched \(outdatedEntries.count) outdated entries: \(outdatedEntries.map { $0.title }.joined(separator: ", "))")
                }
                
                // Store the count to help with race conditions
                self.lastOutdatedCount = outdatedEntries.count
                
                await MainActor.run {
                    // Only update if the view is still in the window hierarchy
                    guard self.view.window != nil else { return }
                    
                    let hasOutdatedEntries = !outdatedEntries.isEmpty
                    let outdatedCount = outdatedEntries.count
                    
                    // Update the nest review section with the fetched count
                    if hasOutdatedEntries {
                        // Update the section with the actual count
                        self.updateNestReviewSection(with: outdatedCount)
                    } else {
                        // If we have no outdated entries, remove the section
                        if self.shouldShowNestReview {
                            self.shouldShowNestReview = false
                            var snapshot = dataSource.snapshot()
                            
                            if snapshot.sectionIdentifiers.contains(.nestReview) {
                                snapshot.deleteSections([.nestReview])
                                dataSource.apply(snapshot, animatingDifferences: true)
                            }
                        }
                    }
                }
            } catch {
                Logger.log(level: .error, category: .nestService, message: "Error fetching outdated entries: \(error.localizedDescription)")
                
                // Even on error, we should update the cell to not show the loading state
                await MainActor.run {
                    self.updateNestReviewSection(with: 0)
                }
            }
        }
    }
    
    // Add a dedicated method for updating the nest review section
    private func updateNestReviewSection(with count: Int) {
        Logger.log(level: .debug, category: .general, message: "Updating NestReviewSection with count: \(count)")
        
        var snapshot = dataSource.snapshot()
        
        // Remove existing nest review item if it exists
        if let existingItem = snapshot.itemIdentifiers(inSection: .nestReview).first {
            snapshot.deleteItems([existingItem])
        }
        
        // Add new item with updated count
        snapshot.appendItems([.nestReview(count: count)], toSection: .nestReview)
        dataSource.apply(snapshot, animatingDifferences: true)
        
        Logger.log(level: .debug, category: .general, message: "NestReviewSection updated successfully with count: \(count)")
    }
}

// MARK: - Types
extension EditSessionViewController {
    enum Section: Int {
        case overview
        case sitter
        case visibility
        case status
        case nestReview
        case expenses
        case exportPDF
        case date
        case events
        case time
        case notes
    }
    
    enum Item: Hashable {
        case overview
        case inviteSitter
        case visibilityLevel(VisibilityLevel)
        case sessionStatus(SessionStatus)
        case nestReview(count: Int?) // nil = loading, Int = actual count
        case expenses
        case exportPDF
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
            case .sessionStatus(let status):
                hasher.combine(3)
                hasher.combine(status)
            case .nestReview(let count):
                hasher.combine(4)
                hasher.combine(count)
            case .expenses:
                hasher.combine(5)
            case .exportPDF:
                hasher.combine(6)
            case .dateSelection(let start, let end, let isMultiDay):
                hasher.combine(7)
                hasher.combine(start)
                hasher.combine(end)
                hasher.combine(isMultiDay)
            case .events:
                hasher.combine(8)
            case .sessionEvent(let event):
                hasher.combine(9)
                hasher.combine(event)
            case .moreEvents(let count):
                hasher.combine(10)
                hasher.combine(count)
            }
        }
        
        static func == (lhs: Item, rhs: Item) -> Bool {
            switch (lhs, rhs) {
            case (.overview, .overview),
                 (.inviteSitter, .inviteSitter),
                 (.expenses, .expenses),
                 (.exportPDF, .exportPDF),
                 (.events, .events):
                return true
            case let (.visibilityLevel(l1), .visibilityLevel(l2)):
                return l1 == l2
            case let (.sessionStatus(s1), .sessionStatus(s2)):
                return s1 == s2
            case let (.nestReview(c1), .nestReview(c2)):
                return c1 == c2
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
        case .inviteSitter:
            return !isArchivedSession
        case .events, .moreEvents:
            // Don't allow highlighting events if they are currently loading
            return !isLoadingEvents
        case .expenses, .exportPDF, .sessionEvent:
            return true
        default:
            return false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch item {
        case .inviteSitter:
            guard !isArchivedSession else { return }
            inviteSitterButtonTapped()
        case .visibilityLevel:
            break
        case .sessionStatus:
            break
        case .dateSelection:
            break
        case .nestReview(let count):
            // For NestReview cell, check if it's still loading
            if count == nil {
                // Still loading, try to force an update
                Logger.log(level: .debug, category: .general, message: "NestReview cell is loading, attempting recovery")
                
                // If we have a non-zero lastOutdatedCount, use it 
                if lastOutdatedCount > 0 {
                    Logger.log(level: .debug, category: .general, message: "Using cached count for recovery: \(lastOutdatedCount)")
                    updateNestReviewSection(with: lastOutdatedCount)
                } else {
                    // Otherwise, fetch again
                    fetchOutdatedEntries()
                }
            } else {
                // Has a count (loading is complete), present the review controller
                presentEntryReview()
            }
        case .expenses:
            expenseButtonTapped()
        case .exportPDF:
            exportPDFButtonTapped()
        case .overview:
            break
        case .events:
            // Skip handling events if we're still loading them
            if isLoadingEvents { return }
            
            // Check if user has session events feature (Pro subscription)
            Task {
                let hasSessionEvents = await SubscriptionService.shared.isFeatureAvailable(.sessionEvents)
                if !hasSessionEvents {
                    await MainActor.run {
                        self.showSessionEventsUpgradePrompt()
                    }
                    return
                }
                
                await MainActor.run {
                    // Always show the calendar view when tapping the events cell
                    self.presentCalendarViewController()
                }
            }
        case .moreEvents:
            self.presentCalendarViewController()
        case .sessionEvent(let event):
            // Check if user has session events feature (Pro subscription)
            Task {
                let hasSessionEvents = await SubscriptionService.shared.isFeatureAvailable(.sessionEvents)
                if !hasSessionEvents {
                    await MainActor.run {
                        self.showSessionEventsUpgradePrompt()
                    }
                    return
                }
                
                await MainActor.run {
                    // Present event details
                    let eventVC = SessionEventViewController(sessionID: self.sessionItem.id, event: event)
                    eventVC.eventDelegate = self
                    self.present(eventVC, animated: true)
                }
            }
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension EditSessionViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Schedule change check after text update
        DispatchQueue.main.async {
            self.checkForChanges()
        }
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
            initialDate: initialDate,
            interval: 15
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
        checkForChanges()
    }
    
    func didToggleMultiDay(_ isMultiDay: Bool, startDate: Date, endDate: Date) {
        // If user is trying to enable multi-day, check if they have pro subscription
        if isMultiDay {
            Task {
                let hasMultiDaySessions = await SubscriptionService.shared.isFeatureAvailable(.multiDaySessions)
                if !hasMultiDaySessions {
                    await MainActor.run {
                        // Revert the switch state in the DateCell
                        self.revertDateCellMultiDayToggle()
                        self.showMultiDayUpgradePrompt()
                    }
                    return
                }
                
                await MainActor.run {
                    // Enable multi-day in the DateCell and update data
                    self.enableDateCellMultiDay()
                    
                    // When enabling multi-day, set end date to start date + 1 day as default
                    let defaultEndDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? endDate
                    self.updateMultiDaySelection(isMultiDay, startDate: startDate, endDate: defaultEndDate)
                }
            }
        } else {
            // Allow toggling off multi-day without restriction
            updateMultiDaySelection(isMultiDay, startDate: startDate, endDate: endDate)
        }
    }
    
    private func updateMultiDaySelection(_ isMultiDay: Bool, startDate: Date, endDate: Date) {
        // Update the data source with the new multi-day state
        guard let snapshot = dataSource.snapshot().itemIdentifiers(inSection: .date).first else { return }
        
        var newSnapshot = dataSource.snapshot()
        newSnapshot.deleteItems([snapshot])
        newSnapshot.appendItems([.dateSelection(startDate: startDate,
                                              endDate: endDate,
                                              isMultiDay: isMultiDay)],
                              toSection: .date)
        dataSource.apply(newSnapshot, animatingDifferences: false)
        checkForChanges()
    }
    
    private func showMultiDayUpgradePrompt() {
        showUpgradePrompt(for: .multiDaySessions)
    }
    
    private func showSessionEventsUpgradePrompt() {
        showUpgradePrompt(for: .sessionEvents)
    }
    
    // Helper methods to interact with DateCell
    private func revertDateCellMultiDayToggle() {
        if let dateCell = getDateCell() {
            dateCell.revertMultiDayToggle()
        }
    }
    
    private func enableDateCellMultiDay() {
        if let dateCell = getDateCell() {
            dateCell.enableMultiDay()
        }
    }
    
    private func getDateCell() -> DateCell? {
        guard let dateItem = dataSource.snapshot().itemIdentifiers(inSection: .date).first,
              let indexPath = dataSource.indexPath(for: dateItem),
              let cell = collectionView.cellForItem(at: indexPath) as? DateCell else {
            return nil
        }
        return cell
    }
}

// MARK: - Communicate from NestReviewCell to present entry review
extension EditSessionViewController: EntryReviewCellDelegate {
    func didTapReview() {
        presentEntryReview()
    }
}

// MARK: - Communicate from date cell to update session dates, etc
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
        
        checkForChanges()
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

// Add delegate conformance
extension EditSessionViewController: SitterListViewControllerDelegate {
    func didDeleteSitterInvite() {
        // Clear the assigned sitter
        sessionItem.assignedSitter = nil
        selectedSitter = nil
        
        // Update the UI
        var snapshot = dataSource.snapshot()
        if let existingItem = snapshot.itemIdentifiers(inSection: .sitter).first {
            snapshot.reloadItems([existingItem])
            dataSource.apply(snapshot, animatingDifferences: true)
        }
        
        // Mark as having unsaved changes
        checkForChanges()
        showToast(text: "Invite deleted")
    }
    
    func sitterListViewController(didSelectSitter sitter: SitterItem) {
        selectedSitter = sitter // Store the entire SitterItem
        checkForChanges() // Add this to check for changes after sitter selection
    }
} 

// Add delegate conformance
extension EditSessionViewController: VisibilityCellDelegate {
    func didChangeVisibilityLevel(_ level: VisibilityLevel) {
        visibilityLevel = level
        checkForChanges()
    }
    
    func didRequestVisibilityLevelInfo() {
        let viewController = VisibilityLevelInfoViewController()
        present(viewController, animated: true)
        HapticsHelper.lightHaptic()
    }
}

// Add delegate conformance
extension EditSessionViewController: SessionCalendarViewControllerDelegate {
    func calendarViewController(_ controller: SessionCalendarViewController, didUpdateEvents events: [SessionEvent]) {
        // Update local events array
        sessionEvents = events
        
        // Add events to sessionItem for change tracking
        sessionItem.events = events
        
        // Update events section
        updateEventsSection(with: events)
        
        // Check for unsaved changes
        checkForChanges()
    }
} 

// Add event delegate
extension EditSessionViewController: SessionEventViewControllerDelegate {
    func sessionEventViewController(_ controller: SessionEventViewController, didDeleteEvent event: SessionEvent) {
        // Remove the event from local events array
        sessionEvents.removeAll { $0.id == event.id }
        
        // Update sessionItem events for change tracking
        sessionItem.events = sessionEvents
        
        // Update events section
        updateEventsSection(with: sessionEvents)
        
        // For single-day sessions, also ensure the EventsCell shows the correct count
        if let eventsItem = dataSource.snapshot().itemIdentifiers(inSection: .events).first(where: { 
            if case .events = $0 { return true }
            return false
        }),
        let indexPath = dataSource.indexPath(for: eventsItem),
        let eventsCell = collectionView.cellForItem(at: indexPath) as? EventsCell {
            eventsCell.configure(eventCount: sessionEvents.count)
        }
        
        // Check for unsaved changes
        checkForChanges()
        
        showToast(text: "Event Deleted", sentiment: .positive)
    }
    
    func sessionEventViewController(_ controller: SessionEventViewController, didCreateEvent event: SessionEvent?) {
        guard let event = event else { return }
        
        // Check if this is an update or a new event
        let isUpdate = sessionEvents.contains { $0.id == event.id }
        
        // Update local events array
        if let existingIndex = sessionEvents.firstIndex(where: { $0.id == event.id }) {
            sessionEvents[existingIndex] = event
        } else {
            sessionEvents.append(event)
        }
        
        // Sort events by start time
        sessionEvents.sort { $0.startDate < $1.startDate }
        
        // Add events to sessionItem for change tracking
        sessionItem.events = sessionEvents
        
        // Update events section
        updateEventsSection(with: sessionEvents)
        
        // For single-day sessions, also ensure the EventsCell shows the correct count
        if let eventsItem = dataSource.snapshot().itemIdentifiers(inSection: .events).first(where: { 
            if case .events = $0 { return true }
            return false
        }),
        let indexPath = dataSource.indexPath(for: eventsItem),
        let eventsCell = collectionView.cellForItem(at: indexPath) as? EventsCell {
            eventsCell.configure(eventCount: sessionEvents.count)
        }
        
        // Check for unsaved changes
        checkForChanges()
        
        // Show appropriate toast message based on whether the event was created or updated
        let toastMessage = isUpdate ? "Event Updated" : "Event Added"
        showToast(text: toastMessage, sentiment: .positive)
    }
}

private extension String {
    var isNilOrEmpty: Bool {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
} 

final class StatusCell: UICollectionViewListCell {
    weak var delegate: StatusCellDelegate?
    private var currentStatus: SessionStatus = .upcoming
    
    private var isReadOnly: Bool = false
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = NNColors.primary
        
        let symbolConfig = UIImage.SymbolConfiguration(weight: .semibold)
        imageView.image = UIImage(systemName: "eye.fill", withConfiguration: symbolConfig)
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.text = "Session Status"
        return label
    }()
    
    private lazy var statusButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(
            title: "Test",
            image: UIImage(systemName: "chevron.up.chevron.down"),
            imagePlacement: .right,
            backgroundColor: NNColors.primary.withAlphaComponent(0.15),
            foregroundColor: NNColors.primary
        )
        button.titleLabel?.font = .h4
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        [titleLabel, statusButton, iconImageView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24).with(priority: .defaultHigh),
            iconImageView.heightAnchor.constraint(equalToConstant: 24).with(priority: .defaultHigh),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            statusButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            statusButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            statusButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            statusButton.heightAnchor.constraint(equalToConstant: 40).with(priority: .defaultHigh)
        ])
        
        iconImageView.image = UIImage(systemName: "info.circle")?.withRenderingMode(.alwaysTemplate)
        
        // Add tap gesture to icon
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(iconTapped))
        iconImageView.addGestureRecognizer(tapGesture)
        iconImageView.isUserInteractionEnabled = true
    }
    
    func configure(with status: SessionStatus, isReadOnly: Bool = false) {
        self.isReadOnly = isReadOnly
        currentStatus = status
        updateButtonAppearance()
        setupStatusMenu(selectedStatus: status)
    }
    
    private func updateButtonAppearance() {
        var container = AttributeContainer()
        container.font = .h4
        
        statusButton.configuration?.attributedTitle = AttributedString(currentStatus.displayName, attributes: container)
        iconImageView.image = UIImage(systemName: currentStatus.icon)
    }
    
    private func setupStatusMenu(selectedStatus: SessionStatus) {
        let infoAction = UIAction(title: "About Session Statuses", image: UIImage(systemName: "info.circle")) { [weak self] _ in
            self?.showStatusInfo()
        }
        
        let statusActions = [
            UIAction(
                title: "Upcoming",
                image: UIImage(systemName: SessionStatus.upcoming.icon),
                state: selectedStatus == .upcoming ? .on : .off
            ) { [weak self] _ in
                self?.updateStatus(.upcoming)
            },
            UIAction(
                title: "In-progress",
                image: UIImage(systemName: SessionStatus.inProgress.icon),
                state: selectedStatus == .inProgress ? .on : .off
            ) { [weak self] _ in
                self?.updateStatus(.inProgress)
            },
            UIAction(
                title: "Extended",
                image: UIImage(systemName: SessionStatus.extended.icon),
                state: selectedStatus == .extended ? .on : .off
            ) { [weak self] _ in
                self?.updateStatus(.extended)
            },
            UIAction(
                title: "Completed",
                image: UIImage(systemName: SessionStatus.completed.icon),
                state: selectedStatus == .completed ? .on : .off
            ) { [weak self] _ in
                self?.updateStatus(.completed)
            }
        ]
        
        let statusSection = UIMenu(title: "Select Status", options: .displayInline, children: statusActions)
        let infoSection = UIMenu(title: "Learn More", options: .displayInline, children: [infoAction])
        
        if !isReadOnly {
            statusButton.menu = UIMenu(children: [statusSection, infoSection])
        } else {
            statusButton.menu = UIMenu(children: [infoSection])
        }
        
        statusButton.showsMenuAsPrimaryAction = true
    }
    
    private func updateStatus(_ newStatus: SessionStatus) {
        HapticsHelper.lightHaptic()
        currentStatus = newStatus
        
        // Update button appearance
        updateButtonAppearance()
        
        // Notify delegate
        delegate?.didChangeSessionStatus(newStatus)
        
        // Recreate menu with updated state
        setupStatusMenu(selectedStatus: newStatus)
    }
    
    private func showStatusInfo() {
        delegate?.didRequestSessionStatusInfo()
    }
    
    @objc private func iconTapped() {
        showStatusInfo()
    }
}

// Add delegate conformance
extension EditSessionViewController: StatusCellDelegate {
    func didChangeSessionStatus(_ status: SessionStatus) {
        updateSessionStatus(status)
    }
    
    func didRequestSessionStatusInfo() {
        let viewController = SessionStatusInfoViewController()
        present(viewController, animated: true)
        HapticsHelper.lightHaptic()
    }
}

// MARK: - InviteSitterViewControllerDelegate
extension EditSessionViewController: InviteSitterViewControllerDelegate {
    func inviteSitterViewControllerDidSendInvite(to sitter: SitterItem) {
        // Update the selected sitter
        selectedSitter = sitter
        
        // Update the UI
        var snapshot = dataSource.snapshot()
        if let existingItem = snapshot.itemIdentifiers(inSection: .sitter).first {
            snapshot.reloadItems([existingItem])
            dataSource.apply(snapshot, animatingDifferences: true)
        }
        
        // Mark as having unsaved changes
        checkForChanges()
    }
    
    func inviteSitterViewControllerDidCancel(_ controller: InviteSitterViewController) {
        // Just pop back to the previous screen
        navigationController?.popViewController(animated: true)
    }
    
    func inviteDetailViewControllerDidDeleteInvite() {
        return
    }
}

// MARK: - InviteStatusCellDelegate
extension EditSessionViewController: InviteStatusCellDelegate {
    func inviteStatusCell(_ cell: InviteStatusCell, didTapViewInviteWithCode code: String) {
        let inviteDetailVC = InviteDetailViewController()
        inviteDetailVC.configure(with: code, sessionID: sessionItem.id)
        inviteDetailVC.delegate = self
        navigationController?.pushViewController(inviteDetailVC, animated: true)
    }
    
    func inviteStatusCellDidTapSendInvite(_ cell: InviteStatusCell) {
        guard let selectedSitter = selectedSitter else { return }
        
        // Create and configure the InviteSitterViewController
        let inviteSitterVC = InviteSitterViewController(sitter: selectedSitter, session: sessionItem)
        inviteSitterVC.delegate = self
        
        // Push it onto the navigation stack
        navigationController?.pushViewController(inviteSitterVC, animated: true)
    }
} 

// Add the EntryReviewViewControllerDelegate conformance
extension EditSessionViewController: EntryReviewViewControllerDelegate {
    func entryReviewDidComplete() {
        Logger.log(level: .debug, category: .general, message: "Entry review completed - removing nest review section")
        
        showToast(text: "Nest Review complete")
        
        // Remove the nest review section since review is complete
        shouldShowNestReview = false
        var snapshot = dataSource.snapshot()
        
        if snapshot.sectionIdentifiers.contains(.nestReview) {
            snapshot.deleteSections([.nestReview])
            dataSource.apply(snapshot, animatingDifferences: true)
        }
    }
}

// MARK: - EventsCellDelegate
extension EditSessionViewController: EventsCellDelegate {
    func eventsCellDidTapPlusButton(_ cell: EventsCell) {
        // Check if user has session events feature (Pro subscription)
        Task {
            let hasSessionEvents = await SubscriptionService.shared.isFeatureAvailable(.sessionEvents)
            if !hasSessionEvents {
                await MainActor.run {
                    self.showSessionEventsUpgradePrompt()
                }
                return
            }
            
            await MainActor.run {
                // Present SessionEventViewController for creating a new event
                self.presentSessionEventViewController()
            }
        }
    }
}

