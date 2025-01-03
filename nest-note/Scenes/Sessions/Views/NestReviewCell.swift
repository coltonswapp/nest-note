//
//  NestReviewCell.swift
//  nest-note
//
//  Created by Colton Swapp on 12/31/24.
//

import UIKit

final class NestReviewCell: UICollectionViewListCell {
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.contentMode = .scaleAspectFit
    
    // Create configuration with hierarchical rendering
    let symbolConfig = UIImage.SymbolConfiguration(weight: .semibold)
        .applying(UIImage.SymbolConfiguration(hierarchicalColor: NNColors.primary))
    
    // Create image with hierarchical rendering mode
    let image = UIImage(systemName: "rectangle.and.hand.point.up.left.fill", withConfiguration: symbolConfig)
    
    imageView.image = image
    return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Nest Review"
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private lazy var reviewButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(
            title: "Review Nest",
            backgroundColor: NNColors.primary.withAlphaComponent(0.15),
            foregroundColor: NNColors.primary
        )
        var container = AttributeContainer()
        container.font = .systemFont(ofSize: 16, weight: .bold)
        button.configuration?.attributedTitle = AttributedString("Review Nest", attributes: container)
        return button
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
        contentView.addSubview(reviewButton)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            reviewButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            reviewButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            reviewButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            reviewButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func configure(itemCount: Int) {
        reviewButton.setTitle(title: "Review \(itemCount) items")
    }
}
