//
//  AccountCell.swift
//  nest-note
//
//  Created by Colton Swapp on 11/9/24.
//
import UIKit

class AccountCell: UICollectionViewCell {
    private let emailLabel = UILabel()
    private let nameLabel = UILabel()
    private let imageView = UIImageView()
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.backgroundColor = self.isHighlighted ? .systemGray4 : .secondarySystemGroupedBackground
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        configureSelectionBehavior()
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 12
        layer.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Set up the image view
        imageView.image = UIImage(systemName: "bird.fill")
        imageView.tintColor = .systemGray3
//        imageView.backgroundColor = .systemGray4
        imageView.clipsToBounds = true
//        imageView.layer.cornerRadius = 25
        
        // Set up constraints for the image view
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 26),
            imageView.heightAnchor.constraint(equalToConstant: 26)
        ])
        
        // Set up the vertical stack view for labels
        let labelStackView = UIStackView(arrangedSubviews: [nameLabel, emailLabel])
        labelStackView.axis = .vertical
        labelStackView.spacing = 4
        
        // Set up the horizontal stack view
        let horizontalStackView = UIStackView(arrangedSubviews: [imageView, labelStackView])
        horizontalStackView.axis = .horizontal
        horizontalStackView.spacing = 16
        horizontalStackView.alignment = .center
        
        contentView.addSubview(horizontalStackView)
        horizontalStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            horizontalStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            horizontalStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            horizontalStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            horizontalStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
        
        emailLabel.font = UIFont.preferredFont(forTextStyle: .body)
        emailLabel.textColor = .secondaryLabel
        nameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
    }
    
    func configure(email: String, name: String) {
        emailLabel.text = email
        nameLabel.text = name
    }
}
