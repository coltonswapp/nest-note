//
//  RoutineDetailViewController.swift
//  nest-note
//
//  Created by Claude on 2/4/25.
//

import UIKit


protocol RoutineDetailViewControllerDelegate: AnyObject {
    func routineDetailViewController(didSaveRoutine routine: RoutineItem?)
    func routineDetailViewController(didDeleteRoutine routine: RoutineItem)
}

final class RoutineDetailViewController: NNSheetViewController, NNTippable {
    
    // MARK: - Properties
    weak var routineDelegate: RoutineDetailViewControllerDelegate?
    private let isReadOnly: Bool
    
    override var hasDiscardableContent: Bool {
        guard !isReadOnly else { return false }
        let titleString = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if routine == nil {
            return !titleString.isEmpty || !routineActions.isEmpty || !pendingAttachmentIds.isEmpty
        }
        let currentTitle = routine?.title ?? ""
        let currentActions = routine?.routineActions ?? []
        let currentFrequency = routine?.frequency ?? "Daily"
        let selectedFrequency = frequencyButton.configuration?.attributedTitle.map { String($0.characters) } ?? frequencyButton.title(for: .normal) ?? "Daily"
        return titleString != currentTitle
            || routineActions != currentActions
            || selectedFrequency != currentFrequency
            || pendingAttachmentIds != originalAttachmentIds
    }
    
