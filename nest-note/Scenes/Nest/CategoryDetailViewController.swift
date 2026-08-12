import UIKit
import Foundation

protocol CategoryDetailViewControllerDelegate: AnyObject {
    func categoryDetailViewController(_ controller: CategoryDetailViewController, didSaveCategory category: String?, withIcon icon: String?)
}

// MARK: - CategoryIconCell
private final class CategoryIconCell: UICollectionViewCell {
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .tertiaryLabel
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    override var isSelected: Bool {
        didSet {
            backgroundColor = isSelected ? NNColors.primary.withAlphaComponent(0.1) : .clear
            iconImageView.tintColor = isSelected ? NNColors.primary : .tertiaryLabel
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 4.0
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(iconImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.6),
            iconImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.6)
        ])
    }
    
    func configure(with iconName: String) {
        iconImageView.image = UIImage(systemName: iconName)
    }
}

// MARK: - CategoryDetailViewController
final class CategoryDetailViewController: NNSheetViewController {
    
    // MARK: - Properties
    weak var categoryDelegate: CategoryDetailViewControllerDelegate?
    
    override var hasDiscardableContent: Bool {
        let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if category == nil {
            return !title.isEmpty || selectedIcon != nil
        }
        let originalName = category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title != originalName || selectedIcon != nil
    }

    private static let previewHeight: CGFloat = 144
    private static let previewWidth: CGFloat = 170
    private static let placeholderTitle = "Folder name"
    private static let placeholderIcon = "folder.fill"

