import UIKit

class BlurBackgroundLabel: UIView {
    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    // Container that holds either a blur view or a colored view
    private var containerView: UIView!
    private var blurView: UIVisualEffectView?
    private var shimmerTimer: Timer?
    private let shimmerLayer = CAGradientLayer()
    private let borderShapeLayer = CAShapeLayer()

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
        get { containerView?.alpha ?? super.alpha }
        set { containerView?.alpha = newValue }
    }

    // MARK: - Initializers
    init(with effect: UIBlurEffect.Style = .systemUltraThinMaterial) {
        super.init(frame: .zero)
        configureBlurView(with: effect)
        setupViews()
    }

    convenience init(backgroundColor: UIColor, foregroundColor: UIColor) {
        self.init(frame: .zero)
        configureColorView(with: backgroundColor, foregroundColor: foregroundColor)
        setupViews()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration
    private func configureBlurView(with effect: UIBlurEffect.Style) {
        let blur = UIBlurEffect(style: effect)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 12
        blurView.clipsToBounds = true
        blurView.layer.borderWidth = 1.5
        blurView.layer.borderColor = UIColor.systemBackground.cgColor
        self.blurView = blurView
        self.containerView = blurView
    }

    private func configureColorView(with color: UIColor, foregroundColor: UIColor) {
        let colorView = UIView()
        colorView.translatesAutoresizingMaskIntoConstraints = false
        colorView.layer.cornerRadius = 12
        colorView.clipsToBounds = true
        colorView.backgroundColor = color
        colorView.layer.borderWidth = 1.5
        colorView.layer.borderColor = foregroundColor.cgColor
        label.textColor = foregroundColor
        self.containerView = colorView
        self.blurView = nil
    }

    private func setupViews() {
        guard containerView != nil else { return }

        addSubview(containerView)

        // Host for label: blur contentView when blurred, else the container itself
        let hostView: UIView
        if let blurView = containerView as? UIVisualEffectView {
            hostView = blurView.contentView
        } else {
            hostView = containerView
        }
        hostView.addSubview(label)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            label.topAnchor.constraint(equalTo: hostView.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: hostView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: hostView.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: hostView.bottomAnchor, constant: -12)
        ])
    }

    @objc private func clearButtonTapped() {
        onClearTapped?()
    }
} 
