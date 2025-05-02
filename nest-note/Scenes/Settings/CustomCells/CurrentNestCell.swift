//
//  CurrentNestCell.swift
//  nest-note
//
//  Created by Colton Swapp on 11/9/24.
//
import UIKit

class CurrentNestCell: UICollectionViewCell {
    private let nameLabel = UILabel()
    private let addressLabel = UILabel()
    private let chevronImageView = UIImageView()
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.backgroundColor = self.isHighlighted ? .systemGray4 : .secondarySystemGroupedBackground
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 12
        layer.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Set up the chevron image view
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        chevronImageView.image = UIImage(systemName: "chevron.up.chevron.down", withConfiguration: config)
        chevronImageView.tintColor = .systemGray3
        chevronImageView.contentMode = .scaleAspectFit
        
        NSLayoutConstraint.activate([
            chevronImageView.widthAnchor.constraint(equalToConstant: 24),
            chevronImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Set up the vertical stack view for labels
        let labelStackView = UIStackView(arrangedSubviews: [nameLabel, addressLabel])
        labelStackView.axis = .vertical
        labelStackView.spacing = 4
        
        // Set up the horizontal stack view
        let horizontalStackView = UIStackView(arrangedSubviews: [labelStackView, chevronImageView])
        horizontalStackView.axis = .horizontal
        horizontalStackView.spacing = 24
        horizontalStackView.alignment = .center
        
        contentView.addSubview(horizontalStackView)
        horizontalStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            horizontalStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            horizontalStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            horizontalStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            horizontalStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
        
        nameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        addressLabel.font = UIFont.preferredFont(forTextStyle: .body)
        addressLabel.textColor = .secondaryLabel
    }
    
    func configure(name: String, address: String, isNoNest: Bool = false) {
        nameLabel.text = name
        addressLabel.text = address
        
        if isNoNest {
            // Style for "no nest" state
            addressLabel.textColor = NNColors.primary
            addressLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
            chevronImageView.image = UIImage(systemName: "arrow.up.right")
        } else {
            // Normal style
            addressLabel.textColor = .secondaryLabel
            addressLabel.font = UIFont.preferredFont(forTextStyle: .body)
        }
    }
}
