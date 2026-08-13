import UIKit

/// Circular liquid-glass icon control. Uses `UIGlassEffect` on iOS 26+ with a blur fallback.
class GlassIconButton: UIControl {
    static let sheetHeaderSize: CGFloat = 36

    let buttonSize: CGFloat

    private let glassView: UIVisualEffectView
    private let iconView: UIImageView

    init(
        systemName: String,
        pointSize: CGFloat = 14,
        weight: UIImage.SymbolWeight = .semibold,
        tintColor: UIColor = .secondaryLabel,
        size: CGFloat = sheetHeaderSize,
        accessibilityLabel: String? = nil
    ) {
        self.buttonSize = size

        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .regular)
            glassEffect.isInteractive = true
            glassView = UIVisualEffectView(effect: glassEffect)
        } else {
            glassView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        }

        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        iconView = UIImageView(image: UIImage(systemName: systemName, withConfiguration: configuration))

        super.init(frame: .zero)
        self.accessibilityLabel = accessibilityLabel
        iconView.tintColor = tintColor
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSymbol(
        _ systemName: String,
        pointSize: CGFloat = 14,
        weight: UIImage.SymbolWeight = .semibold
    ) {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        iconView.image = UIImage(systemName: systemName, withConfiguration: configuration)
    }

    static func makeGlassBackgroundView(size: CGFloat = sheetHeaderSize) -> UIVisualEffectView {
        let effectView: UIVisualEffectView
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .regular)
            glassEffect.isInteractive = true
            effectView = UIVisualEffectView(effect: glassEffect)
        } else {
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        }

        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.layer.cornerRadius = size / 2
        effectView.layer.cornerCurve = .continuous
        effectView.clipsToBounds = true
        effectView.isUserInteractionEnabled = false

        if #available(iOS 26.0, *) {
            // Glass effect handles the background.
        } else {
            effectView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        }

        return effectView
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerCurve = .continuous

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isUserInteractionEnabled = false

        glassView.isUserInteractionEnabled = false
        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.layer.cornerRadius = buttonSize / 2
        glassView.layer.cornerCurve = .continuous
        glassView.clipsToBounds = true

        if #available(iOS 26.0, *) {
            // Glass effect handles the background.
        } else {
            glassView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 2)
            layer.shadowOpacity = 0.12
            layer.shadowRadius = 6
        }

        addSubview(glassView)
        glassView.contentView.addSubview(iconView)

        NSLayoutConstraint.activate([
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.centerXAnchor.constraint(equalTo: glassView.contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor),
        ])
    }
}
