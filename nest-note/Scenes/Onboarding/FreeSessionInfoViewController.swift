//
//  FreeSessionInfoViewController.swift
//  nest-note
//

import UIKit
import FirebaseAnalytics

final class FreeSessionInfoViewController: NNViewController {

    var onContinue: (() -> Void)?

    private static let freeSessionFeatures: [ProFeature] = [
        .unlimitedEntries,
        .multiDaySessions,
        .sessionEvents,
        .sessionPDFExport
    ]

    private static let iconSize: CGFloat = 64
    private static let primaryIconSize: CGFloat = 80
    private static let iconCornerRadius: CGFloat = 12
    private static let iconFanOffsetX: CGFloat = 58
    private static let iconFanRotationDegrees: CGFloat = 18
    private static let iconStackWidth: CGFloat = 200
    private static let iconStackHeight: CGFloat = 84
    private static let bottomBlurFadeHeight: CGFloat = 20
    private static let scrollBottomPadding: CGFloat = 16

    private var hasAnimatedIconStack = false
    private var hasAnimatedFeaturesContent = false

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.alwaysBounceVertical = true
        scroll.backgroundColor = NNColors.groupedBackground
        return scroll
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = NNColors.groupedBackground
        return view
    }()

    private let topImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .rectanglePatternSmall, with: NNColors.primary)
        view.alpha = 0.4
        return view
    }()

    private let iconStackContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        return view
    }()

    private let backIconLeftCard: UIView = {
        makeIconCard(imageName: AppIcon.main.previewImageName)
    }()

    private let backIconRightCard: UIView = {
        makeIconCard(imageName: AppIcon.green.previewImageName)
    }()

    private let iconCard: UIView = {
        makeIconCard(imageName: AppIcon.dark.previewImageName, size: primaryIconSize)
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Your first session is on us"
        label.font = .h1
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Try every premium session feature free — multi-day scheduling, events, PDF export, and unlimited sharing — for one full session."
        label.font = .captionBoldS
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var featureListView: PaywallFeatureListView = {
        PaywallFeatureListView(items: Self.freeSessionFeatures.map {
            PaywallFeatureItem(title: $0.displayName, iconName: $0.iconName)
        })
    }()

    private let bottomPanelContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private lazy var bottomBlurView: UIVisualEffectView = {
        let blur = UIVisualEffectView()
        if let maskImage = UIImage(named: "testBG3") {
            blur.effect = UIBlurEffect.variableBlurEffect(radius: 16, maskImage: maskImage)
        } else {
            blur.effect = UIBlurEffect(style: .regular)
        }
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.isUserInteractionEnabled = false
        return blur
    }()

    private lazy var continueButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Start my free session")
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        prepareFeaturesContentForSlideIn()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIconStackFanOutIfNeeded()
        animateFeaturesContentIfNeeded()

        Analytics.logEvent("free_session_offer_presented", parameters: [
            "source": "onboarding_paywall_decline"
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollInsets()
    }

    private static func makeIconCard(imageName: String, size: CGFloat = iconSize) -> UIView {
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
        imageView.layer.borderColor = UIColor.tertiarySystemBackground.cgColor

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
            roundedRect: CGRect(origin: .zero, size: CGSize(width: size, height: size)),
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

    private func setupView() {
        view.backgroundColor = NNColors.groupedBackground

        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        view.addSubview(bottomPanelContainer)
        bottomPanelContainer.addSubview(bottomBlurView)
        bottomPanelContainer.addSubview(continueButton)

        containerView.addSubview(topImageView)
        containerView.addSubview(iconStackContainer)
        iconStackContainer.addSubview(backIconLeftCard)
        iconStackContainer.addSubview(backIconRightCard)
        iconStackContainer.addSubview(iconCard)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(featureListView)

        [topImageView, iconStackContainer, titleLabel, subtitleLabel, featureListView].forEach {
            $0.isUserInteractionEnabled = false
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomPanelContainer.topAnchor),

            bottomPanelContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanelContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPanelContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            bottomBlurView.leadingAnchor.constraint(equalTo: bottomPanelContainer.leadingAnchor),
            bottomBlurView.trailingAnchor.constraint(equalTo: bottomPanelContainer.trailingAnchor),
            bottomBlurView.bottomAnchor.constraint(equalTo: bottomPanelContainer.bottomAnchor),
            bottomBlurView.topAnchor.constraint(equalTo: bottomPanelContainer.topAnchor, constant: -Self.bottomBlurFadeHeight),

            continueButton.leadingAnchor.constraint(equalTo: bottomPanelContainer.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: bottomPanelContainer.trailingAnchor, constant: -20),
            continueButton.topAnchor.constraint(equalTo: bottomPanelContainer.topAnchor, constant: 12),
            continueButton.bottomAnchor.constraint(equalTo: bottomPanelContainer.bottomAnchor, constant: -12),
            continueButton.heightAnchor.constraint(equalToConstant: 55),

            topImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            topImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            topImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            topImageView.heightAnchor.constraint(
                equalTo: containerView.widthAnchor,
                multiplier: NNAssetType.rectanglePatternSmall.heightMultiplier
            ),

            iconStackContainer.topAnchor.constraint(equalTo: topImageView.bottomAnchor, constant: 24),
            iconStackContainer.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
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
            iconCard.widthAnchor.constraint(equalToConstant: Self.primaryIconSize),
            iconCard.heightAnchor.constraint(equalToConstant: Self.primaryIconSize),

            titleLabel.topAnchor.constraint(equalTo: iconStackContainer.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            featureListView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            featureListView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            featureListView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            featureListView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),

            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        view.bringSubviewToFront(bottomPanelContainer)
    }

    private func prepareFeaturesContentForSlideIn() {
        iconStackContainer.prepareForSlideIn()
        [titleLabel, subtitleLabel, continueButton].forEach {
            $0.prepareForSlideIn()
        }
        featureListView.prepareRowsForSlideIn()
    }

    private func animateFeaturesContentIfNeeded() {
        guard !hasAnimatedFeaturesContent else { return }
        hasAnimatedFeaturesContent = true

        let iconDelay: TimeInterval = 0.12
        let titleDelay: TimeInterval = 0.28
        let rowStagger: TimeInterval = 0.05
        let rowCount = Self.freeSessionFeatures.count

        iconStackContainer.animateSlideIn(delay: iconDelay)
        titleLabel.animateSlideIn(delay: titleDelay)
        subtitleLabel.animateSlideIn(delay: titleDelay + 0.04)
        featureListView.animateRowsIn(stagger: rowStagger, initialDelay: titleDelay + 0.06)

        let footerDelay = titleDelay + 0.09 + (rowStagger * Double(rowCount))
        continueButton.animateSlideIn(delay: footerDelay + 0.04)
    }

    private func animateIconStackFanOutIfNeeded() {
        guard !hasAnimatedIconStack else { return }
        hasAnimatedIconStack = true

        let stackedScale: CGFloat = 0.94

        UIView.animate(
            withDuration: 0.22,
            delay: 0.32,
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
                    rotationDegrees: -Self.iconFanRotationDegrees,
                    scale: stackedScale
                )
                self.backIconRightCard.transform = Self.iconTransform(
                    offsetX: Self.iconFanOffsetX,
                    rotationDegrees: Self.iconFanRotationDegrees,
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

    private func updateScrollInsets() {
        view.layoutIfNeeded()

        let panelTop = bottomPanelContainer.convert(bottomPanelContainer.bounds, to: scrollView).minY
        let obstructedHeight = max(0, scrollView.bounds.maxY - panelTop)
        let bottomInset = obstructedHeight + Self.scrollBottomPadding

        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    @objc private func continueTapped() {
        Analytics.logEvent("free_session_offer_accepted", parameters: [
            "source": "onboarding_paywall_decline"
        ])
        onContinue?()
    }
}
