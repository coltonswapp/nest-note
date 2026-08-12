//
//  DemoModeService.swift
//  nest-note
//
//  Temporarily points eligible users at a shared, read-only demo nest.
//
//  Firestore `adminConfig/demoMode`:
//  {
//    "enabled": true,
//    "nestId": "<shared demo nest id>",
//    "allowedEmails": ["influencer@example.com"]
//  }
//
//  Security rules (Firebase Console — not in this repo) should:
//  - Allow read of nests/{demoNestId} and subcollections (entries, nestCategories,
//    sessions) plus Storage `nests/{demoNestId}/**` when request.auth.token.email
//    is in adminConfig/demoMode.allowedEmails (case-insensitive match in rules
//    is limited; store emails lowercased).
//  - Deny writes to that nest for everyone except the nest ownerId.
//

import Foundation
import FirebaseFirestore

struct DemoModeConfig {
    var enabled: Bool
    var nestId: String
    var allowedEmails: [String]

    static let empty = DemoModeConfig(enabled: false, nestId: "", allowedEmails: [])

    func allows(email: String) -> Bool {
        let needle = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return false }
        return allowedEmails.contains { $0.lowercased() == needle }
    }
}

enum DemoModeError: LocalizedError {
    case notEligible
    case nestNotConfigured
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notEligible:
            return "Demo nest isn’t available for this account."
        case .nestNotConfigured:
            return "The demo nest isn’t set up yet."
        case .notSignedIn:
            return "Sign in to view the demo nest."
        }
    }
}

final class DemoModeService {
    static let shared = DemoModeService()

    static let enterToastText = "Viewing the NestNote demo nest"
    static let enterToastSubtitle = "Tap Demo to hide it while you film"
    static let exitToastText = "Back to your nest"
    /// Shown on the invite screen in demo mode; not written to `invites/`.
    static let placeholderInviteCode = "DEMO00"

    private static let activeDefaultsKey = "demoMode.isActive"
    private static let configDocument = Firestore.firestore()
        .collection("adminConfig")
        .document("demoMode")

    private let defaults = UserDefaults.standard
    private var cachedConfig: DemoModeConfig?

    private init() {}

    var isActive: Bool {
        get { defaults.bool(forKey: Self.activeDefaultsKey) }
        set {
            defaults.set(newValue, forKey: Self.activeDefaultsKey)
            NotificationCenter.default.post(name: .demoModeDidChange, object: nil)
        }
    }

    var nestId: String? {
        let id = cachedConfig?.nestId.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return id.isEmpty ? nil : id
    }

    /// Settings row: production allowlist, or always in DEBUG.
    var shouldShowEntryRow: Bool {
        #if DEBUG
        return UserService.shared.isSignedIn
        #else
        return isEligible
        #endif
    }

    var isEligible: Bool {
        #if DEBUG
        return true
        #else
        guard FeatureFlagService.shared.isEnabled(.demoModeEnabled),
              let config = cachedConfig,
              config.enabled,
              let email = UserService.shared.currentUser?.personalInfo.email,
              !config.nestId.isEmpty
        else {
            return false
        }
        return config.allows(email: email)
        #endif
    }

    func refreshConfig() async {
        do {
            let snapshot = try await Self.configDocument.getDocument()
            cachedConfig = Self.parseConfig(snapshot.data())
            Logger.log(
                level: .info,
                category: .demoMode,
                message: "Loaded demo config enabled=\(cachedConfig?.enabled ?? false) nestId=\(cachedConfig?.nestId ?? "none") emails=\(cachedConfig?.allowedEmails.count ?? 0)"
            )
        } catch {
            Logger.log(
                level: .error,
                category: .demoMode,
                message: "Failed to load demo config: \(error.localizedDescription)"
            )
            if cachedConfig == nil {
                cachedConfig = .empty
            }
        }
    }

    /// Called from `NestService.setup()`. Returns true when the demo nest should be loaded.
    func shouldLoadDemoNestOnSetup() async -> Bool {
        guard isActive else { return false }
        await refreshConfig()

        guard isEligible, nestId != nil else {
            Logger.log(level: .info, category: .demoMode, message: "Demo flag was on but no longer eligible — exiting")
            isActive = false
            return false
        }
        return true
    }

    func enter() async throws {
        guard UserService.shared.isSignedIn else { throw DemoModeError.notSignedIn }

        await refreshConfig()
        guard isEligible else { throw DemoModeError.notEligible }
        guard let nestId else { throw DemoModeError.nestNotConfigured }

        guard let coordinator = LaunchCoordinator.shared else {
            throw DemoModeError.notSignedIn
        }

        try await coordinator.transitionInterface(
            toast: Self.enterToastText,
            toastSubtitle: Self.enterToastSubtitle
        ) {
            self.isActive = true
            if ModeManager.shared.currentMode != .nestOwner {
                ModeManager.shared.currentMode = .nestOwner
            }

            do {
                try await NestService.shared.fetchAndSetCurrentNest(nestId: nestId)
                await SessionService.shared.reset()
            } catch {
                self.isActive = false
                try? await NestService.shared.setup()
                await SessionService.shared.reset()
                throw error
            }
        }

        Logger.log(level: .info, category: .demoMode, message: "Entered demo nest \(nestId)")
    }

    func exit() async throws {
        guard let coordinator = LaunchCoordinator.shared else {
            throw DemoModeError.notSignedIn
        }

        try await coordinator.transitionInterface(toast: Self.exitToastText) {
            self.isActive = false
            try await NestService.shared.setup()
            await SessionService.shared.reset()
        }
        Logger.log(level: .info, category: .demoMode, message: "Exited demo nest")
    }

    func clearOnLogout() {
        isActive = false
        cachedConfig = nil
    }

    #if DEBUG
    func writeConfig(nestId: String, enabled: Bool = true) async throws {
        try await Self.configDocument.setData([
            "enabled": enabled,
            "nestId": nestId
        ], merge: true)
        await refreshConfig()
    }
    #endif

    private static func parseConfig(_ data: [String: Any]?) -> DemoModeConfig {
        guard let data else { return .empty }
        let emails = (data["allowedEmails"] as? [String]) ?? []
        return DemoModeConfig(
            enabled: data["enabled"] as? Bool ?? false,
            nestId: data["nestId"] as? String ?? "",
            allowedEmails: emails
        )
    }
}
