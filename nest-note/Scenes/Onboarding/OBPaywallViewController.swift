//
//  OBPaywallViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 9/9/25.
//

import UIKit
import RevenueCat
import RevenueCatUI

final class OBPaywallViewController: NNOnboardingViewController, PaywallViewControllerDelegate {
    
    private var paywallViewController: PaywallViewController?
    private var hasCompletedPaywall: Bool = false
    private var hasPurchased: Bool = false
    private var hasShownExitOffer: Bool = false
    private var offeringId: String? // Offering to display (nil = default, "partner" = partner offering)
    private var exitOfferingId: String? // Exit offer to display on dismissal

    override func viewDidLoad() {
        super.viewDidLoad()

        // Get offering ID from coordinator (partner offering if they have a referral code)
        offeringId = (coordinator as? OnboardingCoordinator)?.paywallOfferingId

        // Set exit offer ID to show the winback offering when user dismisses
        exitOfferingId = "winback"

        setupOnboarding(
            title: "Unlock Premium Features",
            subtitle: "Get the most out of NestNote with unlimited entries and premium features."
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if paywallViewController == nil {
            setupAndPresentPaywall(isExitOffer: false)
        }
    }

    private func setupAndPresentPaywall(isExitOffer: Bool) {
        Task {
            do {
                // Fetch offerings from RevenueCat
                let offerings = try await Purchases.shared.offerings()

                let offeringIdToUse = isExitOffer ? exitOfferingId : offeringId
                let offering: Offering?

                if let offeringIdToUse = offeringIdToUse {
                    offering = offerings.offering(identifier: offeringIdToUse)
                    if let offering = offering {
                        if isExitOffer {
                            Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Showing exit offer (winback)")
                        } else {
                            Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Showing \(offeringIdToUse) offering")
                        }
                    }
                } else {
                    offering = offerings.current
                    Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Showing default offering")
                }

                await MainActor.run {
                    if let offering = offering {
                        paywallViewController = PaywallViewController(offering: offering)
                    } else {
                        paywallViewController = PaywallViewController()
                    }
                    paywallViewController?.delegate = self
                    presentPaywall()
                }

            } catch {
                Logger.log(level: .error, category: .paywall, message: "🎯 PAYWALL: Failed to fetch offerings: \(error.localizedDescription)")

                await MainActor.run {
                    paywallViewController = PaywallViewController()
                    paywallViewController?.delegate = self
                    presentPaywall()
                }
            }
        }
    }

    private func presentPaywall() {
        guard let paywallViewController = paywallViewController else { return }
        paywallViewController.modalPresentationStyle = .pageSheet
        present(paywallViewController, animated: true)
    }

    private func completePaywallAndContinue() {
        guard !hasCompletedPaywall else {
            // Already completed, ignore duplicate calls
            return
        }
        hasCompletedPaywall = true
        (coordinator as? OnboardingCoordinator)?.next()
    }

    override func reset() {
        super.reset()
        hasCompletedPaywall = false
        hasPurchased = false
        hasShownExitOffer = false
    }

    // MARK: - PaywallViewControllerDelegate

    func paywallViewController(_ controller: PaywallViewController, didFinishPurchasingWith customerInfo: CustomerInfo) {
        hasPurchased = true

        // Track conversion
        let productId = customerInfo.activeSubscriptions.first ?? "unknown_product"
        let conversionSource = hasShownExitOffer ? "exit_offer" : "main_paywall"
        OnboardingAnalyticsService.shared.recordConversion(type: "purchase", productId: productId)

        // Track which offering was used
        let currentOfferingId = hasShownExitOffer ? exitOfferingId : offeringId
        if let currentOfferingId = currentOfferingId {
            Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Conversion completed with \(currentOfferingId) offering (\(conversionSource))")
            Analytics.logEvent("paywall_conversion", parameters: [
                "offering_id": currentOfferingId,
                "product_id": productId,
                "conversion_source": conversionSource
            ])
        } else {
            Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Conversion completed (\(conversionSource))")
            Analytics.logEvent("paywall_conversion", parameters: [
                "product_id": productId,
                "conversion_source": conversionSource
            ])
        }

        Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Purchase complete")

        // Dismiss and continue
        controller.dismiss(animated: true) { [weak self] in
            (self?.coordinator as? OnboardingCoordinator)?.next()
        }
    }

    func paywallViewController(_ controller: PaywallViewController, didFinishRestoringWith customerInfo: CustomerInfo) {
        hasPurchased = true

        // Track restoration
        let productId = customerInfo.activeSubscriptions.first ?? "restored_product"
        OnboardingAnalyticsService.shared.recordConversion(type: "restore", productId: productId)

        if let offeringId = offeringId {
            Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Restore completed with \(offeringId) offering")
            Analytics.logEvent("paywall_restore", parameters: [
                "offering_id": offeringId,
                "product_id": productId
            ])
        }

        Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Restore complete")

        // Dismiss and continue
        controller.dismiss(animated: true) { [weak self] in
            (self?.coordinator as? OnboardingCoordinator)?.next()
        }
    }

    func paywallViewController(_ controller: PaywallViewController, didFailPurchasingWith error: Error) {
        Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Purchase failed: \(error.localizedDescription)")
    }

    func paywallViewController(_ controller: PaywallViewController, didFailRestoringWith error: Error) {
        Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Restore failed: \(error.localizedDescription)")
    }

    func paywallViewControllerWasDismissed(_ controller: PaywallViewController) {
        Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Paywall dismissed - purchased: \(hasPurchased), shown exit offer: \(hasShownExitOffer)")

        // If user dismissed without purchasing and we haven't shown exit offer yet, show it
        if !hasPurchased && !hasShownExitOffer {
            hasShownExitOffer = true
            Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: Showing exit offer")

            // Reset paywall controller for exit offer
            paywallViewController = nil

            // Show exit offer after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.setupAndPresentPaywall(isExitOffer: true)
            }
        } else {
            // Either they purchased or already saw exit offer - continue
            if !hasPurchased {
                Logger.log(level: .info, category: .paywall, message: "🎯 PAYWALL: User declined after exit offer, continuing onboarding")
            }
            completePaywallAndContinue()
        }
    }
}
