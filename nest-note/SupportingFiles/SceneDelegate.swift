//
//  SceneDelegate.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//

import UIKit
import FirebaseAuth
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var coordinator: LaunchCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        // Create and start coordinator
        let coordinator = LaunchCoordinator(window: window)
        self.coordinator = coordinator
        
        Task {
            do {
                try await coordinator.start()
            } catch {
                Logger.log(level: .error, category: .launcher, message: "Configuration failed: \(error)")
                
                // Show error to user
                let alert = UIAlertController(
                    title: "Setup Error",
                    message: "Failed to complete initial setup. Some features may be unavailable.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                window.rootViewController?.present(alert, animated: true)
            }
        }
        
        // Handle any URLs that were passed to the app on launch
        if let urlContext = options.urlContexts.first {
            handleIncomingURL(urlContext.url)
        }
        
        // Handle notification if app was launched from a notification
        if let notification = options.notificationResponse {
            handleNotificationResponse(notification)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        
        // Trigger data refresh when app enters foreground
        NotificationCenter.default.post(name: .sessionDidChange, object: nil)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleIncomingURL(url)
    }
    
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "nestnote",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.host == "invite",
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }
        
        // Present the JoinSessionViewController with the code pre-filled
        DispatchQueue.main.async {
            if let rootVC = self.window?.rootViewController {
                let joinSessionVC = JoinSessionViewController()
                let navigationController = UINavigationController(rootViewController: joinSessionVC)
                
                // Pre-fill the code
                let formattedCode = String(code.prefix(3)) + "-" + String(code.suffix(3))
                joinSessionVC.codeTextField.textField.text = formattedCode
                
                rootVC.present(navigationController, animated: true) { 
                    // Automatically start finding the session
                    joinSessionVC.findSessionButtonTapped()
                }
            }
        }
    }

    // Handle notification response when app is launched via notification tap
    func scene(_ scene: UIScene, willContinueUserActivityWithType userActivityType: String) {
        // Trigger data refresh when app becomes active
        NotificationCenter.default.post(name: .sessionDidChange, object: nil)
    }

    // Add a method to handle notification responses
    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        let content = response.notification.request.content
        let userInfo = content.userInfo
        
        // Handle session status change notification
        if let type = userInfo["type"] as? String, type == "session_status_change" {
            // Post notifications to refresh both home controllers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .sessionDidChange, object: nil)
                NotificationCenter.default.post(name: .sessionStatusDidChange, object: nil)
            }
        }
    }
}
