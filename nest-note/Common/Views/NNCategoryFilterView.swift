import UIKit

protocol NNCategoryFilterViewDelegate: AnyObject {
    func categoryFilterView(_ filterView: NNCategoryFilterView, didUpdateEnabledSections sections: Set<NestCategoryViewController.Section>)
}

class NNCategoryFilterView: UIView {
    weak var delegate: NNCategoryFilterViewDelegate?
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDataSource?
    
    private var availableSections: [NestCategoryViewController.Section] = []
    private var enabledSections: Set<NestCategoryViewController.Section> = [] {
        didSet {
            delegate?.categoryFilterView(self, didUpdateEnabledSections: enabledSections)
        }
    }
    
    private var isAllSelected: Bool = true {
        didSet {
            collectionView.reloadData()
        }
    }
    
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
        
        collectionView.register(CategoryFilterCell.self, forCellWithReuseIdentifier: CategoryFilterCell.reuseIdentifier)
        
        addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(with sections: [NestCategoryViewController.Section]) {
        availableSections = sections
        enabledSections = Set(sections)
        
        // If there's only one section, disable interaction and don't show "ALL"
        isInteractionDisabled = sections.count == 1
        isAllSelected = sections.count > 1  // Only show "ALL" when there are multiple sections
        
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
    
    private func selectAll() {
        isAllSelected = true
        enabledSections = Set(availableSections)
        HapticsHelper.lightHaptic()
    }
    
    private func toggleSection(_ section: NestCategoryViewController.Section) {
        if isAllSelected {
            // If ALL is currently selected, switch to individual selection mode with just this section
            isAllSelected = false
            enabledSections = [section]
        } else {
            // Normal toggle behavior when already in individual selection mode
            if enabledSections.contains(section) {
                enabledSections.remove(section)
            } else {
                enabledSections.insert(section)
            }
        }
        
        HapticsHelper.lightHaptic()
    }
}

extension NNCategoryFilterView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isInteractionDisabled {
            // Single section: show only that section's button (no "ALL" button)
            return availableSections.count
        } else {
            // Multiple sections: show "ALL" button + section buttons
            return availableSections.count + 1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CategoryFilterCell.reuseIdentifier,
            for: indexPath
        ) as! CategoryFilterCell
        
        if isInteractionDisabled {
            // Single section: show only that section's button, always enabled
            let section = availableSections[indexPath.item]
            cell.configure(title: section.displayTitle, isEnabled: true, isInteractionDisabled: true)
        } else {
            // Multiple sections: show "ALL" + section buttons with normal logic
            if indexPath.item == 0 {
                // "ALL" button - only highlighted when ALL is selected
                cell.configure(title: "All", isEnabled: isAllSelected, isInteractionDisabled: false)
            } else {
                // Regular section buttons - only highlighted when ALL is NOT selected and they're in enabledSections
                let section = availableSections[indexPath.item - 1]
                let isEnabled = !isAllSelected && enabledSections.contains(section)
                
                cell.configure(title: section.displayTitle, isEnabled: isEnabled, isInteractionDisabled: false)
            }
        }
        
        return cell
    }
}

extension NNCategoryFilterView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        // Don't handle taps when interaction is disabled (single section mode)
        guard !isInteractionDisabled else { return }
        
        if indexPath.item == 0 {
            selectAll()
        } else {
            // Tapped regular section button
            guard indexPath.item - 1 < availableSections.count else {
                return 
            }
            
            let section = availableSections[indexPath.item - 1]
            toggleSection(section)
        }
    }
}

private class CategoryFilterCell: UICollectionViewCell {
    static let reuseIdentifier = "CategoryFilterCell"

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
        // Leave contentView.translatesAutoresizingMaskIntoConstraints = true for cell autosizing
        
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

extension NestCategoryViewController.Section {
    var displayTitle: String {
        switch self {
        case .folders: return "Folders"
        case .codes: return "Entries"
        case .other: return "Entries"
        case .places: return "Places"
        case .routines: return "Routines"
        }
    }
}
