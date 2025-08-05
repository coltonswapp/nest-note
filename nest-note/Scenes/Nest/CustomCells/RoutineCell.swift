//
//  RoutineCell.swift
//  nest-note
//
//  Created by Claude on 2025-01-05.
//

import UIKit

class RoutineCell: UICollectionViewCell {
    static let reuseIdentifier = "RoutineCell"
    
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let checkmarkImageView = UIImageView()
    
    private var isInEditMode: Bool = false
    private var isRoutineSelected: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(containerView)
        
        // Use the same background color and corner radius as FullWidthCell
        containerView.backgroundColor = NNColors.groupedBackground
        containerView.layer.cornerRadius = 18
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create a vertical stack view for the content (similar to FolderCollectionViewCell)
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 4
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentStack)
        
        // Setup icon image view
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .label
        iconImageView.image = UIImage(systemName: "checklist")
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup title label
        titleLabel.font = .h4
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        
        // Setup subtitle label
        subtitleLabel.font = .bodyS
        subtitleLabel.textColor = .secondaryLabel
        
        // Setup checkmark image view
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.tintColor = NNColors.primary
        checkmarkImageView.isHidden = true
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(checkmarkImageView)
        
        // Add views to stack
        contentStack.addArrangedSubview(iconImageView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            // Container view fills the content view
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Content stack positioned in bottom leading corner (like FolderCollectionViewCell)
            contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            // Icon size
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            // Checkmark position (top-right corner like FullWidthCell)
            checkmarkImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            checkmarkImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 20),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with routine: RoutineItem, isEditMode: Bool = false, isSelected: Bool = false) {
        titleLabel.text = routine.title
        
        // Show number of actions in the routine
        let actionCount = routine.routineActions.count
        let actionText = actionCount == 1 ? "action" : "actions"
        subtitleLabel.text = "\(actionCount) \(actionText)"
        
        self.isInEditMode = isEditMode
        self.isRoutineSelected = isSelected
        
        updateSelectionAppearance()
    }
    
    private func updateSelectionAppearance() {
        if isInEditMode {
            checkmarkImageView.isHidden = false
            checkmarkImageView.image = UIImage(systemName: isRoutineSelected ? "checkmark.circle.fill" : "circle")
            checkmarkImageView.tintColor = isRoutineSelected ? NNColors.primary : .tertiaryLabel
            
            if isRoutineSelected {
                containerView.backgroundColor = NNColors.primary.withAlphaComponent(0.15)
                containerView.layer.borderColor = NNColors.primary.cgColor
                containerView.layer.borderWidth = 1.5
            } else {
                containerView.backgroundColor = NNColors.groupedBackground
                containerView.layer.borderColor = UIColor.clear.cgColor
                containerView.layer.borderWidth = 0
            }
        } else {
            checkmarkImageView.isHidden = true
            containerView.backgroundColor = NNColors.groupedBackground
            containerView.layer.borderColor = UIColor.clear.cgColor
            containerView.layer.borderWidth = 0
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.containerView.backgroundColor = self.isHighlighted ? .systemGray4 : NNColors.groupedBackground
            }
        }
    }
    
    func flash() {
        UIView.animate(withDuration: 0.3, animations: {
            self.containerView.backgroundColor = NNColors.primary.withAlphaComponent(0.3)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.containerView.backgroundColor = NNColors.groupedBackground
            }
        }
    }
}