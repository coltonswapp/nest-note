//
//  EventsCell.swift
//  nest-note
//
//  Created by Colton Swapp on 1/31/25.
//

import UIKit

protocol EventsCellDelegate: AnyObject {
    func eventsCellDidTapPlusButton(_ cell: EventsCell)
}

final class EventsCell: UICollectionViewListCell {
    weak var delegate: EventsCellDelegate?
    
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
    
    // Add activity indicator
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
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
        contentView.addSubview(loadingIndicator)
        
        // Setup plus button target
        plusButton.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: plusButton.leadingAnchor, constant: -8),
            
            plusButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            plusButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: 28),
            plusButton.heightAnchor.constraint(equalToConstant: 28),
            
            eventCountLabel.trailingAnchor.constraint(equalTo: plusButton.leadingAnchor, constant: -8),
            eventCountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            // Add loading indicator constraints, put it where the plus button is
            loadingIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            contentView.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    func configure(eventCount: Int, showPlusButton: Bool = true) {
        loadingIndicator.stopAnimating()
        isUserInteractionEnabled = true
        
        // Always show the plus button when showPlusButton is true
        plusButton.isHidden = !showPlusButton
        plusButton.isUserInteractionEnabled = showPlusButton
        
        // Update title label to show count if there are events
        if eventCount > 0 {
            titleLabel.text = "Events (\(eventCount))"
            eventCountLabel.isHidden = true
        } else {
            titleLabel.text = "Events"
            eventCountLabel.isHidden = true
        }
    }
    
    // Add a specific method for upcoming events
    func configureUpcoming(eventCount: Int, showPlusButton: Bool = true) {
        loadingIndicator.stopAnimating()
        isUserInteractionEnabled = true
        
        if showPlusButton {
            plusButton.isHidden = eventCount > 0
            eventCountLabel.isHidden = eventCount == 0
        } else {
            plusButton.isHidden = true
            eventCountLabel.isHidden = false
        }
        
        if eventCount == 0 {
            eventCountLabel.text = "No upcoming events"
        } else {
            eventCountLabel.text = "\(eventCount) upcoming"
        }
    }
    
    // Add method to show loading state
    func showLoading() {
        plusButton.isHidden = true
        eventCountLabel.isHidden = true
        loadingIndicator.startAnimating()
        isUserInteractionEnabled = false
    }
    
    @objc private func plusButtonTapped() {
        delegate?.eventsCellDidTapPlusButton(self)
    }
} 
