//
//  NNGenericFilterView.swift
//  nest-note
//
//  Created by Claude Code on 8/9/25.
//

import UIKit

protocol NNFilterableSection {
    var displayTitle: String { get }
}

protocol NNGenericFilterViewDelegate: AnyObject {
    func genericFilterView<T: NNFilterableSection>(_ filterView: NNGenericFilterView<T>, didSelectSection section: T)
}

class NNGenericFilterView<SectionType: NNFilterableSection & Hashable>: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    weak var delegate: NNGenericFilterViewDelegate?
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDataSource?
    
    private var availableSections: [SectionType] = []
    private var selectedSection: SectionType?
    
    private var isInteractionDisabled: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCollectionView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        
        collectionView = UICollectionView(frame: bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        collectionView.register(GenericFilterCell.self, forCellWithReuseIdentifier: GenericFilterCell.reuseIdentifier)
        
        addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(with sections: [SectionType]) {
        availableSections = sections
        
        // If there's only one section, disable interaction
        isInteractionDisabled = sections.count == 1
        
        // Set first section as selected by default
        if !sections.isEmpty {
            selectedSection = sections.first
        }
        
        collectionView.reloadData()
    }
    
    func updateDisplayedState() {
        // Just reload the collection view - no state changes
        collectionView.reloadData()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Update colors when switching between light and dark mode
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            collectionView.reloadData()
        }
    }
    
    
    private func selectSection(_ section: SectionType) {
        selectedSection = section
        delegate?.genericFilterView(self, didSelectSection: section)
        HapticsHelper.lightHaptic()
    }
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Always show only section buttons (no "ALL" button)
        return availableSections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GenericFilterCell.reuseIdentifier,
            for: indexPath
        ) as! GenericFilterCell
        
        let section = availableSections[indexPath.item]
        
        if isInteractionDisabled {
            // Single section: show only that section's button, always enabled
            cell.configure(title: section.displayTitle, isEnabled: true, isInteractionDisabled: true)
        } else {
            // Multiple sections: show section buttons, highlight the selected one
            let isEnabled = selectedSection == section
            cell.configure(title: section.displayTitle, isEnabled: isEnabled, isInteractionDisabled: false)
        }
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        // Don't handle taps when interaction is disabled (single section mode)
        guard !isInteractionDisabled else { return }
        
        guard indexPath.item < availableSections.count else { return }
        
        let section = availableSections[indexPath.item]
        selectSection(section)
    }
}

private class GenericFilterCell: UICollectionViewCell {
    static let reuseIdentifier = "GenericFilterCell"

    private let titleLabel = UILabel()
    private var isEnabled: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.layer.cornerRadius = 16
        contentView.layer.borderWidth = 1.5
        
        titleLabel.font = .h5
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(title: String, isEnabled: Bool, isInteractionDisabled: Bool = false) {
        titleLabel.text = title
        self.isEnabled = isEnabled
        
        // Disable user interaction if specified (for single section mode)
        self.isUserInteractionEnabled = !isInteractionDisabled
        
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            if isEnabled {
                self.contentView.backgroundColor = NNColors.primaryOpaque
                self.contentView.layer.borderColor = NNColors.primary.cgColor
                self.titleLabel.textColor = NNColors.primary
            } else {
                self.contentView.backgroundColor = NNColors.NNSystemBackground4.withAlphaComponent(0.5)
                self.contentView.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.3).cgColor
                self.titleLabel.textColor = .tertiaryLabel
            }
            
            // Visual indicator for disabled interaction (slightly more transparent)
            if isInteractionDisabled {
                self.contentView.alpha = 0.8
            } else {
                self.contentView.alpha = 1.0
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Update colors when switching between light and dark mode
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Re-apply current state to update colors
            if let text = titleLabel.text {
                let isInteractionDisabled = !isUserInteractionEnabled
                configure(title: text, isEnabled: isEnabled, isInteractionDisabled: isInteractionDisabled)
            }
        }
    }
}