    private lazy var routineTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.keyboardDismissMode = .onDrag
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(RoutineActionCell.self, forCellReuseIdentifier: "RoutineActionCell")
        tableView.register(AddRoutineActionCell.self, forCellReuseIdentifier: "AddRoutineActionCell")
        return tableView
    }()
    
    private lazy var frequencyButton: NNSmallPrimaryButton = {
        let chevronImage = UIImage(systemName: "chevron.up.chevron.down")
        let button = NNSmallPrimaryButton(
            title: routine?.frequency ?? "Daily",
            image: chevronImage,
            imagePlacement: .right,
            backgroundColor: NNColors.offBlack,
            foregroundColor: .white
        )
        button.addTarget(self, action: #selector(frequencyButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var saveButton: NNLoadingButton = {
        let button = NNLoadingButton(
            title: routine == nil ? "Save" : "Update",
            titleColor: .white,
            fillStyle: .fill(NNColors.primary)
        )
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var ctaStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [frequencyButton, saveButton])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fill
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var folderLabel: NNSmallLabel = {
        let label = NNSmallLabel()
        return label
    }()
    
    let routine: RoutineItem?
    private let category: String
    private let suggestedActions: [String]
    private var routineActions: [String] = []
    private let stateManager = RoutineStateManager.shared
    private var isTableViewInEditMode: Bool = false

    private lazy var attachmentStackView: AttachmentStackView = {
        // Expand left (horizontal accordion) across the footer row.
        let stack = AttachmentStackView(stackSize: 80, expansionDirection: .left)
        stack.delegate = self
        return stack
    }()

    private var pendingAttachmentIds: [String] = []
    private var resolvedAttachments: [any BaseItem] = []
    private var originalAttachmentIds: [String] = []
    private var hasCompletedInitialAttachmentLoad = false
    
    // MARK: - Initialization
    init(category: String, routine: RoutineItem? = nil, sourceFrame: CGRect? = nil, isReadOnly: Bool = false) {
        self.category = category
        self.routine = routine
        self.isReadOnly = isReadOnly
        self.suggestedActions = []
        super.init(sourceFrame: sourceFrame)
        titleField.text = routine?.title
    }
    
    init(
        category: String,
        routineName: String,
        suggestedActions: [String] = [],
        sourceFrame: CGRect? = nil
    ) {
        self.category = category
        self.routine = nil
        self.isReadOnly = false
        self.suggestedActions = suggestedActions
        super.init(sourceFrame: sourceFrame)
        
        titleField.text = routineName
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = routine == nil ? "New Routine" : isReadOnly ? "View Routine" : "Edit Routine"
        
        titleField.placeholder = "Routine Name"
        titleField.delegate = self
        titleField.addTarget(self, action: #selector(titleFieldChanged), for: .editingChanged)
        
        // Load routine actions (or suggested sample steps for new routines from Common Items)
        routineActions = routine?.routineActions ?? suggestedActions
        pendingAttachmentIds = routine?.attachmentIds ?? []
        originalAttachmentIds = pendingAttachmentIds
        
        // Initialize state manager if we have a routine
        if let routine = routine {
            // Load any existing completion state for today
            // The state manager automatically handles daily resets
        }
        
        configureFolderLabel()
        
        if isReadOnly {
            configureReadOnlyMode()
        } else {
            setupInfoButton()
            routineTableView.dragDelegate = self
            routineTableView.dropDelegate = self
            routineTableView.dragInteractionEnabled = true
        }
        
        itemsHiddenDuringTransition = isReadOnly
            ? [attachmentStackView]
            : [ctaStack, attachmentStackView]
        
        // Add content insets so content can scroll above the folder label and save button
        let bottomInset: CGFloat = isReadOnly ? 120 : 168
        routineTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        routineTableView.scrollIndicatorInsets = routineTableView.contentInset
        
        if routine == nil && !isReadOnly && titleField.text == nil  {
            titleField.becomeFirstResponder()
        } else if routine == nil && !isReadOnly {
            routineTableView.becomeFirstResponder()
        }

        // Ensure save button state reflects current title and action list
        updateSaveButtonEnabledState()
        refreshAttachmentStack()
        loadResolvedAttachments()
    }
    
    // MARK: - Setup Methods
    override func addContentToContainer() {
        super.addContentToContainer()
        
        containerView.addSubview(routineTableView)
        containerView.addSubview(attachmentStackView)
        containerView.addSubview(folderLabel)
        if !isReadOnly {
            containerView.addSubview(ctaStack)
        }
        
        folderLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        folderLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        attachmentStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        attachmentStackView.setContentHuggingPriority(.required, for: .horizontal)

        var constraints: [NSLayoutConstraint] = [
            // Table view - extends to bottom of container
            routineTableView.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 8),
            routineTableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            routineTableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            routineTableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),

            // Same row above CTA: folder left, attachments right
            folderLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            folderLabel.trailingAnchor.constraint(lessThanOrEqualTo: attachmentStackView.leadingAnchor, constant: -12),
            folderLabel.heightAnchor.constraint(equalToConstant: 30),

            attachmentStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
        ]
        
        if !isReadOnly {
            constraints.append(contentsOf: [
                folderLabel.bottomAnchor.constraint(equalTo: ctaStack.topAnchor, constant: -12),
                attachmentStackView.bottomAnchor.constraint(equalTo: ctaStack.topAnchor, constant: -12),
                
                ctaStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                ctaStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                ctaStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Self.ctaBottomPadding),
                ctaStack.heightAnchor.constraint(equalToConstant: 46),
                
                frequencyButton.widthAnchor.constraint(lessThanOrEqualTo: ctaStack.widthAnchor, multiplier: isReadOnly ? 1.0 : 0.6),
                
                saveButton.widthAnchor.constraint(lessThanOrEqualTo: ctaStack.widthAnchor, multiplier: 0.4)
            ])
        } else {
            constraints.append(contentsOf: [
                folderLabel.bottomAnchor.constraint(
                    equalTo: containerView.bottomAnchor,
                    constant: -Self.ctaBottomPadding
                ).with(priority: .defaultHigh),
                attachmentStackView.bottomAnchor.constraint(
                    equalTo: containerView.bottomAnchor,
                    constant: -Self.ctaBottomPadding
                ).with(priority: .defaultHigh),
            ])
        }
        
        NSLayoutConstraint.activate(constraints)
        
        // Blur behind folder + attachment stack + CTA (pin from stack so z-order stays correct).
        attachmentStackView.pinVariableBlur(to: containerView, direction: .bottom, blurRadius: 20, height: 140)
        containerView.bringSubviewToFront(folderLabel)
        containerView.bringSubviewToFront(attachmentStackView)
        if !isReadOnly {
            containerView.bringSubviewToFront(ctaStack)
        }
        containerView.clipsToBounds = true
    }
    
    private func updateSaveButtonEnabledState() {
        guard !isReadOnly else { return }
        let titleString = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasTitle = !titleString.isEmpty
        let hasAtLeastOneAction = !routineActions.isEmpty
        
        // For new routines, just check basic requirements
        if routine == nil {
            let shouldEnable = hasTitle && hasAtLeastOneAction
            saveButton.isEnabled = shouldEnable
            return
        }
        
        // For existing routines, also check if anything has changed
        let currentTitle = routine?.title ?? ""
        let currentActions = routine?.routineActions ?? []
        
        // Handle frequency comparison
        let currentFrequency = routine?.frequency ?? "Daily"
        let selectedFrequency = frequencyButton.configuration?.attributedTitle.map { String($0.characters) } ?? frequencyButton.title(for: .normal) ?? "Daily"
        let frequencyChanged = selectedFrequency != currentFrequency
        
        let titleChanged = titleString != currentTitle
        let actionsChanged = routineActions != currentActions
        let attachmentsChanged = pendingAttachmentIds != originalAttachmentIds
        
        
        let hasChanges = titleChanged || actionsChanged || frequencyChanged || attachmentsChanged
        let shouldEnable = hasTitle && hasAtLeastOneAction && hasChanges
        saveButton.isEnabled = shouldEnable
    }

    @objc private func titleFieldChanged() {
        collapseAttachmentsIfNeeded()
        updateSaveButtonEnabledState()
    }

    override func leadingMenuWillPresent() {
        collapseAttachmentsIfNeeded()
    }

    private func collapseAttachmentsIfNeeded() {
        attachmentStackView.collapseIfNeeded()
    }

    /// Applies an in-memory reorder of `routineActions` and keeps per-action completion aligned when `routine` exists.
    private func applyRoutineActionReorder(from sourceRow: Int, to destinationRow: Int) {
        guard sourceRow != destinationRow,
              sourceRow >= 0, sourceRow < routineActions.count,
              destinationRow >= 0, destinationRow < routineActions.count else { return }

        let movedAction = routineActions.remove(at: sourceRow)
        routineActions.insert(movedAction, at: destinationRow)

        if let routineId = routine?.id {
            var completionStates: [Bool] = []
            for index in 0..<routineActions.count {
                completionStates.append(stateManager.isActionCompleted(routineId: routineId, actionIndex: index))
            }

            for index in 0..<routineActions.count {
                stateManager.setActionCompleted(false, routineId: routineId, actionIndex: index)
            }

            let movedCompletion = completionStates[sourceRow]
            completionStates.remove(at: sourceRow)
            completionStates.insert(movedCompletion, at: destinationRow)

            for (index, isCompleted) in completionStates.enumerated() {
                stateManager.setActionCompleted(isCompleted, routineId: routineId, actionIndex: index)
            }
        }

        updateSaveButtonEnabledState()
    }

    // MARK: - Private Methods
    private func configureFolderLabel() {
        let components = category.components(separatedBy: "/")
        if components.count >= 2 {
            folderLabel.text = components.joined(separator: " / ")
        } else if components.count == 1 {
            folderLabel.text = components.first
        } else {
            folderLabel.text = category
        }
    }
    
    private func configureReadOnlyMode() {
        titleField.isEnabled = false
        // Allow table view interaction for routine completion checkboxes
        routineTableView.isUserInteractionEnabled = true
    }
    
    override func setupInfoButton() {
        setLeadingBarButtonHidden(isReadOnly)
        updateInfoButtonAppearance()
    }
    
    
    private func updateInfoButtonAppearance() {
        if isTableViewInEditMode {
            setLeadingDoneBarButton(title: "Done", target: self, action: #selector(doneButtonTapped))
        } else {
            setLeadingBarButtonMenu(createMenu())
        }

        refreshNavigationBarItems()
    }
    
    @objc private func doneButtonTapped() {
        toggleEditMode()
    }
    
    private func presentRoutinesInfo() {
        let infoVC = RoutinesInfoViewController()
        present(infoVC, animated: true)
    }
    
    private func handleDeleteRoutine() {
        guard let routine = routine else { return }
        
        let alert = UIAlertController(
            title: "Delete Routine",
            message: "Are you sure you want to delete \"\(routine.title)\"? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDeleteRoutine()
        })
        
        present(alert, animated: true)
    }
    
    private func performDeleteRoutine() {
        guard let routine = routine else { return }
        
        // Show loading state on save button if it exists
        if !isReadOnly {
            saveButton.startLoading()
        }
        
        Task {
            do {
                try await NestService.shared.deleteRoutine(routine)
                
                await MainActor.run {
                    self.routineDelegate?.routineDetailViewController(didDeleteRoutine: routine)
                    HapticsHelper.thwompHaptic()
                    self.dismissSheet()
                }
            } catch {
                await MainActor.run {
                    if !self.isReadOnly {
                        self.saveButton.stopLoading(withSuccess: false)
                    }
                    self.showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    
    private func createMenu() -> UIMenu {
        var topActions: [UIAction] = []
        var menuChildren: [UIMenuElement] = []
        
        // Top section - Info and Edit actions
        let learnAction = UIAction(
            title: "Learn about Routines",
            image: UIImage(systemName: "info.circle")
        ) { [weak self] _ in
            self?.presentRoutinesInfo()
        }
        topActions.append(learnAction)

        if !isReadOnly {
            let attachTitle = pendingAttachmentIds.isEmpty ? "Add Attachment" : "Manage Attachments"
            let attachAction = UIAction(
                title: attachTitle,
                image: UIImage(systemName: "paperclip")
            ) { [weak self] _ in
                self?.presentAttachmentPicker()
            }
            topActions.append(attachAction)
        }
        
        // Only show edit option if we have routine actions and not in read-only mode
        if !routineActions.isEmpty && !isReadOnly {
            let editAction = UIAction(
                title: "Edit",
                image: UIImage(systemName: "pencil")
            ) { [weak self] _ in
                self?.toggleEditMode()
            }
            topActions.append(editAction)
        }
        
        // Create top section menu
        if !topActions.isEmpty {
            let topSection = UIMenu(title: "", options: .displayInline, children: topActions)
            menuChildren.append(topSection)
        }
        
        // Bottom section - Delete action (separated by divider)
        if routine != nil && !isReadOnly {
            let deleteAction = UIAction(
                title: "Delete Routine",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.handleDeleteRoutine()
            }
            menuChildren.append(deleteAction)
        }
        
        return UIMenu(children: menuChildren)
    }
    
    private func toggleEditMode() {
        collapseAttachmentsIfNeeded()
        let wasInEditMode = isTableViewInEditMode
        isTableViewInEditMode.toggle()
        routineTableView.setEditing(isTableViewInEditMode, animated: true)
        
        // Update the button appearance to reflect the new state
        updateInfoButtonAppearance()
        
        // Enable/disable drag-to-dismiss based on edit mode
        // Handle showing/hiding the "Add Action" cell
        if !isReadOnly && routineActions.count < 10 {
            let addCellIndexPath = IndexPath(row: routineActions.count, section: 0)
            
            if wasInEditMode && !isTableViewInEditMode {
                // Exiting edit mode - show the "Add Action" cell
                routineTableView.insertRows(at: [addCellIndexPath], with: .fade)
            } else if !wasInEditMode && isTableViewInEditMode {
                // Entering edit mode - hide the "Add Action" cell
                routineTableView.deleteRows(at: [addCellIndexPath], with: .fade)
            }
        }
        
        // Reload visible cells to update their appearance
        for cell in routineTableView.visibleCells {
            if let routineCell = cell as? RoutineActionCell,
               let indexPath = routineTableView.indexPath(for: cell),
               indexPath.row < routineActions.count {
                let action = routineActions[indexPath.row]
                let isCompleted = routine.map { stateManager.isActionCompleted(routineId: $0.id, actionIndex: indexPath.row) } ?? false
                routineCell.configure(with: action, isCompleted: isCompleted, isReadOnly: isReadOnly, at: indexPath)
                routineCell.setEditMode(isTableViewInEditMode, isCompleted: isCompleted)
            }
        }
        
    }
    
    @objc private func frequencyButtonTapped() {
        collapseAttachmentsIfNeeded()
        let currentFrequency = routine?.frequency ?? "Daily"
        let frequencyVC = RoutineFrequencyViewController(currentFrequency: currentFrequency)
        frequencyVC.delegate = self
        present(frequencyVC, animated: true)
    }
    
    @objc private func saveButtonTapped() {
        guard let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty,
              !routineActions.isEmpty else {
            shakeContainerView()
            return
        }
        
        saveButton.startLoading()
        prepareToSaveAndDismiss()
        titleField.isUserInteractionEnabled = false
        routineTableView.isUserInteractionEnabled = false
        
        Task {
            do {
                var savedRoutine: RoutineItem
                
                let allItems = try await NestService.shared.fetchAllItems()
                let prunedAttachmentIds = AttachmentResolver.prune(
                    ids: pendingAttachmentIds,
                    against: allItems,
                    excludingHostId: routine?.id
                )

                if let existingRoutine = routine {
                    existingRoutine.title = title
                    existingRoutine.routineActions = routineActions
                    existingRoutine.frequency = frequencyButton.configuration?.attributedTitle.map { String($0.characters) } ?? frequencyButton.title(for: .normal)
                    existingRoutine.attachmentIds = prunedAttachmentIds
                    existingRoutine.updatedAt = Date()
                    
                    try await NestService.shared.updateRoutine(existingRoutine)
                    savedRoutine = existingRoutine
                } else {
                    let newRoutine = RoutineItem(
                        title: title,
                        category: category,
                        routineActions: routineActions,
                        frequency: frequencyButton.configuration?.attributedTitle.map { String($0.characters) } ?? frequencyButton.title(for: .normal),
                        attachmentIds: prunedAttachmentIds
                    )
                    
                    try await NestService.shared.createRoutine(newRoutine)
                    savedRoutine = newRoutine
                }
                
                HapticsHelper.lightHaptic()
                
                // Notify delegate
                await MainActor.run {
                    self.routineDelegate?.routineDetailViewController(didSaveRoutine: savedRoutine)
                    self.dismissSheet()
                }
            } catch {
                await MainActor.run {
                    self.cancelSaveAndDismiss()
                    saveButton.stopLoading(withSuccess: false)
                    titleField.isUserInteractionEnabled = true
                    routineTableView.isUserInteractionEnabled = true
                    self.showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Error Handling
    
    // MARK: - Attachments

    private func refreshAttachmentStack() {
        // Empty editable stacks show a dashed paperclip; otherwise the accordion.
        attachmentStackView.configure(
            items: resolvedAttachments,
            showsPlus: !isReadOnly,
            allowsRemoval: !isReadOnly
        )
        loadPlaceThumbnailsForAttachments()
        if !isReadOnly {
            updateInfoButtonAppearance()
        }
    }

    private func loadResolvedAttachments() {
        guard !pendingAttachmentIds.isEmpty else {
            hasCompletedInitialAttachmentLoad = true
            resolvedAttachments = []
            refreshAttachmentStack()
            return
        }

        Task {
            do {
                let items = try await fetchItemsForAttachmentResolution()
                let resolved = AttachmentResolver.resolve(
                    ids: pendingAttachmentIds,
                    from: items,
                    excludingHostId: routine?.id
                )
                await MainActor.run {
                    self.resolvedAttachments = resolved
                    self.pendingAttachmentIds = resolved.map(\.id)
                    if !self.hasCompletedInitialAttachmentLoad {
                        self.originalAttachmentIds = self.pendingAttachmentIds
                        self.hasCompletedInitialAttachmentLoad = true
                    }
                    self.refreshAttachmentStack()
                    self.updateSaveButtonEnabledState()
                }
            } catch {
                Logger.log(
                    level: .error,
                    category: .general,
                    message: "Failed to resolve routine attachments: \(error.localizedDescription)"
                )
            }
        }
    }

    private func fetchItemsForAttachmentResolution() async throws -> [BaseItem] {
        if isReadOnly {
            return try await SitterViewService.shared.itemsForAttachmentResolution()
        }
        return try await NestService.shared.itemsForAttachmentResolution()
    }

    private func loadPlaceThumbnailsForAttachments() {
        for item in resolvedAttachments {
            guard let place = item as? PlaceItem else { continue }
            Task {
                do {
                    let image: UIImage
                    if isReadOnly {
                        image = try await SitterViewService.shared.loadImages(for: place)
                    } else {
                        image = try await NestService.shared.loadImages(for: place)
                    }
                    await MainActor.run {
                        self.attachmentStackView.setPreviewImage(image, forItemId: place.id)
                    }
                } catch {
                    // Keep icon fallback
                }
            }
        }
    }

    private func presentAttachmentPicker() {
        collapseAttachmentsIfNeeded()
        NNTipManager.shared.dismissTip(AttachmentTips.attachItemsTip)
        AttachmentPickerPresenter.present(
            from: self,
            selectedIds: pendingAttachmentIds,
            excludingHostId: routine?.id
        ) { [weak self] ids in
            guard let self else { return }
            self.pendingAttachmentIds = ids
            self.loadResolvedAttachments()
            self.updateSaveButtonEnabledState()
        }
    }

    // MARK: - NNTippable

    func showTips() {
        guard !isReadOnly else { return }
        trackScreenVisit()

        guard NNTipManager.shared.shouldShowTip(AttachmentTips.attachItemsTip) else { return }
        NNTipManager.shared.showTip(
            AttachmentTips.attachItemsTip,
            sourceView: attachmentStackView,
            in: self,
            pinToEdge: .top,
            offset: CGPoint(x: 0, y: -8)
        )
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension RoutineDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let baseCount = routineActions.count
        
        // Add one more row for "Add Action" if not read-only, under limit, and not in edit mode
        if !isReadOnly && !isTableViewInEditMode && routineActions.count < 10 {
            return baseCount + 1
        }
        
        return baseCount
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Check if this is the "Add Action" row (only show if not in edit mode)
        if indexPath.row == routineActions.count && !isReadOnly && !isTableViewInEditMode && routineActions.count < 10 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AddRoutineActionCell", for: indexPath) as! AddRoutineActionCell
            cell.delegate = self
            return cell
        }
        
        // Regular action cell
        let cell = tableView.dequeueReusableCell(withIdentifier: "RoutineActionCell", for: indexPath) as! RoutineActionCell
        let action = routineActions[indexPath.row]
        let isCompleted = routine.map { stateManager.isActionCompleted(routineId: $0.id, actionIndex: indexPath.row) } ?? false
        
        cell.configure(with: action, isCompleted: isCompleted, isReadOnly: isReadOnly, at: indexPath)
        cell.delegate = self
        
        return cell
    }

    // MARK: - Edit / reorder (UITableViewDataSource)
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row < routineActions.count
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            routineActions.remove(at: indexPath.row)

            if let routineId = routine?.id {
                for actionIndex in (indexPath.row + 1)..<(routineActions.count + 1) {
                    let wasCompleted = stateManager.isActionCompleted(routineId: routineId, actionIndex: actionIndex)
                    if wasCompleted {
                        stateManager.setActionCompleted(false, routineId: routineId, actionIndex: actionIndex)
                        stateManager.setActionCompleted(true, routineId: routineId, actionIndex: actionIndex - 1)
                    }
                }
            }

            tableView.deleteRows(at: [indexPath], with: .fade)

            HapticsHelper.lightHaptic()

            updateSaveButtonEnabledState()
        }
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row < routineActions.count
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath.row < routineActions.count && destinationIndexPath.row < routineActions.count else {
            return
        }
        applyRoutineActionReorder(from: sourceIndexPath.row, to: destinationIndexPath.row)
    }
}

// MARK: - UITableViewDelegate
extension RoutineDetailViewController: UITableViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        collapseAttachmentsIfNeeded()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if proposedDestinationIndexPath.row >= routineActions.count {
            return IndexPath(row: routineActions.count - 1, section: 0)
        }
        return proposedDestinationIndexPath
    }
}

// MARK: - UITableViewDragDelegate & UITableViewDropDelegate (reorder without entering table Edit mode)
extension RoutineDetailViewController: UITableViewDragDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard !isReadOnly,
              !isTableViewInEditMode,
              routineActions.count > 1,
              indexPath.row < routineActions.count else {
            return []
        }
        collapseAttachmentsIfNeeded()
        let itemProvider = NSItemProvider(object: routineActions[indexPath.row] as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = indexPath
        return [dragItem]
    }
}

extension RoutineDetailViewController: UITableViewDropDelegate {
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        guard tableView.hasActiveDrag,
              session.localDragSession != nil,
              let destinationIndexPath,
              destinationIndexPath.row < routineActions.count else {
            return UITableViewDropProposal(operation: .forbidden)
        }
        return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard coordinator.proposal.operation == .move,
              let item = coordinator.items.first,
              let sourceIndexPath = item.sourceIndexPath,
              let destinationIndexPath = coordinator.destinationIndexPath,
              sourceIndexPath != destinationIndexPath,
              destinationIndexPath.row < routineActions.count else {
            return
        }

        tableView.performBatchUpdates({
            self.applyRoutineActionReorder(from: sourceIndexPath.row, to: destinationIndexPath.row)
            tableView.moveRow(at: sourceIndexPath, to: destinationIndexPath)
        })

        coordinator.drop(item.dragItem, toRowAt: destinationIndexPath)
    }
}

