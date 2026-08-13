import UIKit

class OnboardingMissingInfoViewController: NNOnboardingViewController {

    private static let defaultTitle = "You're not giving your sitters\nwhat they need to succeed."
    private static let defaultStatText = "74% of parents fail to share\nhousehold codes & systems"
    private static let defaultSubtitle = "which means the sitter is potentially\nmissing the following:"
    private static let defaultItems = [
        "Garage Codes",
        "Wifi Password",
        "Screen Time rules",
        "Appliance Guides"
    ]
    private static let defaultCtaText = "Continue"

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let statCardView = UIView()
    private let statCardContentView = UIView()
    private let statLabel = UILabel()
    private let stackView = UIStackView()
    private let statCardBackgroundGradient = CAGradientLayer()

    private var itemViews: [UIView] = []
    private var configuredTitle = defaultTitle
    private var configuredStatText = defaultStatText
    private var configuredSubtitle = defaultSubtitle
    private var configuredItems = defaultItems
    private var configuredCtaText = defaultCtaText

    func configure(
        title: String? = nil,
        statText: String? = nil,
        subtitle: String? = nil,
        items: [String]? = nil,
        ctaText: String? = nil
    ) {
        if let title { configuredTitle = title }
        if let statText { configuredStatText = statText }
        if let subtitle { configuredSubtitle = subtitle }
        if let items { configuredItems = items }
        if let ctaText { configuredCtaText = ctaText }
    }

