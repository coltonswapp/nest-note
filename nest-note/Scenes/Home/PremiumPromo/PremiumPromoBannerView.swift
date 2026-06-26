import UIKit
import SwiftUI

/// Reusable premium promo banner used on the owner home screen and in the experiment lab.
final class PremiumPromoBannerView: UIView {

    var onUpgradeTapped: (() -> Void)?

    private static let appIconSize: CGFloat = 52
    private static let appIconBackSize: CGFloat = 64
    private static let appIconCornerRadius: CGFloat = 12
    private static let iconStackWidth: CGFloat = 88
    private static let iconStackHeight: CGFloat = 76
    private static let carouselWidth: CGFloat = 128
    private static let laurelWidth: CGFloat = 44
    private static let titleText = PremiumPromoCopy.homeTitle
    private static let defaultSubtitle = PremiumPromoCopy.homeSubtitle
    private static let defaultVerticalPadding: CGFloat = 14
    private static let horizontalContentLeading: CGFloat = 16
    private static let horizontalTitleSubtitleSpacing: CGFloat = 2
    private static let horizontalTextToButtonSpacing: CGFloat = 8
    private static let horizontalAccessoryGap: CGFloat = 8
    private static let horizontalAccessoryTrailing: CGFloat = 10
    private static let horizontalAccessoryCenterYOffset: CGFloat = 4
    private static let carouselHeight: CGFloat = 108
    private static let centeredSubtitle = "Tools for scheduling, planning, and sitters."
    private static let iconImageViewTag = 1

    private var iconStackWidthConstraint: NSLayoutConstraint?
    private var contentTrailingToIconsConstraint: NSLayoutConstraint?
    private var contentTrailingToCarouselConstraint: NSLayoutConstraint?
    private var horizontalContentLeadingConstraint: NSLayoutConstraint?
    private var horizontalContentTopConstraint: NSLayoutConstraint?
    private var horizontalContentBottomConstraint: NSLayoutConstraint?
    private var centeredContentCenterXConstraint: NSLayoutConstraint?
    private var centeredContentLeadingConstraint: NSLayoutConstraint?
    private var centeredContentTrailingConstraint: NSLayoutConstraint?
    private var centeredContentTopConstraint: NSLayoutConstraint?
    private var centeredContentBottomConstraint: NSLayoutConstraint?
    private var appliedVariant: PremiumPromoVariant = .stackedIconsLabel

