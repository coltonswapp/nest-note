//
//  NestNameCell.swift
//  nest-note
//
//  Created by Colton Swapp on 3/10/25.
//

import UIKit

final class NestNameCell: UICollectionViewCell {
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = NNColors.primary
        
        let symbolConfig = UIImage.SymbolConfiguration(weight: .semibold)
        imageView.image = UIImage(systemName: "bird.fill", withConfiguration: symbolConfig)
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Nest"
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let nestNameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Smith"
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .right
        label.textColor = .secondaryLabel
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
        backgroundColor = .secondarySystemGroupedBackground
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(nestNameLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            nestNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nestNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            nestNameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            nestNameLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func configure(with nestName: String) {
        nestNameLabel.text = nestName
    }
}
