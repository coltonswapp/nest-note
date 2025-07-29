//
//  FullWidthCell.swift
//  nest-note
//
//  Created by Colton Swapp on 11/12/24.
//
import UIKit

class FullWidthCell: UICollectionViewCell {
    static let reuseIdentifier = String(describing: FullWidthCell.self)
    
    private let containerView = UIView()
    private let keyLabel = UILabel()
    private let valueLabel = UILabel()
    private let checkmarkImageView = UIImageView()
    
    var valueContainerBackgroundColor: UIColor = NNColors.groupedBackground
    var valueLabelBackgroundColor: UIColor = .label
    private var isInEditMode: Bool = false
    private var isEntrySelected: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(containerView)
        containerView.addSubview(keyLabel)
        containerView.addSubview(valueLabel)
        containerView.addSubview(checkmarkImageView)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keyLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            keyLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            keyLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12)
        ])

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueLabel.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            valueLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
        
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            checkmarkImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            checkmarkImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 20),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        containerView.clipsToBounds = true
        containerView.backgroundColor = valueContainerBackgroundColor
        containerView.layer.cornerRadius = 10

        keyLabel.font = .bodyM
        keyLabel.textColor = .secondaryLabel

        valueLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        valueLabel.textColor = valueLabelBackgroundColor
        valueLabel.numberOfLines = 2
        
        // Setup checkmark image view
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.tintColor = NNColors.primary
        checkmarkImageView.isHidden = true
    }
    
    func configure(key: String, value: String, entryVisibility: VisibilityLevel, sessionVisibility: VisibilityLevel, isNestOwner: Bool = false, isEditMode: Bool = false, isSelected: Bool = false) {
        keyLabel.text = key
        
        // Show actual value or asterisks based on access level (nest owners bypass all checks)
        if isNestOwner || sessionVisibility.hasAccess(to: entryVisibility) {
            valueLabel.text = value
        } else {
            // For full width cells, we'll show multiple lines of asterisks to indicate more content
            valueLabel.text = "********"
        }
        
        self.isInEditMode = isEditMode
        self.isEntrySelected = isSelected
        
        updateSelectionAppearance()
    }
    
    private func updateSelectionAppearance() {
        if isInEditMode {
            checkmarkImageView.isHidden = false
            checkmarkImageView.image = UIImage(systemName: isEntrySelected ? "checkmark.circle.fill" : "circle")
            checkmarkImageView.tintColor = isEntrySelected ? NNColors.primary : .tertiaryLabel
            
            if isEntrySelected {
                containerView.backgroundColor = NNColors.primary.withAlphaComponent(0.15)
                containerView.layer.borderColor = NNColors.primary.cgColor
                containerView.layer.borderWidth = 1.5
            } else {
                containerView.backgroundColor = valueContainerBackgroundColor
                containerView.layer.borderColor = UIColor.clear.cgColor
                containerView.layer.borderWidth = 0
            }
        } else {
            checkmarkImageView.isHidden = true
            containerView.backgroundColor = valueContainerBackgroundColor
            containerView.layer.borderColor = UIColor.clear.cgColor
            containerView.layer.borderWidth = 0
        }
        
        valueLabel.textColor = valueLabelBackgroundColor
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.containerView.backgroundColor = self.isHighlighted ? .systemGray4 : self.valueContainerBackgroundColor
            }
        }
    }
    
    func flash() {
        UIView.animate(withDuration: 0.3, animations: {
            self.containerView.backgroundColor = NNColors.primary.withAlphaComponent(0.3)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.containerView.backgroundColor = self.valueContainerBackgroundColor
            }
        }
    }
}