    @objc private func continueButtonTapped() {
        (coordinator as? OnboardingCoordinator)?.next()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        labelStack.insertArrangedSubview(statCardView, at: 1)
        labelStack.setCustomSpacing(32, after: titleLabel)
        labelStack.setCustomSpacing(24, after: statCardView)

        statCardView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statCardView.widthAnchor.constraint(equalTo: labelStack.widthAnchor)
        ])

        setupOnboarding(
            title: configuredTitle,
            subtitle: configuredSubtitle
        )
        setupContent()
        addCTAButton(title: configuredCtaText)
        ctaButton?.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        installScrollEdgeInteractions(for: scrollView)
    }

    override func setupContent() {
        setupListScrollView()
        setupStackView()
        setupStatCard()
        createMissingItemViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // By viewWillAppear the view is guaranteed to be attached to its window, so this is the
        // earliest point where `traitCollection` reliably reflects the real current appearance.
        updateStatCardColors()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateStatCardColors()
        animateItems()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Re-resolve every layout pass too: cheap and idempotent, and covers cases where this
        // screen is inserted into a custom container that lays out children before they're
        // attached to a window (viewWillAppear/viewDidAppear act as a safety net above).
        updateStatCardColors()
        statCardBackgroundGradient.frame = statCardContentView.bounds
        statCardView.layer.shadowPath = UIBezierPath(roundedRect: statCardView.bounds, cornerRadius: 16).cgPath

        if #available(iOS 26.0, *) {
            updateScrollViewInsets()
        }
    }

    /// Keeps the scroll view's resting position between the header and CTA now that its frame
    /// extends under both (header height changes with configured text).
    @available(iOS 26.0, *)
    private func updateScrollViewInsets() {
        // Measure from the header container itself (not labelStack): the container extends
        // 16pt past the stack and hosts the scroll-edge interaction that hard-clips content.
        let headerBottom = headerContainerView.convert(headerContainerView.bounds, to: view).maxY
        let topTarget = headerBottom + 12 - scrollView.safeAreaInsets.top

        var bottomTarget: CGFloat = 0
        if let ctaButton {
            let buttonTop = ctaButton.convert(ctaButton.bounds, to: view).minY
            bottomTarget = max(0, view.bounds.height - buttonTop + 16 - scrollView.safeAreaInsets.bottom)
        }

        guard abs(scrollView.contentInset.top - topTarget) > 0.5
                || abs(scrollView.contentInset.bottom - bottomTarget) > 0.5 else { return }

        let wasAtTop = scrollView.contentOffset.y <= -(scrollView.adjustedContentInset.top) + 1
        scrollView.contentInset.top = topTarget
        scrollView.contentInset.bottom = bottomTarget
        if wasAtTop, !scrollView.isDragging, !scrollView.isDecelerating {
            scrollView.contentOffset.y = -scrollView.adjustedContentInset.top
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateStatCardColors()
        }
    }

    private func updateStatCardColors() {
        let backgroundColor = UIColor.systemBackground.resolvedColor(with: traitCollection)
        let tintColor = UIColor.systemRed.resolvedColor(with: traitCollection)

        statCardContentView.backgroundColor = backgroundColor
        statCardBackgroundGradient.colors = [
            tintColor.withAlphaComponent(0.05).cgColor,
            backgroundColor.cgColor
        ]
        statCardBackgroundGradient.locations = [0, 1]
        statCardBackgroundGradient.startPoint = CGPoint(x: 0.5, y: -5)
        statCardBackgroundGradient.endPoint = CGPoint(x: 0.5, y: 0.8)
    }

    private func setupListScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag

        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let topConstraint: NSLayoutConstraint
        let bottomConstraint: NSLayoutConstraint
        if #available(iOS 26.0, *) {
            // Extend under the header and CTA so content can scroll beneath them;
            // insets are managed in viewDidLayoutSubviews
            topConstraint = scrollView.topAnchor.constraint(equalTo: view.topAnchor)
            bottomConstraint = scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        } else {
            topConstraint = scrollView.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 12)
            bottomConstraint = scrollView.bottomAnchor.constraint(equalTo: ctaButton?.topAnchor ?? view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        }

        NSLayoutConstraint.activate([
            topConstraint,
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 36),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -36),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    private func setupStackView() {
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.distribution = .fill
    }

    private func setupStatCard() {
        statCardView.backgroundColor = .clear
        statCardView.layer.cornerRadius = 16
        statCardView.layer.shadowColor = UIColor.black.cgColor
        statCardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        statCardView.layer.shadowOpacity = 0.15
        statCardView.layer.shadowRadius = 8

        statCardContentView.translatesAutoresizingMaskIntoConstraints = false
        statCardContentView.layer.cornerRadius = 16
        statCardContentView.clipsToBounds = true
        statCardView.addSubview(statCardContentView)

        statCardBackgroundGradient.cornerRadius = 16
        statCardContentView.layer.insertSublayer(statCardBackgroundGradient, at: 0)
        updateStatCardColors()

        statLabel.translatesAutoresizingMaskIntoConstraints = false
        statLabel.text = configuredStatText
        statLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        statLabel.textColor = .systemRed
        statLabel.textAlignment = .center
        statLabel.numberOfLines = 0

        statCardContentView.addSubview(statLabel)

        NSLayoutConstraint.activate([
            statCardContentView.topAnchor.constraint(equalTo: statCardView.topAnchor),
            statCardContentView.leadingAnchor.constraint(equalTo: statCardView.leadingAnchor),
            statCardContentView.trailingAnchor.constraint(equalTo: statCardView.trailingAnchor),
            statCardContentView.bottomAnchor.constraint(equalTo: statCardView.bottomAnchor),

            statLabel.topAnchor.constraint(equalTo: statCardContentView.topAnchor, constant: 24),
            statLabel.leadingAnchor.constraint(equalTo: statCardContentView.leadingAnchor, constant: 24),
            statLabel.trailingAnchor.constraint(equalTo: statCardContentView.trailingAnchor, constant: -24),
            statLabel.bottomAnchor.constraint(equalTo: statCardContentView.bottomAnchor, constant: -24)
        ])

        // Add immediately rather than waiting on a bounds check in viewDidLayoutSubviews: the
        // shimmer view's own constraints are pinned to statLabel, so it naturally gets a correct
        // frame (and re-runs its layoutSubviews/updateTextMask) as part of the same Auto Layout
        // pass that first sizes the label, with no dependence on how many times the parent view
        // controller's viewDidLayoutSubviews happens to fire.
        statLabel.addShimmerEffect()
    }

    private func createMissingItemViews() {
        for item in configuredItems {
            let itemView = createMissingItemView(title: item)

            itemView.alpha = 0
            itemView.transform = CGAffineTransform(translationX: 0, y: 30)

            stackView.addArrangedSubview(itemView)
            itemViews.append(itemView)
        }
    }

    private func createMissingItemView(title: String) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.05)
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.systemRed.cgColor

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        let xmarkImageView = UIImageView()
        let xmarkConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        xmarkImageView.image = UIImage(systemName: "xmark", withConfiguration: xmarkConfig)
        xmarkImageView.tintColor = .white
        xmarkImageView.contentMode = .scaleAspectFit

        let xmarkContainer = UIView()
        xmarkContainer.backgroundColor = UIColor.systemRed
        xmarkContainer.layer.cornerRadius = 8
        xmarkContainer.addSubview(xmarkImageView)

        containerView.addSubview(titleLabel)
        containerView.addSubview(xmarkContainer)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        xmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        xmarkContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),

            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: xmarkContainer.leadingAnchor, constant: -12),

            xmarkContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            xmarkContainer.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            xmarkContainer.widthAnchor.constraint(equalToConstant: 24),
            xmarkContainer.heightAnchor.constraint(equalToConstant: 24),

            xmarkImageView.centerXAnchor.constraint(equalTo: xmarkContainer.centerXAnchor),
            xmarkImageView.centerYAnchor.constraint(equalTo: xmarkContainer.centerYAnchor),
            xmarkImageView.widthAnchor.constraint(equalToConstant: 12),
            xmarkImageView.heightAnchor.constraint(equalToConstant: 12)
        ])

        return containerView
    }

    private func animateItems() {
        for (index, itemView) in itemViews.enumerated() {
            let delay = Double(index) * 0.3

            UIView.animate(
                withDuration: 1.2,
                delay: delay,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3,
                options: [.curveEaseOut]
            ) {
                itemView.alpha = 1.0
                itemView.transform = .identity
            }
        }
    }
}
