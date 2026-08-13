import UIKit
import Toast

/// Custom glass toast conforming to toast-swift's `ToastView` protocol.
final class NNToastView: UIView, ToastView {

    private static let cornerRadius: CGFloat = 16
    private static let horizontalInset: CGFloat = 16
    private static let contentPadding: CGFloat = 14
    private static let actionCornerRadius: CGFloat = 10

    /// Light: dark glass. Dark: translucent gray glass.
    private static let lightTint = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
    private static let darkTint = UIColor(red: 137 / 255, green: 137 / 255, blue: 137 / 255, alpha: 0.3)
    /// Lighter than the toast chrome so the CTA reads as a raised chip (screenshot-inspired).
    private static let lightActionFill = UIColor.white.withAlphaComponent(0.22)
    private static let darkActionFill = UIColor.white.withAlphaComponent(0.28)

    private let glassView: UIVisualEffectView
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let textStack = UIStackView()
    private let headerStack = UIStackView()
    private let contentStack = UIStackView()
    private var actionButton: UIButton?

    private weak var toast: Toast?
    private let onAction: (() -> Void)?
    private var didHandleAction = false

    init(
        title: String,
        subtitle: String? = nil,
        sentiment: Sentiment = .positive,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .regular)
            glassEffect.isInteractive = true
            glassView = UIVisualEffectView(effect: glassEffect)
        } else {
            glassView = UIVisualEffectView(effect: nil)
        }

        self.onAction = onAction
        super.init(frame: .zero)

        setupChrome()
        setupContent(title: title, subtitle: subtitle, sentiment: sentiment, actionTitle: actionTitle)
        applyAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let fitting = contentStack.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        return CGSize(
            width: fitting.width + Self.contentPadding * 2,
            height: fitting.height + Self.contentPadding * 2
        )
    }

    func createView(for toast: Toast) {
        self.toast = toast
        guard let superview else { return }

        translatesAutoresizingMaskIntoConstraints = false
        applyAppearance()

        NSLayoutConstraint.activate([
            leadingAnchor.constraint(greaterThanOrEqualTo: superview.leadingAnchor, constant: Self.horizontalInset),
            trailingAnchor.constraint(lessThanOrEqualTo: superview.trailingAnchor, constant: -Self.horizontalInset),
            centerXAnchor.constraint(equalTo: superview.centerXAnchor),
            widthAnchor.constraint(lessThanOrEqualTo: superview.widthAnchor, constant: -Self.horizontalInset * 2)
        ])

        switch toast.config.direction {
        case .bottom:
            bottomAnchor.constraint(equalTo: superview.layoutMarginsGuide.bottomAnchor).isActive = true
        case .top:
            topAnchor.constraint(equalTo: superview.layoutMarginsGuide.topAnchor).isActive = true
        case .center:
            centerYAnchor.constraint(equalTo: superview.layoutMarginsGuide.centerYAnchor).isActive = true
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        applyAppearance()
    }

    // MARK: - Setup

    private func setupChrome() {
        backgroundColor = .clear
        layer.zPosition = 999

        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.layer.cornerRadius = Self.cornerRadius
        glassView.layer.cornerCurve = .continuous
        glassView.clipsToBounds = true

        addSubview(glassView)
        NSLayoutConstraint.activate([
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func setupContent(
        title: String,
        subtitle: String?,
        sentiment: Sentiment,
        actionTitle: String?
    ) {
        let hasSubtitle = !(subtitle ?? "").isEmpty
        let hasAction = !(actionTitle ?? "").isEmpty
        let isSingleLine = !hasSubtitle && !hasAction

        let symbolName = sentiment == .positive ? "checkmark.circle" : "xmark.circle"
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        iconView.image = UIImage(systemName: symbolName, withConfiguration: symbolConfig)
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24)
        ])

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.numberOfLines = isSingleLine ? 1 : 2
        titleLabel.textAlignment = isSingleLine ? .center : .natural
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        textStack.axis = .vertical
        textStack.alignment = isSingleLine ? .center : .leading
        textStack.spacing = 2
        textStack.addArrangedSubview(titleLabel)

        if hasSubtitle, let subtitle {
            subtitleLabel.text = subtitle
            subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
            subtitleLabel.numberOfLines = 2
            textStack.addArrangedSubview(subtitleLabel)
        }

        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 10
        headerStack.addArrangedSubview(iconView)
        headerStack.addArrangedSubview(textStack)

        contentStack.axis = .vertical
        // Single-line hugs content and stays centered; multi-line/action fill for the button width.
        contentStack.alignment = isSingleLine ? .center : .fill
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(headerStack)

        if hasAction, let actionTitle {
            var configuration = UIButton.Configuration.filled()
            configuration.title = actionTitle
            configuration.cornerStyle = .fixed
            configuration.background.cornerRadius = Self.actionCornerRadius
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 14, weight: .semibold)
                return outgoing
            }

            let button = UIButton(configuration: configuration)
            button.addTarget(self, action: #selector(handleActionTap), for: .touchUpInside)
            actionButton = button
            contentStack.addArrangedSubview(button)
        }

        glassView.contentView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: glassView.contentView.topAnchor, constant: Self.contentPadding),
            contentStack.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: Self.contentPadding),
            contentStack.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -Self.contentPadding),
            contentStack.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor, constant: -Self.contentPadding)
        ])

        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        invalidateIntrinsicContentSize()
    }

    private func applyAppearance() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let tint = isDark ? Self.darkTint : Self.lightTint

        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .regular)
            glassEffect.isInteractive = true
            glassEffect.tintColor = tint
            glassView.effect = glassEffect
            glassView.backgroundColor = nil
            layer.shadowOpacity = 0
        } else {
            glassView.effect = nil
            glassView.backgroundColor = tint
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 4)
            layer.shadowOpacity = 0.18
            layer.shadowRadius = 10
            layer.masksToBounds = false
        }

        iconView.tintColor = .white
        titleLabel.textColor = .white
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)

        if var configuration = actionButton?.configuration {
            configuration.baseForegroundColor = .white
            configuration.baseBackgroundColor = isDark ? Self.darkActionFill : Self.lightActionFill
            actionButton?.configuration = configuration
        }
    }

    @objc private func handleActionTap() {
        guard !didHandleAction else { return }
        didHandleAction = true
        // Let ToastManager own dismiss — calling toast.close() here races our slide-off.
        onAction?()
    }
}
