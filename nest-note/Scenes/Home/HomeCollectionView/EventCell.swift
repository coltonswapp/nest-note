//
//  EventCell.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//

import UIKit

class EventCell: UICollectionViewListCell {
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let statusLabel = UILabel()
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        titleLabel.font = .h4
        titleLabel.numberOfLines = 0
        titleLabel.textColor = .label
        
        dateLabel.textAlignment = .right
        dateLabel.textColor = .secondaryLabel
        statusLabel.textColor = .secondaryLabel
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, statusLabel])
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.alignment = .leading
        
        let mainStackView = UIStackView(arrangedSubviews: [stackView, dateLabel])
        mainStackView.axis = .horizontal
        mainStackView.spacing = 4
        mainStackView.distribution = .fill
        mainStackView.alignment = .center
        
        contentView.addSubview(mainStackView)
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(title: String, time: String, status: String) {
        titleLabel.text = title
        dateLabel.text = time
        statusLabel.text = status
    }
}
