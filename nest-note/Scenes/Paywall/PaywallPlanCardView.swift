//
//  PaywallPlanCardView.swift
//  nest-note
//

import UIKit
import RevenueCat

final class PaywallPlanCardView: UIControl {

    enum AppearanceStyle {
        case standard
        case darkCarousel
    }

    private(set) var package: Package?

    var appearanceStyle: AppearanceStyle = .standard {
        didSet {
            heightConstraint?.constant = preferredHeight
            updateAppearance()
            configurePriceLabels()
        }
    }

    var isPlanSelected: Bool = false {
        didSet { updateAppearance() }
    }

    private var heightConstraint: NSLayoutConstraint?

    private let selectionIndicator: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private enum LayoutMetrics {
        static let titleRowHeight: CGFloat = 20
        static let priceRowHeight: CGFloat = 20
        static let secondaryPriceRowHeight: CGFloat = 16
        static let leftTextStackHeight: CGFloat = titleRowHeight + 4 + priceRowHeight + 4 + secondaryPriceRowHeight
        static let verticalPadding: CGFloat = 14
    }

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4
        label.textColor = .label
        label.textAlignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.isUserInteractionEnabled = false
        return label
    }()

    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.isUserInteractionEnabled = false
        return label
    }()

    private let secondaryPriceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.alpha = 0
        label.text = " "
        label.isUserInteractionEnabled = false
        return label
    }()

    private let leftTextStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        stack.isUserInteractionEnabled = false
        return stack
    }()

    private var preferredHeight: CGFloat {
        LayoutMetrics.verticalPadding * 2 + LayoutMetrics.leftTextStackHeight
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
        priceSlashAnimator?.stop()
        priceSlashAnimator = nil
        pendingPriceSlash = nil
        titleLabel.text = displayTitle(for: package)
        configurePriceLabels()
        updateAppearance()
    }

    func prepareForPriceSlash(from previous: PaywallPriceSnapshot, to updated: PaywallPriceSnapshot) {
        pendingPriceSlash = (previous, updated)
        lockPriceLabelWidths(from: previous, to: updated)
        priceLabel.text = previous.primary
        setSecondaryPrice(previous.secondary)
    }

    func playPriceSlashAnimation(delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
        guard let pendingPriceSlash else {
            completion?()
            return
        }

        lockPriceLabelWidths(from: pendingPriceSlash.from, to: pendingPriceSlash.to)
        transform = .identity
        alpha = 1

        var labels: [(
            label: UILabel,
            from: String,
            to: String,
            fromAmount: Decimal?,
            toAmount: Decimal?,
            suffix: String?,
            currencyCode: String?
        )] = [
            (
                priceLabel,
                pendingPriceSlash.from.primary,
                pendingPriceSlash.to.primary,
                pendingPriceSlash.from.primaryPrice?.amount,
                pendingPriceSlash.to.primaryPrice?.amount,
                pendingPriceSlash.to.primaryPrice?.suffix,
                pendingPriceSlash.to.primaryPrice?.currencyCode
            )
        ]

        if let fromSecondary = pendingPriceSlash.from.secondary,
           let toSecondary = pendingPriceSlash.to.secondary {
            labels.append((
                secondaryPriceLabel,
                fromSecondary,
                toSecondary,
                pendingPriceSlash.from.secondaryPrice?.amount,
                pendingPriceSlash.to.secondaryPrice?.amount,
                pendingPriceSlash.to.secondaryPrice?.suffix,
                pendingPriceSlash.to.secondaryPrice?.currencyCode
            ))
            setSecondaryPrice(toSecondary)
        }

        self.pendingPriceSlash = nil
        priceSlashAnimator?.stop()
        priceSlashAnimator = PaywallPriceSlashAnimator()
        priceSlashAnimator?.animate(labels: labels, delay: delay) { [weak self] in
            guard let self, self.package != nil else {
                completion?()
                return
            }
            self.configurePriceLabels()
            completion?()
        }
    }

    static func priceSnapshot(for package: Package) -> PaywallPriceSnapshot {
        let primary: String
        let secondary: String?
        let primaryPrice: PriceAnimationComponent?
        let secondaryPrice: PriceAnimationComponent?

        let currencyCode = package.storeProduct.currencyCode
            ?? Locale.current.currency?.identifier
            ?? "USD"

        switch package.packageType {
        case .annual:
            primary = "\(package.localizedPriceString)/yr"
            secondary = package.storeProduct.localizedPricePerMonth.map { "\($0)/mo" }
            primaryPrice = PriceAnimationComponent(
                amount: package.storeProduct.price,
                suffix: "/yr",
                currencyCode: currencyCode
            )
            secondaryPrice = PriceAnimationComponent(
                amount: package.storeProduct.price / Decimal(12),
                suffix: "/mo",
                currencyCode: currencyCode
            )
        case .monthly:
            primary = "\(package.localizedPriceString)/mo"
            secondary = nil
            primaryPrice = PriceAnimationComponent(
                amount: package.storeProduct.price,
                suffix: "/mo",
                currencyCode: currencyCode
            )
            secondaryPrice = nil
        default:
            primary = package.localizedPriceString
            secondary = nil
            primaryPrice = PriceAnimationComponent(
                amount: package.storeProduct.price,
                suffix: "",
                currencyCode: currencyCode
            )
            secondaryPrice = nil
        }

        return PaywallPriceSnapshot(
            primary: primary,
            secondary: secondary,
            primaryPrice: primaryPrice,
            secondaryPrice: secondaryPrice
        )
    }

    private var priceSlashAnimator: PaywallPriceSlashAnimator?
    private var pendingPriceSlash: (from: PaywallPriceSnapshot, to: PaywallPriceSnapshot)?
    private var priceLabelWidthConstraint: NSLayoutConstraint?
    private var secondaryPriceLabelWidthConstraint: NSLayoutConstraint?

    private func setup() {
        clipsToBounds = true
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5

        leftTextStack.addArrangedSubview(titleLabel)
        leftTextStack.addArrangedSubview(priceLabel)
        leftTextStack.addArrangedSubview(secondaryPriceLabel)

        addSubview(leftTextStack)
        addSubview(selectionIndicator)

        heightConstraint = heightAnchor.constraint(equalToConstant: preferredHeight)

        NSLayoutConstraint.activate([
            heightConstraint!,

            leftTextStack.heightAnchor.constraint(equalToConstant: LayoutMetrics.leftTextStackHeight),
            titleLabel.heightAnchor.constraint(equalToConstant: LayoutMetrics.titleRowHeight),
            priceLabel.heightAnchor.constraint(equalToConstant: LayoutMetrics.priceRowHeight),
            secondaryPriceLabel.heightAnchor.constraint(equalToConstant: LayoutMetrics.secondaryPriceRowHeight),

            leftTextStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftTextStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            leftTextStack.trailingAnchor.constraint(lessThanOrEqualTo: selectionIndicator.leadingAnchor, constant: -8),

            selectionIndicator.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            selectionIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            selectionIndicator.widthAnchor.constraint(equalToConstant: 22),
            selectionIndicator.heightAnchor.constraint(equalToConstant: 22)
        ])

        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: .touchUpInside)
        addTarget(self, action: #selector(touchCancel), for: [.touchUpOutside, .touchCancel])

        updateAppearance()
    }

    private func configurePriceLabels() {
        guard let package else { return }

        switch appearanceStyle {
        case .standard, .darkCarousel:
            switch package.packageType {
            case .annual:
                priceLabel.text = "\(package.localizedPriceString)/yr"
                if let monthlyPrice = package.storeProduct.localizedPricePerMonth {
                    setSecondaryPrice("\(monthlyPrice)/mo")
                } else {
                    setSecondaryPrice(nil)
                }
            case .monthly:
                priceLabel.text = "\(package.localizedPriceString)/mo"
                setSecondaryPrice(nil)
            default:
                priceLabel.text = package.localizedPriceString
                setSecondaryPrice(nil)
            }
        }
    }

    private func setSecondaryPrice(_ text: String?) {
        if let text {
            secondaryPriceLabel.text = text
            secondaryPriceLabel.alpha = 1
        } else {
            secondaryPriceLabel.text = " "
            secondaryPriceLabel.alpha = 0
        }
    }

    private func lockPriceLabelWidths(from previous: PaywallPriceSnapshot, to updated: PaywallPriceSnapshot) {
        updateWidthConstraint(
            on: priceLabel,
            existingConstraint: &priceLabelWidthConstraint,
            texts: [previous.primary, updated.primary]
        )

        let secondaryTexts = [previous.secondary, updated.secondary].compactMap { $0 }
        if secondaryTexts.isEmpty {
            secondaryPriceLabelWidthConstraint?.isActive = false
            secondaryPriceLabelWidthConstraint = nil
        } else {
            updateWidthConstraint(
                on: secondaryPriceLabel,
                existingConstraint: &secondaryPriceLabelWidthConstraint,
                texts: secondaryTexts
            )
        }
    }

    private func updateWidthConstraint(
        on label: UILabel,
        existingConstraint: inout NSLayoutConstraint?,
        texts: [String]
    ) {
        let font = label.font ?? .systemFont(ofSize: 16, weight: .semibold)
        let maxWidth = texts
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0

        existingConstraint?.isActive = false
        let constraint = label.widthAnchor.constraint(equalToConstant: ceil(maxWidth))
        constraint.priority = .required
        constraint.isActive = true
        existingConstraint = constraint
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


    static func cardIntroOfferText(for package: Package) -> String? {
        guard let discount = package.storeProduct.introductoryDiscount else { return nil }

        let value = discount.subscriptionPeriod.value
        switch discount.subscriptionPeriod.unit {
        case .day:
            return value == 1 ? "Free for 1 day" : "Free for \(value) days"
        case .week:
            return value == 1 ? "Free for 1 week" : "Free for \(value) weeks"
        case .month:
            return value == 1 ? "Free for 1 month" : "Free for \(value) months"
        case .year:
            return value == 1 ? "Free for 1 year" : "Free for \(value) years"
        @unknown default:
            return "Free trial"
        }
    }

    static func billingDetailText(for package: Package) -> String {
        let price = package.localizedPriceString
        let hasFreeTrial = package.storeProduct.introductoryDiscount != nil

        switch package.packageType {
        case .annual:
            if hasFreeTrial {
                return "Billed at \(price)/yr after free trial."
            }
            return "Billed at \(price)/yr."
        case .monthly:
            if hasFreeTrial {
                return "Billed at \(price)/mo after free trial."
            }
            return "Billed at \(price)/mo."
        default:
            return "Billed at \(price)."
        }
    }

    private func updateAppearance() {
        let indicatorConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)

        switch appearanceStyle {
        case .standard:
            applyStandardAppearance(indicatorConfig: indicatorConfig)
        case .darkCarousel:
            applyDarkCarouselAppearance(indicatorConfig: indicatorConfig)
        }
    }

    private func applyStandardAppearance(indicatorConfig: UIImage.SymbolConfiguration) {
        secondaryPriceLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        secondaryPriceLabel.textColor = .secondaryLabel
        priceLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold)

        if isPlanSelected {
            layer.borderColor = NNColors.primary.cgColor
            layer.borderWidth = 2
            backgroundColor = NNColors.primaryOpaque.withAlphaComponent(0.2)
            titleLabel.textColor = NNColors.primary
            priceLabel.textColor = .label
            selectionIndicator.tintColor = NNColors.primary
            selectionIndicator.image = UIImage(
                systemName: "checkmark.circle.fill",
                withConfiguration: indicatorConfig
            )
        } else {
            layer.borderColor = UIColor.tertiarySystemFill.cgColor
            layer.borderWidth = 1.5
            backgroundColor = .secondarySystemGroupedBackground
            titleLabel.textColor = .label
            priceLabel.textColor = .label
            selectionIndicator.tintColor = .tertiaryLabel
            selectionIndicator.image = UIImage(
                systemName: "circle",
                withConfiguration: indicatorConfig
            )
        }
    }

    private func applyDarkCarouselAppearance(indicatorConfig: UIImage.SymbolConfiguration) {
        secondaryPriceLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        secondaryPriceLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        priceLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        priceLabel.textColor = .white

        if isPlanSelected {
            layer.borderColor = UIColor.white.cgColor
            layer.borderWidth = 2
            backgroundColor = UIColor.white.withAlphaComponent(0.22)
            titleLabel.textColor = .white
            selectionIndicator.tintColor = .white
            selectionIndicator.image = UIImage(
                systemName: "checkmark.circle.fill",
                withConfiguration: indicatorConfig
            )
        } else {
            layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
            layer.borderWidth = 1.5
            backgroundColor = UIColor.white.withAlphaComponent(0.1)
            titleLabel.textColor = UIColor.white.withAlphaComponent(0.95)
            selectionIndicator.tintColor = UIColor.white.withAlphaComponent(0.35)
            selectionIndicator.image = UIImage(
                systemName: "circle",
                withConfiguration: indicatorConfig
            )
        }
    }

    @objc private func touchDown() {
        UIView.animate(withDuration: 0.15) {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
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