// MARK: - RoutineActionCellDelegate
extension RoutineDetailViewController: RoutineActionCellDelegate {
    func routineActionCellDidBeginEditing(_ cell: RoutineActionCell) {
        collapseAttachmentsIfNeeded()
    }

    func routineActionCellDidChangeText(_ cell: RoutineActionCell) {
        collapseAttachmentsIfNeeded()
    }

    func routineActionCell(_ cell: RoutineActionCell, didToggleCompletion isCompleted: Bool) {
        collapseAttachmentsIfNeeded()
        guard let indexPath = routineTableView.indexPath(for: cell),
              let routineId = routine?.id else { return }
        
        stateManager.setActionCompleted(isCompleted, routineId: routineId, actionIndex: indexPath.row)
        
        // Cell already handled its own appearance update in checkboxTapped
        // No need to reconfigure here as it would override the cell's internal state
    }
    
    func routineActionCell(_ cell: RoutineActionCell, didRequestDelete action: String) {
        guard let index = routineActions.firstIndex(of: action) else { return }
        
        routineActions.remove(at: index)
        
        // Update completion state - shift indices down for actions after the deleted one
        if let routineId = routine?.id {
            for actionIndex in (index + 1)..<(routineActions.count + 1) {
                let wasCompleted = stateManager.isActionCompleted(routineId: routineId, actionIndex: actionIndex)
                if wasCompleted {
                    stateManager.setActionCompleted(false, routineId: routineId, actionIndex: actionIndex)
                    stateManager.setActionCompleted(true, routineId: routineId, actionIndex: actionIndex - 1)
                }
            }
        }
        
        routineTableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        
        // If we were at the limit and now have space, reload to show add cell
        if routineActions.count == 9 {
            let addIndexPath = IndexPath(row: routineActions.count, section: 0)
            routineTableView.insertRows(at: [addIndexPath], with: .fade)
        }

        updateSaveButtonEnabledState()
    }
    
