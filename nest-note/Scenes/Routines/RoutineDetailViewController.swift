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
    private var completedActionIndices: Set<Int> = []
    private var isTableViewInEditMode: Bool = false
    private var infoButtonWidthConstraint: NSLayoutConstraint?
    
    // MARK: - Initialization
    init(category: String, routine: RoutineItem? = nil, sourceFrame: CGRect? = nil, isReadOnly: Bool = false) {
        self.category = category
        self.routine = routine
        self.isReadOnly = isReadOnly
        super.init(sourceFrame: sourceFrame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = routine == nil ? "New Routine" : isReadOnly ? "View Routine" : "Edit Routine"
        titleField.text = routine?.title
        titleField.placeholder = "Routine Name"
        titleField.delegate = self
        
        // Load routine actions
        routineActions = routine?.routineActions ?? []
        
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
        
        if routine == nil && !isReadOnly {
            titleField.becomeFirstResponder()
        }
        
        // Setup gesture forwarding for scroll-to-dismiss behavior
        setupScrollGestureForwarding()
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
        routineTableView.isUserInteractionEnabled = false
    }
    
    override func setupInfoButton() {
        // Configure the base class info button 
        infoButton.isHidden = false
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
        
        // For now, just notify the delegate that the routine was deleted
        // In a real app, this would make an API call to delete the routine
        routineDelegate?.routineDetailViewController(didDeleteRoutine: routine)
        
        // Show success feedback
        HapticsHelper.thwompHaptic()
        
        // Dismiss the sheet
        dismiss(animated: true)
    }
    
    
    private func createMenu() -> UIMenu {
        var actions: [UIAction] = []
        
        // Only show edit option if we have routine actions and not in read-only mode
        if !routineActions.isEmpty && !isReadOnly {
            let editAction = UIAction(
                title: "Edit",
                image: UIImage(systemName: "pencil")
            ) { [weak self] _ in
                self?.toggleEditMode()
            }
            actions.append(editAction)
        }
        
        // Only show delete option if we have an existing routine and not in read-only mode
        if routine != nil && !isReadOnly {
            let deleteAction = UIAction(
                title: "Delete Routine",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.handleDeleteRoutine()
            }
            actions.append(deleteAction)
        }
        
        return UIMenu(children: actions)
    }
    
    private func toggleEditMode() {
        let wasInEditMode = isTableViewInEditMode
        isTableViewInEditMode.toggle()
        routineTableView.setEditing(isTableViewInEditMode, animated: true)
        
        // Update the button appearance to reflect the new state
        updateInfoButtonAppearance()
        
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
                let isCompleted = completedActionIndices.contains(indexPath.row)
                routineCell.configure(with: action, isCompleted: isCompleted, isReadOnly: isReadOnly, at: indexPath)
                routineCell.setEditMode(isTableViewInEditMode, isCompleted: isCompleted)
            }
        }
        
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
        
        // For now, just create/update the routine object and notify delegate
        let savedRoutine: RoutineItem
        
        if let existingRoutine = routine {
            existingRoutine.title = title
            existingRoutine.routineActions = routineActions
            existingRoutine.updatedAt = Date()
            savedRoutine = existingRoutine
        } else {
            savedRoutine = RoutineItem(
                title: title,
                category: category,
                routineActions: routineActions
            )
        }
        
        HapticsHelper.lightHaptic()
        
        // Simulate a brief delay for the loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.routineDelegate?.routineDetailViewController(didSaveRoutine: savedRoutine)
            self.dismiss(animated: true)
        }
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
        let isCompleted = completedActionIndices.contains(indexPath.row)
        
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
            
            // Update completion indices - remove the deleted index and shift others down
            var newCompletedIndices: Set<Int> = []
            for completedIndex in completedActionIndices {
                if completedIndex < indexPath.row {
                    newCompletedIndices.insert(completedIndex)
                } else if completedIndex > indexPath.row {
                    newCompletedIndices.insert(completedIndex - 1)
                }
                // Skip the deleted index (completedIndex == indexPath.row)
            }
            completedActionIndices = newCompletedIndices
            
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
        
        // Update completion indices to match the new order
        var newCompletedIndices: Set<Int> = []
        for completedIndex in completedActionIndices {
            if completedIndex == sourceIndexPath.row {
                // The moved item maintains its completion state at the new position
                newCompletedIndices.insert(destinationIndexPath.row)
            } else if completedIndex < sourceIndexPath.row && completedIndex < destinationIndexPath.row {
                // Items before both positions stay the same
                newCompletedIndices.insert(completedIndex)
            } else if completedIndex > sourceIndexPath.row && completedIndex > destinationIndexPath.row {
                // Items after both positions stay the same
                newCompletedIndices.insert(completedIndex)
            } else if sourceIndexPath.row < destinationIndexPath.row {
                // Moving down: items between source and destination shift up
                if completedIndex > sourceIndexPath.row && completedIndex <= destinationIndexPath.row {
                    newCompletedIndices.insert(completedIndex - 1)
                } else {
                    newCompletedIndices.insert(completedIndex)
                }
            } else {
                // Moving up: items between destination and source shift down
                if completedIndex >= destinationIndexPath.row && completedIndex < sourceIndexPath.row {
                    newCompletedIndices.insert(completedIndex + 1)
                } else {
                    newCompletedIndices.insert(completedIndex)
                }
            }
        }
        completedActionIndices = newCompletedIndices
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
        guard let indexPath = routineTableView.indexPath(for: cell) else { return }
        
        if isCompleted {
            completedActionIndices.insert(indexPath.row)
        } else {
            completedActionIndices.remove(indexPath.row)
        }
    }
    
    func routineActionCell(_ cell: RoutineActionCell, didRequestDelete action: String) {
        guard let index = routineActions.firstIndex(of: action) else { return }
        
        routineActions.remove(at: index)
        
        // Update completion indices - remove the deleted index and shift others down
        var newCompletedIndices: Set<Int> = []
        for completedIndex in completedActionIndices {
            if completedIndex < index {
                newCompletedIndices.insert(completedIndex)
            } else if completedIndex > index {
                newCompletedIndices.insert(completedIndex - 1)
            }
            // Skip the deleted index (completedIndex == index)
        }
        completedActionIndices = newCompletedIndices
        
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
        
        routineActions.append(action)
        
        // Insert the new action row
        let newActionIndexPath = IndexPath(row: routineActions.count - 1, section: 0)
        routineTableView.insertRows(at: [newActionIndexPath], with: .fade)
        
        // If we've reached the limit, remove the add cell
        if routineActions.count == 10 {
            let addCellIndexPath = IndexPath(row: routineActions.count, section: 0)
            routineTableView.deleteRows(at: [addCellIndexPath], with: .fade)
        }
        
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

// MARK: - Scroll-to-Dismiss Implementation  
extension RoutineDetailViewController {
    
    private func setupScrollGestureForwarding() {
        // Override the table view's pan gesture behavior
        let customPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleScrollPan(_:)))
        customPanGesture.delegate = self
        routineTableView.addGestureRecognizer(customPanGesture)
    }
    
    @objc private func handleScrollPan(_ recognizer: UIPanGestureRecognizer) {
        let isAtTop = routineTableView.contentOffset.y <= -routineTableView.contentInset.top
        let translation = recognizer.translation(in: view)
        let isDraggingDown = translation.y > 0
        
        // If we're at the top and dragging down, directly call the container's dismiss logic
        if isAtTop && isDraggingDown {
            // Find the container's pan gesture and invoke its handler
            if let containerPanGesture = containerView.gestureRecognizers?.compactMap({ $0 as? UIPanGestureRecognizer }).first,
               let target = containerPanGesture.value(forKey: "_targets") as? NSArray,
               let targetActionPair = target.firstObject {
                
                // Get the target and action from the container's pan gesture
                let targetObject = targetActionPair.value(forKey: "target")
                let action = targetActionPair.value(forKey: "action") as? Selector
                
                if let target = targetObject, let action = action {
                    // Call the container's pan gesture handler with our recognizer
                    _ = (target as AnyObject).perform(action, with: recognizer)
                    return
                }
            }
        }
        
        // If we're not forwarding, let the table view handle it normally
        // (This won't work perfectly since we can't easily forward to the built-in scroll handler)
    }
}

extension RoutineDetailViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow our custom gesture to work with the table view's pan gesture
        return otherGestureRecognizer == routineTableView.panGestureRecognizer
    }
}
