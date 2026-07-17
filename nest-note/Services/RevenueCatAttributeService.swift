//
//  RevenueCatAttributeService.swift
//  nest-note
//

import Foundation
import RevenueCat

final class RevenueCatAttributeService {

    static let shared = RevenueCatAttributeService()

    private init() {}

    // MARK: - Onboarding (anonymous customer, before paywall)

    func syncBeforePaywall(
        email: String,
        phone: String,
        displayName: String,
        discoveryMethod: String?,
        onboardingVariant: String,
        referralCode: String?,
        referralCodeType: ReferralCodeType? = nil
    ) {
        applySubscriberAttributes(email: email, phone: phone, displayName: displayName)
        applyCustomAttributes(buildOnboardingCustomAttributes(
            firebaseUID: nil,
            discoveryMethod: discoveryMethod,
            onboardingVariant: onboardingVariant,
            referralCode: referralCode,
            referralCodeType: referralCodeType
        ))
        syncAttributes()

        Logger.log(
            level: .info,
            category: .subscription,
            message: "RevenueCat attributes synced before paywall (email: \(email.isEmpty ? "none" : "set"))"
        )
    }

    // MARK: - Identified user (after logIn or returning session)

    func syncFromUser(_ user: NestUser, custom: [String: String] = [:]) {
        syncFromProfile(
            email: user.personalInfo.email,
            phone: user.personalInfo.phone,
            displayName: user.personalInfo.name,
            firebaseUID: user.id,
            custom: custom
        )
    }

    func syncFromProfile(
        email: String?,
        phone: String?,
        displayName: String?,
        firebaseUID: String?,
        custom: [String: String] = [:]
    ) {
        applySubscriberAttributes(email: email, phone: phone, displayName: displayName)

        var mergedCustom = custom
        if let firebaseUID, !firebaseUID.isEmpty {
            mergedCustom["firebase_uid"] = firebaseUID
        }
        applyCustomAttributes(mergedCustom.filter { !$0.value.isEmpty })
        syncAttributes()

        Logger.log(
            level: .info,
            category: .subscription,
            message: "RevenueCat subscriber attributes synced for user: \(firebaseUID ?? "anonymous")"
        )
    }

    func syncOnboardingContext(
        for user: NestUser,
        discoveryMethod: String?,
        onboardingVariant: String,
        referralCode: String?,
        referralCodeType: ReferralCodeType? = nil
    ) {
        var custom = buildOnboardingCustomAttributes(
            firebaseUID: user.id,
            discoveryMethod: discoveryMethod,
            onboardingVariant: onboardingVariant,
            referralCode: referralCode,
            referralCodeType: referralCodeType
        )
        syncFromUser(user, custom: custom)
    }

    /// Syncs referral code and type to RevenueCat before purchase so they appear on webhooks and customer profiles.
    func syncReferralCode(_ referralCode: String, type: ReferralCodeType) async {
        let code = referralCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return }

        applyCustomAttributes([
            "referral_code": code,
            "referral_code_type": type.rawValue,
        ])

        do {
            try await Purchases.shared.syncAttributesAndOfferingsIfNeeded()
            Logger.log(
                level: .info,
                category: .subscription,
                message: "RevenueCat referral_code synced: \(code)"
            )
        } catch {
            Logger.log(
                level: .error,
                category: .subscription,
                message: "Failed to sync RevenueCat referral_code: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - RevenueCat logIn (with single retry)

    @discardableResult
    func logIn(appUserID: String) async throws -> CustomerInfo {
        var lastError: Error?

        for attempt in 1...2 {
            do {
                let customerInfo = try await performLogIn(appUserID: appUserID)
                Logger.log(
                    level: .info,
                    category: .subscription,
                    message: "RevenueCat logIn succeeded for \(appUserID) (attempt \(attempt))"
                )
                return customerInfo
            } catch {
                lastError = error
                Logger.log(
                    level: .error,
                    category: .subscription,
                    message: "RevenueCat logIn failed for \(appUserID) (attempt \(attempt)): \(error.localizedDescription)"
                )
                if attempt < 2 {
                    try await Task.sleep(for: .milliseconds(500))
                }
            }
        }

        throw lastError ?? SubscriptionError.unknown
    }

    // MARK: - Private

    private func performLogIn(appUserID: String) async throws -> CustomerInfo {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.logIn(appUserID) { customerInfo, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let customerInfo {
                    continuation.resume(returning: customerInfo)
                } else {
                    continuation.resume(throwing: SubscriptionError.noCustomerInfo)
                }
            }
        }
    }

    private func applySubscriberAttributes(email: String?, phone: String?, displayName: String?) {
        if let email, !email.isEmpty {
            Purchases.shared.attribution.setEmail(email)
        }

        if let phone, !phone.isEmpty {
            Purchases.shared.attribution.setPhoneNumber(phone)
        } else {
            Purchases.shared.attribution.setPhoneNumber(nil)
        }

        if let displayName, !displayName.isEmpty {
            Purchases.shared.attribution.setDisplayName(displayName)
        }
    }

    private func applyCustomAttributes(_ attributes: [String: String]) {
        guard !attributes.isEmpty else { return }
        Purchases.shared.attribution.setAttributes(attributes)
    }

    private func buildOnboardingCustomAttributes(
        firebaseUID: String?,
        discoveryMethod: String?,
        onboardingVariant: String,
        referralCode: String?,
        referralCodeType: ReferralCodeType? = nil
    ) -> [String: String] {
        var attributes: [String: String] = [
            "onboarding_variant": onboardingVariant
        ]

        if let firebaseUID, !firebaseUID.isEmpty {
            attributes["firebase_uid"] = firebaseUID
        }
        if let discoveryMethod, !discoveryMethod.isEmpty {
            attributes["discovery_method"] = discoveryMethod
        }
        if let referralCode, !referralCode.isEmpty {
            attributes["referral_code"] = referralCode
        }
        if let referralCodeType {
            attributes["referral_code_type"] = referralCodeType.rawValue
        }

        return attributes
    }

    private func syncAttributes() {
        Task {
            do {
                try await Purchases.shared.syncAttributesAndOfferingsIfNeeded()
            } catch {
                Logger.log(
                    level: .error,
                    category: .subscription,
                    message: "Failed to sync RevenueCat attributes: \(error.localizedDescription)"
                )
            }
        }
    }
}
