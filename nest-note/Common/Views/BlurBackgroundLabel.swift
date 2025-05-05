import UIKit

class BlurBackgroundLabel: UIView {
    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    private var blurView: UIVisualEffectView!
    
    var onClearTapped: (() -> Void)?
    
    var text: String? {
        get { label.text }
        set { label.text = newValue }
    }
    
    var font: UIFont {
        get { label.font }
        set { label.font = newValue }
    }
    
    var textColor: UIColor {
        get { label.textColor }
        set { label.textColor = newValue }
    }
    
    override var alpha: CGFloat {
        get { blurView.alpha }
        set { blurView.alpha = newValue }
    }
    
    init(with effect: UIBlurEffect.Style = .systemUltraThinMaterial) {
        super.init(frame: .zero)
        configureBlurView(with: effect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureBlurView(with effect: UIBlurEffect.Style) {
        let blur = UIBlurEffect(style: effect)
        blurView = UIVisualEffectView(effect: blur)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 12
        blurView.clipsToBounds = true
    }
    
    private func setupViews() {
        addSubview(blurView)
        blurView.contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            label.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -12)
        ])
    }
    
    @objc private func clearButtonTapped() {
        onClearTapped?()
    }
} 
