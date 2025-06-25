//
//  SubscriptionService.swift
//  nest-note
//
//  Created by Claude Code on 16/6/2024.
//

import Foundation
import RevenueCat
import RevenueCatUI
import UIKit

final class SubscriptionService {
    
    // MARK: - Properties
    static let shared = SubscriptionService()
    
    private var cachedCustomerInfo: CustomerInfo?
    private var lastFetchTime: Date?
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    // MARK: - Subscription Status
    enum SubscriptionTier {
        case free
        case pro
    }
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Gets the current subscription tier for the user
    /// - Returns: The user's current subscription tier
    func getCurrentTier() async -> SubscriptionTier {
        do {
            let customerInfo = try await getCustomerInfo()
            return determineTier(from: customerInfo)
        } catch {
            Logger.log(level: .error, category: .subscription, message: "Failed to get customer info: \(error.localizedDescription)")
            // Default to free tier on error
            return .free
        }
    }
    
    /// Checks if the user has an active pro subscription
    /// - Returns: True if user has pro subscription, false otherwise
    func hasProSubscription() async -> Bool {
        let tier = await getCurrentTier()
        return tier == .pro
    }
    
    /// Gets the current customer info from RevenueCat
    /// Uses cached data if available and not expired
    /// - Returns: CustomerInfo from RevenueCat
    private func getCustomerInfo() async throws -> CustomerInfo {
        // Check if we have cached data that's still valid
        if let cachedInfo = cachedCustomerInfo,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheExpirationTime {
            return cachedInfo
        }
        
        // Fetch fresh data from RevenueCat
        return try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getCustomerInfo { [weak self] customerInfo, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let customerInfo = customerInfo {
                    // Cache the result
                    self?.cachedCustomerInfo = customerInfo
                    self?.lastFetchTime = Date()
                    continuation.resume(returning: customerInfo)
                } else {
                    continuation.resume(throwing: SubscriptionError.noCustomerInfo)
                }
            }
        }
    }
    
    /// Determines the subscription tier based on customer info
    /// - Parameter customerInfo: RevenueCat customer info
    /// - Returns: The user's subscription tier
    private func determineTier(from customerInfo: CustomerInfo) -> SubscriptionTier {
        // Check if user has any active entitlements
        if customerInfo.entitlements.active.isEmpty {
            return .free
        }
        
        // Check specifically for pro entitlement
        // You'll need to configure this entitlement identifier in RevenueCat dashboard
        if customerInfo.entitlements.active["Pro"] != nil {
            return .pro
        }
        
        // Default to free if no pro entitlement found
        return .free
    }
    
    /// Refreshes the cached customer info
    func refreshCustomerInfo() async {
        do {
            // Clear cache to force fresh fetch
            cachedCustomerInfo = nil
            lastFetchTime = nil
            
            let _ = try await getCustomerInfo()
            Logger.log(level: .info, category: .subscription, message: "Customer info refreshed successfully")
        } catch {
            Logger.log(level: .error, category: .subscription, message: "Failed to refresh customer info: \(error.localizedDescription)")
        }
    }
    
    /// Clears the cached customer info (useful when user logs out)
    func clearCache() {
        cachedCustomerInfo = nil
        lastFetchTime = nil
    }
}

// MARK: - Subscription Errors
enum SubscriptionError: LocalizedError {
    case noCustomerInfo
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noCustomerInfo:
            return "No customer information available"
        case .networkError:
            return "Network error while fetching subscription status"
        case .unknown:
            return "Unknown subscription error"
        }
    }
}

// MARK: - Convenience Extensions
extension SubscriptionService {
    
    /// Checks if a feature is available for the current subscription tier
    /// - Parameter feature: The feature to check
    /// - Returns: True if feature is available, false otherwise
    func isFeatureAvailable(_ feature: ProFeature) async -> Bool {
        let tier = await getCurrentTier()
        return feature.isAvailable(for: tier)
    }
}

// MARK: - Pro Features Enum
enum ProFeature {
    case unlimitedEntries
    case customCategories
    case multiDaySessions
    case sessionEvents
    
    func isAvailable(for tier: SubscriptionService.SubscriptionTier) -> Bool {
        switch tier {
        case .free:
            return false // All pro features are disabled for free tier
        case .pro:
            return true // All features available for pro tier
        }
    }
    
