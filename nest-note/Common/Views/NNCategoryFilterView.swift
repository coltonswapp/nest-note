import UIKit

// MARK: - Protocols & Types

protocol NNCategoryFilterOption: Hashable {
    var displayTitle: String { get }
}

protocol NNCategoryFilterViewDelegate: AnyObject {
    func categoryFilterView(_ filterView: NNCategoryFilterView, didUpdateSelection selection: NNCategoryFilterView.Selection)
}

final class NNCategoryFilterView: UIView {
    // MARK: - Selection
    enum Selection {
        case all
        case specific(Set<AnyHashable>)
    }

    // MARK: - Public
    weak var delegate: NNCategoryFilterViewDelegate?

    // MARK: - UI
    private var collectionView: UICollectionView!

    // MARK: - Data
    private struct OptionItem {
        let id: AnyHashable
        let title: String
    }

    private var options: [OptionItem] = []
    private var allowsMultipleSelection: Bool = true
    private var showsAllOption: Bool = true
    private var isConfiguring: Bool = false
    private var activeOptionIds: Set<AnyHashable> = [] {
        didSet {
            // Avoid partial reloads while reconfiguring the option set (item count may change)
            if isConfiguring {
                return
            }
            // Reload visible items to animate state change smoothly
            let visible = collectionView?.indexPathsForVisibleItems ?? []
            if !visible.isEmpty {
                collectionView?.reloadItems(at: visible)
            } else {
                collectionView?.reloadData()
            }
            notifyDelegate()
        }
    }

    // Tracks whether the All chip is explicitly active
    private var isAllChipActive: Bool = false

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCollectionView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration
    func configure<T: NNCategoryFilterOption>(
        with options: [T],
        allowsMultipleSelection: Bool = true,
        showsAllOption: Bool? = nil,
        defaultSelection: T? = nil
    ) {
        isConfiguring = true
        self.options = options.map { OptionItem(id: AnyHashable($0), title: $0.displayTitle) }
        self.allowsMultipleSelection = allowsMultipleSelection
        self.showsAllOption = showsAllOption ?? allowsMultipleSelection

        if allowsMultipleSelection {
            // Default to All selected when multi-select and All is shown
            if self.showsAllOption {
                isAllChipActive = true
                activeOptionIds = Set(self.options.map { $0.id })
            } else {
                // No "All" chip shown; start with empty set and wait for user input
                isAllChipActive = false
                activeOptionIds = []
            }
        } else {
            // Single-select must always have one selected
            let initial = defaultSelection ?? options.first
            if let initial = initial {
                isAllChipActive = false
                activeOptionIds = [AnyHashable(initial)]
            } else {
                isAllChipActive = false
                activeOptionIds = []
            }
        }

        collectionView.reloadData()
        isConfiguring = false
        // After configuration is complete, notify delegate of the initial selection state
        notifyDelegate()
    }

    func updateDisplayedState() {
        collectionView.reloadData()
    }

    // MARK: - Private
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

    private func notifyDelegate() {
        if allowsMultipleSelection && showsAllOption && isAllChipActive {
            delegate?.categoryFilterView(self, didUpdateSelection: .all)
        } else {
            delegate?.categoryFilterView(self, didUpdateSelection: .specific(activeOptionIds))
        }
    }

    private func handleTapOnAll() {
        guard allowsMultipleSelection && showsAllOption else { return }
        // Select All → activate all options and mark All chip active
        isAllChipActive = true
        activeOptionIds = Set(options.map { $0.id })
        HapticsHelper.lightHaptic()
    }

    private func handleTapOnOption(at index: Int) {
        guard index >= 0 && index < options.count else { return }
        let optionId = options[index].id

        if allowsMultipleSelection {
            if isAllChipActive {
                // Transition from All → single specific
                isAllChipActive = false
                activeOptionIds = [optionId]
            } else {
                var next = activeOptionIds
                if next.contains(optionId) {
                    next.remove(optionId)
                } else {
                    next.insert(optionId)
                }
                if next.isEmpty {
                    // Auto-select All when cleared
                    isAllChipActive = true
                    activeOptionIds = Set(options.map { $0.id })
                } else {
                    // If user manually selects all items, keep All chip OFF per requirement
                    isAllChipActive = false
                    activeOptionIds = next
                }
            }
        } else {
            // Enforce exactly one selected
            if !activeOptionIds.contains(optionId) {
                activeOptionIds = [optionId]
            }
        }

        HapticsHelper.lightHaptic()
    }

    // MARK: - Trait changes
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            collectionView.reloadData()
        }
    }
}

// MARK: - UICollectionViewDataSource
extension NNCategoryFilterView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return options.count + (showsAllOption ? 1 : 0)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CategoryFilterCell.reuseIdentifier,
            for: indexPath
        ) as! CategoryFilterCell

        if showsAllOption && indexPath.item == 0 {
            cell.configure(title: "All", isEnabled: isAllChipActive, isInteractionDisabled: false)
            return cell
        }

        let baseIndex = indexPath.item - (showsAllOption ? 1 : 0)
        let option = options[baseIndex]

        let isEnabled: Bool
        if allowsMultipleSelection {
            isEnabled = !isAllChipActive && activeOptionIds.contains(option.id)
        } else {
            isEnabled = activeOptionIds.contains(option.id)
        }

        cell.configure(title: option.title, isEnabled: isEnabled, isInteractionDisabled: false)
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension NNCategoryFilterView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        if showsAllOption && indexPath.item == 0 {
            handleTapOnAll()
        } else {
            let baseIndex = indexPath.item - (showsAllOption ? 1 : 0)
            handleTapOnOption(at: baseIndex)
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
        
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
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

extension NestCategoryViewController.Section: NNCategoryFilterOption {
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
