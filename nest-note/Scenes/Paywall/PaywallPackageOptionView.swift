//
//  PaywallPackageOptionView.swift
//  nest-note
//

import UIKit
import RevenueCat

final class PaywallPackageOptionView: UIControl {

    enum LayoutStyle {
        case standard
        case compact
    }

    private(set) var package: Package?
    var showsInlineTrialBadge = true
    var layoutStyle: LayoutStyle = .standard

    var isOptionSelected: Bool = false {
        didSet { updateAppearance() }
    }

    private let radioImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = NNColors.primary
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .h4
        label.textColor = .label
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private let trialBadge: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .captionBoldS
        label.textColor = NNColors.primary
        label.backgroundColor = NNColors.primaryOpaque.withAlphaComponent(0.45)
        label.textAlignment = .center
        label.layer.cornerRadius = 10
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()

    private let priceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .h4
        label.textColor = .label
        label.textAlignment = .right
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let priceRowStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        return stack
    }()

    private let titleRowStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()

    private let compactContentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .fill
        return stack
    }()

    private var heightConstraint: NSLayoutConstraint?

    init(layoutStyle: LayoutStyle = .standard) {
        self.layoutStyle = layoutStyle
        super.init(frame: .zero)
        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with package: Package) {
        self.package = package
        titleLabel.text = displayTitle(for: package)
        priceLabel.text = package.localizedPriceString

        if showsInlineTrialBadge, let badgeText = Self.introOfferText(for: package) {
            trialBadge.text = "  \(badgeText)  "
            trialBadge.isHidden = false
        } else {
            trialBadge.isHidden = true
        }

        updateAppearance()
    }

    private func setup() {
        layer.borderWidth = 1.5
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        clipsToBounds = true

        switch layoutStyle {
        case .standard:
            setupStandardLayout()
        case .compact:
            setupCompactLayout()
        }

        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: .touchUpInside)
        addTarget(self, action: #selector(touchCancel), for: [.touchUpOutside, .touchCancel])

        updateAppearance()
    }

    private func setupStandardLayout() {
        priceRowStack.addArrangedSubview(trialBadge)
        priceRowStack.addArrangedSubview(priceLabel)

        addSubview(radioImageView)
        addSubview(titleLabel)
        addSubview(priceRowStack)

        heightConstraint = heightAnchor.constraint(equalToConstant: 56)

        NSLayoutConstraint.activate([
            heightConstraint!,

            radioImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            radioImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            radioImageView.widthAnchor.constraint(equalToConstant: 22),
            radioImageView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: radioImageView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: priceRowStack.leadingAnchor, constant: -8),

            trialBadge.heightAnchor.constraint(equalToConstant: 20),

            priceRowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            priceRowStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func setupCompactLayout() {
        titleLabel.font = .captionBoldS
        priceLabel.font = .captionBoldS
        priceLabel.textAlignment = .left

        titleRowStack.addArrangedSubview(radioImageView)
        titleRowStack.addArrangedSubview(titleLabel)
        compactContentStack.addArrangedSubview(titleRowStack)
        compactContentStack.addArrangedSubview(priceLabel)

        addSubview(compactContentStack)

        heightConstraint = heightAnchor.constraint(equalToConstant: 58)

        NSLayoutConstraint.activate([
            heightConstraint!,

            radioImageView.widthAnchor.constraint(equalToConstant: 18),
            radioImageView.heightAnchor.constraint(equalToConstant: 18),

            compactContentStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            compactContentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            compactContentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            compactContentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),

            priceLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor)
        ])
    }

    private func displayTitle(for package: Package) -> String {
        switch package.packageType {
        case .annual:
            return "Annual"
        case .monthly:
            return "Monthly"
        default:
            return package.storeProduct.localizedTitle
        }
    }

    static func introOfferText(for package: Package) -> String? {
        guard package.packageType == .annual else { return nil }
        return formattedTrialDuration(for: package) ?? "3-day free trial"
    }

    private static func formattedTrialDuration(for package: Package) -> String? {
        guard let discount = package.storeProduct.introductoryDiscount else { return nil }

        let value = discount.subscriptionPeriod.value
        switch discount.subscriptionPeriod.unit {
        case .day:
            return value == 1 ? "1-day free trial" : "\(value)-day free trial"
        case .week:
            return value == 1 ? "1-week free trial" : "\(value)-week free trial"
        case .month:
            return value == 1 ? "1-month free trial" : "\(value)-month free trial"
        case .year:
            return value == 1 ? "1-year free trial" : "\(value)-year free trial"
        @unknown default:
            return "Free trial"
        }
    }

    private func updateAppearance() {
        if isOptionSelected {
            layer.borderColor = NNColors.primary.cgColor
            backgroundColor = NNColors.primaryOpaque.withAlphaComponent(0.35)
            radioImageView.tintColor = NNColors.primary
            radioImageView.image = UIImage(systemName: "largecircle.fill.circle")
        } else {
            layer.borderColor = UIColor.tertiarySystemFill.cgColor
            backgroundColor = .systemBackground
            radioImageView.tintColor = .tertiaryLabel
            radioImageView.image = UIImage(systemName: "circle")
        }
    }

    @objc private func touchDown() {
        UIView.animate(withDuration: 0.15) {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }
    }

    @objc private func touchUp() {
        UIView.animate(withDuration: 0.15) {
            self.transform = .identity
        }
    }

    @objc private func touchCancel() {
        UIView.animate(withDuration: 0.15) {
            self.transform = .identity
        }
    }
}
