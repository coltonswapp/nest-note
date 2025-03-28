import UIKit

class NNCircularIconButton: NNBaseControl {
    
    // MARK: - Properties
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Initialization
    init(
        icon: UIImage?,
        backgroundColor: UIColor = .tertiarySystemGroupedBackground,
        foregroundColor: UIColor = .label,
        size: CGFloat = 60
    ) {
        super.init(title: "")
        
        self.backgroundColor = backgroundColor
        iconImageView.tintColor = foregroundColor
        iconImageView.image = icon?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: size * 0.4, weight: .medium)
        )
        
        setupView(size: size)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupView(size: CGFloat) {
        addSubview(iconImageView)
        
        // Make the button circular
        layer.cornerRadius = size / 2
        clipsToBounds = true
        
        // Center the icon
        NSLayoutConstraint.activate([
            // Set button size
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            
            // Center icon
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5),
            iconImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5)
        ])
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        animateScale(to: 0.9)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        animateScale(to: 1.0)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        animateScale(to: 1.0)
    }
    
    private func animateScale(to scale: CGFloat) {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        })
    }
    
    // MARK: - Public Methods
    func setIconTintColor(_ color: UIColor) {
        iconImageView.tintColor = color
    }
} 