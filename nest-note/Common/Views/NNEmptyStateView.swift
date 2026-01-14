import UIKit

@objc protocol NNEmptyStateViewDelegate: AnyObject {
    func emptyStateViewDidTapActionButton(_ emptyStateView: NNEmptyStateView)
    func emptyStateView(_ emptyStateView: NNEmptyStateView, didTapActionWithTag tag: Int)
    @objc optional func emptyStateViewDidTapSecondaryActionButton(_ emptyStateView: NNEmptyStateView)
}

class NNEmptyStateView: UIView {
    weak var delegate: NNEmptyStateViewDelegate?
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = true
        return stack
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label
        imageView.isUserInteractionEnabled = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3
        label.textColor = .label
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isUserInteractionEnabled = false
        return label
    }()
    
    private lazy var buttonStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.distribution = .fillProportionally
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private(set) var actionButtons: [NNSmallPrimaryButton] = []

    private lazy var actionButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(title: "Test", backgroundColor: NNColors.primary.withAlphaComponent(0.15), foregroundColor: NNColors.primary)
        button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        button.isUserInteractionEnabled = true
        button.tag = 0
        return button
    }()

    private var secondaryActionButton: UIButton?
    
    init(icon: UIImage?, title: String, subtitle: String, actionButtonTitle: String? = nil, actionButtonMenu: UIMenu? = nil) {
        super.init(frame: .zero)
        setupView()
        configure(icon: icon, title: title, subtitle: subtitle, actionButtonTitle: actionButtonTitle)
        
        if let menu = actionButtonMenu {
            addMenuToActionButton(menu: menu)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(stackView)
        
        stackView.addArrangedSubview(iconImageView)
        stackView.setCustomSpacing(16, after: iconImageView)

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(buttonStackView)
        buttonStackView.addArrangedSubview(actionButton)

        stackView.setCustomSpacing(16, after: subtitleLabel)
        
        // Ensure the view itself is user interaction enabled
        isUserInteractionEnabled = true
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            
            actionButton.heightAnchor.constraint(equalToConstant: 46),
            buttonStackView.heightAnchor.constraint(equalToConstant: 46)
        ])
    }
    
    func configure(icon: UIImage?, title: String, subtitle: String, actionButtonTitle: String? = nil) {
        iconImageView.image = icon?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 36, weight: .regular)
        )
        titleLabel.text = title
        subtitleLabel.text = subtitle

        if let buttonTitle = actionButtonTitle {
            actionButton.setTitle(buttonTitle, for: .normal)
            actionButton.isHidden = false
        } else {
            actionButton.isHidden = true
        }

        if let icon {
            iconImageView.isHidden = false
        } else {
            iconImageView.isHidden = true
        }
    }
    
    @objc private func actionButtonTapped() {
        delegate?.emptyStateViewDidTapActionButton(self)
    }

    @objc private func secondaryActionButtonTapped() {
        delegate?.emptyStateViewDidTapSecondaryActionButton?(self)
    }

    /// Adds a secondary action button below the primary action button
    /// - Parameter title: The title for the secondary button
    func addSecondaryAction(title: String) {
        // Only create if it doesn't exist
        guard secondaryActionButton == nil else {
            // If it exists, just update the title
            var config = secondaryActionButton?.configuration
            config?.title = title
            secondaryActionButton?.configuration = config
            secondaryActionButton?.isHidden = false
            return
        }

        // Create the secondary action button
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .systemBlue
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(secondaryActionButtonTapped), for: .touchUpInside)

        // Add to stack view
        stackView.addArrangedSubview(button)
        stackView.setCustomSpacing(8, after: buttonStackView)

        secondaryActionButton = button
    }

    func addMenuToActionButton(menu: UIMenu) {
        actionButton.showsMenuAsPrimaryAction = true
        actionButton.menu = menu
    }
    
    func addAction(title: String, backgroundColor: UIColor = NNColors.primary.withAlphaComponent(0.15), foregroundColor: UIColor = NNColors.primary, tag: Int) {
        let button = NNSmallPrimaryButton(title: title, backgroundColor: backgroundColor, foregroundColor: foregroundColor)
        button.addTarget(self, action: #selector(actionButtonWithTagTapped(_:)), for: .touchUpInside)
        button.tag = tag
        
        actionButtons.append(button)
        buttonStackView.addArrangedSubview(button)
        
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 46)
        ])
    }
    
    @objc private func actionButtonWithTagTapped(_ sender: UIButton) {
        delegate?.emptyStateView(self, didTapActionWithTag: sender.tag)
    }
}