    private let cardContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let cardBackgroundView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let patternImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = false
        NNAssetHelper.configureImageView(imageView, for: .rectanglePattern, with: NNColors.primary)
        imageView.alpha = 0.11
        return imageView
    }()

    private let iconStackContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        return view
    }()

    private let lightIconCard = PremiumPromoBannerView.makeIconCard(imageName: AppIcon.main.previewImageName)
    private let darkIconCard = PremiumPromoBannerView.makeIconCard(imageName: AppIcon.dark.previewImageName)

    private let leftLaurelImageView: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 80, weight: .ultraLight)
        let imageView = UIImageView(
            image: UIImage(systemName: "laurel.leading", withConfiguration: configuration)
        )
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.tertiarySystemFill
        imageView.isHidden = true
        return imageView
    }()

    private let rightLaurelImageView: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 80, weight: .ultraLight)
        let imageView = UIImageView(
            image: UIImage(systemName: "laurel.trailing", withConfiguration: configuration)
        )
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.tertiarySystemFill
        imageView.isHidden = true
        return imageView
    }()

    private let carouselContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        view.isHidden = true
        return view
    }()

    private lazy var carouselHostingController: UIHostingController<PremiumPromoAssetCarousel> = {
        let controller = UIHostingController(rootView: PremiumPromoAssetCarousel())
        controller.view.backgroundColor = .clear
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.safeAreaRegions = []
        return controller
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = PremiumPromoBannerView.titleText
        label.font = .h3
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = PremiumPromoBannerView.defaultSubtitle
        label.font = .bodyS
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleSubtitleStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var upgradeButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = PremiumPromoCopy.learnMoreCTA
        config.baseBackgroundColor = NNColors.primary
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .captionBoldS
            return outgoing
        }

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleUpgradeTapped), for: .touchUpInside)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        configure(variant: .stackedIconsLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        variant: PremiumPromoVariant,
        ctaTitle: String = PremiumPromoCopy.learnMoreCTA,
        title: String? = nil,
        subtitle: String? = nil,
        contentVerticalPadding: CGFloat = 0
    ) {
        appliedVariant = variant
        upgradeButton.configuration?.title = ctaTitle
        applyContentVerticalPadding(contentVerticalPadding)
        applyVariant(variant)

        if let title {
            titleLabel.attributedText = nil
            titleLabel.text = title
        }
        if let subtitle {
            subtitleLabel.attributedText = nil
            subtitleLabel.text = subtitle
        }
    }

    private func applyContentVerticalPadding(_ extraPadding: CGFloat) {
        let padding = Self.defaultVerticalPadding + extraPadding
        horizontalContentTopConstraint?.constant = padding
        horizontalContentBottomConstraint?.constant = -padding
        centeredContentTopConstraint?.constant = 16 + extraPadding
        centeredContentBottomConstraint?.constant = -(16 + extraPadding)
    }

    private func setupView() {
        titleSubtitleStack.addArrangedSubview(titleLabel)
        titleSubtitleStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(titleSubtitleStack)
        contentStack.addArrangedSubview(upgradeButton)
        contentStack.setCustomSpacing(Self.horizontalTextToButtonSpacing, after: titleSubtitleStack)

        addSubview(cardContainer)
        cardContainer.addSubview(cardBackgroundView)
        cardBackgroundView.addSubview(patternImageView)
        cardContainer.addSubview(leftLaurelImageView)
        cardContainer.addSubview(rightLaurelImageView)
        cardContainer.addSubview(contentStack)
        cardContainer.addSubview(iconStackContainer)
        cardContainer.addSubview(carouselContainer)
        iconStackContainer.addSubview(lightIconCard)
        iconStackContainer.addSubview(darkIconCard)
        carouselContainer.addSubview(carouselHostingController.view)
        cardBackgroundView.sendSubviewToBack(patternImageView)

        patternImageView.transform = CGAffineTransform(rotationAngle: 30 * .pi / 180)

        let iconStackWidthConstraint = iconStackContainer.widthAnchor.constraint(equalToConstant: Self.iconStackWidth)
        self.iconStackWidthConstraint = iconStackWidthConstraint

        let contentTrailingToIconsConstraint = contentStack.trailingAnchor.constraint(
            lessThanOrEqualTo: iconStackContainer.leadingAnchor,
            constant: -Self.horizontalAccessoryGap
        )
        let contentTrailingToCarouselConstraint = contentStack.trailingAnchor.constraint(
            lessThanOrEqualTo: carouselContainer.leadingAnchor,
            constant: -Self.horizontalAccessoryGap
        )
        self.contentTrailingToIconsConstraint = contentTrailingToIconsConstraint
        self.contentTrailingToCarouselConstraint = contentTrailingToCarouselConstraint

        let horizontalContentLeadingConstraint = contentStack.leadingAnchor.constraint(
            equalTo: cardContainer.leadingAnchor,
            constant: Self.horizontalContentLeading
        )
        let horizontalContentTopConstraint = contentStack.topAnchor.constraint(
            equalTo: cardContainer.topAnchor,
            constant: Self.defaultVerticalPadding
        )
        let horizontalContentBottomConstraint = contentStack.bottomAnchor.constraint(
            equalTo: cardContainer.bottomAnchor,
            constant: -Self.defaultVerticalPadding
        )
        self.horizontalContentLeadingConstraint = horizontalContentLeadingConstraint
        self.horizontalContentTopConstraint = horizontalContentTopConstraint
        self.horizontalContentBottomConstraint = horizontalContentBottomConstraint

        let centeredContentCenterXConstraint = contentStack.centerXAnchor.constraint(equalTo: cardContainer.centerXAnchor)
        let centeredContentLeadingConstraint = contentStack.leadingAnchor.constraint(
            greaterThanOrEqualTo: leftLaurelImageView.trailingAnchor,
            constant: 4
        )
        let centeredContentTrailingConstraint = contentStack.trailingAnchor.constraint(
            lessThanOrEqualTo: rightLaurelImageView.leadingAnchor,
            constant: -4
        )
        let centeredContentTopConstraint = contentStack.topAnchor.constraint(
            equalTo: cardContainer.topAnchor,
            constant: 16
        )
        let centeredContentBottomConstraint = contentStack.bottomAnchor.constraint(
            equalTo: cardContainer.bottomAnchor,
            constant: -16
        )
        self.centeredContentCenterXConstraint = centeredContentCenterXConstraint
        self.centeredContentLeadingConstraint = centeredContentLeadingConstraint
        self.centeredContentTrailingConstraint = centeredContentTrailingConstraint
        self.centeredContentTopConstraint = centeredContentTopConstraint
        self.centeredContentBottomConstraint = centeredContentBottomConstraint

        NSLayoutConstraint.activate([
            cardContainer.topAnchor.constraint(equalTo: topAnchor),
            cardContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            cardBackgroundView.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            cardBackgroundView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            cardBackgroundView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            cardBackgroundView.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),

            patternImageView.trailingAnchor.constraint(equalTo: cardBackgroundView.trailingAnchor, constant: 32),
            patternImageView.topAnchor.constraint(equalTo: cardBackgroundView.topAnchor, constant: -24),
            patternImageView.bottomAnchor.constraint(equalTo: cardBackgroundView.bottomAnchor, constant: 24),
            patternImageView.widthAnchor.constraint(equalToConstant: 140),

            leftLaurelImageView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 8),
            leftLaurelImageView.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 6),
            leftLaurelImageView.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -6),
            leftLaurelImageView.widthAnchor.constraint(equalToConstant: Self.laurelWidth),

            rightLaurelImageView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -8),
            rightLaurelImageView.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 6),
            rightLaurelImageView.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -6),
            rightLaurelImageView.widthAnchor.constraint(equalToConstant: Self.laurelWidth),

            iconStackContainer.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -Self.horizontalAccessoryTrailing),
            iconStackContainer.centerYAnchor.constraint(equalTo: cardContainer.centerYAnchor, constant: Self.horizontalAccessoryCenterYOffset),
            iconStackWidthConstraint,
            iconStackContainer.heightAnchor.constraint(equalToConstant: Self.iconStackHeight),

            lightIconCard.centerXAnchor.constraint(equalTo: iconStackContainer.centerXAnchor),
            lightIconCard.centerYAnchor.constraint(equalTo: iconStackContainer.centerYAnchor),
            lightIconCard.widthAnchor.constraint(equalToConstant: Self.appIconBackSize),
            lightIconCard.heightAnchor.constraint(equalToConstant: Self.appIconBackSize),

            darkIconCard.centerXAnchor.constraint(equalTo: iconStackContainer.centerXAnchor),
            darkIconCard.centerYAnchor.constraint(equalTo: iconStackContainer.centerYAnchor),
            darkIconCard.widthAnchor.constraint(equalToConstant: Self.appIconSize),
            darkIconCard.heightAnchor.constraint(equalToConstant: Self.appIconSize),

            carouselContainer.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -Self.horizontalAccessoryTrailing),
            carouselContainer.centerYAnchor.constraint(equalTo: cardContainer.centerYAnchor, constant: Self.horizontalAccessoryCenterYOffset),
            carouselContainer.widthAnchor.constraint(equalToConstant: Self.carouselWidth),
            carouselContainer.heightAnchor.constraint(equalToConstant: Self.carouselHeight),

            carouselHostingController.view.topAnchor.constraint(equalTo: carouselContainer.topAnchor),
            carouselHostingController.view.leadingAnchor.constraint(equalTo: carouselContainer.leadingAnchor),
            carouselHostingController.view.trailingAnchor.constraint(equalTo: carouselContainer.trailingAnchor),
            carouselHostingController.view.bottomAnchor.constraint(equalTo: carouselContainer.bottomAnchor),
        ])

        applyLayoutStyle(.horizontalIcons)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateIconAppearance()
        cardBackgroundView.layer.borderColor = appliedVariant.cardBorderColor?.cgColor
    }

    /// Re-applies icon shadows after the view has its final bounds (e.g. from a hosting cell's `layoutSubviews`).
    func refreshIconShadows() {
        layoutIfNeeded()
        updateIconAppearance()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateIconAppearance()
        cardBackgroundView.layer.borderColor = appliedVariant.cardBorderColor?.cgColor
    }

    private func applyVariant(_ variant: PremiumPromoVariant) {
        titleLabel.font = variant.titleFont
        titleLabel.textColor = variant.titleColor
        subtitleLabel.isHidden = !variant.showsSubtitle
        patternImageView.isHidden = !variant.showsPattern

        cardBackgroundView.backgroundColor = variant.cardBackgroundColor
        cardBackgroundView.layer.cornerRadius = variant.cardCornerRadius
        cardBackgroundView.layer.borderWidth = variant.cardBorderWidth
        cardBackgroundView.layer.borderColor = variant.cardBorderColor?.cgColor

        applyLayoutStyle(variant.layoutStyle)
        setNeedsLayout()
        layoutIfNeeded()
        updateIconAppearance()
    }

    private func applyLayoutStyle(_ style: PremiumPromoLayoutStyle) {
        switch style {
        case .horizontalIcons:
            applyHorizontalContentLayout()
            leftLaurelImageView.isHidden = true
            rightLaurelImageView.isHidden = true
            iconStackContainer.isHidden = false
            carouselContainer.isHidden = true
            iconStackWidthConstraint?.constant = Self.iconStackWidth
            lightIconCard.isHidden = false
            darkIconCard.isHidden = false
            applyStackedIconTransforms()
        case .centeredLaurels:
            applyCenteredContentLayout()
            leftLaurelImageView.isHidden = false
            rightLaurelImageView.isHidden = false
            iconStackContainer.isHidden = true
            carouselContainer.isHidden = true
        case .landingCarousel:
            applyHorizontalContentLayout()
            leftLaurelImageView.isHidden = true
            rightLaurelImageView.isHidden = true
            iconStackContainer.isHidden = true
            carouselContainer.isHidden = false
        }
    }

    private func applyHorizontalContentLayout() {
        contentStack.alignment = .leading
        contentStack.distribution = .fill
        titleSubtitleStack.alignment = .leading
        titleSubtitleStack.spacing = Self.horizontalTitleSubtitleSpacing
        titleLabel.textAlignment = .natural
        subtitleLabel.textAlignment = .natural
        subtitleLabel.transform = .identity
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        subtitleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleSubtitleStack.setContentHuggingPriority(.required, for: .vertical)
        applyPlainPromoText(alignment: .natural)
        contentStack.setCustomSpacing(Self.horizontalTextToButtonSpacing, after: titleSubtitleStack)

        centeredContentCenterXConstraint?.isActive = false
        centeredContentLeadingConstraint?.isActive = false
        centeredContentTrailingConstraint?.isActive = false
        centeredContentTopConstraint?.isActive = false
        centeredContentBottomConstraint?.isActive = false

        horizontalContentLeadingConstraint?.isActive = true
        horizontalContentTopConstraint?.isActive = true
        horizontalContentBottomConstraint?.isActive = false

        contentTrailingToCarouselConstraint?.isActive = false
        contentTrailingToIconsConstraint?.isActive = false

        switch appliedVariant.layoutStyle {
        case .horizontalIcons:
            contentTrailingToIconsConstraint?.isActive = true
        case .landingCarousel:
            contentTrailingToCarouselConstraint?.isActive = true
        case .centeredLaurels:
            break
        }
    }

    private func applyCenteredContentLayout() {
        contentStack.alignment = .center
        titleSubtitleStack.alignment = .center
        titleSubtitleStack.spacing = -16
        titleLabel.textAlignment = .center
        subtitleLabel.textAlignment = .center
        subtitleLabel.transform = .identity
        applyCenteredPromoText()
        contentStack.setCustomSpacing(8, after: titleSubtitleStack)

        horizontalContentLeadingConstraint?.isActive = false
        horizontalContentTopConstraint?.isActive = false
        horizontalContentBottomConstraint?.isActive = false
        contentTrailingToIconsConstraint?.isActive = false
        contentTrailingToCarouselConstraint?.isActive = false

        centeredContentCenterXConstraint?.isActive = true
        centeredContentLeadingConstraint?.isActive = true
        centeredContentTrailingConstraint?.isActive = true
        centeredContentTopConstraint?.isActive = true
        centeredContentBottomConstraint?.isActive = true
    }

    private func applyPlainPromoText(alignment: NSTextAlignment) {
        titleLabel.attributedText = nil
        subtitleLabel.attributedText = nil
        titleLabel.text = Self.titleText
        titleLabel.textColor = appliedVariant.titleColor
        subtitleLabel.text = Self.defaultSubtitle
        subtitleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = alignment
        subtitleLabel.textAlignment = alignment
    }

    private func applyCenteredPromoText() {
        titleLabel.attributedText = nil
        subtitleLabel.attributedText = nil
        titleLabel.text = Self.titleText
        titleLabel.textColor = appliedVariant.titleColor
        subtitleLabel.text = Self.centeredSubtitle
        subtitleLabel.textColor = .secondaryLabel
    }

    private func applyStackedIconTransforms() {
        lightIconCard.transform = Self.iconTransform(offsetX: -14, offsetY: -8, rotationDegrees: 8)
        darkIconCard.transform = Self.iconTransform(offsetX: 12, offsetY: 4, rotationDegrees: -6)
    }

    private func updateIconAppearance() {
        for card in [lightIconCard, darkIconCard] {
            guard let imageView = card.viewWithTag(Self.iconImageViewTag) as? UIImageView else { continue }
            imageView.layer.borderColor = UIColor.tertiarySystemBackground.cgColor

            guard !card.bounds.isEmpty else {
                card.layer.shadowPath = nil
                continue
            }

            card.layer.shadowPath = UIBezierPath(
                roundedRect: card.bounds,
                cornerRadius: Self.appIconCornerRadius
            ).cgPath
        }
    }

    private static func makeIconCard(imageName: String) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.2
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 10
        card.layer.masksToBounds = false

        let imageView = UIImageView()
        imageView.tag = iconImageViewTag
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: imageName)
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = appIconCornerRadius
        imageView.layer.cornerCurve = .continuous
        imageView.layer.borderWidth = 2
        imageView.clipsToBounds = true

        card.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: card.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return card
    }

    private static func iconTransform(
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0,
        rotationDegrees: CGFloat = 0
    ) -> CGAffineTransform {
        let radians = rotationDegrees * .pi / 180
        return CGAffineTransform(translationX: offsetX, y: offsetY).rotated(by: radians)
    }

    @objc private func handleUpgradeTapped() {
        HapticsHelper.lightHaptic()
        onUpgradeTapped?()
    }
}
