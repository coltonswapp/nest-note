import UIKit

final class SessionPaymentReminderRouter {
    static let shared = SessionPaymentReminderRouter()

    private init() {}

    func handlePaymentReminderNotification(userInfo: [AnyHashable: Any]) {
        guard Self.notificationType(from: userInfo) == "session_payment_reminder" else { return }
        guard let sessionId = userInfo["sessionId"] as? String, !sessionId.isEmpty,
              let nestId = userInfo["nestId"] as? String, !nestId.isEmpty else {
            return
        }

        Task { @MainActor in
            await presentPaymentDestination(sessionId: sessionId, nestId: nestId)
        }
    }

    static func notificationType(from userInfo: [AnyHashable: Any]) -> String? {
        if let type = userInfo["type"] as? String {
            return type
        }

        if let gcmData = userInfo["gcm.notification.data"] as? [String: Any],
           let type = gcmData["type"] as? String {
            return type
        }

        return nil
    }

    @MainActor
    private func presentPaymentDestination(sessionId: String, nestId: String) async {
        guard UserService.shared.isAuthenticated else { return }

        do {
            guard let session = try await SessionService.shared.getSession(
                nestID: nestId,
                sessionID: sessionId
            ) else {
                Logger.log(
                    level: .info,
                    category: .sessionService,
                    message: "Payment reminder session not found: \(sessionId)"
                )
                return
            }

            guard let presenter = topViewController() else { return }

            if let configuration = SessionPaymentViewController.Configuration.from(
                session: session,
                nestId: nestId
            ) {
                SessionPaymentCalculator.presentPaymentCalculator(
                    from: presenter,
                    configuration: configuration
                )
                return
            }

            let editVC = EditSessionViewController(sessionItem: session)
            let nav = UINavigationController(rootViewController: editVC)
            nav.modalPresentationStyle = .formSheet
            presenter.present(nav, animated: true)
        } catch {
            Logger.log(
                level: .error,
                category: .sessionService,
                message: "Failed to open payment reminder destination: \(error.localizedDescription)"
            )
        }
    }

    @MainActor
    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        if let nav = top as? UINavigationController {
            return nav.topViewController ?? nav
        }
        return top
    }
}
