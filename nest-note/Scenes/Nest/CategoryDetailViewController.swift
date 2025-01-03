import UIKit
import Foundation

protocol CategoryDetailViewControllerDelegate: AnyObject {
    func categoryDetailViewController(_ controller: CategoryDetailViewController, didSaveCategory category: String?)
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
        let button = NNSmallPrimaryButton(title: "Save")
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
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let selectedIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .tertiaryLabel
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "square.dashed")
        return imageView
    }()
    
    private let selectedIconStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private var selectedIcon: String?
    private let category: String?
    
    // MARK: - Icons Array
    private let icons = [
        // Home & Security
        "house.fill", "door.left.hand.closed", "key.fill", "lock.fill", "wifi",
        "bed.double.fill", "window.horizontal", "spigot.fill",
        
        // Time & Schedule
        "clock.fill", "calendar", "alarm", "moon.fill", "sun.max.fill",
        
        // Info & Rules
        "list.bullet", "checkmark.square", "exclamationmark.triangle", "bell.fill",
        
        // Family & Social
        "figure.2.and.child.holdinghands", "person.2.fill", "figure.wave",
        "figure.play", "figure.american.football", "person.3.fill", "heart.fill",
        "heart.text.clipboard", "pills.fill",
        
        // Objects & Activities
        "pencil", "book.fill", "car.fill", "bicycle", "fork.knife",
        "gamecontroller.fill", "tv.fill", "phone.fill", "cross.case.fill",
        "pawprint.fill"
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
        titleLabel.text = category == nil ? "New Category" : "Edit Category"
        titleField.text = category
        titleField.placeholder = "Category name"
        
        iconCollectionView.delegate = self
        iconCollectionView.dataSource = self
        
        itemsHiddenDuringTransition = [buttonStackView]
        
        if category == nil {
            titleField.becomeFirstResponder()
        }
    }
    
    // MARK: - Setup Methods
    override func addContentToContainer() {
        super.addContentToContainer()
        
        selectedIconStackView.addArrangedSubview(selectedIconLabel)
        selectedIconStackView.addArrangedSubview(selectedIconImageView)
        buttonStackView.addArrangedSubview(saveButton)
        
        containerView.addSubview(selectedIconStackView)
        containerView.addSubview(iconCollectionView)
        containerView.addSubview(buttonStackView)
        
        NSLayoutConstraint.activate([
            selectedIconStackView.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 16),
            selectedIconStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            selectedIconStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            selectedIconImageView.widthAnchor.constraint(equalToConstant: 24),
            selectedIconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            iconCollectionView.topAnchor.constraint(equalTo: selectedIconStackView.bottomAnchor, constant: 32),
            iconCollectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconCollectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            iconCollectionView.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -16),
            
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            buttonStackView.heightAnchor.constraint(equalToConstant: 46)
        ])
    }
    
    // MARK: - Actions
    @objc private func saveButtonTapped() {
        guard let categoryName = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !categoryName.isEmpty,
              selectedIcon != nil else {
            shakeContainerView()
            return
        }
        
        categoryDelegate?.categoryDetailViewController(self, didSaveCategory: categoryName)
        dismiss(animated: true)
    }
    
    override func handleDismissalResult() -> Any? {
        return titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
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
        selectedIconImageView.image = UIImage(systemName: icons[indexPath.item])
        selectedIconImageView.tintColor = NNColors.primary
        selectedIconImageView.bounce(includeScale: true)
        HapticsHelper.lightHaptic()
    }
} 
