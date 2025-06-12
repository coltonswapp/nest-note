//
//  AppIconCell.swift
//  nest-note
//
//  Created by Colton Swapp on 12/6/24.
//

import UIKit

class AppIconCell: UICollectionViewCell {
    static let reuseIdentifier = "AppIconCell"
    
    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let selectionIndicator = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // Icon image view
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = 12
        iconImageView.layer.masksToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Name label
        nameLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        nameLabel.textAlignment = .center
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Selection indicator
        selectionIndicator.image = UIImage(systemName: "checkmark.circle.fill")
        selectionIndicator.tintColor = NNColors.primary
        selectionIndicator.contentMode = .scaleAspectFit
        selectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        selectionIndicator.isHidden = true
        
        contentView.addSubview(iconImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(selectionIndicator)
        
        NSLayoutConstraint.activate([
            // Icon image view
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            iconImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 60),
            iconImageView.heightAnchor.constraint(equalToConstant: 60),
            
            // Name label
            nameLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // Selection indicator
            selectionIndicator.topAnchor.constraint(equalTo: iconImageView.topAnchor, constant: -4),
            selectionIndicator.trailingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 4),
            selectionIndicator.widthAnchor.constraint(equalToConstant: 20),
            selectionIndicator.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with appIcon: AppIcon) {
        nameLabel.text = appIcon.displayName
        iconImageView.image = UIImage(named: appIcon.previewImageName)
        selectionIndicator.isHidden = !appIcon.isSelected
        
        // Add subtle border for better visual separation
        layer.borderWidth = appIcon.isSelected ? 2 : 0
        layer.borderColor = appIcon.isSelected ? NNColors.primary.cgColor : UIColor.clear.cgColor
        layer.cornerRadius = 8
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = nil
        nameLabel.text = nil
        selectionIndicator.isHidden = true
        layer.borderWidth = 0
    }
}