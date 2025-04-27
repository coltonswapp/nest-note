//
//  NestReviewCell.swift
//  nest-note
//
//  Created by Colton Swapp on 12/31/24.
//

import UIKit

final class NestReviewCell: UICollectionViewListCell {
    
    weak var delegate: EntryReviewCellDelegate?
    
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
    
    public lazy var reviewButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(
            title: "Review Nest",
            backgroundColor: NNColors.primary.withAlphaComponent(0.15),
            foregroundColor: NNColors.primary
        )
        var container = AttributeContainer()
        container.font = .systemFont(ofSize: 16, weight: .bold)
        button.configuration?.attributedTitle = AttributedString("Review Nest", attributes: container)
        button.addTarget(self, action: #selector(reviewButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // Add a loading indicator
    public lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
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
        contentView.addSubview(reviewButton)
        contentView.addSubview(loadingIndicator)
        
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
            reviewButton.heightAnchor.constraint(equalToConstant: 40),
            
            loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            loadingIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24)
        ])
    }
    
    func configure(itemCount: Int? = nil) {
        Logger.log(level: .debug, category: .general, message: "NestReviewCell configure called with itemCount: \(String(describing: itemCount))")
        
        if let count = itemCount {
            if count > 0 {
                // Update button title
                reviewButton.setTitle("Review \(count) \(count == 1 ? "item" : "items")", for: .normal)
                reviewButton.backgroundColor = NNColors.primary.withAlphaComponent(0.15)
                reviewButton.tintColor = NNColors.primary
            } else {
                // No outdated entries
                reviewButton.setTitle("Nest up to date", for: .normal)
                reviewButton.backgroundColor = .systemGreen.withAlphaComponent(0.15)
                reviewButton.tintColor = .systemGreen
            }
            
            // Hide loading indicator and show button
            loadingIndicator.stopAnimating()
            reviewButton.isHidden = false
            
            Logger.log(level: .debug, category: .general, message: "NestReviewCell configured with button title: \(reviewButton.titleLabel?.text ?? "nil")")
        } else {
            // Show loading state
            reviewButton.isHidden = true
            loadingIndicator.startAnimating()
            
            Logger.log(level: .debug, category: .general, message: "NestReviewCell showing loading state")
        }
    }
    
    @objc func reviewButtonTapped() {
        delegate?.didTapReview()
    }
    
    // Add a method to explicitly stop loading
    func stopLoading() {
        Logger.log(level: .debug, category: .general, message: "NestReviewCell stopLoading called")
        loadingIndicator.stopAnimating()
        reviewButton.isHidden = false
        reviewButton.setTitle("Review Nest", for: .normal)
    }
}
