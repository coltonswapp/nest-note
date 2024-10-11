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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        titleLabel.font = UIFont.systemFont(ofSize: 20.0, weight: .bold)
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(imageView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: 0),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: -16),
            
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
    
            imageView.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            imageView.heightAnchor.constraint(equalToConstant: 80),
            
            imageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -20),
            imageView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
    }
    
    func configure(with title: String, subtitle: String, image: UIImage?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        imageView.image = image
    }
}
