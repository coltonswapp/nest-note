import UIKit
import Foundation
import RevenueCat
import RevenueCatUI
import QuickLook

// MARK: - Protocols
protocol DatePresentationDelegate: AnyObject {
    func presentDatePicker(for type: NNDateTimePickerSheet.PickerType, initialDate: Date)
    func didToggleMultiDay(_ isMultiDay: Bool, startDate: Date, endDate: Date)
    func didChangeEarlyAccess(_ duration: EarlyAccessDuration)
}

protocol EntryReviewCellDelegate: AnyObject {
    func didTapReview()
}

protocol SelectEntriesCellDelegate: AnyObject {
    func selectEntriesCellDidTapButton(_ cell: SelectEntriesCell)
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
    func inviteSitterViewControllerDidSendInvite(to sitter: SitterItem, inviteId: String)
    func inviteSitterViewControllerDidCancel()
    func inviteDetailViewControllerDidDeleteInvite()
}

// MARK: - EditSessionViewController
class EditSessionViewController: NNViewController, PaywallPresentable, PaywallViewControllerDelegate, QLPreviewControllerDataSource {
    // MARK: - Properties
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    // 4 day, multi-day session by default
    private var initialDate: (startDate: Date, endDate: Date, isMultiDay: Bool) = (startDate: Date().roundedToNextHour(), endDate: Date().addingTimeInterval(60 * 60 * 96).roundedToNextHour(), isMultiDay: true)
    
