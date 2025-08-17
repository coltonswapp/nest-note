//
//  NNSectionHeaderView.swift
//  nest-note
//
//  Created by Colton Swapp on 11/2/24.
//

import UIKit

class NNSectionHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "NNSectionHeaderView"
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .captionBoldS
        label.textColor = .secondaryLabel
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func configure(title: String) {
        titleLabel.text = title.uppercased()
    }
} 