    var displayName: String {
        switch self {
        case .unlimitedEntries:
            return "Unlimited Entries"
        case .customCategories:
            return "Custom Categories"
        case .multiDaySessions:
            return "Multi-day Sessions"
        case .sessionEvents:
            return "Session Events"
        }
    }
    
    var description: String {
        switch self {
        case .unlimitedEntries:
            return "Create unlimited entries across all categories"
        case .customCategories:
            return "Create your own specialized categories"
        case .multiDaySessions:
            return "Schedule overnight stays and extended care sessions"
        case .sessionEvents:
            return "Add detailed scheduling within sessions"
        }
    }
    
    // MARK: - Pro Feature Alert Messages
    
    var alertTitle: String {
        switch self {
        case .unlimitedEntries:
            return "Entry Limit Reached"
        case .customCategories:
            return "Pro Feature"
        case .multiDaySessions:
            return "Pro Feature"
        case .sessionEvents:
            return "Pro Feature"
        }
    }
    
    var alertMessage: String {
        switch self {
        case .unlimitedEntries:
            return "You've reached the 10 entry limit on the free plan. Upgrade to Pro for unlimited entries and more features."
        case .customCategories:
            return "Creating custom categories is a Pro feature. Upgrade to Pro for unlimited categories and more features."
        case .multiDaySessions:
            return "Multi-day sessions are a Pro feature. Upgrade to Pro for multi-day sessions and more features."
        case .sessionEvents:
            return "Session events are a Pro feature. Upgrade to Pro for session events and more features."
        }
    }
    
    var successMessage: String {
        switch self {
        case .unlimitedEntries:
            return "Subscription activated! You can now create unlimited entries & do so much more!"
        case .customCategories:
            return "Subscription activated! You can now create unlimited categories & do so much more!"
        case .multiDaySessions:
            return "Subscription activated! You can now create multi-day sessions & do so much more!"
        case .sessionEvents:
            return "Subscription activated! You can now create session events & do so much more!"
        }
    }
}

// MARK: - Shared Paywall Handling Protocol
protocol PaywallPresentable: UIViewController {
    func showUpgradeFlow()
    var proFeature: ProFeature { get }
}

extension PaywallPresentable where Self: PaywallViewControllerDelegate {
    func showUpgradeFlow() {
        let paywallViewController = PaywallViewController()
        paywallViewController.delegate = self
        present(paywallViewController, animated: true)
        
        // Mark the final setup step as complete when paywall is viewed
        SetupService.shared.markStepComplete(.finalStep)
    }
    
    func showUpgradePrompt(for feature: ProFeature) {
        let alert = UIAlertController(
            title: feature.alertTitle,
            message: feature.alertMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Maybe Later", style: .cancel))
        alert.addAction(UIAlertAction(title: "Upgrade to Pro", style: .default) { [weak self] _ in
            self?.showUpgradeFlow()
        })
        
        present(alert, animated: true)
    }
}

// MARK: - Default PaywallViewControllerDelegate Implementation
extension PaywallPresentable where Self: PaywallViewControllerDelegate {
    func paywallViewController(_ controller: PaywallViewController, didFinishPurchasingWith customerInfo: CustomerInfo) {
        controller.dismiss(animated: true) { [weak self] in
            Task {
                await SubscriptionService.shared.refreshCustomerInfo()
                self?.showToast(text: self?.proFeature.successMessage ?? "Subscription activated!")
            }
        }
    }
    
    func paywallViewController(_ controller: PaywallViewController, didFailPurchasingWith error: Error) {
        Logger.log(level: .error, category: .purchases, message: "Subscription purchase failed: \(error.localizedDescription)")
    }
    
    func paywallViewController(_ controller: PaywallViewController, didFinishRestoringWith customerInfo: CustomerInfo) {
        controller.dismiss(animated: true) { [weak self] in
            Task {
                await SubscriptionService.shared.refreshCustomerInfo()
                self?.showToast(text: self?.proFeature.successMessage ?? "Subscription restored!")
            }
        }
    }
    
    func paywallViewController(_ controller: PaywallViewController, didFailRestoringWith error: Error) {
        Logger.log(level: .error, category: .purchases, message: "Subscription restore failed: \(error.localizedDescription)")
    }
}