    func routineActionCell(_ cell: RoutineActionCell, didUpdateAction newAction: String, at indexPath: IndexPath) {
        routineActions[indexPath.row] = newAction
        updateSaveButtonEnabledState()
    }
}

// MARK: - AddRoutineActionCellDelegate
extension RoutineDetailViewController: AddRoutineActionCellDelegate {
    func addRoutineActionCellDidBeginEditing(_ cell: AddRoutineActionCell) {
        collapseAttachmentsIfNeeded()
    }

    func addRoutineActionCellDidChangeText(_ cell: AddRoutineActionCell) {
        collapseAttachmentsIfNeeded()
    }

    func addRoutineActionCell(_ cell: AddRoutineActionCell, didAddAction action: String) {
        collapseAttachmentsIfNeeded()
        guard routineActions.count < 10 else { return }
        
        let wasAtLimit = routineActions.count == 9
        let oldCount = routineActions.count
        
        routineActions.append(action)
        
        // Batch the table view updates to avoid inconsistent state
        routineTableView.performBatchUpdates({
            if wasAtLimit {
                // When we have 9 items, the add cell is at index 9
                // We need to replace the add cell with the new action item
                let addCellIndexPath = IndexPath(row: oldCount, section: 0)
                routineTableView.deleteRows(at: [addCellIndexPath], with: .fade)
                
                // Insert the new action row at the same position
                let newActionIndexPath = IndexPath(row: oldCount, section: 0)
                routineTableView.insertRows(at: [newActionIndexPath], with: .fade)
            } else {
                // Normal case: just insert the new action row, add cell will still be there after it
                let newActionIndexPath = IndexPath(row: oldCount, section: 0)
                routineTableView.insertRows(at: [newActionIndexPath], with: .fade)
            }
        }, completion: { [weak self] _ in
            self?.updateSaveButtonEnabledState()
        })
    }
}

