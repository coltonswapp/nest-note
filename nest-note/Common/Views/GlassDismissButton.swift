import UIKit

/// Circular glass dismiss control with an xmark icon. Safe to use on iOS 26+ glass and pre-26 blur fallback.
final class GlassDismissButton: UIControl {
    static let size: CGFloat = 30

    private let glassView: UIVisualEffectView
    private let iconView: UIImageView

    override init(frame: CGRect) {
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .regular)
            glassEffect.isInteractive = true
            glassView = UIVisualEffectView(effect: glassEffect)
        } else {
            glassView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        }

        let configuration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        iconView = UIImageView(image: UIImage(systemName: "xmark", withConfiguration: configuration))

        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        accessibilityLabel = String(localized: "Dismiss")
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerCurve = .continuous

        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isUserInteractionEnabled = false

        glassView.isUserInteractionEnabled = false
        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.layer.cornerRadius = Self.size / 2
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
