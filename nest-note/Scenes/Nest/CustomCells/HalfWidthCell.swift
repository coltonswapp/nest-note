//
//  HalfWidthCell.swift
//  nest-note
//
//  Created by Colton Swapp on 11/12/24.
//
import UIKit

class HalfWidthCell: UICollectionViewCell {
    static let reuseIdentifier = "HalfWidthCell"
    
    private let valueContainer = UIView()
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
        contentView.addSubview(valueContainer)
        valueContainer.addSubview(keyLabel)
        valueContainer.addSubview(valueLabel)
        valueContainer.addSubview(checkmarkImageView)
        
        valueContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            valueContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            valueContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            valueContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])

        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keyLabel.topAnchor.constraint(equalTo: valueContainer.topAnchor, constant: 12),
            keyLabel.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor, constant: 12),
            keyLabel.trailingAnchor.constraint(equalTo: valueContainer.trailingAnchor, constant: -12)
        ])

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueLabel.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: valueContainer.trailingAnchor, constant: -12),
            valueLabel.bottomAnchor.constraint(equalTo: valueContainer.bottomAnchor, constant: -16)
        ])
        
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            checkmarkImageView.topAnchor.constraint(equalTo: valueContainer.topAnchor, constant: 8),
            checkmarkImageView.trailingAnchor.constraint(equalTo: valueContainer.trailingAnchor, constant: -8),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 20),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 20)
        ])

        keyLabel.font = .bodyM
        keyLabel.textColor = .secondaryLabel
        
        valueContainer.clipsToBounds = true
        valueContainer.backgroundColor = valueContainerBackgroundColor
        valueContainer.layer.cornerRadius = 10
        
        valueLabel.font = UIFont.systemFont(ofSize: 22, weight: .medium)
        valueLabel.textColor = valueLabelBackgroundColor
        valueLabel.numberOfLines = 1
        
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
            valueLabel.text = "****"
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
                valueContainer.backgroundColor = NNColors.primary.withAlphaComponent(0.15)
                valueContainer.layer.borderColor = NNColors.primary.cgColor
                valueContainer.layer.borderWidth = 1.5
            } else {
                valueContainer.backgroundColor = valueContainerBackgroundColor
                valueContainer.layer.borderColor = UIColor.clear.cgColor
                valueContainer.layer.borderWidth = 0
            }
        } else {
            checkmarkImageView.isHidden = true
            valueContainer.backgroundColor = valueContainerBackgroundColor
            valueContainer.layer.borderColor = UIColor.clear.cgColor
            valueContainer.layer.borderWidth = 0
        }
        
        valueLabel.textColor = valueLabelBackgroundColor
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.valueContainer.backgroundColor = self.isHighlighted ? .systemGray4 : self.valueContainerBackgroundColor
            }
        }
    }
    
    func flash() {
        UIView.animate(withDuration: 0.3, animations: {
            self.valueContainer.backgroundColor = NNColors.primary.withAlphaComponent(0.3)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.valueContainer.backgroundColor = self.valueContainerBackgroundColor
            }
        }
    }
}
