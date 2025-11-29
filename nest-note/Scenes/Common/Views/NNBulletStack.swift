import UIKit

struct NNBulletItem {
    let title: String
    let description: String
    let iconName: String
}

final class NNBulletStack: UIView {

    // MARK: - Properties
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 32
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let animated: Bool
    private var iconImageViews: [UIImageView] = []
    
    // MARK: - Initialization
    init(items: [NNBulletItem], animated: Bool = false) {
        self.animated = animated
        super.init(frame: .zero)
        setupView(with: items)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupView(with items: [NNBulletItem]) {
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Add items
        for (_, item) in items.enumerated() {
            let container = addLevelInfo(title: item.title, description: item.description, iconName: item.iconName)

            if animated {
                // Set initial state for animation
                container.alpha = 0
                container.transform = CGAffineTransform(translationX: 0, y: 30)
            }
        }

        if animated {
            animateItems()
        }
    }
    
    @discardableResult
    private func addLevelInfo(title: String, description: String, iconName: String) -> UIView {
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

        // Store reference for animation
        iconImageViews.append(iconImageView)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .h4
        titleLabel.textColor = .label
        
        titleStack.addArrangedSubview(iconImageView)
        titleStack.addArrangedSubview(titleLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = .bodyM
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
        return container
    }

    // MARK: - Animation
    private func animateItems() {
        let containers = stackView.arrangedSubviews

        for (index, container) in containers.enumerated() {
            let delay = Double(index) * 0.3 // 300ms delay between each item

            UIView.animate(
                withDuration: 1.2,
                delay: delay,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3,
                options: [.curveEaseOut]
            ) {
                container.alpha = 1.0
                container.transform = .identity
            }

            // Add symbol effect to the corresponding icon
            if index < iconImageViews.count {
                let iconImageView = iconImageViews[index]
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.2) {
                    iconImageView.addSymbolEffect(.appear.up)
                }
            }
        }
    }
} 