    private let titleTextField: FlashingPlaceholderTextField = {
        let placeholders = [
            "Date Night",
            "Weekend Getaway", 
            "Anniversary Trip",
            "Birthday Trip",
            "Family Vacation",
            "Sleepover w/ Grandma",
            "Evening Out"
        ]
        let field = FlashingPlaceholderTextField(placeholders: placeholders)
        field.font = .h2
        field.borderStyle = .none
        field.returnKeyType = .done
        return field
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(refresh), for: .valueChanged)
        return control
    }()
    
    private var selectedItemIds: [String] = []
    
    // Properties for select entries flow
    private var currentSelectEntriesNavController: UINavigationController?
    
    private var sessionItem: SessionItem
    private var hasUnsavedChanges: Bool = false {
        didSet {
            updateSaveButtonState()
        }
    }
    
    // Keep a copy of the original session for comparison
    private let originalSession: SessionItem
    
    
    private var sessionEvents: [SessionEvent] = []
    private var pdfURL: URL?
    private let maxVisibleEvents = 4
    
    // Add property for save button
    private lazy var saveButton: NNLoadingButton = {
        let buttonTitle = isEditingSession ? "Save Changes" : "Next"
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
        return currentDateSelection?.startDate ?? originalSession.startDate
    }
    
    private var currentEndDate: Date {
        return currentDateSelection?.endDate ?? originalSession.endDate
    }
    
    private var currentIsMultiDay: Bool {
        return currentDateSelection?.isMultiDay ?? originalSession.isMultiDay
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
    
    // Add property to track pending status change when date update is required
    private var pendingStatusChange: SessionStatus?
    
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
        // Note: visibilityLevel is no longer used, will use selectedEntries instead
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
        
        // Prevent accidental dismissal by swipe or other gestures
        isModalInPresentation = true
        
        if let sheetPresentationController = sheetPresentationController {
            sheetPresentationController.detents = [.large()]
            sheetPresentationController.prefersGrabberVisible = false
        }
        
        // Hide navigation bar for this view controller
        navigationItem.preferredNavigationBarVisibility = .hidden
        
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
        
        // Restore selected entries if editing an existing session
        restoreSelectedEntriesFromSession()
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
        
        // Debug logging for initial state
        Logger.log(level: .debug, category: .sessionService, message: "=== Initial Setup Debug ===")
        Logger.log(level: .debug, category: .sessionService, message: "isEditingSession: \(isEditingSession)")
        Logger.log(level: .debug, category: .sessionService, message: "sessionItem.entryIds: \(sessionItem.entryIds?.description ?? "nil")")
        Logger.log(level: .debug, category: .sessionService, message: "originalSession.entryIds: \(originalSession.entryIds?.description ?? "nil")")
        Logger.log(level: .debug, category: .sessionService, message: "selectedEntries count: \(selectedItemIds.count)")
        Logger.log(level: .debug, category: .sessionService, message: "=== End Initial Setup Debug ===")
        
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
        // Note: visibilityLevel is no longer used, using selectedEntries instead
        
        // Note: sessionItem.assignedSitter already contains the sitter information
        // No need to fetch additional sitter details since AssignedSitter has all necessary data
        
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
                
                // Update assigned sitter from refreshed session
                if let assignedSitter = refreshedSession.assignedSitter {
                    // Update originalSession to match the refreshed data
                    self.originalSession.assignedSitter = assignedSitter
                } else {
                    // Only clear assignedSitter if we previously had one
                    // This prevents race conditions from clearing valid sitter assignments
                    if self.originalSession.assignedSitter != nil {
                        // Update originalSession to match the refreshed data
                        self.originalSession.assignedSitter = nil
                    }
                }
                
                // Update originalSession entryIds to match refreshed data
                self.originalSession.entryIds = refreshedSession.entryIds
                
                // Update data source with refreshed session data
                self.updateDataSourceAfterRefresh()
                
                // Restore selected entries from refreshed session
                self.restoreSelectedEntriesFromSession()
                
                // Note: checkForChanges() is now called within restoreSelectedEntriesFromSession() 
                // after proper synchronization, so we don't need to call it again here
                
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
    
    // MARK: - Entry Selection Restoration
    
    private func restoreSelectedEntriesFromSession() {
        Logger.log(level: .info, category: .general, message: "restoreSelectedEntriesFromSession called - isEditingSession: \(isEditingSession)")
        Logger.log(level: .info, category: .general, message: "sessionItem.entryIds: \(sessionItem.entryIds?.description ?? "nil")")
        
        guard isEditingSession, let entryIds = sessionItem.entryIds, !entryIds.isEmpty else {
            Logger.log(level: .info, category: .general, message: "No entries to restore - early return")
            return
        }
        
        Logger.log(level: .info, category: .general, message: "Attempting to restore \(entryIds.count) entry IDs: \(entryIds)")
        
        Task {
            do {
                // Fetch all items to match with the stored IDs
                let nestService = NestService.shared
                let allItems = try await nestService.fetchAllItems()
                
                // Separate by type
                let matchingEntries = allItems.compactMap { $0 as? BaseEntry }.filter { entryIds.contains($0.id) }
                let matchingPlaces = allItems.compactMap { $0 as? PlaceItem }.filter { entryIds.contains($0.id) }
                let matchingRoutines = allItems.compactMap { $0 as? RoutineItem }.filter { entryIds.contains($0.id) }
                
                Logger.log(level: .info, category: .general, message: "Fetched \(allItems.count) total items")
                Logger.log(level: .info, category: .general, message: "Looking for item IDs: \(entryIds)")
                
                Logger.log(level: .info, category: .general, message: "Found \(matchingEntries.count) matching entries")
                Logger.log(level: .info, category: .general, message: "Found \(matchingPlaces.count) matching places")
                Logger.log(level: .info, category: .general, message: "Found \(matchingRoutines.count) matching routines")
                Logger.log(level: .info, category: .general, message: "Matching entry titles: \(matchingEntries.map { $0.title })")
                Logger.log(level: .info, category: .general, message: "Matching place aliases: \(matchingPlaces.map { $0.alias ?? "Unnamed"})")
                Logger.log(level: .info, category: .general, message: "Matching routine titles: \(matchingRoutines.map { $0.title })")
                
                // If no matching items found, the stored items may have been deleted
                if matchingEntries.isEmpty && matchingPlaces.isEmpty && matchingRoutines.isEmpty && !entryIds.isEmpty {
                    Logger.log(level: .info, category: .general, message: "No matching items found for stored IDs - items may have been deleted. Clearing session entryIds.")
                    
                    await MainActor.run {
                        // Clear the stored entryIds since they're no longer valid
                        self.sessionItem.entryIds = nil
                        self.selectedItemIds = []
                        self.updateSelectEntriesSection()
                        Logger.log(level: .info, category: .general, message: "Cleared invalid entryIds from session")
                    }
                } else {
                    await MainActor.run {
                        // Store only the IDs that were found
                        let restoredIds = matchingEntries.map { $0.id } + matchingPlaces.map { $0.id } + matchingRoutines.map { $0.id }
                        self.selectedItemIds = restoredIds
                        
                        Logger.log(level: .info, category: .general, message: "Updated selectedItemIds count to: \(self.selectedItemIds.count)")
                        Logger.log(level: .info, category: .general, message: "Restored entry IDs: \(matchingEntries.map { $0.id }.sorted())")
                        Logger.log(level: .info, category: .general, message: "Restored place IDs: \(matchingPlaces.map { $0.id }.sorted())")
                        Logger.log(level: .info, category: .general, message: "Restored routine IDs: \(matchingRoutines.map { $0.id }.sorted())")
                        self.updateSelectEntriesSection()
                        
                        // Update originalSession.entryIds to match the restored entries to prevent false change detection
                        self.originalSession.entryIds = restoredIds.isEmpty ? nil : restoredIds
                        
                        // Now check for changes after restoration - should show no changes since we just synced
                        Logger.log(level: .info, category: .general, message: "Calling checkForChanges() after item restoration and originalSession sync")
                        self.checkForChanges()
                    }
                }
                
            } catch {
                Logger.log(level: .error, category: .general, message: "Failed to restore selected entries: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateDataSourceAfterRefresh() {
        var snapshot = dataSource.snapshot()
        
        // Update select entries item
        if let existingSelectEntriesItem = snapshot.itemIdentifiers(inSection: .selectEntries).first {
            snapshot.deleteItems([existingSelectEntriesItem])
            snapshot.appendItems([.selectEntries(count: selectedItemIds.count)], toSection: .selectEntries)
        }
        
        // Update date selection items
        let dateItems = snapshot.itemIdentifiers(inSection: .date)
        snapshot.deleteItems(dateItems)
        snapshot.appendItems([.dateSelection(startDate: sessionItem.startDate, endDate: sessionItem.endDate, isMultiDay: sessionItem.isMultiDay)], toSection: .date)
        
        // Update status items
        let statusItems = snapshot.itemIdentifiers(inSection: .status)
        snapshot.deleteItems(statusItems)
        snapshot.appendItems([.sessionStatus(sessionItem.status)], toSection: .status)
        
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
            message: "Selected entries and session events will be included in the PDF export.",
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
                    events: sessionEvents,
                    selectedItemIds: (self.selectedItemIds.isEmpty ? (self.sessionItem.entryIds ?? []) : self.selectedItemIds)
                ) else {
                    await showError(message: "Failed to generate PDF")
                    return
                }
                
                // Create temporary file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(sessionItem.title)_session_details.pdf")
                
                try pdfData.write(to: tempURL)
                
                // Store PDF URL for QuickLook
                self.pdfURL = tempURL
                
                // Present QuickLook preview
                await MainActor.run {
                    let previewController = QLPreviewController()
                    previewController.dataSource = self
                    present(previewController, animated: true)
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
    
    // MARK: - QLPreviewControllerDataSource
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return pdfURL != nil ? 1 : 0
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return pdfURL! as QLPreviewItem
    }
    
    @objc private func saveButtonTapped() {
        Task {
            do {
                // Validate required fields
                guard let titleText = titleTextField.text, !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    showToast(text: "Please enter a session title", sentiment: .negative)
                    return
                }
                
                // Trim whitespace from title
                let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                
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
                // Note: sessionItem.assignedSitter is now updated directly in delegate methods
                sessionItem.startDate = startDate
                sessionItem.endDate = endDate
                sessionItem.isMultiDay = isMultiDay
                // Note: visibilityLevel is no longer used, replaced by selectedEntries
                sessionItem.ownerID = NestService.shared.currentNest?.ownerId
                
                // Store selected item IDs in the session
                if !selectedItemIds.isEmpty {
                    sessionItem.entryIds = selectedItemIds
                } else {
                    sessionItem.entryIds = nil // Clear entryIds if no items selected
                }
                
                if isEditingSession {
                    try await updateSession()
                } else {
                    
                    saveButton.startLoading()
                    
                    let newSession = try await SessionService.shared.createSession(sessionItem)
                    sessionItem = newSession // Update sessionItem with the created session
                    
                    try await Task.sleep(for: .seconds(0.75))
                    saveButton.stopLoading(withSuccess: true)
                    
                    // Notify sessions list to reload now that a new session exists
                    delegate?.editSessionViewController(self, didCreateSession: newSession)

                    // Auto-create an open invite and pass it to the InviteDetailViewController
                    Task { [weak self] in
                        guard let self = self else { return }
                        do {
                            let invite = try await SessionService.shared.createOpenInvite(sessionID: newSession.id)
                            let inviteDetailVC = InviteDetailViewController(sitter: nil, sessionID: newSession.id)
                            inviteDetailVC.delegate = self
                            inviteDetailVC.configure(with: invite.code, sessionID: newSession.id, sitter: nil)
                            self.navigationController?.pushViewController(inviteDetailVC, animated: true)
                        } catch {
                            // If open invite creation fails, still navigate and allow manual creation
                            let inviteDetailVC = InviteDetailViewController(sitter: nil, sessionID: newSession.id)
                            inviteDetailVC.delegate = self
                            self.navigationController?.pushViewController(inviteDetailVC, animated: true)
                        }
                    }
                    return
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
        
        // Ensure selection is enabled
        collectionView.allowsSelection = true
        collectionView.allowsMultipleSelection = false
        
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
        
        // Set delegate and other properties after collection view is fully configured
        collectionView.delegate = self
        collectionView.delaysContentTouches = false
        collectionView.refreshControl = refreshControl
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
        
        let inviteSitterRegistration = UICollectionView.CellRegistration<SessionInviteSitterCell, Item> { [weak self] cell, indexPath, item in
            guard let self else { return }
            
            switch item {
            case .inviteSitter:
                // Determine the sitter to display from assignedSitter
                if isEditingSession {
                    
                    let displaySitter = self.sessionItem.assignedSitter?.asSitterItem()
                    let assignedSitter = self.sessionItem.assignedSitter

                    // Prefer code from assigned sitter if present
                    var derivedCode: String? = nil
                    if let inviteID = assignedSitter?.inviteID,
                       let code = inviteID.split(separator: "-").last {
                        derivedCode = String(code)
                    }

                    let displayName: String = {
                        if let sitter = displaySitter {
                            return sitter.name.isEmpty ? sitter.email : sitter.name
                        } else {
                            return "Open Invite"
                        }
                    }()

                    cell.configure(name: displayName, inviteCode: derivedCode)
                } else {
                    cell.configureDisabled()
                }
                
            default:
                break
            }
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
                
                content.directionalLayoutMargins.top = 17
                content.directionalLayoutMargins.bottom = 17
                
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
                
                content.directionalLayoutMargins.top = 17
                content.directionalLayoutMargins.bottom = 17
                
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
        
        let selectEntriesRegistration = UICollectionView.CellRegistration<SelectEntriesCell, Item> { [weak self] cell, indexPath, item in
            guard let self else { return }
            if case let .selectEntries(count) = item {
                cell.configure(with: count)
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
                cell.configure(startDate: startDate, endDate: endDate, isMultiDay: isMultiDay, earlyAccessDuration: sessionItem.earlyAccessDuration, isReadOnly: isArchivedSession)
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
            case .sitter:
                if !self.isArchivedSession && self.isEditingSession {
                    configuration.text = "Tap to manage sitter and invite details"
                } else if !self.isEditingSession {
                    configuration.text = "Create an invite after creating your session"
                }
            case .nestReview:
                configuration.text = "Review items to ensure your Nest is up to date."
            case .events:
                configuration.text = "Add Nest-related events for this session."
                configuration.textProperties.numberOfLines = 0
            case .exportPDF:
                configuration.text = "Old school backup for new school parents"
                configuration.textProperties.numberOfLines = 0
            case .date:
                configuration.text = "Early access allows sitters to prepare by accessing your nest ahead of time."
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
            case .inviteSitter:
                return collectionView.dequeueConfiguredReusableCell(using: inviteSitterRegistration, for: indexPath, item: item)
            case .selectEntries(let count):
                return collectionView.dequeueConfiguredReusableCell(using: selectEntriesRegistration, for: indexPath, item: item)
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
            var sections: [Section] = [.date, .status, .selectEntries, .events]
            
            // Only show expenses section if user hasn't voted on the feature
            if !SurveyService.shared.hasVotedForFeature(SurveyService.Feature.expenses.id) {
                sections.insert(.expenses, at: sections.count - 1) // Insert before .events
            }
            
            if isEditingSession {
                sections.insert(.sitter, at: 0)
            }
            snapshot.appendSections(sections)
            
            if isEditingSession {
                snapshot.appendItems([.inviteSitter], toSection: .sitter)
            }
            snapshot.appendItems([.dateSelection(startDate: dateRange.start, endDate: dateRange.end, isMultiDay: sessionItem.isMultiDay)], toSection: .date)
            snapshot.appendItems([.sessionStatus(sessionItem.status)], toSection: .status)
            snapshot.appendItems([.selectEntries(count: selectedItemIds.count)], toSection: .selectEntries)
            
            // Only add expenses item if section exists
            if sections.contains(.expenses) {
                snapshot.appendItems([.expenses], toSection: .expenses)
            }
            
            snapshot.appendItems([.events], toSection: .events)
            
            if isEditingSession && sessionItem.status != .archived {
                snapshot.appendSections([.exportPDF])
                snapshot.appendItems([.exportPDF], toSection: .exportPDF)
            }
            
            // We'll add the nest review section later after checking if entries need review
        } else {
            snapshot.appendSections([.sitter, .date, .status, .selectEntries])
            snapshot.appendItems([.inviteSitter], toSection: .sitter)
            snapshot.appendItems([.dateSelection(startDate: dateRange.start, endDate: dateRange.end, isMultiDay: sessionItem.isMultiDay)], toSection: .date)
            snapshot.appendItems([.sessionStatus(sessionItem.status)], toSection: .status)
            snapshot.appendItems([.selectEntries(count: selectedItemIds.count)], toSection: .selectEntries)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
        
        // The fetchOutdatedEntries will be called from viewWillAppear
    }
    
    
    // Add this method to present the SessionEventViewController
    private func presentSessionEventViewController() {
        let selectedDate = sessionItem.isMultiDay ? nil : sessionItem.startDate
        let eventVC = SessionEventViewController(sessionID: sessionItem.id, selectedDate: selectedDate, entryRepository: NestService.shared)
        eventVC.eventDelegate = self
        present(eventVC, animated: true)
    }
    
    private func inviteSitterButtonTapped() {
        // Always navigate to InviteDetailViewController where users can manage sitters and invites
        let displaySitter = sessionItem.assignedSitter?.asSitterItem()
        let inviteDetailVC: InviteDetailViewController
        
        if let sitter = displaySitter,
           let assignedSitter = sessionItem.assignedSitter,
           let inviteID = assignedSitter.inviteID,
           let code = inviteID.split(separator: "-").last {
            inviteDetailVC = InviteDetailViewController()
            inviteDetailVC.configure(with: String(code), sessionID: sessionItem.id, sitter: sitter)
        } else if let assignedSitter = sessionItem.assignedSitter,
                  let inviteID = assignedSitter.inviteID,
                  let code = inviteID.split(separator: "-").last {
            inviteDetailVC = InviteDetailViewController()
            inviteDetailVC.configure(with: String(code), sessionID: sessionItem.id, sitter: nil)
        } else {
            inviteDetailVC = InviteDetailViewController(sitter: displaySitter, sessionID: sessionItem.id)
        }
        
        inviteDetailVC.delegate = self
        present(UINavigationController(rootViewController: inviteDetailVC), animated: true)
    }
    
    private func expenseButtonTapped() {
        let vc = NNFeaturePreviewViewController(feature: .expenses)
        present(vc, animated: true)
    }
    
    private func exportPDFButtonTapped() {
        // Create alert with PDF export warning
        let alert = UIAlertController(
            title: "Export Session as PDF",
            message: "Selected entries and session events will be included in the PDF export.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Export PDF", style: .default) { [weak self] _ in
            self?.exportToPDF()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
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
    
    private func presentSelectEntriesFlow() {
        guard let entryRepository = (NestService.shared as EntryRepository?) else { return }
        
        // Create the folder view controller directly
        let folderVC = ModifiedSelectFolderViewController(entryRepository: entryRepository)
        folderVC.title = "Select Items"
        folderVC.delegate = self
        
        // Pass current selected item IDs to restore selection state
        folderVC.setInitialSelectedItemIds(selectedItemIds)
        
        // Add cancel button
        folderVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(selectEntriesDidCancel)
        )
        
        // Create navigation controller and present normally
        let navController = UINavigationController(rootViewController: folderVC)
        navController.navigationBar.prefersLargeTitles = false
        navController.navigationBar.tintColor = NNColors.primary
        navController.modalPresentationStyle = .pageSheet
        
        // Store reference for later use
        currentSelectEntriesNavController = navController
        
        // Set up continue callback to receive selected IDs
        folderVC.onContinueTapped = { [weak self] selectedIds in
            self?.selectEntriesDidFinish(with: selectedIds)
        }
        
        present(navController, animated: true)
    }
    
    @objc private func selectEntriesDidCancel() {
        currentSelectEntriesNavController?.dismiss(animated: true)
        currentSelectEntriesNavController = nil
    }
    
    private func selectEntriesDidFinish(with selectedIds: [String]) {
        let totalCount = selectedIds.count
        let itemText = totalCount == 1 ? "item" : "items"
        
        let alert = UIAlertController(
            title: "Confirm Selection",
            message: "Add \(totalCount) \(itemText) to the session? These items will be visible to sitters throughout the duration of the session.",
            preferredStyle: .alert
        )
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let confirmAction = UIAlertAction(title: "Continue", style: .default) { _ in
            // ONLY NOW do we commit the selections
            self.selectedItemIds = selectedIds
            self.currentSelectEntriesNavController?.dismiss(animated: true)
            self.currentSelectEntriesNavController = nil
            self.updateSelectEntriesSection()
            self.checkForChanges()
        }
        
        alert.addAction(cancelAction)
        alert.addAction(confirmAction)
        
        currentSelectEntriesNavController?.present(alert, animated: true)
    }
    
    private func updateSelectEntriesSection() {
        var snapshot = dataSource.snapshot()
        
        // Update select entries item with count of selected item IDs
        if let existingItem = snapshot.itemIdentifiers(inSection: .selectEntries).first {
            snapshot.deleteItems([existingItem])
            snapshot.appendItems([.selectEntries(count: selectedItemIds.count)], toSection: .selectEntries)
            dataSource.apply(snapshot, animatingDifferences: true)
        }
    }
    
    private func updateSaveButtonState() {
        saveButton.isEnabled = !isEditingSession || hasUnsavedChanges
        
        // Debug logging for save button state
        Logger.log(level: .debug, category: .sessionService, message: "=== Save Button State Debug ===")
        Logger.log(level: .debug, category: .sessionService, message: "isEditingSession: \(isEditingSession)")
        Logger.log(level: .debug, category: .sessionService, message: "hasUnsavedChanges: \(hasUnsavedChanges)")
        Logger.log(level: .debug, category: .sessionService, message: "saveButton.isEnabled: \(saveButton.isEnabled)")
        Logger.log(level: .debug, category: .sessionService, message: "=== End Save Button Debug ===")
        
        // Update button title to show state
        let baseTitle = isEditingSession ? "Save Changes" : "Next"
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
        // Compare current selected item IDs with original session's entryIds
        let currentItemIds = Set(selectedItemIds)
        let originalItemIds = Set(originalSession.entryIds ?? [])
        let itemsChanged = currentItemIds != originalItemIds
        
        // Enhanced debug logging for item selection changes
        Logger.log(level: .debug, category: .sessionService, message: "=== checkForChanges() Debug ===")
        Logger.log(level: .debug, category: .sessionService, message: "Current selected items count: \(selectedItemIds.count)")
        Logger.log(level: .debug, category: .sessionService, message: "Current item IDs: \(selectedItemIds.sorted())")
        Logger.log(level: .debug, category: .sessionService, message: "Original item IDs: \(Array(originalItemIds).sorted())")
        Logger.log(level: .debug, category: .sessionService, message: "Items changed: \(itemsChanged)")
        Logger.log(level: .debug, category: .sessionService, message: "=== End Debug ===")
        
        // Individual change checks for debugging
        let titleChanged = titleTextField.text != originalSession.title
        let sitterChanged = sessionItem.assignedSitter?.id != originalSession.assignedSitter?.id
        let startDateChanged = currentStartDate != originalSession.startDate
        let endDateChanged = currentEndDate != originalSession.endDate
        let multiDayChanged = currentIsMultiDay != originalSession.isMultiDay
        let statusChanged = sessionItem.status != originalSession.status
        let earlyAccessChanged = sessionItem.earlyAccessDuration != originalSession.earlyAccessDuration
        let eventsChanged = !sessionEventsMatch()
        
        // Log each comparison for debugging
        Logger.log(level: .debug, category: .sessionService, message: "Title changed: \(titleChanged) (current: '\(titleTextField.text ?? "nil")' vs original: '\(originalSession.title)')")
        Logger.log(level: .debug, category: .sessionService, message: "Sitter changed: \(sitterChanged) (current: '\(sessionItem.assignedSitter?.id ?? "nil")' vs original: '\(originalSession.assignedSitter?.id ?? "nil")')")
        Logger.log(level: .debug, category: .sessionService, message: "Start date changed: \(startDateChanged) (current: \(currentStartDate) vs original: \(originalSession.startDate))")
        Logger.log(level: .debug, category: .sessionService, message: "End date changed: \(endDateChanged) (current: \(currentEndDate) vs original: \(originalSession.endDate))")
        Logger.log(level: .debug, category: .sessionService, message: "Multi-day changed: \(multiDayChanged) (current: \(currentIsMultiDay) vs original: \(originalSession.isMultiDay))")
        Logger.log(level: .debug, category: .sessionService, message: "Status changed: \(statusChanged) (current: \(sessionItem.status) vs original: \(originalSession.status))")
        Logger.log(level: .debug, category: .sessionService, message: "Early access changed: \(earlyAccessChanged) (current: \(sessionItem.earlyAccessDuration) vs original: \(originalSession.earlyAccessDuration))")
        Logger.log(level: .debug, category: .sessionService, message: "Events changed: \(eventsChanged)")
        
        let hasChanges = titleChanged || sitterChanged || startDateChanged || endDateChanged || multiDayChanged || itemsChanged || statusChanged || earlyAccessChanged || eventsChanged
        
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
                    
                    // Sync originalSession events with fetched events so that
                    // opening a session with existing events does not appear
                    // as an unsaved change.
                    self.originalSession.events = events
                    
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
                    
                    // Re-evaluate save state after syncing events
                    self.checkForChanges()
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
    
    private var statusMenu: UIMenu {
        let actions = [
            UIAction(title: "Upcoming", image: UIImage(systemName: SessionStatus.upcoming.icon)) { [weak self] _ in
                self?.updateSessionStatus(.upcoming)
            },
            UIAction(title: "In-progress", image: UIImage(systemName: SessionStatus.inProgress.icon)) { [weak self] _ in
                self?.updateSessionStatus(.inProgress)
            },
            UIAction(title: "Completed", image: UIImage(systemName: SessionStatus.completed.icon)) { [weak self] _ in
                self?.updateSessionStatus(.completed)
            }
        ]
        
        return UIMenu(title: "Select Session Status", children: actions)
    }
    
    private func updateSessionStatus(_ status: SessionStatus) {
        // If we're changing FROM completed to inProgress or upcoming, require end date update
        if sessionItem.status == .completed && (status == .inProgress || status == .upcoming) {
            let alert = UIAlertController(
                title: "Update End Date Required",
                message: "To change a completed session back to active status, you must update the end date to a future time. Would you like to proceed?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(
                title: "Cancel",
                style: .cancel
            ))
            
            alert.addAction(UIAlertAction(
                title: "Update End Date",
                style: .default
            ) { [weak self] _ in
                guard let self = self else { return }
                
                // Present date picker for end date
                let currentEndDate = self.currentEndDate
                let futureEndDate = Date().addingTimeInterval(2 * 60 * 60) // 2 hours from now as default
                
                self.presentDatePicker(for: currentIsMultiDay ? .endDate : .endTime, initialDate: futureEndDate)
                
                // After date is updated, apply the status change
                // This will be handled in the date picker delegate
                self.pendingStatusChange = status
            })
            
            present(alert, animated: true)
            return
        }
        
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
                self?.applyStatusChange(status)
            })
            
            present(alert, animated: true)
            return
        }
        
        // For all other status changes, proceed as normal
        applyStatusChange(status)
    }
    
    private func applyStatusChange(_ status: SessionStatus) {
        sessionItem.status = status
        
        var snapshot = dataSource.snapshot()
        
        // Update status section
        let statusItems = snapshot.itemIdentifiers(inSection: .status)
        snapshot.deleteItems(statusItems)
        snapshot.appendItems([.sessionStatus(status)], toSection: .status)
        dataSource.apply(snapshot, animatingDifferences: true)
        
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
        
        // Call delegate BEFORE dismissing to ensure the update is received
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
        
        // Update status section
        let statusItems = snapshot.itemIdentifiers(inSection: .status)
        snapshot.deleteItems(statusItems)
        snapshot.appendItems([.sessionStatus(newStatus)], toSection: .status)
        dataSource.apply(snapshot, animatingDifferences: true)
        
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
        case selectEntries
        case nestReview
        case expenses
        case exportPDF
        case date
        case status
        case events
        case time
        case notes
    }
    
    enum Item: Hashable {
        case inviteSitter
        case selectEntries(count: Int)
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
            case .inviteSitter:
                hasher.combine(1)
            case .selectEntries(let count):
                hasher.combine(2)
                hasher.combine(count)
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
            case (.inviteSitter, .inviteSitter),
                 (.expenses, .expenses),
                 (.exportPDF, .exportPDF),
                 (.events, .events):
                return true
            case let (.selectEntries(c1), .selectEntries(c2)):
                return c1 == c2
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
            guard !isArchivedSession && isEditingSession else { break }
            inviteSitterButtonTapped()
        case .selectEntries:
            presentSelectEntriesFlow()
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
                    self.presentSessionCalendarViewController()
                }
            }
        case .moreEvents:
            self.presentSessionCalendarViewController()
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
                    let eventVC = SessionEventViewController(sessionID: self.sessionItem.id, event: event, entryRepository: NestService.shared)
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
        let dateItems = dataSource.snapshot().itemIdentifiers(inSection: .date)
        
        var newSnapshot = dataSource.snapshot()
        newSnapshot.deleteItems(dateItems)
        
        // Add date selection to date section
        newSnapshot.appendItems([.dateSelection(startDate: startDate, endDate: endDate, isMultiDay: isMultiDay)], toSection: .date)
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
        let dateItems = dataSource.snapshot().itemIdentifiers(inSection: .date)
        
        var newSnapshot = dataSource.snapshot()
        newSnapshot.deleteItems(dateItems)
        
        // Add date selection to date section
        newSnapshot.appendItems([.dateSelection(startDate: newStartDate, endDate: newEndDate, isMultiDay: currentMultiDayState)], toSection: .date)
        dataSource.apply(newSnapshot, animatingDifferences: false)
        
        // Check if we need to apply a pending status change
        if let pendingStatus = pendingStatusChange {
            // Validate that the new end date is in the future if we're changing to active status
            if (pendingStatus == .inProgress || pendingStatus == .upcoming) && newEndDate > Date() {
                pendingStatusChange = nil
                applyStatusChange(pendingStatus)
            }
        }
        
        checkForChanges()
    }
    
    func didChangeEarlyAccess(_ duration: EarlyAccessDuration) {
        sessionItem.earlyAccessDuration = duration
        checkForChanges()
    }
}

// Add delegate conformance
extension EditSessionViewController: SitterListViewControllerDelegate {
    func didDeleteSitterInvite() {
        // Clear the assigned sitter
        sessionItem.assignedSitter = nil
        
        // Update the UI
        var snapshot = dataSource.snapshot()
        if snapshot.sectionIdentifiers.contains(.sitter),
           let existingItem = snapshot.itemIdentifiers(inSection: .sitter).first {
            snapshot.reloadItems([existingItem])
            dataSource.apply(snapshot, animatingDifferences: true)
        }
        
        // Mark as having unsaved changes
        checkForChanges()
        showToast(text: "Invite deleted")
    }
    
    func sitterListViewController(didSelectSitter sitter: SitterItem) {
        // Update the sessionItem's assignedSitter to reflect the new selection
        sessionItem.assignedSitter = AssignedSitter(
            id: sitter.id,
            name: sitter.name,
            email: sitter.email,
            userID: nil,
            inviteStatus: .none,
            inviteID: nil
        )
        
        // Update originalSession to reflect saved changes
        originalSession.assignedSitter = sessionItem.assignedSitter
        
        // Update the UI to reflect the sitter selection
        var snapshot = dataSource.snapshot()
        if let existingItem = snapshot.itemIdentifiers(inSection: .sitter).first {
            snapshot.reloadItems([existingItem])
            dataSource.apply(snapshot, animatingDifferences: true)
        }
        
        checkForChanges() // Add this to check for changes after sitter selection
    }
}

extension EditSessionViewController: SelectEntriesCellDelegate {
    func selectEntriesCellDidTapButton(_ cell: SelectEntriesCell) {
        presentSelectEntriesFlow()
    }
}

// Add delegate conformance
extension EditSessionViewController: SessionCalendarViewControllerDelegate {
    func calendarViewController(_ controller: SessionCalendarViewController, didUpdateEvents events: [SessionEvent]) {
        // Update local events array
        sessionEvents = events
        
        // Add events to sessionItem for change tracking
        sessionItem.events = events
        
        // Update originalSession to reflect saved changes
        originalSession.events = events
        
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
        
        // Update originalSession to reflect saved changes
        originalSession.events = sessionEvents
        
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
        
        // Update originalSession to reflect saved changes
        originalSession.events = sessionEvents
        
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

// MARK: - ModifiedSelectFolderViewControllerDelegate
extension EditSessionViewController: ModifiedSelectFolderViewControllerDelegate {
    func modifiedSelectFolderViewController(_ controller: ModifiedSelectFolderViewController, didSelectFolder folderPath: String) {
        guard let entryRepository = (NestService.shared as EntryRepository?) else { return }
        
        // Create and push the category view controller
        let categoryVC = NestCategoryViewController(
            entryRepository: entryRepository,
            initialCategory: folderPath,
            isEditOnlyMode: true
        )
        // Set the folder view controller as the delegate to receive selection updates
        categoryVC.selectEntriesDelegate = controller
        categoryVC.title = folderPath.components(separatedBy: "/").last ?? folderPath
        
        // Restore previously selected items
        Task {
            let selectedItems = await controller.getCurrentSelectedItems()
            await MainActor.run {
                categoryVC.restoreSelectedEntries(selectedItems.entries)
                categoryVC.restoreSelectedPlaces(selectedItems.places)
                categoryVC.restoreSelectedRoutines(selectedItems.routines)
            }
        }
        
        currentSelectEntriesNavController?.pushViewController(categoryVC, animated: true)
        
    }
}


// MARK: - InviteSitterViewControllerDelegate
extension EditSessionViewController: InviteSitterViewControllerDelegate {
    func inviteSitterViewControllerDidSendInvite(to sitter: SitterItem, inviteId: String) {
        // Update the sessionItem's assignedSitter to reflect the change
        // We assume the server was already updated when the invite was created/updated
        if let existingAssignedSitter = sessionItem.assignedSitter {
            // Keep existing invite ID and status, just update sitter info
            sessionItem.assignedSitter = AssignedSitter(
                id: sitter.id,
                name: sitter.name,
                email: sitter.email,
                userID: existingAssignedSitter.userID,
                inviteStatus: existingAssignedSitter.inviteStatus,
                inviteID: existingAssignedSitter.inviteID
            )
        } else {
            // Create new assigned sitter (for new invites)
            sessionItem.assignedSitter = AssignedSitter(
                id: sitter.id,
                name: sitter.name,
                email: sitter.email,
                userID: nil,
                inviteStatus: .none,
                inviteID: inviteId
            )
        }
        
        // Update originalSession to reflect saved changes
        originalSession.assignedSitter = sessionItem.assignedSitter
        
        // Update the UI
        var snapshot = dataSource.snapshot()
        if snapshot.sectionIdentifiers.contains(.sitter),
           let existingItem = snapshot.itemIdentifiers(inSection: .sitter).first {
            snapshot.reloadItems([existingItem])
            dataSource.apply(snapshot, animatingDifferences: true)
        }
        
        // Mark as having unsaved changes
        checkForChanges()
    }
    
    func inviteSitterViewControllerDidCancel() {
        // Just pop back to the previous screen
        navigationController?.popViewController(animated: true)
    }
    
    func inviteDetailViewControllerDidDeleteInvite() {
        // Clear the assigned sitter
        sessionItem.assignedSitter = nil
        
        // Update originalSession to reflect saved changes
        originalSession.assignedSitter = nil
        
        // Update the UI
        var snapshot = dataSource.snapshot()
        if snapshot.sectionIdentifiers.contains(.sitter),
           let existingItem = snapshot.itemIdentifiers(inSection: .sitter).first {
            snapshot.reloadItems([existingItem])
            dataSource.apply(snapshot, animatingDifferences: true)
        }
        
        // Mark as having unsaved changes
        checkForChanges()
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

// MARK: - SessionInviteSitterCell
class SessionInviteSitterCell: UICollectionViewListCell {
    static let reuseIdentifier = "SessionInviteSitterCell"
    
    private var currentInviteCode: String?
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = NNColors.primary
        
        let symbolConfig = UIImage.SymbolConfiguration(weight: .semibold)
        imageView.image = UIImage(systemName: "mail.fill", withConfiguration: symbolConfig)
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var codeLabel: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(
            title: "Test",
            image: nil,
            backgroundColor: NNColors.primary.withAlphaComponent(0.15),
            foregroundColor: NNColors.primary
        )
        button.titleLabel?.font = .h4
        button.isUserInteractionEnabled = true
        button.addTarget(self, action: #selector(codeButtonTapped), for: .touchUpInside)
        
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(codeLabel)
        
        NSLayoutConstraint.activate([
            
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: codeLabel.leadingAnchor, constant: -8),
            
            codeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            codeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            codeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            codeLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func configure(name: String, inviteCode: String?, isSelected: Bool = false) {
        nameLabel.text = name.isEmpty ? "Configure Invite" : name
        nameLabel.textColor = name.isEmpty ? .secondaryLabel : .label
        iconImageView.tintColor = NNColors.primary
        
        // Store the current invite code for copying
        currentInviteCode = inviteCode
        
        if let code = inviteCode, !code.isEmpty && code != "000-000" {
            let formattedCode = String(code.prefix(3)) + "-" + String(code.suffix(3))
            codeLabel.setTitle(formattedCode, for: .normal)
            codeLabel.isUserInteractionEnabled = true
        } else {
            codeLabel.backgroundColor = UIColor.tertiarySystemGroupedBackground
            codeLabel.foregroundColor = .secondaryLabel
            codeLabel.setTitle("000-000", for: .normal)
            codeLabel.isUserInteractionEnabled = false
        }
    }
    
    @objc private func codeButtonTapped() {
        guard let code = currentInviteCode, !code.isEmpty && code != "000-000" else { return }
        
        // Copy the unformatted code to pasteboard
        UIPasteboard.general.string = code
        
        // Haptic feedback
        HapticsHelper.lightHaptic()
        
        // Store the original title and temporarily disable button interaction
        let originalTitle = codeLabel.titleLabel?.text ?? ""
        codeLabel.isUserInteractionEnabled = false
        
        // Change button title to "Copied!"
        codeLabel.setTitle("Copied!", for: .normal)
        
        // Restore original title after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.codeLabel.setTitle(originalTitle, for: .normal)
            self?.codeLabel.isUserInteractionEnabled = true
        }
    }
    
    func configureDisabled() {
        nameLabel.text = "Configure Invite"
        nameLabel.textColor = .secondaryLabel
        iconImageView.tintColor = .secondaryLabel
        
        currentInviteCode = nil
        codeLabel.backgroundColor = UIColor.tertiarySystemGroupedBackground
        codeLabel.foregroundColor = .secondaryLabel
        codeLabel.setTitle("000-000", for: .normal)
        codeLabel.isUserInteractionEnabled = false
    }
}

