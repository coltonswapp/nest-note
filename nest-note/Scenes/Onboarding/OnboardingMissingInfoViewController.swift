import UIKit

class OnboardingMissingInfoViewController: NNOnboardingViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let statCardView = UIView()
    private let statLabel = UILabel()
    private let stackView = UIStackView()

    private var itemViews: [UIView] = []

    private let missingItems = [
        "Garage Codes",
        "Wifi Password",
        "Screen Time rules",
        "Appliance Guides"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupOnboarding(
            title: "You're not giving your sitters\nwhat they need to succeed.",
            subtitle: "which means the sitter is potentially\nmissing the following:"
        )
        setupContent()
        addCTAButton(title: "Continue")
        setupActions()
    }

    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
    }

    @objc private func continueButtonTapped() {
        if let coordinator = coordinator as? OnboardingCoordinator {
            coordinator.next()
        }
    }

    override func setupBaseUI() {
        view.addSubview(labelStack)
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(statCardView)
        labelStack.addArrangedSubview(subtitleLabel)

        labelStack.setCustomSpacing(32, after: titleLabel)
        labelStack.setCustomSpacing(24, after: statCardView)

        NSLayoutConstraint.activate([
            labelStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            labelStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            labelStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),

            statCardView.heightAnchor.constraint(lessThanOrEqualToConstant: 100)
        ])
    }

    override func setupContent() {
        setupLayout()
        setupStackView()
        setupStatCard()
        createMissingItemViews()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateItems()
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: ctaButton?.topAnchor ?? view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 36),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -36),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    private func setupStackView() {
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.distribution = .fill
    }

    private func setupStatCard() {
        statCardView.backgroundColor = .systemBackground
        statCardView.layer.cornerRadius = 16

        statCardView.layer.shadowColor = UIColor.black.cgColor
        statCardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        statCardView.layer.shadowOpacity = 0.15
        statCardView.layer.shadowRadius = 8

        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemRed.withAlphaComponent(0.05).cgColor,
            UIColor.systemBackground.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: -5)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.8)
        gradientLayer.cornerRadius = 16
        statCardView.layer.insertSublayer(gradientLayer, at: 0)

        statCardView.addSubview(statLabel)
        statLabel.translatesAutoresizingMaskIntoConstraints = false

        statLabel.text = "74% of parents fail to share\nhousehold codes & systems"
        statLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        statLabel.textColor = .systemRed
        statLabel.textAlignment = .center
        statLabel.numberOfLines = 0
        
        statLabel.addShimmerEffect()
        statLabel.startShimmer()

        NSLayoutConstraint.activate([
            statLabel.centerXAnchor.constraint(equalTo: statCardView.centerXAnchor),
            statLabel.centerYAnchor.constraint(equalTo: statCardView.centerYAnchor),
            statLabel.leadingAnchor.constraint(greaterThanOrEqualTo: statCardView.leadingAnchor, constant: 24),
            statLabel.trailingAnchor.constraint(lessThanOrEqualTo: statCardView.trailingAnchor, constant: -24),
            statLabel.topAnchor.constraint(greaterThanOrEqualTo: statCardView.topAnchor, constant: 24),
            statLabel.bottomAnchor.constraint(lessThanOrEqualTo: statCardView.bottomAnchor, constant: -24)
        ])

        statCardView.layoutIfNeeded()
        gradientLayer.frame = statCardView.bounds
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let gradientLayer = statCardView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = statCardView.bounds
        }
    }

    private func createMissingItemViews() {
        for item in missingItems {
            let itemView = createMissingItemView(title: item)

            // Set initial state for animation
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
            containerView.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
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

    // MARK: - Animation
    private func animateItems() {
        for (index, itemView) in itemViews.enumerated() {
            let delay = Double(index) * 0.3 // 300ms delay between each item

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
