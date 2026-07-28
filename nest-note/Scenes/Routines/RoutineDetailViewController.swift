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

final class RoutineDetailViewController: NNSheetViewController {
    
    // MARK: - Properties
    weak var routineDelegate: RoutineDetailViewControllerDelegate?
    private let isReadOnly: Bool
    
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
    private var routineActions: [String] = []
    private let stateManager = RoutineStateManager.shared
    private var isTableViewInEditMode: Bool = false
    
    // MARK: - Initialization
    init(category: String, routine: RoutineItem? = nil, sourceFrame: CGRect? = nil, isReadOnly: Bool = false) {
        self.category = category
        self.routine = routine
        self.isReadOnly = isReadOnly
        super.init(sourceFrame: sourceFrame)
        titleField.text = routine?.title
    }
    
    init(category: String, routineName: String, sourceFrame: CGRect? = nil) {
        self.category = category
        self.routine = nil
        self.isReadOnly = false
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
        
        // Load routine actions
        routineActions = routine?.routineActions ?? []
        
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
        
        itemsHiddenDuringTransition = isReadOnly ? [] : [ctaStack]
        
        // Add content insets so content can scroll above the folder label and save button
        let bottomInset: CGFloat = isReadOnly ? 56 : 104
        routineTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        routineTableView.scrollIndicatorInsets = routineTableView.contentInset
        
        if routine == nil && !isReadOnly && titleField.text == nil  {
            titleField.becomeFirstResponder()
        } else if routine == nil && !isReadOnly {
            routineTableView.becomeFirstResponder()
        }

        // Ensure save button state reflects current title and action list
        updateSaveButtonEnabledState()
    }
    
    // MARK: - Setup Methods
    override func addContentToContainer() {
        super.addContentToContainer()
        
        containerView.addSubview(routineTableView)
        containerView.addSubview(folderLabel)
        if !isReadOnly {
            containerView.addSubview(ctaStack)
        }
        
        var constraints: [NSLayoutConstraint] = [
            // Table view - extends to bottom of container
            routineTableView.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 8),
            routineTableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            routineTableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Folder label - positioned above CTA stack
            folderLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            folderLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16),
            folderLabel.heightAnchor.constraint(equalToConstant: 30),
        ]
        
        if !isReadOnly {
            constraints.append(contentsOf: [
                // Table view extends all the way to bottom
                routineTableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
                
                // Folder label and CTA stack float over the table view
                folderLabel.bottomAnchor.constraint(equalTo: ctaStack.topAnchor, constant: -16),
                
                ctaStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                ctaStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                ctaStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Self.ctaBottomPadding),
                ctaStack.heightAnchor.constraint(equalToConstant: 46),
                
                frequencyButton.widthAnchor.constraint(lessThanOrEqualTo: ctaStack.widthAnchor, multiplier: isReadOnly ? 1.0 : 0.6),
                
                saveButton.widthAnchor.constraint(lessThanOrEqualTo: ctaStack.widthAnchor, multiplier: 0.4)
            ])
        } else {
            constraints.append(contentsOf: [
                // Table view extends all the way to bottom
                routineTableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
                
                // Folder label floats over the table view
                folderLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Self.ctaBottomPadding).with(priority: .defaultHigh),
            ])
        }
        
        NSLayoutConstraint.activate(constraints)
        
        // Add variable blur effect at the bottom to fade content behind floating elements
        folderLabel.pinVariableBlur(to: containerView, direction: .bottom, blurRadius: 20, height: 120)
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
        
        
        let hasChanges = titleChanged || actionsChanged || frequencyChanged
        let shouldEnable = hasTitle && hasAtLeastOneAction && hasChanges
        saveButton.isEnabled = shouldEnable
    }

    @objc private func titleFieldChanged() {
        updateSaveButtonEnabledState()
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
                    self.dismiss(animated: true)
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
        var bottomActions: [UIAction] = []
        var menuChildren: [UIMenuElement] = []
        
        // Top section - Info and Edit actions
        let learnAction = UIAction(
            title: "Learn about Routines",
            image: UIImage(systemName: "info.circle")
        ) { [weak self] _ in
            self?.presentRoutinesInfo()
        }
        topActions.append(learnAction)
        
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
        
        // Bottom section - Delete action
        if routine != nil && !isReadOnly {
            let deleteAction = UIAction(
                title: "Delete Routine",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.handleDeleteRoutine()
            }
            bottomActions.append(deleteAction)
        }
        
        // Add bottom actions directly (they'll be separated from top section automatically)
        menuChildren.append(contentsOf: bottomActions)
        
        return UIMenu(children: menuChildren)
    }
    
    private func toggleEditMode() {
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
        titleField.isUserInteractionEnabled = false
        routineTableView.isUserInteractionEnabled = false
        
        Task {
            do {
                var savedRoutine: RoutineItem
                
                if let existingRoutine = routine {
                    existingRoutine.title = title
                    existingRoutine.routineActions = routineActions
                    existingRoutine.frequency = frequencyButton.configuration?.attributedTitle.map { String($0.characters) } ?? frequencyButton.title(for: .normal)
                    existingRoutine.updatedAt = Date()
                    
                    try await NestService.shared.updateRoutine(existingRoutine)
                    savedRoutine = existingRoutine
                } else {
                    let newRoutine = RoutineItem(
                        title: title,
                        category: category,
                        routineActions: routineActions,
                        frequency: frequencyButton.configuration?.attributedTitle.map { String($0.characters) } ?? frequencyButton.title(for: .normal)
                    )
                    
                    try await NestService.shared.createRoutine(newRoutine)
                    savedRoutine = newRoutine
                }
                
                HapticsHelper.lightHaptic()
                
                // Notify delegate
                await MainActor.run {
                    self.routineDelegate?.routineDetailViewController(didSaveRoutine: savedRoutine)
                    self.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    saveButton.stopLoading(withSuccess: false)
                    titleField.isUserInteractionEnabled = true
                    routineTableView.isUserInteractionEnabled = true
                    self.showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Error Handling
    
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
    func routineActionCell(_ cell: RoutineActionCell, didToggleCompletion isCompleted: Bool) {
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
    func addRoutineActionCell(_ cell: AddRoutineActionCell, didAddAction action: String) {
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
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == titleField {
            textField.resignFirstResponder()
            return false
        }
        return true
    }
}
