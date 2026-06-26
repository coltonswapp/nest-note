//
//  CarouselPaywallViewController.swift
//  nest-note
//

import UIKit
import SwiftUI
import RevenueCat
import SafariServices

final class CarouselPaywallViewController: NNViewController {

    private let viewModel = CarouselPaywallViewModel()
    private var hostingController: UIHostingController<CarouselPaywallPage>?
    private var packageByID: [String: Package] = [:]
    private var selectedPackage: Package?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHostingController()
        bindViewModel()
    }

    private func setupHostingController() {
        view.backgroundColor = .black

        let page = CarouselPaywallPage(viewModel: viewModel)
        let host = UIHostingController(rootView: page)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hostingController = host
    }

    private func bindViewModel() {
        viewModel.onPrimaryAction = { [weak self] in
            guard let self else { return }
            switch viewModel.stage {
            case .features:
                continueToCheckout()
            case .checkout:
                upgradeTapped()
            }
        }
        viewModel.onApplyReferralCode = { [weak self] code in
            self?.applyReferralCode(code)
        }
        viewModel.onSelectPlan = { [weak self] planID in
            self?.selectPlan(id: planID)
        }
        viewModel.onRestore = { [weak self] in
            self?.restoreTapped()
        }
        viewModel.onTerms = { [weak self] in
            self?.openURL("https://www.nestnoteapp.com/terms")
        }
        viewModel.onPrivacy = { [weak self] in
            self?.openURL("https://www.nestnoteapp.com/privacypolicy")
        }
    }

    private func applyReferralCode(_ input: String) {
        viewModel.referralCodeError = nil
        setLoading(true)

        Task {
            do {
                if let outcome = try await ReferralCodeApplicationHelper.apply(input) {
                    let codeInfo = outcome.codeInfo
                    await MainActor.run {
                        viewModel.appliedReferralCode = codeInfo.code
                        viewModel.appliedReferralCodeType = codeInfo.type
                        viewModel.referralCodeInput = ""
                        viewModel.showReferralSheet = false
                        setLoading(false)
                        HapticsHelper.lightHaptic()
                    }
                } else {
                    await MainActor.run {
                        viewModel.referralCodeError = "That referral code isn't valid."
                        setLoading(false)
                        Tracker.shared.track(.referralValidationFailed)
                    }
                }
            } catch {
                await MainActor.run {
                    viewModel.referralCodeError = error.localizedDescription
                    setLoading(false)
                }
            }
        }
    }

    private var usesCreatorPartnerPricing: Bool {
        viewModel.appliedReferralCode != nil
            && (viewModel.appliedReferralCodeType ?? .creator) == .creator
    }

    private func continueToCheckout() {
        setLoading(true)
        viewModel.errorMessage = nil

        Task {
            do {
                let offeringIdentifier = usesCreatorPartnerPricing ? "partner" : nil
                let offering = try await SubscriptionService.shared.fetchOffering(identifier: offeringIdentifier)
                let packages = offering.availablePackages.filter {
                    $0.packageType == .monthly || $0.packageType == .annual
                }
                let sorted = packages.sorted { lhs, _ in lhs.packageType == .monthly }

                guard !sorted.isEmpty else {
                    await MainActor.run {
                        setLoading(false)
                        viewModel.errorMessage = usesCreatorPartnerPricing
                            ? "Partner plans aren't available right now."
                            : "No subscription plans are available right now."
                    }
                    return
                }

                await MainActor.run {
                    configureCheckout(with: sorted)
                    viewModel.stage = .checkout
                    setLoading(false)
                    HapticsHelper.lightHaptic()
                }
            } catch {
                await MainActor.run {
                    setLoading(false)
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func configureCheckout(with packages: [Package]) {
        packageByID.removeAll()
        selectedPackage = nil

        viewModel.plans = packages.map { makePlanDisplay(for: $0) }
        packages.forEach { packageByID[$0.identifier] = $0 }

        updateHeadline()
        let defaultPackage = packages.first(where: { $0.packageType == .annual })
            ?? packages.first(where: { $0.packageType == .monthly })
            ?? packages[0]
        selectPackage(defaultPackage)
    }

    private func selectPlan(id: String) {
        guard let package = packageByID[id] else { return }
        selectPackage(package)
        HapticsHelper.lightHaptic()
    }

    private func selectPackage(_ package: Package) {
        selectedPackage = package
        viewModel.selectedPlanID = package.identifier
        updateTrialInfoLabel(for: package)
    }

    private func updateHeadline() {
        viewModel.headline = "Upgrade to Premium"
    }

    private func makePlanDisplay(for package: Package) -> CarouselPaywallPlan {
        let title: String
        let price: String
        let secondaryPrice: String?

        switch package.packageType {
        case .annual:
            title = "Annual"
            price = "\(package.localizedPriceString)/yr"
            secondaryPrice = package.storeProduct.localizedPricePerMonth.map { "\($0)/mo" }
        case .monthly:
            title = "Monthly"
            price = "\(package.localizedPriceString)/mo"
            secondaryPrice = nil
        default:
            title = package.storeProduct.localizedTitle
            price = package.localizedPriceString
            secondaryPrice = nil
        }

        return CarouselPaywallPlan(
            id: package.identifier,
            title: title,
            price: price,
            secondaryPrice: secondaryPrice,
            billingDetail: PaywallPlanCardView.billingDetailText(for: package)
        )
    }

    private func updateTrialInfoLabel(for package: Package) {
        switch package.packageType {
        case .annual:
            if let discount = package.storeProduct.introductoryDiscount {
                let trialDuration = formattedTrialDurationLabel(for: discount)
                viewModel.trialInfo = "\(trialDuration), then \(package.localizedPriceString)/yr. Cancel anytime."
            } else {
                viewModel.trialInfo = "\(package.localizedPriceString)/yr. Cancel anytime."
            }
        case .monthly:
            viewModel.trialInfo = "\(package.localizedPriceString)/mo. Cancel anytime."
        default:
            viewModel.trialInfo = "Cancel anytime."
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
        viewModel.isLoading = isLoading
    }

    private func upgradeTapped() {
        guard let selectedPackage else { return }

        setLoading(true)

        Task {
            do {
                _ = try await SubscriptionService.shared.purchase(
                    package: selectedPackage,
                    referralCode: viewModel.appliedReferralCode,
                    referralCodeType: viewModel.appliedReferralCodeType
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
                    Logger.log(level: .error, category: .purchases, message: "Carousel paywall purchase failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func restoreTapped() {
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
                    Logger.log(level: .error, category: .purchases, message: "Carousel paywall restore failed: \(error.localizedDescription)")
                }
            }
        }
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
