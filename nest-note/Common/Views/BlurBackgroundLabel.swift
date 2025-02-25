import UIKit

class BlurBackgroundLabel: UIView {
    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    private let blurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterial)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
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
    
    init() {
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
