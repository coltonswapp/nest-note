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
    
    var valueContainerBackgroundColor: UIColor = NNColors.groupedBackground
    var valueLabelBackgroundColor: UIColor = .label
    
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
        
        containerView.clipsToBounds = true
        containerView.backgroundColor = valueContainerBackgroundColor
        containerView.layer.cornerRadius = 10

        keyLabel.font = .bodyM
        keyLabel.textColor = .secondaryLabel

        valueLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        valueLabel.textColor = valueLabelBackgroundColor
        valueLabel.numberOfLines = 2
    }
    
    func configure(key: String, value: String, entryVisibility: VisibilityLevel, sessionVisibility: VisibilityLevel) {
        keyLabel.text = key
        
        // Show actual value or asterisks based on access level
        if sessionVisibility.hasAccess(to: entryVisibility) {
            valueLabel.text = value
        } else {
            // For full width cells, we'll show multiple lines of asterisks to indicate more content
            valueLabel.text = "********"
        }
        
        valueLabel.textColor = valueLabelBackgroundColor
        containerView.backgroundColor = valueContainerBackgroundColor
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
