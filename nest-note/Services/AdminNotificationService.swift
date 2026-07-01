import Foundation
import FirebaseFirestore
import FirebaseFunctions
import FirebaseMessaging

struct AdminSignupAlertStatus {
    let isEnabled: Bool
    let fcmTokenPrefix: String?
    let registeredAt: Date?
    let registeredUserId: String?
}

final class AdminNotificationService {
    static let shared = AdminNotificationService()

    private static let localEnabledKey = "adminSignupAlertsEnabledLocally"

    private let db = Firestore.firestore()
    private let configRef = Firestore.firestore().collection("adminConfig").document("signupAlerts")

    private init() {}

    var isLocallyEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.localEnabledKey)
    }

    func currentFCMToken() async throws -> String {
        try await Messaging.messaging().token()
    }

    func registerSignupAlerts(fcmToken: String, userId: String) async throws {
        try await configRef.setData([
            "fcmToken": fcmToken,
            "registeredUserId": userId,
            "registeredAt": FieldValue.serverTimestamp(),
            "enabled": true,
            "apnsEnvironment": apnsEnvironmentLabel()
        ])
        UserDefaults.standard.set(true, forKey: Self.localEnabledKey)
        Logger.log(
            level: .info,
            category: .general,
            message: "Registered admin signup alerts (\(apnsEnvironmentLabel())) token: \(String(fcmToken.prefix(12)))…"
        )
    }

    func unregisterSignupAlerts() async throws {
        try await configRef.setData([
            "enabled": false
        ], merge: true)
        UserDefaults.standard.set(false, forKey: Self.localEnabledKey)
        Logger.log(level: .info, category: .general, message: "Disabled admin signup alerts for device")
    }

    func syncRegisteredTokenIfNeeded(_ fcmToken: String) async {
        guard isLocallyEnabled,
              let userId = UserService.shared.currentUser?.id else {
            return
        }

        do {
            let status = try await fetchSignupAlertStatus()
            guard status.isEnabled, status.registeredUserId == userId else { return }
            try await registerSignupAlerts(fcmToken: fcmToken, userId: userId)
        } catch {
            Logger.log(
                level: .error,
                category: .general,
                message: "Failed to refresh admin signup alert token: \(error.localizedDescription)"
            )
        }
    }

    func fetchSignupAlertStatus() async throws -> AdminSignupAlertStatus {
        let snapshot = try await configRef.getDocument()
        guard let data = snapshot.data() else {
            return AdminSignupAlertStatus(isEnabled: false, fcmTokenPrefix: nil, registeredAt: nil, registeredUserId: nil)
        }

        let enabled = data["enabled"] as? Bool ?? false
        let token = data["fcmToken"] as? String
        let prefix = token.map { String($0.prefix(12)) + "…" }
        let registeredAt = (data["registeredAt"] as? Timestamp)?.dateValue()
        let registeredUserId = data["registeredUserId"] as? String

        return AdminSignupAlertStatus(
            isEnabled: enabled,
            fcmTokenPrefix: prefix,
            registeredAt: registeredAt,
            registeredUserId: registeredUserId
        )
    }

    func sendTestSignupAlert() async throws {
        let callable = Functions.functions(region: "us-central1").httpsCallable("sendTestAdminSignupAlert")
        _ = try await callable.call([:])
    }

    private func apnsEnvironmentLabel() -> String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
}
