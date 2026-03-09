//
//  NestCell.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//

import UIKit

class NestCell: UICollectionViewCell {
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let imageView = UIImageView()
    private let textStackView = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        configureSelectionBehavior()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Configure title label
        titleLabel.font = .h3
        
        // Configure subtitle label
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail
        
        // Configure image view
        imageView.contentMode = .scaleAspectFit
        
        // Configure stack view
        textStackView.axis = .vertical
        textStackView.spacing = 2
        textStackView.alignment = .leading
        textStackView.distribution = .fill
        
        // Add labels to stack view
        textStackView.addArrangedSubview(titleLabel)
        textStackView.addArrangedSubview(subtitleLabel)
        
        // Add subviews
        contentView.addSubview(textStackView)
        contentView.addSubview(imageView)
        
        // Disable autoresizing masks
        textStackView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Image view constraints - center right
            imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            imageView.widthAnchor.constraint(equalToConstant: 72),
            imageView.heightAnchor.constraint(equalToConstant: 72),
            
            // Stack view constraints - center left, vertically centered
            textStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textStackView.trailingAnchor.constraint(lessThanOrEqualTo: imageView.leadingAnchor, constant: -12),
            textStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Update corner radius when traits change (e.g., dark/light mode)
        selectedBackgroundView?.layer.cornerRadius = 12
    }
    
    func configure(with title: String, subtitle: String, image: UIImage?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        imageView.image = image
    }
}

extension UICollectionViewCell {
    
    func configureSelectionBehavior(with color: UIColor = UIColor.systemGray4) {
        // Create a view for the selected state
        let selectedBgView = UIView()
        selectedBgView.backgroundColor = color
        selectedBgView.layer.masksToBounds = true
        
        // Set the selected background view
        selectedBackgroundView = selectedBgView
        
        // Enable user interaction
        isUserInteractionEnabled = true
    }
    
}