// MARK: - RoutineFrequencyViewControllerDelegate
extension RoutineDetailViewController: RoutineFrequencyViewControllerDelegate {
    func routineFrequencyViewController(_ controller: RoutineFrequencyViewController, didSelectFrequency frequency: String) {
        // Update the frequency button title
        frequencyButton.setTitle(frequency, for: .normal)
        // Update save button state to reflect the change
        updateSaveButtonEnabledState()
    }
}

// MARK: - UITextFieldDelegate
extension RoutineDetailViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        collapseAttachmentsIfNeeded()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == titleField {
            textField.resignFirstResponder()
            return false
        }
        return true
    }
}

// MARK: - AttachmentStackViewDelegate
extension RoutineDetailViewController: AttachmentStackViewDelegate {
    func attachmentStackView(_ stackView: AttachmentStackView, didTapItem item: any BaseItem) {
        NestItemDetailRouter.presentDetail(
            for: item,
            from: self,
            nestItemRepository: isReadOnly ? SitterViewService.shared : NestService.shared,
            category: item.category,
            sourceFrame: stackView.convert(stackView.bounds, to: nil),
            placeListDelegate: nil,
            noteDelegate: nil,
            routineDelegate: nil,
            contactDelegate: nil
        )
    }

    func attachmentStackViewDidTapPlus(_ stackView: AttachmentStackView) {
        presentAttachmentPicker()
    }

    func attachmentStackView(_ stackView: AttachmentStackView, didChangeExpanded isExpanded: Bool) {
        // Hide folder while the horizontal accordion is open so cards have room.
        UIView.animate(withDuration: 0.2) {
            self.folderLabel.alpha = isExpanded ? 0 : 1
        }
        self.folderLabel.isUserInteractionEnabled = !isExpanded
    }

    func attachmentStackView(_ stackView: AttachmentStackView, didRequestRemoveItem item: any BaseItem) {
        pendingAttachmentIds.removeAll { $0 == item.id }
        resolvedAttachments.removeAll { $0.id == item.id }
        // Stack already animated the drop; keep local state in sync without rebuilding.
        updateSaveButtonEnabledState()
        if !isReadOnly {
            setupInfoButton()
        }
    }
}
