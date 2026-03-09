import UIKit
import FirebaseAuth

protocol CreateSessionRequestViewControllerDelegate: AnyObject {
    func createSessionRequestViewController(_ controller: CreateSessionRequestViewController, didCreateRequest inviteCode: String, sessionID: String)
}

class CreateSessionRequestViewController: NNViewController {

    // MARK: - Section & Item Enums

    enum Section: Hashable {
        case inviteCode
        case nest
        case date
    }

    enum Item: Hashable {
        case inviteCode(code: String)
        case nestSelection(id: String?, name: String)
        case dateSelection(startDate: Date, endDate: Date, isMultiDay: Bool)
    }

    // MARK: - Properties

    weak var delegate: CreateSessionRequestViewControllerDelegate?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    private let titleTextField: FlashingPlaceholderTextField = {
        let placeholders = [
            "Date Night",
            "Weekend Getaway",
            "Evening Out",
            "Family Event"
        ]
        let field = FlashingPlaceholderTextField(placeholders: placeholders)
        field.font = .h2
        field.borderStyle = .none
        field.returnKeyType = .done
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private lazy var createButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Create Request", titleColor: .white, fillStyle: .fill(NNColors.primary))
        button.addTarget(self, action: #selector(createButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var availableNests: [(id: String, name: String)] = []
    private var selectedNest: (id: String, name: String)?

    private var startDate: Date = Date().roundedToNextHour()
    private var endDate: Date = Date().addingTimeInterval(3 * 60 * 60).roundedToNextHour()
    private var isMultiDay: Bool = false

    // Viewing mode properties
    private var isViewingMode: Bool = false
    private var inviteCode: String?
    private var sessionID: String?
    private var pendingTitle: String?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        // Hide navigation bar for this view controller
        navigationItem.preferredNavigationBarVisibility = .hidden

        titleTextField.delegate = self
    }

    override func setup() {
        super.setup()

        setupCollectionView()
        setupNavigationBar()
        setupDataSource()
        applyInitialSnapshot()

        if !isViewingMode {
            loadAvailableNests()
        } else {
            // In viewing mode, set the title and disable editing
            if let title = pendingTitle {
                titleTextField.text = title
            }
            titleTextField.isEnabled = false
            createButton.isHidden = true
        }

        createButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
    }

    // MARK: - Configuration

    func configure(with session: SessionItem, inviteCode: String, nestName: String) {
        self.isViewingMode = true
        self.inviteCode = inviteCode
        self.sessionID = session.id
        self.startDate = session.startDate
        self.endDate = session.endDate
        self.isMultiDay = session.isMultiDay
        // Handle empty nestID - set to nil if empty string
        if session.nestID.isEmpty {
            self.selectedNest = nil
        } else {
            self.selectedNest = (id: session.nestID, name: nestName)
        }
        self.pendingTitle = session.title

        // Update UI if already loaded
        if isViewLoaded {
            titleTextField.text = session.title
            titleTextField.isEnabled = false
            createButton.isHidden = true
            applyInitialSnapshot()
        }
    }

    // MARK: - Setup

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
        closeButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
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

            titleTextField.leadingAnchor.constraint(equalTo: customNavBar.leadingAnchor, constant: 24),
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
    }

