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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "Unlock Premium Features",
            subtitle: "Get the most out of NestNote with unlimited entries and premium features."
        )
        
        setupPaywall()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentPaywall()
    }
    
    private func setupPaywall() {
        paywallViewController = PaywallViewController()
        paywallViewController?.delegate = self
    }
    
    private func presentPaywall() {
        guard let paywallViewController = paywallViewController else { return }
        
        // Present the paywall modally
        paywallViewController.modalPresentationStyle = .pageSheet
        present(paywallViewController, animated: true)
    }
    
    // MARK: - PaywallViewControllerDelegate
    
    func paywallViewController(_ controller: PaywallViewController, didFinishPurchasingWith customerInfo: CustomerInfo) {
        // Purchase successful, dismiss paywall and continue onboarding
        controller.dismiss(animated: true) { [weak self] in
            (self?.coordinator as? OnboardingCoordinator)?.next()
        }
    }
    
    func paywallViewController(_ controller: PaywallViewController, didFailPurchasingWith error: Error) {
        // Purchase failed, but allow user to continue
        controller.dismiss(animated: true) { [weak self] in
            (self?.coordinator as? OnboardingCoordinator)?.next()
        }
    }
    
    func paywallViewController(_ controller: PaywallViewController, didFinishRestoringWith customerInfo: CustomerInfo) {
        // Restore successful, dismiss paywall and continue onboarding
        controller.dismiss(animated: true) { [weak self] in
            (self?.coordinator as? OnboardingCoordinator)?.next()
        }
    }
    
    func paywallViewController(_ controller: PaywallViewController, didFailRestoringWith error: Error) {
        // Restore failed, but allow user to continue
        controller.dismiss(animated: true) { [weak self] in
            (self?.coordinator as? OnboardingCoordinator)?.next()
        }
    }
    
    func paywallViewControllerWasDismissed(_ controller: PaywallViewController) {
        // User dismissed the paywall without purchasing, continue onboarding
        (coordinator as? OnboardingCoordinator)?.next()
    }
}