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

final class RoutineDetailViewController: NNSheetViewController, ScrollViewDismissalProvider {
    
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
    
    private lazy var saveButton: NNLoadingButton = {
        let button = NNLoadingButton(
            title: routine == nil ? "Save" : "Update",
            titleColor: .white,
            fillStyle: .fill(NNColors.primary)
        )
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
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
    private var infoButtonWidthConstraint: NSLayoutConstraint?
    
    // MARK: - ScrollViewDismissalProvider Properties
    var dismissalHandlingScrollView: UIScrollView? {
        return routineTableView
    }
    
    var shouldDisableScrollDismissalForEditMode: Bool {
        return isTableViewInEditMode
    }
    
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
        }
        
        itemsHiddenDuringTransition = [saveButton]
        
        // Add content insets so content can scroll above the folder label and save button
        let bottomInset: CGFloat = isReadOnly ? 56 : 104
        routineTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        routineTableView.scrollIndicatorInsets = routineTableView.contentInset
        
        if routine == nil && !isReadOnly && titleField.text == nil  {
            titleField.becomeFirstResponder()
        } else if routine == nil && !isReadOnly {
            routineTableView.becomeFirstResponder()
        }
    }
    
    // MARK: - Setup Methods
    override func addContentToContainer() {
        super.addContentToContainer()
        
        containerView.addSubview(routineTableView)
        containerView.addSubview(folderLabel)
        if !isReadOnly {
            containerView.addSubview(saveButton)
        }
        
        var constraints: [NSLayoutConstraint] = [
            // Table view - extends to bottom of container
            routineTableView.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 8),
            routineTableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            routineTableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Folder label - positioned above save button
            folderLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            folderLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16),
            folderLabel.heightAnchor.constraint(equalToConstant: 30),
        ]
        
        if !isReadOnly {
            constraints.append(contentsOf: [
                // Table view extends all the way to bottom
                routineTableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
                
                // Folder label and save button float over the table view
                folderLabel.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -16),
                
                saveButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                saveButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                saveButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16).with(priority: .defaultHigh),
                saveButton.heightAnchor.constraint(equalToConstant: 46),
            ])
        } else {
            constraints.append(contentsOf: [
                // Table view extends all the way to bottom
                routineTableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
                
                // Folder label floats over the table view
                folderLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16).with(priority: .defaultHigh),
            ])
        }
        
        NSLayoutConstraint.activate(constraints)
        
        // Add variable blur effect at the bottom to fade content behind floating elements
        folderLabel.pinVariableBlur(to: containerView, direction: .bottom, blurRadius: 20, height: 120)
        containerView.clipsToBounds = true
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
        // Configure the base class info button 
        infoButton.isHidden = isReadOnly
        updateInfoButtonAppearance()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Find the width constraint after the view is set up
        if let containerView = infoButton.superview {
            for constraint in containerView.constraints {
                if (constraint.firstItem as? UIButton) == infoButton && 
                   constraint.firstAttribute == .width && 
                   constraint.constant == 36 {
                    infoButtonWidthConstraint = constraint
                    break
                }
            }
        }
    }
    
    private func updateInfoButtonAppearance() {
        if isTableViewInEditMode {
            // In edit mode, show "Done" button
            infoButton.setTitle("Done", for: .normal)
            infoButton.setTitleColor(.systemBlue, for: .normal)
            infoButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
            infoButton.setImage(nil, for: .normal)
            infoButton.menu = nil
            infoButton.showsMenuAsPrimaryAction = false
            infoButton.removeTarget(nil, action: nil, for: .allEvents)
            infoButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
            
            // Adjust button width to fit the text properly
            infoButtonWidthConstraint?.constant = 50 // Wider to fit "Done" text
            infoButton.contentHorizontalAlignment = .center
        } else {
            // In normal mode, show ellipsis menu
            infoButton.setTitle(nil, for: .normal)
            infoButton.setTitleColor(.tertiaryLabel, for: .normal)
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
            let image = UIImage(systemName: "ellipsis", withConfiguration: config)
            infoButton.setImage(image, for: .normal)
            infoButton.tintColor = .tertiaryLabel
            infoButton.menu = createMenu()
            infoButton.showsMenuAsPrimaryAction = true
            infoButton.removeTarget(nil, action: nil, for: .allEvents)
            
            // Reset button width to original size
            infoButtonWidthConstraint?.constant = 36
            infoButton.contentHorizontalAlignment = .center
        }
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
        updateDragToDismissGesture()
        
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
    
    private func updateDragToDismissGesture() {
        // Disable container gesture during edit mode
        if let panGesture = containerView.gestureRecognizers?.first(where: { $0 is UIPanGestureRecognizer }) as? UIPanGestureRecognizer {
            panGesture.isEnabled = !isTableViewInEditMode
        }
        
        // The scroll view dismissal is automatically handled by shouldDisableScrollDismissalForEditMode
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
                    existingRoutine.updatedAt = Date()
                    
                    try await NestService.shared.updateRoutine(existingRoutine)
                    savedRoutine = existingRoutine
                } else {
                    let newRoutine = RoutineItem(
                        title: title,
                        category: category,
                        routineActions: routineActions
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
}

// MARK: - UITableViewDelegate
extension RoutineDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    // MARK: - Edit Mode Support
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Only allow editing routine action rows (not the "Add Action" cell)
        return indexPath.row < routineActions.count
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Remove the action from the array
            routineActions.remove(at: indexPath.row)
            
            // Update completion state - shift indices down for actions after the deleted one
            if let routineId = routine?.id {
                for actionIndex in (indexPath.row + 1)..<(routineActions.count + 1) {
                    let wasCompleted = stateManager.isActionCompleted(routineId: routineId, actionIndex: actionIndex)
                    if wasCompleted {
                        stateManager.setActionCompleted(false, routineId: routineId, actionIndex: actionIndex)
                        stateManager.setActionCompleted(true, routineId: routineId, actionIndex: actionIndex - 1)
                    }
                }
            }
            
            // Delete the row from the table view
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            // If we were at the limit and now have space, show add cell when exiting edit mode
            // (The add cell is already hidden in edit mode, so no need to show it here)
            
            
            HapticsHelper.lightHaptic()
        }
    }
    
    // MARK: - Drag and Drop Support
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Only allow moving routine action rows (not the "Add Action" cell)
        return indexPath.row < routineActions.count
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // Don't allow moving to the "Add Action" cell position
        guard sourceIndexPath.row < routineActions.count && destinationIndexPath.row < routineActions.count else {
            return
        }
        
        // Move the item in the array
        let movedAction = routineActions.remove(at: sourceIndexPath.row)
        routineActions.insert(movedAction, at: destinationIndexPath.row)
        
        // Update completion state to match the new order
        if let routineId = routine?.id {
            // Store current completion states
            var completionStates: [Bool] = []
            for index in 0..<routineActions.count {
                completionStates.append(stateManager.isActionCompleted(routineId: routineId, actionIndex: index))
            }
            
            // Clear all states
            for index in 0..<routineActions.count {
                stateManager.setActionCompleted(false, routineId: routineId, actionIndex: index)
            }
            
            // Reapply states in new order
            let movedCompletion = completionStates[sourceIndexPath.row]
            completionStates.remove(at: sourceIndexPath.row)
            completionStates.insert(movedCompletion, at: destinationIndexPath.row)
            
            for (index, isCompleted) in completionStates.enumerated() {
                stateManager.setActionCompleted(isCompleted, routineId: routineId, actionIndex: index)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        // Prevent moving to the "Add Action" cell position
        if proposedDestinationIndexPath.row >= routineActions.count {
            return IndexPath(row: routineActions.count - 1, section: 0)
        }
        return proposedDestinationIndexPath
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
        
    }
    
    func routineActionCell(_ cell: RoutineActionCell, didUpdateAction newAction: String, at indexPath: IndexPath) {
        routineActions[indexPath.row] = newAction
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
        }, completion: nil)
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
