import UIKit

class BlurBackgroundLabel: UIVisualEffectView {
    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        return label
    }()

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


    // MARK: - Initializers
    override init(effect: UIVisualEffect?) {
        super.init(effect: effect)
        setupViews()
    }

    convenience init() {
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .clear)
            glassEffect.isInteractive = true
            self.init(effect: glassEffect)
        } else {
            // Fallback: No effect for older iOS versions
            self.init(effect: nil)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    // MARK: - Setup
    private func setupViews() {
        setupAppearance()
        setupLabel()
        setupConstraints()
    }

    private func setupAppearance() {
        layer.cornerRadius = 18
        translatesAutoresizingMaskIntoConstraints = false

        // Add background styling for non-glass versions
        if #available(iOS 26.0, *) {
            // Glass effect handles the background
        } else {
            // Fallback: Add background color and shadow for non-glass
            backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 2)
            layer.shadowOpacity = 0.1
            layer.shadowRadius = 8
        }
    }

    private func setupLabel() {
        contentView.addSubview(label)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    @objc private func clearButtonTapped() {
        onClearTapped?()
    }

}
