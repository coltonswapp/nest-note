import UIKit

final class AdminNotificationRouter {
    static let shared = AdminNotificationRouter()

    private init() {}

    func handleSignupNotification(userInfo: [AnyHashable: Any]) {
        guard userInfo["type"] as? String == "new_signup" else { return }

        let surveyId = userInfo["surveyId"] as? String ?? ""

        Task { @MainActor in
            await presentSignupDestination(surveyId: surveyId)
        }
    }

    @MainActor
    private func presentSignupDestination(surveyId: String) async {
        guard let presenter = topViewController() else { return }

        if !surveyId.isEmpty, let survey = try? await SurveyService.shared.getSurveyResponse(id: surveyId) {
            let detailVC = SurveyResponseDetailViewController(survey: survey)
            let nav = UINavigationController(rootViewController: detailVC)
            nav.modalPresentationStyle = .formSheet
            presenter.present(nav, animated: true)
            return
        }

        let dashboardVC = SurveyDashboardViewController()
        let nav = UINavigationController(rootViewController: dashboardVC)
        nav.modalPresentationStyle = .formSheet
        presenter.present(nav, animated: true)
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
