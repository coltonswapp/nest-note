import UIKit

protocol NNEmptyStateViewDelegate: AnyObject {
    func emptyStateViewDidTapActionButton(_ emptyStateView: NNEmptyStateView)
}

class NNEmptyStateView: UIView {
    weak var delegate: NNEmptyStateViewDelegate?
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var actionButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(title: "", backgroundColor: NNColors.primary.withAlphaComponent(0.15), foregroundColor: NNColors.primary)
        button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    init(icon: UIImage?, title: String, subtitle: String, actionButtonTitle: String? = nil) {
        super.init(frame: .zero)
        setupView()
        configure(icon: icon, title: title, subtitle: subtitle, actionButtonTitle: actionButtonTitle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(stackView)
        
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(actionButton)
        
        stackView.setCustomSpacing(16, after: subtitleLabel)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            
            actionButton.heightAnchor.constraint(equalToConstant: 46)
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
    }
    
    @objc private func actionButtonTapped() {
        delegate?.emptyStateViewDidTapActionButton(self)
    }
} 
