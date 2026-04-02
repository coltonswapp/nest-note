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
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.65
        
        // Setup checkmark image view
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.tintColor = NNColors.primary
        checkmarkImageView.isHidden = true
    }
    
    /// Prefers ASCII digits so formatted phone strings shrink from the numeric length, not punctuation.
    private static func asciiDigitCount(in string: String) -> Int {
        string.reduce(0) { count, ch in
            count + (("0"..."9").contains(ch) ? 1 : 0)
        }
    }
    
    /// Smaller point sizes for longer numbers so half-width cells don’t clip gate codes / phone values.
    private static func valueFont(forDigitCount digits: Int) -> UIFont {
        let size: CGFloat
        switch digits {
        case ...10:
            size = 22
        case 11...12:
            size = 19
        case 13...14:
            size = 17
        case 15...16:
            size = 15
        default:
            size = 14
        }
        return UIFont.systemFont(ofSize: size, weight: .medium)
    }
    
    func configure(key: String, value: String, isNestOwner: Bool = false, isEditMode: Bool = false, isSelected: Bool = false, isModalInPresentation: Bool = false) {
        keyLabel.text = key
        
        valueLabel.text = value
        valueLabel.font = Self.valueFont(forDigitCount: Self.asciiDigitCount(in: value))
        
        self.isInEditMode = isEditMode
        self.isEntrySelected = isSelected
        
        if isModalInPresentation {
            valueContainerBackgroundColor = .secondarySystemBackground
        } else {
            valueContainerBackgroundColor = NNColors.groupedBackground
        }
        
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
