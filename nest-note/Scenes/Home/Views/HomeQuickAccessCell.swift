import UIKit

/// Represents the type of quick access item being displayed
enum HomeQuickAccessType {
    case sitterHousehold    // Sitter's access to household info
    case sitterEmergency    // Sitter's access to emergency info
    case ownerHousehold     // Owner's access to household management
    case ownerEmergency     // Owner's access to emergency settings
    
    var backgroundColor: UIColor {
        switch self {
        case .sitterHousehold, .ownerHousehold:
            return .secondarySystemGroupedBackground
        case .sitterEmergency, .ownerEmergency:
            return .secondarySystemGroupedBackground
        }
    }
    
    var titleColor: UIColor {
        switch self {
        case .sitterHousehold, .ownerHousehold:
            return .label
        case .sitterEmergency, .ownerEmergency:
            return .label
        }
    }
    
    var iconColor: UIColor {
        switch self {
        case .sitterHousehold, .ownerHousehold:
            return .label
        case .sitterEmergency, .ownerEmergency:
            return NNColors.primary
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .sitterHousehold, .ownerHousehold:
            return "house"
        case .sitterEmergency, .ownerEmergency:
            return "light.beacon.max"
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .sitterHousehold, .sitterEmergency:
            return 50  // Slightly smaller for sitter view
        case .ownerHousehold, .ownerEmergency:
            return 60  // Larger for owner view
        }
    }
    
    var title: String {
        switch self {
        case .sitterHousehold, .ownerHousehold:
            return "Household"
        case .sitterEmergency, .ownerEmergency:
            return "Emergency"
        }
    }
}

final class HomeQuickAccessCell: UICollectionViewCell {
    // MARK: - Properties
    private var accessType: HomeQuickAccessType = .ownerHousehold
    
    // MARK: - UI Elements
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .h4
        return label
    }()
    
    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageHeightConstraint: NSLayoutConstraint?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        // Add views to stackView
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(titleLabel)
        
        // Add stackView to contentView
        contentView.addSubview(stackView)
        
        // Create image size constraints (will be updated in configure)
        imageWidthConstraint = iconImageView.widthAnchor.constraint(equalToConstant: 60)
        imageHeightConstraint = iconImageView.heightAnchor.constraint(equalToConstant: 60)
        
        NSLayoutConstraint.activate([
            // Stack view constraints
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 6),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
            
            // Image constraints
            imageWidthConstraint!,
            imageHeightConstraint!
        ])
        
        // Set corner radius
        layer.cornerRadius = 12
        layer.masksToBounds = true
    }
    
    func configure(type: HomeQuickAccessType, customImage: UIImage? = nil) {
        self.accessType = type
        
        // Update text
        titleLabel.text = type.title
        titleLabel.textColor = type.titleColor
        
        // Update colors
        backgroundColor = type.backgroundColor
        
        // Update image size constraints
        imageWidthConstraint?.constant = type.iconSize
        imageHeightConstraint?.constant = type.iconSize
        
        // Update icon
        if let customImage = customImage {
            iconImageView.image = customImage
            iconImageView.tintColor = type.iconColor
        } else {
            let imageConfig = UIImage.SymbolConfiguration(pointSize: type.iconSize * 0.7, weight: .semibold)
            iconImageView.image = UIImage(systemName: type.defaultIcon, withConfiguration: imageConfig)
            iconImageView.tintColor = type.iconColor
        }
    }
} 