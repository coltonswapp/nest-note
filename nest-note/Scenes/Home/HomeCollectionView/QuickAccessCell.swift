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
        label.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
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
    
    func configure(with title: String, image: UIImage?) {
        label.text = title
        imageView.image = image
    }
}