    private lazy var folderPreviewCell: FolderCollectionViewCell = {
        let cell = FolderCollectionViewCell(frame: .zero)
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.isUserInteractionEnabled = false
        // Outside a UICollectionView, contentView won't auto-fill — pin it explicitly.
        cell.contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cell.contentView.topAnchor.constraint(equalTo: cell.topAnchor),
            cell.contentView.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            cell.contentView.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            cell.contentView.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
        ])
        return cell
    }()

    override var contentAboveTitleField: UIView? { folderPreviewCell }
    
    private lazy var iconCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.itemSize = CGSize(width: 36, height: 36)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.allowsSelection = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(CategoryIconCell.self, forCellWithReuseIdentifier: "CategoryIconCell")
        return collectionView
    }()
    
    private lazy var saveButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(title: category == nil ? "Create Folder" : "Update Folder")
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let selectedIconLabel: UILabel = {
        let label = UILabel()
        label.text = "Select an icon"
        label.font = .bodyL
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var selectedIcon: String?
    private let category: String?
    
    private var suggestedFolderName: String?
    private var suggestedIcon: String?
    
    // MARK: - Icons Array
    private let icons = [
        // Home & Security
        "door.left.hand.closed", "key.fill", "lock.fill",
        "bed.double.fill", "window.horizontal", "spigot.fill",
        
        // Time & Schedule
        "clock.fill", "calendar", "alarm",
        
        // Info & Rules
        "list.bullet", "checkmark.square", "exclamationmark.triangle", "bell.fill",
        
        "figure.walk",
        "figure.wave",
        "bus",
        "bicycle",
        "tram.fill",
        "binoculars.fill",
        "sun.max.fill",
        "sparkles",
        "moon.stars",
        "wind",
        "phone.fill",
        "trash.fill",
        "folder.fill",
        "paperplane.fill",
        "magazine.fill",
        "backpack.fill",
        "studentdesk",
        "american.football.fill",
        "basketball.fill",
        "baseball.fill",
        "tennis.racket",
        "tennisball.fill",
        "volleyball.fill",
        "surfboard.fill",
        "beach.umbrella.fill",
        "dishwasher.fill",
        "refrigerator.fill",
        "key.2.on.ring.fill",
        "stroller.fill",
        "helmet.fill",
        "shoe.2.fill",
        "gamecontroller.fill",
        "arcade.stick.console.fill",
        "wifi.circle.fill",
        "house.fill",
        "tortoise.fill",
        "dog.fill",
        "bird.fill",
        "lizard.fill",
        "ant.fill",
        "fish.fill",
        "pawprint.fill",
        "bubbles.and.sparkles.fill",
        "pills.fill",
        "cross.vial.fill",
        "staroflife.fill",
        "leaf.fill",
        "tree.fill",
        "list.bullet.clipboard.fill",
        "heart.fill"
    ]
    
    // MARK: - Initialization
    init(category: String? = nil, sourceFrame: CGRect? = nil) {
        self.category = category
        super.init(sourceFrame: sourceFrame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = category == nil ? "New Folder" : "Edit Folder"
        
        // Use suggested folder name if provided, otherwise use category
        titleField.text = suggestedFolderName ?? category
        titleField.placeholder = Self.placeholderTitle
        titleField.delegate = self
        titleField.addTarget(self, action: #selector(titleFieldChanged), for: .editingChanged)
        
        // Set suggested icon if provided
        if let suggestedIcon = suggestedIcon {
            selectedIcon = suggestedIcon
        }
        
        iconCollectionView.delegate = self
        iconCollectionView.dataSource = self
        
        itemsHiddenDuringTransition = [buttonStackView]

        updateFolderPreview()
        
        if category == nil && suggestedFolderName == nil {
            titleField.becomeFirstResponder()
        }
    }
    
    // MARK: - Public Methods
    func setSuggestedFolderName(_ name: String, withIcon icon: String) {
        suggestedFolderName = name
        suggestedIcon = icon
        
        // If view is already loaded, update the UI immediately
        if isViewLoaded {
            titleField.text = name
            selectedIcon = icon
            updateFolderPreview()
            
            // Reload collection view to show the selected icon
            iconCollectionView.reloadData()
        }
    }
    
    // MARK: - Setup Methods
    
    override func setupInfoButton() {
        setLeadingBarButtonHidden(true)
    }
    
    override func addContentToContainer() {
        super.addContentToContainer()
        
        containerView.addSubview(folderPreviewCell)
        buttonStackView.addArrangedSubview(saveButton)
        
        containerView.addSubview(selectedIconLabel)
        containerView.addSubview(iconCollectionView)
        containerView.addSubview(buttonStackView)
        
        NSLayoutConstraint.activate([
            folderPreviewCell.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            folderPreviewCell.widthAnchor.constraint(equalToConstant: Self.previewWidth),
            folderPreviewCell.heightAnchor.constraint(equalToConstant: Self.previewHeight),

            selectedIconLabel.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 16),
            selectedIconLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            selectedIconLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            iconCollectionView.topAnchor.constraint(equalTo: selectedIconLabel.bottomAnchor, constant: 16),
            iconCollectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconCollectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            iconCollectionView.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -16),
            
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Self.ctaBottomPadding),
            buttonStackView.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    // MARK: - Preview

    private func updateFolderPreview() {
        let trimmed = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = trimmed.isEmpty ? Self.placeholderTitle : trimmed
        let symbolName = selectedIcon ?? Self.placeholderIcon

        let data = FolderData(
            title: title,
            image: UIImage(systemName: symbolName),
            itemCount: 0,
            fullPath: title
        )
        folderPreviewCell.configure(with: data)
    }
    
    // MARK: - Actions
    @objc private func titleFieldChanged() {
        updateFolderPreview()
    }

    @objc private func saveButtonTapped() {
        guard let categoryName = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !categoryName.isEmpty,
              selectedIcon != nil else {
            shakeContainerView()
            return
        }
        
        // Pass both the folder name and selected icon to the delegate
        categoryDelegate?.categoryDetailViewController(self, didSaveCategory: categoryName, withIcon: selectedIcon!)
        dismissSheet()
    }
    
    override func handleDismissalResult() -> Any? {
        return titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - UITextFieldDelegate
extension CategoryDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UICollectionView DataSource & Delegate
extension CategoryDetailViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return icons.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryIconCell", for: indexPath) as! CategoryIconCell
        let icon = icons[indexPath.item]
        cell.configure(with: icon)
        cell.isSelected = icon == selectedIcon
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIcon = icons[indexPath.item]
        updateFolderPreview()
        collectionView.cellForItem(at: indexPath)?.bounce(includeScale: true)
        HapticsHelper.lightHaptic()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Prevent the sheet dismiss gesture from stealing icon-grid scrolls.
        isModalInPresentation = true
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            isModalInPresentation = false
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isModalInPresentation = false
    }
}
