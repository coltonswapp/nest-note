import UIKit

class NNSmallCircularButton: NNBaseControl {
    
    // MARK: - Properties
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .captionBold
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    init(
        icon: UIImage?,
        title: String,
        backgroundColor: UIColor = .tertiarySystemGroupedBackground,
        foregroundColor: UIColor = .label,
        size: CGFloat = 46
    ) {
        super.init(title: "")
        self.backgroundColor = backgroundColor
        
        iconImageView.tintColor = foregroundColor
        iconImageView.image = icon?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: size * 0.4, weight: .medium)
        )
        subtitleLabel.text = title
        
        setupView(size: size)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupView(size: CGFloat) {
        addSubview(iconImageView)
        addSubview(subtitleLabel)
        
        // Make the button circular
        layer.cornerRadius = size / 2
        clipsToBounds = true
        
        NSLayoutConstraint.activate([
            // Set button size
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            
            // Center icon
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5),
            iconImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5),
            
            // Position label below button
            subtitleLabel.topAnchor.constraint(equalTo: bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleLabel.widthAnchor.constraint(equalToConstant: 80)
        ])
        
        layer.borderWidth = 1
        layer.borderColor = backgroundColor?.lighter(by: 15).cgColor
    }
    
    // MARK: - Public Methods
    func setIconTintColor(_ color: UIColor) {
        iconImageView.tintColor = color
    }
    
    func setSubtitle(_ title: String) {
        subtitleLabel.text = title
    }
} 
