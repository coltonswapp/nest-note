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
    private var pendingURL: URL?
    private var backgroundTime: Date?

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
                
                // After initialization is complete, handle any pending URL
                await MainActor.run {
                    if let pendingURL = self.pendingURL {
                        self.handleIncomingURL(pendingURL)
                        self.pendingURL = nil
                    }
                }
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
        
        // Store any URLs that were passed to the app on launch for later processing
        if let urlContext = options.urlContexts.first {
            self.pendingURL = urlContext.url
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
        
        // Only process background return if user is authenticated
        guard UserService.shared.isAuthenticated else { return }
        
        // Check if we need to refresh based on background time
        guard let backgroundTime = backgroundTime else {
            // No background time recorded, just trigger normal refresh
            NotificationCenter.default.post(name: .sessionDidChange, object: nil)
            return
        }
        
        let elapsedTime = Date().timeIntervalSince(backgroundTime)
        let thirtyMinutes: TimeInterval = 30 * 60
        let elapsedMinutes = Int(elapsedTime / 60)
        
        if elapsedTime >= thirtyMinutes {
            // Log Firebase event for extended background period
            Tracker.shared.trackAppBackgroundReturn(
                backgroundDurationMinutes: elapsedMinutes,
                requiresRefresh: true
            )
            
            // Trigger refresh on active view controllers
            NotificationCenter.default.post(name: .appReturnedFromLongBackground, object: nil)
        } else {
            // Log Firebase event for shorter background period (optional)
            Tracker.shared.trackAppBackgroundReturn(
                backgroundDurationMinutes: elapsedMinutes,
                requiresRefresh: false
            )
            
            // Trigger normal session refresh
            NotificationCenter.default.post(name: .sessionDidChange, object: nil)
        }
        
        // Clear background time
        self.backgroundTime = nil
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        
        // Track when app enters background
        backgroundTime = Date()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        
        // If the coordinator hasn't finished initialization yet, store for later
        // This handles cases where a URL is opened while the app is still starting up
        if coordinator == nil {
            self.pendingURL = url
        } else {
            handleIncomingURL(url)
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "nestnote",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.host == "invite",
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }
        
        // Ensure we have an authenticated user before proceeding
        guard Auth.auth().currentUser != nil else {
            Logger.log(level: .info, category: .launcher, message: "Attempted to handle invite URL but user is not authenticated")
            // If user is not authenticated, they need to sign in first
            // The URL will be lost, but this is the expected behavior for security
            return
        }
        
        // Check if user is in nest owner mode and needs to switch to sitter mode
        if ModeManager.shared.isNestOwnerMode {
            DispatchQueue.main.async {
                self.showModeSwitchAlert(for: code)
            }
        } else {
            // User is already in sitter mode, proceed directly
            DispatchQueue.main.async {
                self.presentJoinSessionViewController(with: code)
            }
        }
    }
    
    private func showModeSwitchAlert(for code: String) {
        guard let rootVC = self.window?.rootViewController else { return }
        
        let alert = UIAlertController(
            title: "Switch to Sitter Mode?",
            message: "You're currently in Nest Owner mode. To accept this sitting invitation, you need to switch to Sitter mode. Would you like to switch now?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Switch & Join", style: .default) { [weak self] _ in
            // Properly switch to sitter mode with completion handler
            self?.performModeSwitch(to: .sitter) {
                // After mode switch is complete, present the join session view controller
                self?.presentJoinSessionViewController(with: code)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        rootVC.present(alert, animated: true)
    }
    
    private func presentJoinSessionViewController(with code: String) {
        guard let rootVC = self.window?.rootViewController else { return }
        
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
    
    private func performModeSwitch(to newMode: AppMode, completion: @escaping () -> Void) {
        // 1. Update the mode first
        ModeManager.shared.currentMode = newMode
        Logger.log(level: .info, message: "Switching to \(newMode.rawValue) mode for invite acceptance")
        
        // 2. Provide haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        
        // 3. Get shared LaunchCoordinator
        guard let launchCoordinator = LaunchCoordinator.shared else {
            Logger.log(level: .error, message: "LaunchCoordinator shared instance not available")
            completion() // Still call completion even if mode switch fails
            return
        }
        
        // 4. Post notification and perform mode switch
        NotificationCenter.default.post(name: .modeDidChange, object: nil)
        
        Task {
            do {
                try await launchCoordinator.switchMode(to: newMode)
                
                // Call completion on main actor after mode switch is complete
                await MainActor.run {
                    completion()
                }
            } catch {
                Logger.log(level: .error, message: "Failed to complete mode transition: \(error.localizedDescription)")
                // Still call completion even if mode switch fails
                await MainActor.run {
                    completion()
                }
            }
        }
    }

    // Handle notification response when app is launched via notification tap
    func scene(_ scene: UIScene, willContinueUserActivityWithType userActivityType: String) {
        // Only trigger data refresh if user is authenticated
        if UserService.shared.isAuthenticated {
            NotificationCenter.default.post(name: .sessionDidChange, object: nil)
        }
    }

    // Add a method to handle notification responses
    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        let content = response.notification.request.content
        let userInfo = content.userInfo
        
        // Handle session status change notification
        if let type = userInfo["type"] as? String, type == "session_status_change" {
            // Only post notifications if user is authenticated
            if UserService.shared.isAuthenticated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: .sessionDidChange, object: nil)
                    NotificationCenter.default.post(name: .sessionStatusDidChange, object: nil)
                }
            }
        }
    }
}
