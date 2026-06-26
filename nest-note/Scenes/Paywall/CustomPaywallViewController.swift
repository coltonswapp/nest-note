//
//  CustomPaywallViewController.swift
//  nest-note
//

import UIKit
import RevenueCat
import SafariServices

final class CustomPaywallViewController: NNViewController {

    private var packageOptionViews: [PaywallPackageOptionView] = []
    private var selectedPackage: Package?
    private var loadedPackages: [Package] = []

    private let topImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .rectanglePatternSmall, with: NNColors.primary)
        view.alpha = 0.4
        return view
    }()

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.image = UIImage(named: AppIcon.dark.previewImageName)
        view.contentMode = .scaleAspectFit
        view.layer.cornerRadius = 12
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Try Premium for 3 days, free"
        label.font = .h1
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var featureListView: PaywallFeatureListView = {
        PaywallFeatureListView(features: ProFeature.paywallFeatures.map(\.displayName))
    }()

    private let packagesStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
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

    private let bottomStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        return stack
    }()

    private let footerLinksStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.alignment = .center
        return stack
    }()

    private let footerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
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
        button.tintColor = NNColors.primary
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        return button
    }()

    private lazy var upgradeButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Upgrade Now")
        button.addTarget(self, action: #selector(upgradeTapped), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()

    private lazy var termsButton: UIButton = makeFooterLinkButton(title: "Terms", action: #selector(termsTapped))
    private lazy var privacyButton: UIButton = makeFooterLinkButton(title: "Privacy", action: #selector(privacyTapped))
    private lazy var restoreButton: UIButton = makeFooterLinkButton(title: "Restore", action: #selector(restoreTapped))

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        loadOffering()
    }

    private func makeFooterLinkButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .captionBoldS
        button.tintColor = .secondaryLabel
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func setupView() {
        view.backgroundColor = NNColors.groupedBackground

        view.addSubview(topImageView)
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        view.addSubview(bottomStack)
        view.addSubview(loadingIndicator)
        view.addSubview(errorLabel)
        view.addSubview(retryButton)

        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(featureListView)
        containerView.addSubview(packagesStack)
        containerView.addSubview(trialInfoLabel)

        bottomStack.addArrangedSubview(upgradeButton)
        footerContainer.addSubview(footerLinksStack)
        bottomStack.addArrangedSubview(footerContainer)
        footerLinksStack.addArrangedSubview(termsButton)
        footerLinksStack.addArrangedSubview(privacyButton)
        footerLinksStack.addArrangedSubview(restoreButton)

        topImageView.pinToTop(of: view)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topImageView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomStack.topAnchor, constant: -12),

            bottomStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bottomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            upgradeButton.heightAnchor.constraint(equalToConstant: 55),

            footerLinksStack.topAnchor.constraint(equalTo: footerContainer.topAnchor),
            footerLinksStack.bottomAnchor.constraint(equalTo: footerContainer.bottomAnchor),
            footerLinksStack.centerXAnchor.constraint(equalTo: footerContainer.centerXAnchor),
            footerLinksStack.leadingAnchor.constraint(greaterThanOrEqualTo: footerContainer.leadingAnchor),
            footerLinksStack.trailingAnchor.constraint(lessThanOrEqualTo: footerContainer.trailingAnchor),

            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 40),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 64),
            iconImageView.heightAnchor.constraint(equalToConstant: 64),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            featureListView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            featureListView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            featureListView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            packagesStack.topAnchor.constraint(equalTo: featureListView.bottomAnchor, constant: 24),
            packagesStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            packagesStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            packagesStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),

            trialInfoLabel.topAnchor.constraint(equalTo: packagesStack.bottomAnchor, constant: 12),
            trialInfoLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            trialInfoLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            trialInfoLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),

            loadingIndicator.centerXAnchor.constraint(equalTo: packagesStack.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: packagesStack.centerYAnchor),

            errorLabel.centerXAnchor.constraint(equalTo: packagesStack.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: packagesStack.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 12),
            retryButton.centerXAnchor.constraint(equalTo: packagesStack.centerXAnchor)
        ])
    }

    private func loadOffering() {
        setLoading(true)
        hideError()

        Task {
            do {
                let offering = try await SubscriptionService.shared.fetchOffering()
                let filtered = offering.availablePackages.filter {
                    $0.packageType == .monthly || $0.packageType == .annual
                }
                let sorted = filtered.sorted { lhs, _ in lhs.packageType == .monthly }

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

    private func configurePackages(_ packages: [Package]) {
        loadedPackages = packages
        packagesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        packageOptionViews.removeAll()

        guard !packages.isEmpty else {
            showError("No subscription plans are available right now.")
            upgradeButton.isEnabled = false
            return
        }

        packages.forEach { package in
            let optionView = PaywallPackageOptionView()
            optionView.configure(with: package)
            optionView.addTarget(self, action: #selector(packageOptionTapped(_:)), for: .touchUpInside)
            packagesStack.addArrangedSubview(optionView)
            packageOptionViews.append(optionView)
        }

        updateHeadline(from: packages)
        let defaultPackage = packages.first(where: { $0.packageType == .monthly }) ?? packages[0]
        selectPackage(defaultPackage)
        upgradeButton.isEnabled = true
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
        packageOptionViews.forEach { optionView in
            optionView.isOptionSelected = optionView.package?.identifier == package.identifier
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
        if isLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
        upgradeButton.isEnabled = !isLoading && selectedPackage != nil
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

    @objc private func packageOptionTapped(_ sender: PaywallPackageOptionView) {
        guard let package = sender.package else { return }
        selectPackage(package)
        HapticsHelper.lightHaptic()
    }

    @objc private func retryTapped() {
        loadOffering()
    }

    @objc private func upgradeTapped() {
        guard let selectedPackage else { return }

        setLoading(true)
        upgradeButton.isEnabled = false

        Task {
            do {
                _ = try await SubscriptionService.shared.purchase(package: selectedPackage)
                await MainActor.run {
                    setLoading(false)
                    TikTokTracker.shared.trackSubscribe()
                    dismissPaywall(showing: "Subscription activated!")
                }
            } catch SubscriptionError.purchaseCancelled {
                await MainActor.run {
                    setLoading(false)
                    upgradeButton.isEnabled = true
                }
            } catch {
                await MainActor.run {
                    setLoading(false)
                    upgradeButton.isEnabled = true
                    showToast(text: "Purchase failed. Please try again.")
                    Logger.log(level: .error, category: .purchases, message: "Custom paywall purchase failed: \(error.localizedDescription)")
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
                    Logger.log(level: .error, category: .purchases, message: "Custom paywall restore failed: \(error.localizedDescription)")
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

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    private func dismissPaywall(showing message: String) {
        Task {
            await SubscriptionService.shared.refreshCustomerInfo()
            await MainActor.run {
                let presenter = presentingViewController
                dismiss(animated: true) {
                    presenter?.showToast(text: message)
                }
            }
        }
    }
}
