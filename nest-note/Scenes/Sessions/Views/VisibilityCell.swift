//
//  VisibilityCell.swift
//  nest-note
//
//  Created by Colton Swapp on 12/31/24.
//

import UIKit

final class VisibilityCell: UICollectionViewListCell {
    weak var delegate: VisibilityCellDelegate?
    private var currentLevel: VisibilityLevel = .standard
    private var isReadOnly: Bool = false
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = NNColors.primary
        
        let symbolConfig = UIImage.SymbolConfiguration(weight: .semibold)
        imageView.image = UIImage(systemName: "eye.fill", withConfiguration: symbolConfig)
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Visibility"
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private lazy var visibilityButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(
            title: "Test",
            image: nil,
            backgroundColor: NNColors.primary.withAlphaComponent(0.15),
            foregroundColor: NNColors.primary
        )
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
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
        contentView.addSubview(visibilityButton)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            visibilityButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            visibilityButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            visibilityButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            visibilityButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func configure(with level: VisibilityLevel, isReadOnly: Bool = false) {
        self.currentLevel = level
        self.isReadOnly = isReadOnly
        
        var container = AttributeContainer()
        container.font = UIFont.boldSystemFont(ofSize: 16)
        visibilityButton.configuration?.attributedTitle = AttributedString(level.title, attributes: container)
        
        // Configure button based on read-only state
        if isReadOnly {
            visibilityButton.configureButton(
                title: level.title,
                image: UIImage(systemName: "lock.circle.fill"),
                imagePlacement: .right,
                foregroundColor: NNColors.primary
            )
            visibilityButton.isUserInteractionEnabled = true
        } else {
            visibilityButton.configureButton(
                title: level.title,
                image: UIImage(systemName: "chevron.up.chevron.down"),
                imagePlacement: .right,
                foregroundColor: NNColors.primary
            )
            visibilityButton.isUserInteractionEnabled = true
            setupVisibilityMenu(selectedLevel: level)
        }
    }
    
    private func setupVisibilityMenu(selectedLevel: VisibilityLevel) {
        // Only setup menu if not in read-only mode
        guard !isReadOnly else { return }
        
        let infoAction = UIAction(title: "Learn about Levels", image: UIImage(systemName: "info.circle")) { [weak self] _ in
            self?.delegate?.didRequestVisibilityLevelInfo()
        }
        
        let visibilityActions = VisibilityLevel.allCases.map { level in
            UIAction(
                title: level.title,
                state: level == selectedLevel ? .on : .off
            ) { [weak self] _ in
                guard let self = self else { return }
                HapticsHelper.lightHaptic()
                self.currentLevel = level
                
                // Update button title
                var container = AttributeContainer()
                container.font = UIFont.boldSystemFont(ofSize: 16)
                self.visibilityButton.configuration?.attributedTitle = AttributedString(level.title, attributes: container)    
                
                // Notify delegate
                self.delegate?.didChangeVisibilityLevel(level)
                
                // Recreate menu with updated state
                self.setupVisibilityMenu(selectedLevel: level)
            }
        }
        
        let visibilitySection = UIMenu(title: "Select Visibility", options: .displayInline, children: visibilityActions)
        let infoSection = UIMenu(title: "What level is right for me?", options: .displayInline, children: [infoAction])
        
        visibilityButton.menu = UIMenu(children: [visibilitySection, infoSection])
        visibilityButton.showsMenuAsPrimaryAction = true
    }
}
