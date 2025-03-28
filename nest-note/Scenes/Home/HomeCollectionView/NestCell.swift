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
        titleLabel.font = UIFont.systemFont(ofSize: 20.0, weight: .bold)
        
        // Configure subtitle label
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2
        subtitleLabel.lineBreakMode = .byTruncatingTail
        
        // Configure image view
        imageView.contentMode = .scaleAspectFit
        
        // Add subviews
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(imageView)
        
        // Disable autoresizing masks
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Image view constraints - top right corner
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            imageView.widthAnchor.constraint(equalToConstant: 100),
            imageView.heightAnchor.constraint(equalToConstant: 100),
            
            // Title label constraints - bottom left
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: imageView.leadingAnchor, constant: -20),
            titleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -4),
            
            // Subtitle label constraints - below title, bottom left
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: imageView.leadingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
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