    private func setupCollectionView() {
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

    private func setupDataSource() {
        let inviteCodeRegistration = UICollectionView.CellRegistration<SessionRequestCodeCell, Item> { [weak self] cell, indexPath, item in
            guard let self else { return }
            if case let .inviteCode(code) = item {
                if let sessionID = self.sessionID {
                    cell.configure(inviteCode: code, sessionID: sessionID)
                    cell.delegate = self
                }
            }
        }

        let nestRegistration = UICollectionView.CellRegistration<NestNameCell, Item> { [weak self] cell, indexPath, item in
            guard let self else { return }
            if case let .nestSelection(_, name) = item {
                cell.configure(with: name)
            }
        }

        let dateRegistration = UICollectionView.CellRegistration<DateCell, Item> { [weak self] cell, indexPath, item in
            guard let self else { return }
            if case let .dateSelection(startDate, endDate, isMultiDay) = item {
                cell.configure(startDate: startDate, endDate: endDate, isMultiDay: isMultiDay, isReadOnly: self.isViewingMode)
                cell.delegate = self
            }
        }

        // Register footer
        let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { supplementaryView, elementKind, indexPath in
            var configuration = supplementaryView.defaultContentConfiguration()

            // Configure footer based on section
            switch self.dataSource.sectionIdentifier(for: indexPath.section) {
            case .date:
                configuration.text = "Send this request to a Nest Owner. They'll receive an invite code and can accept your session or adjust the dates and times as needed."
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
            case .inviteCode:
                return collectionView.dequeueConfiguredReusableCell(using: inviteCodeRegistration, for: indexPath, item: item)
            case .nestSelection:
                return collectionView.dequeueConfiguredReusableCell(using: nestRegistration, for: indexPath, item: item)
            case .dateSelection:
                return collectionView.dequeueConfiguredReusableCell(using: dateRegistration, for: indexPath, item: item)
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

    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()

        // Add invite code section first if in viewing mode
        if isViewingMode, let code = inviteCode {
            snapshot.appendSections([.inviteCode])
            snapshot.appendItems([.inviteCode(code: code)], toSection: .inviteCode)
        }

        snapshot.appendSections([.nest, .date])

        // Nest section - always show, even if no nest selected
        if let nest = selectedNest {
            snapshot.appendItems([.nestSelection(id: nest.id, name: nest.name)], toSection: .nest)
        } else {
            snapshot.appendItems([.nestSelection(id: nil, name: "No nest selected")], toSection: .nest)
        }

        // Date section
        snapshot.appendItems([.dateSelection(startDate: startDate, endDate: endDate, isMultiDay: isMultiDay)], toSection: .date)

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func updateSnapshot() {
        var snapshot = dataSource.snapshot()

        // Update nest - always show, even if no nest selected
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .nest))
        if let nest = selectedNest {
            snapshot.appendItems([.nestSelection(id: nest.id, name: nest.name)], toSection: .nest)
        } else {
            snapshot.appendItems([.nestSelection(id: nil, name: "No nest selected")], toSection: .nest)
        }

        // Update date
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .date))
        snapshot.appendItems([.dateSelection(startDate: startDate, endDate: endDate, isMultiDay: isMultiDay)], toSection: .date)

        dataSource.apply(snapshot, animatingDifferences: true)
    }

    // MARK: - Data Loading

