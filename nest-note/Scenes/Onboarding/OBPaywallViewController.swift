//
//  OBPaywallViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 9/9/25.
//

import UIKit
import FirebaseAnalytics

final class OBPaywallViewController: NNOnboardingViewController {

    private var presentedPaywall: FeatureInfoPaywallViewController?
    private var hasCompletedPaywall = false
    private var paywallPresentedAt: Date?
    private var dwellRecorded = false

    override func viewDidLoad() {
        super.viewDidLoad()
        labelStack.isHidden = true
        view.backgroundColor = NNColors.groupedBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        (coordinator as? OnboardingCoordinator)?.syncRevenueCatAttributesBeforePaywallIfNeeded()
        presentFeatureInfoPaywallIfNeeded()
    }

    private func presentFeatureInfoPaywallIfNeeded() {
        guard presentedPaywall == nil, !hasCompletedPaywall, presentedViewController == nil else { return }

        let paywall = FeatureInfoPaywallViewController()
        if let pendingCode = ReferralDeepLinkStore.pendingCode {
            paywall.pendingReferralCodeToApply = pendingCode
            if let source = ReferralDeepLinkStore.pendingSource {
                paywall.pendingReferralSource = ReferralApplicationSource(rawValue: source) ?? .deepLink
            }
        }
        paywall.onPaywallFinished = { [weak self] subscribed in
            let referralCode = paywall.currentReferralCode
            self?.dismissPresentedPaywall {
                self?.completePaywall(subscribed: subscribed, referralCode: referralCode)
            }
        }

        paywall.modalPresentationStyle = .pageSheet
        if let sheet = paywall.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        paywall.presentationController?.delegate = self
        presentedPaywall = paywall
        paywallPresentedAt = Date()

        present(paywall, animated: true)

        Analytics.logEvent("paywall_presented", parameters: [
            "offering_id": (coordinator as? OnboardingCoordinator)?.paywallOfferingId ?? "default",
            "paywall_type": "feature_info"
        ])
    }

    private func dismissPresentedPaywall(completion: @escaping () -> Void) {
        guard let presentedPaywall else {
            completion()
            return
        }

        presentedPaywall.dismiss(animated: true) { [weak self] in
            self?.presentedPaywall = nil
            completion()
        }
    }

    private func secondsOnPaywall() -> Int {
        guard let start = paywallPresentedAt else { return 0 }
        return max(0, Int(Date().timeIntervalSince(start)))
    }

    private func recordDwellTimeIfNeeded() {
        guard !dwellRecorded, let start = paywallPresentedAt else { return }
        dwellRecorded = true
        paywallPresentedAt = nil
        let seconds = Date().timeIntervalSince(start)
        guard seconds > 0 else { return }
        (coordinator as? OnboardingCoordinator)?.addPaywallDwellTime(seconds)
    }

    private func completePaywall(subscribed: Bool, referralCode: String?) {
        guard !hasCompletedPaywall else { return }
        hasCompletedPaywall = true

        if let referralCode {
            (coordinator as? OnboardingCoordinator)?.updateReferralCode(referralCode)
        }

        let dwellSeconds = secondsOnPaywall()
        recordDwellTimeIfNeeded()
        (coordinator as? OnboardingCoordinator)?.recordPaywallOutcome(subscribed: subscribed)

        if subscribed {
            OnboardingAnalyticsService.shared.recordConversion(type: "purchase", productId: "feature_info_paywall")
            Analytics.logEvent("paywall_conversion", parameters: [
                "offering_id": (coordinator as? OnboardingCoordinator)?.paywallOfferingId ?? "default",
                "conversion_source": "feature_info_paywall",
                "dwell_seconds": dwellSeconds,
                "paywall_type": "feature_info"
            ])
            Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Feature info paywall conversion completed")
        } else {
            Analytics.logEvent("paywall_declined", parameters: [
                "offering_id": (coordinator as? OnboardingCoordinator)?.paywallOfferingId ?? "default",
                "dwell_seconds": dwellSeconds,
                "paywall_type": "feature_info"
            ])
            Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Feature info paywall declined, continuing onboarding")
        }

        (coordinator as? OnboardingCoordinator)?.next()
    }

    override func reset() {
        super.reset()
        hasCompletedPaywall = false
        paywallPresentedAt = nil
        dwellRecorded = false
        presentedPaywall = nil
    }
}

extension OBPaywallViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard let paywall = presentationController.presentedViewController as? FeatureInfoPaywallViewController else {
            return
        }

        presentedPaywall = nil
        completePaywall(subscribed: false, referralCode: paywall.currentReferralCode)
    }
}
