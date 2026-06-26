//
//  CarouselFeaturePaywallViewController.swift
//  nest-note
//

import UIKit
import RevenueCat
import SafariServices

private enum CarouselFeaturePaywallStage {
    case features
    case checkout
}

final class CarouselFeaturePaywallViewController: NNViewController {

    private static let featuresCardToScreenRatio: CGFloat = 0.30
    private static let checkoutCardToScreenRatio: CGFloat = 0.22

    /// When set, the paywall runs in onboarding mode and calls back instead of dismissing modally.
    var onPaywallFinished: ((Bool) -> Void)? {
        didSet {
            showsDelayedCloseButton = onPaywallFinished != nil
        }
    }

    var currentReferralCode: String? { appliedReferralCode }

    private var showsDelayedCloseButton = false
    private var hasAnimatedCloseButton = false

    private final class PassThroughView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let hitView = super.hitTest(point, with: event)
            return hitView === self ? nil : hitView
        }
    }

    private final class ReferralEntryState: ReferralCodeEntryPresenting {
        var referralCodeInput = ""
        var referralCodeError: String?
        var isLoading = false
        var onApplyReferralCode: (String) -> Void = { _ in }
    }

    private let bottomBlurFadeHeight: CGFloat = 20
    private let footerHeight: CGFloat = 36

    private var planCardViews: [PaywallPlanCardView] = []
    private var selectedPackage: Package?
    private var loadedPackages: [Package] = []
    private var appliedReferralCode: String?
    private var appliedReferralCodeType: ReferralCodeType?

    private var usesCreatorPartnerPricing: Bool {
        appliedReferralCode != nil && (appliedReferralCodeType ?? .creator) == .creator
    }
    private let referralState = ReferralEntryState()
    private var referralSheetController: ReferralCodeEntryViewController?
    private var stage: CarouselFeaturePaywallStage = .features
    private var standardComparisonPackages: [PackageType: Package] = [:]
    private var prefetchedPartnerPackages: [Package] = []
    private var loadingIndicatorConstraints: [NSLayoutConstraint] = []

    private let ambientBackgroundView: PaywallAmbientBackgroundView = {
        let view = PaywallAmbientBackgroundView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 0
        stack.alignment = .fill
        return stack
    }()

    private let bottomPanelContainer: PassThroughView = {
        let view = PassThroughView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.clipsToBounds = false
        return view
    }()

    private let checkoutPanel: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private let checkoutStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        return stack
    }()

    private let featuresPanelStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .fill
        return stack
    }()

    private static let iconSize: CGFloat = 64
    private static let iconCornerRadius: CGFloat = 12

    private let iconStackContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        return view
    }()

    private static let iconFanOffsetX: CGFloat = 42
    private static let iconStackWidth: CGFloat = 156
    private static let iconStackHeight: CGFloat = 72

    private let backIconLeftCard: UIView = {
        makeIconCard(imageName: AppIcon.main.previewImageName)
    }()

    private let backIconRightCard: UIView = {
        makeIconCard(imageName: AppIcon.green.previewImageName)
    }()

    private let iconCard: UIView = {
        makeIconCard(imageName: AppIcon.dark.previewImageName)
    }()

    private var hasAnimatedIconStack = false

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Upgrade to Premium"
        label.font = .h1
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var carouselView: PaywallFeatureCarouselView = {
        let view = PaywallFeatureCarouselView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.cardHeight = Self.featuresCardHeight
        view.onPageChanged = { [weak self] _, card in
            self?.updateActiveFeatureCaption(for: card, animated: true)
            self?.ambientBackgroundView.setActiveCard(card, animated: true)
        }
        return view
    }()

    private let captionTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let captionDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = UIColor.white.withAlphaComponent(0.65)
        label.textAlignment = .center
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let captionContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let plansContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let packagesStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.isUserInteractionEnabled = true
        return stack
    }()

    private let trialInfoLabel: UILabel = {
        let label = UILabel()
        label.font = .captionBoldS
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var referralButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(referralTapped), for: .touchUpInside)

        let ticketConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "ticket.fill", withConfiguration: ticketConfig)
        config.title = "Have a referral code?"
        config.imagePadding = 8
        config.baseForegroundColor = .white
        config.background.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        config.background.cornerRadius = 27.5
        config.background.strokeColor = UIColor.white.withAlphaComponent(0.4)
        config.background.strokeWidth = 1.5
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 15, weight: .semibold)
            return outgoing
        }
        button.configuration = config
        return button
    }()

    private let appliedReferralLabel: UILabel = {
        let label = UILabel()
        label.font = .captionBoldS
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var bottomBlurView: UIVisualEffectView = {
        let blur = UIVisualEffectView()
        if let maskImage = UIImage(named: "testBG3") {
            blur.effect = UIBlurEffect.variableBlurEffect(radius: 16, maskImage: maskImage)
        } else {
            blur.effect = UIBlurEffect(style: .dark)
        }
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.isUserInteractionEnabled = false
        return blur
    }()

    private let footerLinksStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        return stack
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Try Again", for: .normal)
        button.titleLabel?.font = .h4
        button.tintColor = .white
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        return button
    }()

    private lazy var continueButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Continue")
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(primaryActionTapped), for: .touchUpInside)
        return button
    }()

    private lazy var upgradeButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Upgrade Now")
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(primaryActionTapped), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()

    private lazy var termsButton: UIButton = makeFooterLinkButton(title: "Terms", action: #selector(termsTapped))
    private lazy var privacyButton: UIButton = makeFooterLinkButton(title: "Privacy", action: #selector(privacyTapped))
    private lazy var restoreButton: UIButton = makeFooterLinkButton(title: "Restore", action: #selector(restoreTapped))

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.alpha = 0
        button.isHidden = true
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        var config = UIButton.Configuration.plain()
        config.image = UIImage(
            systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        )
        config.baseForegroundColor = UIColor.white.withAlphaComponent(0.85)
        config.background.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        config.background.cornerRadius = 16
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        button.configuration = config
        return button
    }()

    private static var featuresCardHeight: CGFloat {
        UIScreen.main.bounds.height * featuresCardToScreenRatio
    }

    private static var checkoutCardHeight: CGFloat {
        UIScreen.main.bounds.height * checkoutCardToScreenRatio
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindReferralHandlers()
        setupView()
        updateStageUI()
        updateLoadingIndicatorPosition()

        if let firstCard = paywallFeatureCarouselCards.first {
            updateActiveFeatureCaption(for: firstCard, animated: false)
            ambientBackgroundView.setActiveCard(firstCard, animated: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIconStackFanOutIfNeeded()
        animateCloseButtonAppearanceIfNeeded()
    }

    private static func makeIconCard(imageName: String) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: imageName)
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = iconCornerRadius
        imageView.layer.cornerCurve = .continuous
        imageView.clipsToBounds = true
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.white.cgColor

        card.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: card.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.2
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 10
        card.layer.shadowPath = UIBezierPath(
            roundedRect: CGRect(origin: .zero, size: CGSize(width: iconSize, height: iconSize)),
            cornerRadius: iconCornerRadius
        ).cgPath

        return card
    }

    private static func iconTransform(
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0,
        rotationDegrees: CGFloat = 0,
        scale: CGFloat = 1
    ) -> CGAffineTransform {
        let radians = rotationDegrees * .pi / 180
        return CGAffineTransform(translationX: offsetX, y: offsetY)
            .rotated(by: radians)
            .scaledBy(x: scale, y: scale)
    }

    private func animateIconStackFanOutIfNeeded() {
        guard !hasAnimatedIconStack else { return }
        hasAnimatedIconStack = true

        let stackedScale: CGFloat = 0.94

        UIView.animate(
            withDuration: 0.22,
            delay: 0.4,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            let stacked = Self.iconTransform(scale: stackedScale)
            self.backIconLeftCard.transform = stacked
            self.backIconRightCard.transform = stacked
            self.iconCard.transform = stacked
        } completion: { _ in
            HapticsHelper.superLightHaptic()
            self.triggerIconStackFanOutExplosion()

            UIView.animate(
                withDuration: 0.65,
                delay: 0,
                usingSpringWithDamping: 0.72,
                initialSpringVelocity: 0.55,
                options: [.allowUserInteraction]
            ) {
                self.backIconLeftCard.transform = Self.iconTransform(
                    offsetX: -Self.iconFanOffsetX,
                    rotationDegrees: -14,
                    scale: stackedScale
                )
                self.backIconRightCard.transform = Self.iconTransform(
                    offsetX: Self.iconFanOffsetX,
                    rotationDegrees: 14,
                    scale: stackedScale
                )
                self.iconCard.transform = Self.iconTransform(offsetY: -5, scale: 1)
            }
        }
    }

    private func triggerIconStackFanOutExplosion() {
        view.layoutIfNeeded()

        let explosionCenter = CGPoint(x: iconStackContainer.bounds.midX, y: iconStackContainer.bounds.midY)
        let explosionPoint: CGPoint
        if let window = view.window {
            explosionPoint = iconStackContainer.convert(explosionCenter, to: window)
        } else {
            explosionPoint = iconStackContainer.convert(explosionCenter, to: view)
        }

        ExplosionManager.trigger(.tiny, at: explosionPoint)
    }

    private func bindReferralHandlers() {
        referralState.onApplyReferralCode = { [weak self] code in
            self?.applyReferralCode(code)
        }
    }

    private func makeFooterLinkButton(title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = UIColor.white.withAlphaComponent(0.65)
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        var titleAttributes = AttributeContainer()
        titleAttributes.font = .captionBoldS
        config.attributedTitle = AttributedString(title, attributes: titleAttributes)

        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func setupView() {
        view.backgroundColor = .clear

        view.addSubview(ambientBackgroundView)
        view.addSubview(contentStack)
        view.addSubview(bottomPanelContainer)
        bottomPanelContainer.addSubview(bottomBlurView)
        bottomPanelContainer.addSubview(continueButton)
        bottomPanelContainer.addSubview(featuresPanelStack)
        bottomPanelContainer.addSubview(checkoutPanel)
        checkoutPanel.addSubview(checkoutStack)

        view.addSubview(loadingIndicator)
        view.addSubview(errorLabel)
        view.addSubview(retryButton)

        let iconWrapper = UIView()
        iconWrapper.translatesAutoresizingMaskIntoConstraints = false
        iconWrapper.addSubview(iconStackContainer)
        iconStackContainer.addSubview(backIconLeftCard)
        iconStackContainer.addSubview(backIconRightCard)
        iconStackContainer.addSubview(iconCard)

        captionContainer.addSubview(captionTitleLabel)
        captionContainer.addSubview(captionDescriptionLabel)

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        contentStack.addArrangedSubview(iconWrapper)
        contentStack.addArrangedSubview(titleLabel)

        view.addSubview(carouselView)
        view.addSubview(captionContainer)
        view.addSubview(spacer)

        contentStack.setCustomSpacing(24, after: iconWrapper)

        featuresPanelStack.addArrangedSubview(referralButton)
        featuresPanelStack.addArrangedSubview(appliedReferralLabel)

        checkoutStack.addArrangedSubview(plansContainer)
        checkoutStack.addArrangedSubview(trialInfoLabel)
        checkoutStack.addArrangedSubview(upgradeButton)

        plansContainer.clipsToBounds = false
        packagesStack.clipsToBounds = false
        plansContainer.addSubview(packagesStack)

        view.addSubview(footerLinksStack)
        footerLinksStack.addArrangedSubview(termsButton)
        footerLinksStack.addArrangedSubview(privacyButton)
        footerLinksStack.addArrangedSubview(restoreButton)

        if showsDelayedCloseButton {
            closeButton.isHidden = false
            view.addSubview(closeButton)
        }

        NSLayoutConstraint.activate([
            ambientBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            ambientBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ambientBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ambientBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            carouselView.topAnchor.constraint(equalTo: contentStack.bottomAnchor, constant: 20),
            carouselView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            carouselView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            captionContainer.topAnchor.constraint(equalTo: carouselView.bottomAnchor, constant: 8),
            captionContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            captionContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            spacer.topAnchor.constraint(equalTo: captionContainer.bottomAnchor),
            spacer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            spacer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            spacer.bottomAnchor.constraint(equalTo: bottomPanelContainer.topAnchor),

            iconStackContainer.centerXAnchor.constraint(equalTo: iconWrapper.centerXAnchor),
            iconStackContainer.topAnchor.constraint(equalTo: iconWrapper.topAnchor),
            iconStackContainer.bottomAnchor.constraint(equalTo: iconWrapper.bottomAnchor),
            iconStackContainer.widthAnchor.constraint(equalToConstant: Self.iconStackWidth),
            iconStackContainer.heightAnchor.constraint(equalToConstant: Self.iconStackHeight),

            backIconLeftCard.centerXAnchor.constraint(equalTo: iconStackContainer.centerXAnchor),
            backIconLeftCard.centerYAnchor.constraint(equalTo: iconStackContainer.centerYAnchor),
            backIconLeftCard.widthAnchor.constraint(equalToConstant: Self.iconSize),
            backIconLeftCard.heightAnchor.constraint(equalToConstant: Self.iconSize),

            backIconRightCard.centerXAnchor.constraint(equalTo: iconStackContainer.centerXAnchor),
            backIconRightCard.centerYAnchor.constraint(equalTo: iconStackContainer.centerYAnchor),
            backIconRightCard.widthAnchor.constraint(equalToConstant: Self.iconSize),
            backIconRightCard.heightAnchor.constraint(equalToConstant: Self.iconSize),

            iconCard.centerXAnchor.constraint(equalTo: iconStackContainer.centerXAnchor),
            iconCard.centerYAnchor.constraint(equalTo: iconStackContainer.centerYAnchor),
            iconCard.widthAnchor.constraint(equalToConstant: Self.iconSize),
            iconCard.heightAnchor.constraint(equalToConstant: Self.iconSize),

            captionTitleLabel.topAnchor.constraint(equalTo: captionContainer.topAnchor),
            captionTitleLabel.leadingAnchor.constraint(equalTo: captionContainer.leadingAnchor),
            captionTitleLabel.trailingAnchor.constraint(equalTo: captionContainer.trailingAnchor),
            captionTitleLabel.heightAnchor.constraint(equalToConstant: 22),

            captionDescriptionLabel.topAnchor.constraint(equalTo: captionTitleLabel.bottomAnchor, constant: 6),
            captionDescriptionLabel.leadingAnchor.constraint(equalTo: captionContainer.leadingAnchor),
            captionDescriptionLabel.trailingAnchor.constraint(equalTo: captionContainer.trailingAnchor),
            captionDescriptionLabel.bottomAnchor.constraint(equalTo: captionContainer.bottomAnchor),
            captionDescriptionLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),

            bottomPanelContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanelContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPanelContainer.bottomAnchor.constraint(equalTo: footerLinksStack.topAnchor),

            bottomBlurView.leadingAnchor.constraint(equalTo: bottomPanelContainer.leadingAnchor),
            bottomBlurView.trailingAnchor.constraint(equalTo: bottomPanelContainer.trailingAnchor),
            bottomBlurView.bottomAnchor.constraint(equalTo: bottomPanelContainer.bottomAnchor),
            bottomBlurView.topAnchor.constraint(equalTo: bottomPanelContainer.topAnchor, constant: -bottomBlurFadeHeight),

            continueButton.leadingAnchor.constraint(equalTo: bottomPanelContainer.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: bottomPanelContainer.trailingAnchor, constant: -20),
            continueButton.bottomAnchor.constraint(equalTo: bottomPanelContainer.bottomAnchor, constant: -12),
            continueButton.heightAnchor.constraint(equalToConstant: 55),

            featuresPanelStack.leadingAnchor.constraint(equalTo: bottomPanelContainer.leadingAnchor, constant: 20),
            featuresPanelStack.trailingAnchor.constraint(equalTo: bottomPanelContainer.trailingAnchor, constant: -20),
            featuresPanelStack.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -12),

            referralButton.heightAnchor.constraint(equalToConstant: 55),

            checkoutPanel.topAnchor.constraint(equalTo: bottomPanelContainer.topAnchor),
            checkoutPanel.leadingAnchor.constraint(equalTo: bottomPanelContainer.leadingAnchor),
            checkoutPanel.trailingAnchor.constraint(equalTo: bottomPanelContainer.trailingAnchor),
            checkoutPanel.bottomAnchor.constraint(equalTo: bottomPanelContainer.bottomAnchor),

            checkoutStack.topAnchor.constraint(equalTo: checkoutPanel.topAnchor, constant: 12),
            checkoutStack.leadingAnchor.constraint(equalTo: checkoutPanel.leadingAnchor, constant: 20),
            checkoutStack.trailingAnchor.constraint(equalTo: checkoutPanel.trailingAnchor, constant: -20),
            checkoutStack.bottomAnchor.constraint(equalTo: checkoutPanel.bottomAnchor),

            upgradeButton.heightAnchor.constraint(equalToConstant: 55),

            footerLinksStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            footerLinksStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            footerLinksStack.heightAnchor.constraint(equalToConstant: footerHeight),

            plansContainer.heightAnchor.constraint(equalToConstant: 88),
            packagesStack.topAnchor.constraint(equalTo: plansContainer.topAnchor),
            packagesStack.leadingAnchor.constraint(equalTo: plansContainer.leadingAnchor),
            packagesStack.trailingAnchor.constraint(equalTo: plansContainer.trailingAnchor),
            packagesStack.bottomAnchor.constraint(equalTo: plansContainer.bottomAnchor),

            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            errorLabel.centerYAnchor.constraint(equalTo: bottomPanelContainer.centerYAnchor),

            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 12),
            retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        if showsDelayedCloseButton {
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
                closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                closeButton.widthAnchor.constraint(equalToConstant: 32),
                closeButton.heightAnchor.constraint(equalToConstant: 32),
            ])
        }

        view.bringSubviewToFront(contentStack)
        view.bringSubviewToFront(carouselView)
        view.bringSubviewToFront(captionContainer)
        view.bringSubviewToFront(bottomPanelContainer)
        view.bringSubviewToFront(loadingIndicator)
        view.bringSubviewToFront(errorLabel)
        view.bringSubviewToFront(retryButton)
        view.bringSubviewToFront(footerLinksStack)
        if showsDelayedCloseButton {
            view.bringSubviewToFront(closeButton)
        }

        prepareCheckoutPanelOffscreen()
    }

    private func updateActiveFeatureCaption(for card: PaywallFeatureCarouselCard, animated: Bool) {
        let updates = {
            self.captionTitleLabel.text = card.feature.displayName
            self.captionDescriptionLabel.text = card.feature.description
        }

        if animated {
            UIView.transition(with: captionContainer, duration: 0.35, options: .transitionCrossDissolve) {
                updates()
            }
        } else {
            updates()
        }
    }

    private func prepareCheckoutPanelOffscreen() {
        view.layoutIfNeeded()
        checkoutPanel.transform = CGAffineTransform(translationX: view.bounds.width, y: 0)
        checkoutPanel.alpha = 1
        continueButton.alpha = 1
        continueButton.isHidden = false
        featuresPanelStack.alpha = 1
        featuresPanelStack.isHidden = false
    }

    private func updateStageUI() {
        checkoutPanel.isUserInteractionEnabled = stage == .checkout
        continueButton.isEnabled = !referralState.isLoading && stage == .features
        continueButton.isHidden = stage == .checkout
        featuresPanelStack.isHidden = stage == .checkout
        upgradeButton.isEnabled = !referralState.isLoading && selectedPackage != nil
        carouselView.isInteractionEnabledForCarousel = stage == .features
        updateLoadingIndicatorPosition()
    }

    private func updateLoadingIndicatorPosition() {
        NSLayoutConstraint.deactivate(loadingIndicatorConstraints)

        let anchorView = stage == .features ? continueButton : upgradeButton
        loadingIndicatorConstraints = [
            loadingIndicator.centerXAnchor.constraint(equalTo: anchorView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: anchorView.centerYAnchor),
        ]
        NSLayoutConstraint.activate(loadingIndicatorConstraints)
    }

    private func continueToCheckout() {
        setLoading(true)
        hideError()

        Task {
            do {
                let sorted: [Package]
                if usesCreatorPartnerPricing, !prefetchedPartnerPackages.isEmpty {
                    sorted = prefetchedPartnerPackages
                } else {
                    let offeringIdentifier = usesCreatorPartnerPricing ? "partner" : nil
                    let offering = try await SubscriptionService.shared.fetchOffering(identifier: offeringIdentifier)
                    sorted = Self.filteredPaywallPackages(from: offering)
                }

                guard !sorted.isEmpty else {
                    await MainActor.run {
                        setLoading(false)
                        showError(usesCreatorPartnerPricing
                            ? "Partner plans aren't available right now."
                            : "No subscription plans are available right now.")
                    }
                    return
                }

                let shouldSlashPrices = usesCreatorPartnerPricing && !standardComparisonPackages.isEmpty

                await MainActor.run {
                    configurePackages(sorted, animatePriceSlash: shouldSlashPrices)
                    stage = .checkout
                    setLoading(false)
                    updateStageUI()
                    view.layoutIfNeeded()
                    animateToCheckout(shouldSlashPrices: shouldSlashPrices)
                }
            } catch {
                await MainActor.run {
                    setLoading(false)
                    showError(error.localizedDescription)
                }
            }
        }
    }

    private static func filteredPaywallPackages(from offering: Offering) -> [Package] {
        offering.availablePackages
            .filter { $0.packageType == .monthly || $0.packageType == .annual }
            .sorted { lhs, _ in lhs.packageType == .monthly }
    }

    private func prefetchComparisonPackages() {
        Task {
            do {
                async let standardOffering = SubscriptionService.shared.fetchOffering(identifier: nil)
                async let partnerOffering = SubscriptionService.shared.fetchOffering(identifier: "partner")

                let standard = try await standardOffering
                let partner = try await partnerOffering

                await MainActor.run {
                    standardComparisonPackages = Dictionary(
                        uniqueKeysWithValues: Self.filteredPaywallPackages(from: standard).map { ($0.packageType, $0) }
                    )
                    prefetchedPartnerPackages = Self.filteredPaywallPackages(from: partner)
                }
            } catch {
                Logger.log(
                    level: .error,
                    category: .purchases,
                    message: "Failed to prefetch partner comparison packages: \(error.localizedDescription)"
                )
            }
        }
    }

    private func animateToCheckout(shouldSlashPrices: Bool = false) {
        prepareCheckoutPanelOffscreen()

        UIView.animate(
            withDuration: 0.55,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.4,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            self.checkoutPanel.transform = .identity
            self.continueButton.alpha = 0
            self.featuresPanelStack.alpha = 0
            self.carouselView.cardHeight = Self.checkoutCardHeight
        } completion: { _ in
            self.continueButton.isHidden = true
            self.featuresPanelStack.isHidden = true
            if shouldSlashPrices {
                self.playPartnerPriceSlashAnimations()
            }
        }
    }

    private func playPartnerPriceSlashAnimations() {
        var delay: TimeInterval = 0.05
        for cardView in planCardViews {
            cardView.playPriceSlashAnimation(delay: delay)
            delay += 0.12
        }
    }

    private func transitionToPartnerPricingWithAnimation() {
        Task {
            do {
                let partnerPackages: [Package]
                if !prefetchedPartnerPackages.isEmpty {
                    partnerPackages = prefetchedPartnerPackages
                } else {
                    let offering = try await SubscriptionService.shared.fetchOffering(identifier: "partner")
                    partnerPackages = Self.filteredPaywallPackages(from: offering)
                    await MainActor.run {
                        prefetchedPartnerPackages = partnerPackages
                    }
                }

                guard !partnerPackages.isEmpty else { return }

                await MainActor.run {
                    applyPartnerPackageTransition(partnerPackages)
                }
            } catch {
                Logger.log(
                    level: .error,
                    category: .purchases,
                    message: "Failed to load partner packages for price animation: \(error.localizedDescription)"
                )
            }
        }
    }

    private func applyPartnerPackageTransition(_ partnerPackages: [Package]) {
        guard stage == .checkout, !planCardViews.isEmpty else { return }

        let partnerByType = Dictionary(uniqueKeysWithValues: partnerPackages.map { ($0.packageType, $0) })
        loadedPackages = partnerPackages

        for cardView in planCardViews {
            guard let currentPackage = cardView.package,
                  let partnerPackage = partnerByType[currentPackage.packageType] else { continue }

            let fromSnapshot = PaywallPlanCardView.priceSnapshot(for: currentPackage)
            let toSnapshot = PaywallPlanCardView.priceSnapshot(for: partnerPackage)

            cardView.configure(with: partnerPackage)
            if fromSnapshot != toSnapshot {
                cardView.prepareForPriceSlash(from: fromSnapshot, to: toSnapshot)
            }
        }

        let selectedType = selectedPackage?.packageType ?? .annual
        if let partner = partnerByType[selectedType] ?? partnerPackages.first {
            selectPackage(partner)
        }
        updateHeadline(from: partnerPackages)
        updateStageUI()
        playPartnerPriceSlashAnimations()
    }

    private func loadOffering(identifier: String? = nil) {
        setLoading(true)
        hideError()

        Task {
            do {
                let offering = try await SubscriptionService.shared.fetchOffering(identifier: identifier)
                let sorted = Self.filteredPaywallPackages(from: offering)

                await MainActor.run {
                    configurePackages(sorted)
                    setLoading(false)
                }
            } catch {
                await MainActor.run {
                    setLoading(false)
                    showError(error.localizedDescription)
                }
            }
        }
    }

    private func configurePackages(_ packages: [Package], animatePriceSlash: Bool = false) {
        loadedPackages = packages
        packagesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        planCardViews.removeAll()

        guard !packages.isEmpty else {
            showError("No subscription plans are available right now.")
            updateStageUI()
            return
        }

        packages.forEach { package in
            let cardView = PaywallPlanCardView()
            cardView.configure(with: package)

            if animatePriceSlash,
               let standardPackage = standardComparisonPackages[package.packageType] {
                let fromSnapshot = PaywallPlanCardView.priceSnapshot(for: standardPackage)
                let toSnapshot = PaywallPlanCardView.priceSnapshot(for: package)
                if fromSnapshot != toSnapshot {
                    cardView.prepareForPriceSlash(from: fromSnapshot, to: toSnapshot)
                }
            }

            cardView.addTarget(self, action: #selector(planCardTapped(_:)), for: .touchUpInside)
            packagesStack.addArrangedSubview(cardView)
            planCardViews.append(cardView)
        }

        updateHeadline(from: packages)
        let defaultPackage = packages.first(where: { $0.packageType == .annual })
            ?? packages.first(where: { $0.packageType == .monthly })
            ?? packages[0]
        selectPackage(defaultPackage)
        updateStageUI()
        view.setNeedsLayout()
    }

    private func updateHeadline(from packages: [Package]) {
        if let annual = packages.first(where: { $0.packageType == .annual }),
           let trialText = headlineTrialText(for: annual) {
            titleLabel.text = "Try Premium \(trialText), free"
        } else {
            titleLabel.text = "Upgrade to Premium"
        }
    }

    private func headlineTrialText(for package: Package) -> String? {
        guard let discount = package.storeProduct.introductoryDiscount else { return nil }
        let value = discount.subscriptionPeriod.value
        switch discount.subscriptionPeriod.unit {
        case .day:
            return value == 1 ? "for 1 day" : "for \(value) days"
        case .week:
            return value == 1 ? "for 1 week" : "for \(value) weeks"
        case .month:
            return value == 1 ? "for 1 month" : "for \(value) months"
        case .year:
            return value == 1 ? "for 1 year" : "for \(value) years"
        @unknown default:
            return nil
        }
    }

    private func selectPackage(_ package: Package) {
        selectedPackage = package
        planCardViews.forEach { cardView in
            cardView.isPlanSelected = cardView.package?.identifier == package.identifier
        }
        updateTrialInfoLabel(for: package)
    }

    private func updateTrialInfoLabel(for package: Package) {
        switch package.packageType {
        case .annual:
            if let discount = package.storeProduct.introductoryDiscount {
                let trialDuration = formattedTrialDurationLabel(for: discount)
                trialInfoLabel.text = "\(trialDuration), then \(package.localizedPriceString)/yr. Cancel anytime."
            } else {
                trialInfoLabel.text = "\(package.localizedPriceString)/yr. Cancel anytime."
            }
        case .monthly:
            trialInfoLabel.text = "\(package.localizedPriceString)/mo. Cancel anytime."
        default:
            trialInfoLabel.text = "Cancel anytime."
        }
    }

    private func formattedTrialDurationLabel(for discount: StoreProductDiscount) -> String {
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

    private func setLoading(_ isLoading: Bool) {
        referralState.isLoading = isLoading
        referralSheetController?.refresh()

        if isLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
        continueButton.isEnabled = !isLoading && stage == .features
        updateStageUI()
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        retryButton.isHidden = false
    }

    private func hideError() {
        errorLabel.isHidden = true
        retryButton.isHidden = true
    }

    @objc private func planCardTapped(_ sender: PaywallPlanCardView) {
        guard let package = sender.package else { return }
        guard selectedPackage?.identifier != package.identifier else { return }
        selectPackage(package)
        triggerPlanSelectionExplosion(for: package, from: sender)
        HapticsHelper.lightHaptic()
    }

    private func triggerPlanSelectionExplosion(for package: Package, from cardView: PaywallPlanCardView) {
        let cardCenter = CGPoint(x: cardView.bounds.midX, y: cardView.bounds.midY)
        let explosionPoint: CGPoint
        if let window = view.window {
            explosionPoint = cardView.convert(cardCenter, to: window)
        } else {
            explosionPoint = cardView.convert(cardCenter, to: view)
        }

        let preset: ExplosionPreset
        switch package.packageType {
        case .annual:
            preset = .medium
        case .monthly:
            preset = .small
        default:
            preset = .small
        }

        ExplosionManager.trigger(preset, at: explosionPoint)
    }

    @objc private func retryTapped() {
        if stage == .features {
            continueToCheckout()
        } else {
            loadOffering(identifier: usesCreatorPartnerPricing ? "partner" : nil)
        }
    }

    @objc private func referralTapped() {
        presentReferralSheet()
    }

    private func presentReferralSheet() {
        referralState.referralCodeError = nil
        let sheet = ReferralCodeEntryViewController(presenting: referralState)
        referralSheetController = sheet

        if let sheetPresentation = sheet.sheetPresentationController {
            sheetPresentation.detents = [.custom(resolver: { _ in 280 })]
            sheetPresentation.prefersGrabberVisible = true
        }

        present(sheet, animated: true)
    }

    private func applyReferralCode(_ input: String) {
        referralState.referralCodeError = nil
        setLoading(true)

        Task {
            do {
                if let outcome = try await ReferralCodeApplicationHelper.apply(input) {
                    let codeInfo = outcome.codeInfo
                    await MainActor.run {
                        appliedReferralCode = codeInfo.code
                        appliedReferralCodeType = codeInfo.type
                        referralState.referralCodeInput = ""
                        setLoading(false)
                        referralSheetController?.dismiss(animated: true) {
                            self.referralSheetController = nil
                            self.updateReferralUI(for: codeInfo)
                            self.playReferralAppliedFeedback()
                            switch outcome {
                            case .creator:
                                self.prefetchComparisonPackages()
                                if self.stage == .checkout {
                                    self.transitionToPartnerPricingWithAnimation()
                                }
                            case .sitter:
                                break
                            }
                        }
                    }
                } else {
                    await MainActor.run {
                        referralState.referralCodeError = "That referral code isn't valid."
                        setLoading(false)
                        referralSheetController?.refresh()
                        Tracker.shared.track(.referralValidationFailed)
                    }
                }
            } catch {
                await MainActor.run {
                    referralState.referralCodeError = error.localizedDescription
                    setLoading(false)
                    referralSheetController?.refresh()
                }
            }
        }
    }

    private func updateReferralUI(for codeInfo: ReferralCodeInfo? = nil) {
        let info: ReferralCodeInfo?
        if let codeInfo {
            info = codeInfo
        } else if let code = appliedReferralCode {
            info = ReferralCodeInfo(
                code: code,
                type: appliedReferralCodeType ?? .creator,
                displayName: code,
                sitterUserId: nil
            )
        } else {
            info = nil
        }

        let hasAppliedCode = appliedReferralCode != nil
        referralButton.isHidden = hasAppliedCode

        if let info {
            appliedReferralLabel.attributedText = attributedReferralAppliedText(codeInfo: info)
            appliedReferralLabel.isHidden = false
        } else {
            appliedReferralLabel.text = nil
            appliedReferralLabel.isHidden = true
        }
        updateStageUI()
    }

    private func attributedReferralAppliedText(codeInfo: ReferralCodeInfo) -> NSAttributedString {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let checkmark = UIImage(systemName: "checkmark.circle.fill", withConfiguration: symbolConfig)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)

        let result = NSMutableAttributedString()
        if let checkmark {
            let attachment = NSTextAttachment()
            attachment.image = checkmark
            attachment.bounds = CGRect(x: 0, y: -2, width: 16, height: 16)
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: "  "))
        }

        let message: String
        switch codeInfo.type {
        case .creator:
            message = "Creator code applied: \(codeInfo.code)"
        case .sitter:
            message = "Referral from \(codeInfo.displayName) applied"
        }

        result.append(NSAttributedString(
            string: message,
            attributes: [
                .font: UIFont.captionBoldS,
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
        ))
        return result
    }

    private func playReferralAppliedFeedback() {
        view.layoutIfNeeded()

        let feedbackCenter = CGPoint(
            x: featuresPanelStack.bounds.midX,
            y: featuresPanelStack.bounds.midY
        )
        let explosionPoint: CGPoint
        if let window = view.window {
            explosionPoint = featuresPanelStack.convert(feedbackCenter, to: window)
        } else {
            explosionPoint = featuresPanelStack.convert(feedbackCenter, to: view)
        }

        ExplosionManager.trigger(.small, at: explosionPoint)

        featuresPanelStack.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        featuresPanelStack.layer.cornerRadius = 12
        featuresPanelStack.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        featuresPanelStack.isLayoutMarginsRelativeArrangement = true

        appliedReferralLabel.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        appliedReferralLabel.alpha = 0

        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.45,
            options: [.allowUserInteraction]
        ) {
            self.appliedReferralLabel.transform = .identity
            self.appliedReferralLabel.alpha = 1
        }

        UIView.animate(withDuration: 0.35, delay: 0.8, options: [.curveEaseOut]) {
            self.featuresPanelStack.backgroundColor = .clear
        }
    }

    @objc private func primaryActionTapped() {
        switch stage {
        case .features:
            continueToCheckout()
        case .checkout:
            upgradeTapped()
        }
    }

    @objc private func upgradeTapped() {
        guard let selectedPackage else { return }

        setLoading(true)

        Task {
            do {
                _ = try await SubscriptionService.shared.purchase(
                    package: selectedPackage,
                    referralCode: appliedReferralCode,
                    referralCodeType: appliedReferralCodeType
                )
                await MainActor.run {
                    setLoading(false)
                    TikTokTracker.shared.trackSubscribe()
                    dismissPaywall(showing: "Subscription activated!")
                }
            } catch SubscriptionError.purchaseCancelled {
                await MainActor.run {
                    setLoading(false)
                }
            } catch {
                await MainActor.run {
                    setLoading(false)
                    showToast(text: "Purchase failed. Please try again.")
                    Logger.log(level: .error, category: .purchases, message: "Carousel feature paywall purchase failed: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func restoreTapped() {
        setLoading(true)

        Task {
            do {
                let customerInfo = try await SubscriptionService.shared.restorePurchases()
                await MainActor.run {
                    setLoading(false)
                    if customerInfo.entitlements.active["Pro"] != nil {
                        TikTokTracker.shared.trackSubscribe()
                        dismissPaywall(showing: "Subscription restored!")
                    } else {
                        showToast(text: "No active subscription found.")
                    }
                }
            } catch {
                await MainActor.run {
                    setLoading(false)
                    showToast(text: "Restore failed. Please try again.")
                    Logger.log(level: .error, category: .purchases, message: "Carousel feature paywall restore failed: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func termsTapped() {
        openURL("https://www.nestnoteapp.com/terms")
    }

    @objc private func privacyTapped() {
        openURL("https://www.nestnoteapp.com/privacypolicy")
    }

    private func animateCloseButtonAppearanceIfNeeded() {
        guard showsDelayedCloseButton, !hasAnimatedCloseButton else { return }
        hasAnimatedCloseButton = true

        UIView.animate(
            withDuration: 0.35,
            delay: 3.0,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            self.closeButton.alpha = 1
        }
    }

    @objc private func closeTapped() {
        finishPaywall(subscribed: false)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    private func dismissPaywall(showing message: String) {
        Task {
            await SubscriptionService.shared.refreshCustomerInfo()
            await MainActor.run {
                finishPaywall(subscribed: true, successMessage: message)
            }
        }
    }

    private func finishPaywall(subscribed: Bool, successMessage: String? = nil) {
        if let onPaywallFinished {
            onPaywallFinished(subscribed)
            return
        }

        guard subscribed, let successMessage else { return }

        let presenter = presentingViewController
        dismiss(animated: true) {
            presenter?.showToast(text: successMessage)
        }
    }
}
