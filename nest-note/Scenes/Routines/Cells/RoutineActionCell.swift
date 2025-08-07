//
//  RoutineActionCell.swift
//  nest-note
//
//  Created by Claude on 2/4/25.
//

import UIKit

protocol RoutineActionCellDelegate: AnyObject {
    func routineActionCell(_ cell: RoutineActionCell, didToggleCompletion isCompleted: Bool)
    func routineActionCell(_ cell: RoutineActionCell, didRequestDelete action: String)
    func routineActionCell(_ cell: RoutineActionCell, didUpdateAction newAction: String, at indexPath: IndexPath)
}

class RoutineActionCell: UITableViewCell {
    
    weak var delegate: RoutineActionCellDelegate?
    private var action: String = ""
    private var isReadOnly: Bool = false
    private var indexPath: IndexPath?
    private var isEditingMode: Bool = false
    private var labelLeadingConstraint: NSLayoutConstraint?
    private var editTextViewLeadingConstraint: NSLayoutConstraint?
    private var isCompleted: Bool = false
    
    private lazy var checkboxButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var actionLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyXL
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var editTextView: UITextView = {
        let textView = UITextView()
        textView.font = .bodyXL
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets.zero
        textView.textContainer.lineFragmentPadding = 0
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isHidden = true
        textView.returnKeyType = .done
        return textView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(checkboxButton)
        contentView.addSubview(actionLabel)
        contentView.addSubview(editTextView)
        
        // Create dynamic constraints for the label and text view leading anchors
        labelLeadingConstraint = actionLabel.leadingAnchor.constraint(equalTo: checkboxButton.trailingAnchor, constant: 8)
        editTextViewLeadingConstraint = editTextView.leadingAnchor.constraint(equalTo: checkboxButton.trailingAnchor, constant: 8)
        
        NSLayoutConstraint.activate([
            // Checkbox button - aligned with text top
            checkboxButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            checkboxButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            checkboxButton.widthAnchor.constraint(equalToConstant: 30),
            checkboxButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Action label - dynamic leading constraint
            labelLeadingConstraint!,
            actionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            actionLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            actionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            // Edit text view - dynamic leading constraint
            editTextViewLeadingConstraint!,
            editTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            editTextView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            editTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
        
        
        // Add tap gesture to label for editing
        let labelTap = UITapGestureRecognizer(target: self, action: #selector(handleLabelTap(_:)))
        actionLabel.addGestureRecognizer(labelTap)
        actionLabel.isUserInteractionEnabled = true
    }
    
    func configure(with action: String, isCompleted: Bool, isReadOnly: Bool, at indexPath: IndexPath? = nil) {
        self.action = action
        self.isReadOnly = isReadOnly
        self.indexPath = indexPath
        self.isCompleted = isCompleted
        
        // Configure checkbox appearance
        updateCheckboxAppearance(isCompleted: isCompleted)
        
        // Configure label
        actionLabel.text = action
        updateLabelAppearance(isCompleted: isCompleted)
        
        // Allow checkbox interaction even in read-only mode for routine completion
        checkboxButton.isUserInteractionEnabled = true
        
        // Enable/disable label tap for editing
        actionLabel.isUserInteractionEnabled = !isReadOnly
        
        // Make sure we're in display mode initially
        setEditingMode(false)
    }
    
    func setEditMode(_ isInEditMode: Bool, isCompleted: Bool = false) {
        if isInEditMode {
            // In edit mode, hide the checkbox completely
            checkboxButton.isHidden = true
            
            // Disable tap gesture for editing text in edit mode
            actionLabel.isUserInteractionEnabled = false
            
            // Update constraints to align label to leading edge with constant 8
            labelLeadingConstraint?.isActive = false
            editTextViewLeadingConstraint?.isActive = false
            
            labelLeadingConstraint = actionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8)
            editTextViewLeadingConstraint = editTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8)
            
            labelLeadingConstraint?.isActive = true
            editTextViewLeadingConstraint?.isActive = true
            
            // Remove strikethrough and make text normal
            actionLabel.attributedText = NSAttributedString(
                string: action,
                attributes: [
                    .foregroundColor: UIColor.label,
                    .font: UIFont.bodyXL
                ]
            )
        } else {
            // In normal mode, show checkbox and update appearance based on completion
            checkboxButton.isHidden = false
            
            // Re-enable tap gesture for editing text (only if not read-only)
            actionLabel.isUserInteractionEnabled = !isReadOnly
            
            // Restore original constraints relative to checkbox
            labelLeadingConstraint?.isActive = false
            editTextViewLeadingConstraint?.isActive = false
            
            labelLeadingConstraint = actionLabel.leadingAnchor.constraint(equalTo: checkboxButton.trailingAnchor, constant: 8)
            editTextViewLeadingConstraint = editTextView.leadingAnchor.constraint(equalTo: checkboxButton.trailingAnchor, constant: 8)
            
            labelLeadingConstraint?.isActive = true
            editTextViewLeadingConstraint?.isActive = true
            
            updateCheckboxAppearance(isCompleted: isCompleted)
            updateLabelAppearance(isCompleted: isCompleted)
        }
    }
    
    private func setEditingMode(_ editing: Bool) {
        isEditingMode = editing
        
        if editing {
            actionLabel.isHidden = true
            editTextView.isHidden = false
            editTextView.text = action
            editTextView.becomeFirstResponder()
        } else {
            actionLabel.isHidden = false
            editTextView.isHidden = true
            editTextView.resignFirstResponder()
        }
    }
    
    private func updateCheckboxAppearance(isCompleted: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        
        if isCompleted {
            let image = UIImage(systemName: "checkmark.square.fill", withConfiguration: config)
            checkboxButton.setImage(image, for: .normal)
            checkboxButton.tintColor = .tertiaryLabel
        } else {
            let image = UIImage(systemName: "square", withConfiguration: config)
            checkboxButton.setImage(image, for: .normal)
            checkboxButton.tintColor = .tertiaryLabel
        }
    }
    
    private func updateLabelAppearance(isCompleted: Bool) {
        if isCompleted {
            let attributedText = NSAttributedString(
                string: action,
                attributes: [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: UIColor.tertiaryLabel,
                    .font: UIFont.bodyXL
                ]
            )
            actionLabel.attributedText = attributedText
        } else {
            actionLabel.attributedText = NSAttributedString(
                string: action,
                attributes: [
                    .foregroundColor: UIColor.label,
                    .font: UIFont.bodyXL
                ]
            )
        }
    }
    
    @objc private func checkboxTapped() {
        // Only handle completion toggle (checkbox should be hidden in edit mode anyway)
        let newState = !isCompleted
        self.isCompleted = newState
        
        updateCheckboxAppearance(isCompleted: newState)
        updateLabelAppearance(isCompleted: newState)
        
        delegate?.routineActionCell(self, didToggleCompletion: newState)
        
        // Add haptic feedback
        HapticsHelper.lightHaptic()
    }
    
    
    @objc private func handleLabelTap(_ gesture: UITapGestureRecognizer) {
        guard !isReadOnly else { return }
        setEditingMode(true)
    }
}

// MARK: - UITextViewDelegate
extension RoutineActionCell: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        // Auto-resize the table view cell with smoother animation
        if let tableView = superview as? UITableView {
            UIView.performWithoutAnimation {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        guard let newText = textView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !newText.isEmpty,
              let indexPath = indexPath else {
            // If empty or invalid, revert to original text
            setEditingMode(false)
            return
        }
        
        // Update the action and notify delegate
        action = newText
        actionLabel.text = newText
        setEditingMode(false)
        
        delegate?.routineActionCell(self, didUpdateAction: newText, at: indexPath)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Handle return key to finish editing
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}
