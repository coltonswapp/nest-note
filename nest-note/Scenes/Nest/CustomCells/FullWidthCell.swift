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
            valueLabel.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 2),
            valueLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            valueLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
        
        containerView.clipsToBounds = true
        containerView.backgroundColor = NNColors.groupedBackground
        containerView.layer.cornerRadius = 10

        keyLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        keyLabel.textColor = .secondaryLabel

        valueLabel.font = UIFont.systemFont(ofSize: 17)
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 0
    }
    
    func configure(key: String, value: String) {
        keyLabel.text = key
        valueLabel.text = value
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
