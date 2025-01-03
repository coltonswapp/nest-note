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

        keyLabel.font = UIFont.systemFont(ofSize: 12)
        keyLabel.textColor = .secondaryLabel
        
        valueContainer.clipsToBounds = true
        valueContainer.backgroundColor = NNColors.groupedBackground
        valueContainer.layer.cornerRadius = 10
        
        // Update border color initially
        updateBorderColor()
        
        valueLabel.font = UIFont.systemFont(ofSize: 22)
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 1
    }
    
    // Add this method to update border color
    private func updateBorderColor() {
//        valueContainer.layer.borderColor = UIColor.secondarySystemBackground.cgColor
    }
    
    // Add this override to handle theme changes
//    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
//        super.traitCollectionDidChange(previousTraitCollection)
//        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
//            updateBorderColor()
//        }
//    }
    
    func configure(key: String, value: String) {
        keyLabel.text = key
        valueLabel.text = value
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.valueContainer.backgroundColor = self.isHighlighted ? .systemGray4 : NNColors.groupedBackground
            }
        }
    }
    
    func flash() {
        UIView.animate(withDuration: 0.3, animations: {
            self.valueContainer.backgroundColor = NNColors.primary.withAlphaComponent(0.3)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.valueContainer.backgroundColor = NNColors.groupedBackground
            }
        }
    }
}