    private func loadAvailableNests() {
        guard let userID = Auth.auth().currentUser?.uid else {
            showError("Not authenticated")
            return
        }

        Task {
            do {
                // Fetch sitter sessions to get nest info
                let sitterSessionsRef = SessionService.shared.db.collection("users").document(userID)
                    .collection("sitterSessions")
                let snapshot = try await sitterSessionsRef.getDocuments()

                var nestMap: [String: String] = [:]
                for doc in snapshot.documents {
                    if let sitterSession = try? doc.data(as: SitterSession.self) {
                        nestMap[sitterSession.nestID] = sitterSession.nestName
                    }
                }

                await MainActor.run {
                    self.availableNests = nestMap.map { (id: $0.key, name: $0.value) }
                        .sorted { $0.name < $1.name }

                    // Don't auto-select a nest - let user choose or leave it unselected
                    self.updateSnapshot()
                }
            } catch {
                Logger.log(level: .error, category: .sessionService, message: "Failed to load nests: \(error.localizedDescription)")
                await MainActor.run {
                    self.showError("Failed to load nests")
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func createButtonTapped() {
        guard let title = titleTextField.text, !title.isEmpty else {
            showError("Please enter a session title")
            return
        }

        // Nest selection is optional - allow nil
        let nest = selectedNest

        // Validate dates using unified validation logic
        guard SessionDateValidator.validateAndShowAlertIfNeeded(startDate: startDate, endDate: endDate, in: self) else {
            return
        }

        createButton.startLoading()

        Task {
            do {
                let (code, sessionID) = try await SessionService.shared.createSitterSessionRequest(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    targetNestID: nest?.id,
                    targetNestName: nest?.name
                )

                await MainActor.run {
                    self.createButton.stopLoading(withSuccess: true)
                    self.delegate?.createSessionRequestViewController(self, didCreateRequest: code, sessionID: sessionID)
                }
            } catch {
                await MainActor.run {
                    self.createButton.stopLoading(withSuccess: false)
                    self.showError("Failed to create session request: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDelegate

extension CreateSessionRequestViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .inviteCode:
            // Handled by SessionRequestCodeCell
            break
        case .nestSelection:
            if !isViewingMode {
                showNestPicker()
            }
        case .dateSelection:
            break // Handled by DateCell delegate
        }
    }

    private func showNestPicker() {
        let alert = UIAlertController(title: "Select Nest", message: nil, preferredStyle: .actionSheet)

        // Add "None" option to allow deselecting
        let noneAction = UIAlertAction(title: "None", style: .default) { [weak self] _ in
            self?.selectedNest = nil
            self?.updateSnapshot()
        }
        alert.addAction(noneAction)

        for nest in availableNests {
            let action = UIAlertAction(title: nest.name, style: .default) { [weak self] _ in
                self?.selectedNest = nest
                self?.updateSnapshot()
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = collectionView
            if let cell = collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) {
                popover.sourceRect = cell.frame
            }
        }

        present(alert, animated: true)
    }
}

// MARK: - DatePresentationDelegate

extension CreateSessionRequestViewController: DatePresentationDelegate {
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
    }

    func didToggleMultiDay(_ isMultiDay: Bool, startDate: Date, endDate: Date) {
        self.isMultiDay = isMultiDay
        self.startDate = startDate

        if isMultiDay {
            // When enabling multi-day, set end date to start date + 1 day as default
            self.endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? endDate

            // Enable multi-day on the cell after updating dates
            if let dateCell = getCellForSection(.date) as? DateCell {
                dateCell.enableMultiDay()
            }
        } else {
            // When disabling multi-day, sync end date to use start date's day with end time
            self.endDate = Date.syncEndDateToStartDay(startDate: startDate, endDate: endDate) ?? endDate
        }

        updateSnapshot()
    }

    private func getCellForSection(_ section: Section) -> UICollectionViewCell? {
        guard let sectionIndex = dataSource.snapshot().indexOfSection(section),
              let firstItem = dataSource.snapshot().itemIdentifiers(inSection: section).first,
              let indexPath = dataSource.indexPath(for: firstItem) else {
            return nil
        }
        return collectionView.cellForItem(at: indexPath)
    }

    func didChangeEarlyAccess(_ duration: EarlyAccessDuration) {
        // Not used in request creation - parent sets this
    }
}

// MARK: - NNDateTimePickerSheetDelegate

extension CreateSessionRequestViewController: NNDateTimePickerSheetDelegate {
    func dateTimePickerSheet(_ sheet: NNDateTimePickerSheet, didSelectDate date: Date) {
        let previousStartDate = startDate
        let result = SessionDateSynchronizer.synchronizeDates(
            pickerType: sheet.pickerType,
            newDate: date,
            previousStartDate: previousStartDate,
            currentEndDate: endDate,
            isMultiDay: isMultiDay
        )
        
        // Validate the synchronized dates using unified validation logic
        guard SessionDateValidator.validateAndShowAlertIfNeeded(startDate: result.adjustedStartDate, endDate: result.adjustedEndDate, isMultiDay: isMultiDay, in: self) else {
            return // Don't update dates if invalid
        }
        
        startDate = result.adjustedStartDate
        endDate = result.adjustedEndDate
        
        updateSnapshot()
    }
}

// MARK: - UITextFieldDelegate

extension CreateSessionRequestViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - SessionRequestCodeCellDelegate

extension CreateSessionRequestViewController: SessionRequestCodeCellDelegate {
    func sessionRequestCodeCellDidTap(inviteCode: String, sessionID: String) {
        // Push to InviteDetailViewController
        let inviteVC = InviteDetailViewController()
        inviteVC.configure(
            with: inviteCode,
            sessionID: sessionID,
            sitter: nil,
            isSitterInitiated: true
        )
        inviteVC.delegate = self
        navigationController?.pushViewController(inviteVC, animated: true)
    }
}

// MARK: - InviteSitterViewControllerDelegate

extension CreateSessionRequestViewController: InviteSitterViewControllerDelegate {
    func inviteSitterViewControllerDidSendInvite(to sitter: SitterItem, inviteId: String) {
        // Not applicable for session requests - invites are created during request creation
    }
    
    func inviteSitterViewControllerDidCancel() {
        // Not applicable for session requests
    }
    
    func inviteDetailViewControllerDidDeleteInvite() {
        // When the invite is deleted, the session request is also cancelled
        // Post notification to refresh the sessions list and dismiss this view controller
        NotificationCenter.default.post(name: .sessionDidChange, object: nil)
        
        // Dismiss this view controller since the session request no longer exists
        if let navController = navigationController {
            navController.dismiss(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
