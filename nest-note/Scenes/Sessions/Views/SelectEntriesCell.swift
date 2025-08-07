//
//  SelectEntriesCell.swift
//  nest-note
//
//  Created by Colton Swapp on 1/29/25
//

import UIKit

//protocol SelectEntriesCellDelegate: AnyObject {
//    func selectEntriesCellDidTapButton(_ cell: SelectEntriesCell)
//}

final class SelectEntriesCell: UICollectionViewListCell {
    weak var delegate: SelectEntriesCellDelegate?
    private var selectedCount: Int = 0
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = NNColors.primary
        
        let symbolConfig = UIImage.SymbolConfiguration(weight: .semibold)
        imageView.image = UIImage(systemName: "rectangle.fill.on.rectangle.angled.fill", withConfiguration: symbolConfig)
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Select Items"
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private lazy var selectButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(
            title: "0 items",
            image: nil,
            backgroundColor: NNColors.primary.withAlphaComponent(0.15),
            foregroundColor: NNColors.primary
        )
        button.titleLabel?.font = .h4
        button.addTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
        return button
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
        contentView.addSubview(selectButton)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            selectButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            selectButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            selectButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            selectButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func configure(with selectedCount: Int) {
        self.selectedCount = selectedCount
        
        let itemText = selectedCount == 1 ? "item" : "items"
        let buttonTitle = "\(selectedCount) \(itemText)"
        
        var container = AttributeContainer()
        container.font = .h4
        selectButton.configuration?.attributedTitle = AttributedString(buttonTitle, attributes: container)
        
        selectButton.configureButton(
            title: buttonTitle,
            image: UIImage(systemName: "chevron.right"),
            imagePlacement: .right,
            foregroundColor: NNColors.primary
        )
    }
    
    @objc private func selectButtonTapped() {
        delegate?.selectEntriesCellDidTapButton(self)
    }
}
