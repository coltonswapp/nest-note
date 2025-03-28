import UIKit

/// Represents the type of nest view being displayed
enum HomeNestType {
    case sitterAccess     // Sitter's limited view of the nest
    case ownerPrimary     // Owner's primary nest view
    case ownerSecondary   // Owner's secondary/alternate nest
    
    var backgroundColor: UIColor {
        switch self {
        case .sitterAccess:
            return .secondarySystemGroupedBackground
        case .ownerPrimary:
            return .secondarySystemGroupedBackground
        case .ownerSecondary:
            return .tertiarySystemGroupedBackground
        }
    }
    
    var titleColor: UIColor {
        switch self {
        case .sitterAccess, .ownerPrimary, .ownerSecondary:
            return .label
        }
    }
    
    var subtitleColor: UIColor {
        switch self {
        case .sitterAccess, .ownerPrimary, .ownerSecondary:
            return .secondaryLabel
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .sitterAccess:
            return "house.lodge.fill"
        case .ownerPrimary:
            return "house.lodge.fill"
        case .ownerSecondary:
            return "house.lodge"
        }
    }
    
    var imageSize: CGFloat {
        switch self {
        case .sitterAccess:
            return 80  // Slightly smaller for sitter view
        case .ownerPrimary, .ownerSecondary:
            return 100 // Larger for owner view
        }
    }
}

final class HomeNestCell: UICollectionViewCell {
    // MARK: - Properties
    private var nestType: HomeNestType = .ownerPrimary
    
    // MARK: - UI Elements
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
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
        // Add subviews
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(iconImageView)
        
        // Create image size constraints (will be updated in configure)
        imageWidthConstraint = iconImageView.widthAnchor.constraint(equalToConstant: 100)
        imageHeightConstraint = iconImageView.heightAnchor.constraint(equalToConstant: 100)
        
        NSLayoutConstraint.activate([
            // Image view constraints - top right corner
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            iconImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            imageWidthConstraint!,
            imageHeightConstraint!,
            
            // Title label constraints - bottom left
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: iconImageView.leadingAnchor, constant: -20),
            titleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -4),
            
            // Subtitle label constraints - below title, bottom left
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: iconImageView.leadingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        // Set corner radius
        layer.cornerRadius = 12
        layer.masksToBounds = true
    }
    
    func configure(with nest: NestItem) {
        configure(
            title: nest.name,
            subtitle: nest.address,
            type: .sitterAccess
        )
    }
    
    func configure(title: String, subtitle: String, type: HomeNestType, customImage: UIImage? = nil) {
        self.nestType = type
        
        // Update text
        titleLabel.text = title
        subtitleLabel.text = subtitle
        
        // Update colors
        titleLabel.textColor = type.titleColor
        subtitleLabel.textColor = type.subtitleColor
        backgroundColor = type.backgroundColor
        
        // Update image size constraints
        imageWidthConstraint?.constant = type.imageSize
        imageHeightConstraint?.constant = type.imageSize
        
        // Update icon
        if let customImage = customImage {
            iconImageView.image = customImage
            iconImageView.tintColor = type.titleColor
        } else {
            let imageConfig = UIImage.SymbolConfiguration(pointSize: type.imageSize * 0.6, weight: .semibold)
            iconImageView.image = UIImage(systemName: type.defaultIcon, withConfiguration: imageConfig)
            iconImageView.tintColor = type.titleColor
        }
    }
} 