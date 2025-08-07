//
//  AddRoutineActionCell.swift
//  nest-note
//
//  Created by Claude on 2/4/25.
//

import UIKit

protocol AddRoutineActionCellDelegate: AnyObject {
    func addRoutineActionCell(_ cell: AddRoutineActionCell, didAddAction action: String)
}

class AddRoutineActionCell: UITableViewCell {
    
    weak var delegate: AddRoutineActionCellDelegate?
    
    private lazy var plusIcon: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = UIImage(systemName: "plus", withConfiguration: config)
        imageView.image = image
        imageView.tintColor = .tertiaryLabel
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var textView: UITextView = {
        let textView = UITextView()
        textView.font = .bodyXL
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets.zero
        textView.textContainer.lineFragmentPadding = 0
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.returnKeyType = .done
        return textView
    }()
    
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Add routine item"
        label.font = .bodyXL
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
        
        contentView.addSubview(plusIcon)
        contentView.addSubview(textView)
        contentView.addSubview(placeholderLabel)
        
        NSLayoutConstraint.activate([
            // Plus icon - aligned with text top
            plusIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            plusIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            plusIcon.widthAnchor.constraint(equalToConstant: 20),
            plusIcon.heightAnchor.constraint(equalToConstant: 20),
            
            // Text view
            textView.leadingAnchor.constraint(equalTo: plusIcon.trailingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            
            // Placeholder label
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor),
        ])
        
        // Add tap gesture to focus text view when tapping the cell
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cellTapped))
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func cellTapped() {
        textView.becomeFirstResponder()
    }
    
    private func addAction() {
        guard let text = textView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return
        }
        
        delegate?.addRoutineActionCell(self, didAddAction: text)
        textView.text = ""
        placeholderLabel.isHidden = false
        
        // Keep the text view focused for rapid-fire adding
        // The text view will lose focus automatically if this cell gets removed (10th item)
        
        // Scroll to keep this cell visible after the table view updates
        if let tableView = superview as? UITableView,
           let indexPath = tableView.indexPath(for: self) {
            DispatchQueue.main.async {
                // Use a slight delay to ensure the table view update is complete
                tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
        
        HapticsHelper.lightHaptic()
    }
}

// MARK: - UITextViewDelegate
extension AddRoutineActionCell: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        
        // Auto-resize the table view cell with smoother animation
        if let tableView = superview as? UITableView {
            UIView.performWithoutAnimation {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
            
            // Smoothly scroll to keep this cell visible when it grows
            if let indexPath = tableView.indexPath(for: self) {
                DispatchQueue.main.async {
                    tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
                }
            }
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        
        // Scroll to show the cell when editing begins - with delay to ensure keyboard is shown
        if let tableView = superview as? UITableView,
           let indexPath = tableView.indexPath(for: self) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Handle return key to add the action
        if text == "\n" {
            addAction()
            return false
        }
        return true
    }
}
