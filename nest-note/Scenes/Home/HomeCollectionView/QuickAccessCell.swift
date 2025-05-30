//
//  QuickAccessCell.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//

import UIKit

class QuickAccessCell: UICollectionViewCell {
    private let stackView = UIStackView()
    let imageView = UIImageView()
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        configureSelectionBehavior()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Configure stackView
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        
        // Configure imageView
        imageView.contentMode = .scaleAspectFit
        imageView.widthAnchor.constraint(equalToConstant: 60).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 60).isActive = true
        
        // Configure label
        label.textAlignment = .center
        label.font = .h4
        label.textColor = .label
        
        // Add views to stackView
        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(label)
        
        // Add stackView to contentView
        contentView.addSubview(stackView)
        
        // Setup constraints
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 6),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    private func configureSelectionBehavior() {
        // Create a view for the selected state
        let selectedBgView = UIView()
        selectedBgView.backgroundColor = .systemGray4  // Darker, more noticeable selection
        selectedBgView.layer.cornerRadius = 12
        selectedBgView.layer.masksToBounds = true
        
        // Set the selected background view
        selectedBackgroundView = selectedBgView
        
        // Enable user interaction
        isUserInteractionEnabled = true
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        selectedBackgroundView?.layer.cornerRadius = 12
    }
    
    func configure(with title: String, image: UIImage?) {
        label.text = title
        imageView.image = image
    }
}
