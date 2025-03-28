//
//  EventsCell.swift
//  nest-note
//
//  Created by Colton Swapp on 1/31/25.
//

import UIKit

final class EventsCell: UICollectionViewListCell {
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        
        let symbolConfig = UIImage.SymbolConfiguration(weight: .semibold)
            .applying(UIImage.SymbolConfiguration(hierarchicalColor: NNColors.primary))
        
        let image = UIImage(systemName: "calendar.badge.plus", withConfiguration: symbolConfig)
        
        imageView.image = image
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Events"
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let plusButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let symbolConfig = UIImage.SymbolConfiguration(weight: .regular)
        let image = UIImage(systemName: "plus", withConfiguration: symbolConfig)?
            .withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
        
        button.setImage(image, for: .normal)
        return button
    }()
    
    private let eventCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(plusButton)
        contentView.addSubview(eventCountLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            plusButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            plusButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: 28),
            plusButton.heightAnchor.constraint(equalToConstant: 28),
            
            eventCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            eventCountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    
    func configure(eventCount: Int) {
        plusButton.isHidden = eventCount > 0
        eventCountLabel.isHidden = eventCount == 0
        
        if eventCount > 0 {
            let inflectedString = String(AttributedString(
                localized: "^[\(eventCount) \("event")](inflect: true)"
            ).characters)
            eventCountLabel.text = inflectedString
        }
    }
} 
