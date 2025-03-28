import UIKit

final class VisibilityLevelInfoView: UIView {
    
    // MARK: - Properties
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 32
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupView() {
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Add level info views
        addLevelInfo(
            title: "Essential",
            description: "Critical details always visible to sitters for the safety and basic care of your children.",
            iconName: "exclamationmark.shield.fill"
        )
        
        addLevelInfo(
            title: "Standard",
            description: "Additional guidelines and instructions that appear for typically longer daytime stays.",
            iconName: "clock.fill"
        )
        
        addLevelInfo(
            title: "Extended",
            description: "Overnight-specific details that become visible when sitters stay through the night.",
            iconName: "moon.stars.fill"
        )
        
        addLevelInfo(
            title: "Comprehensive",
            description: "Complete household management information that unlocks for extended multi-day stays.",
            iconName: "calendar.badge.clock"
        )
    }
    
    private func addLevelInfo(title: String, description: String, iconName: String) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleStack = UIStackView()
        titleStack.axis = .horizontal
        titleStack.spacing = 8
        titleStack.alignment = .center
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        iconImageView.image = UIImage(systemName: iconName, withConfiguration: config)
        iconImageView.tintColor = NNColors.primary
        iconImageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        
        titleStack.addArrangedSubview(iconImageView)
        titleStack.addArrangedSubview(titleLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleStack)
        container.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleStack.topAnchor.constraint(equalTo: container.topAnchor),
            titleStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleStack.leadingAnchor, constant: 32),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        stackView.addArrangedSubview(container)
    }
} 
