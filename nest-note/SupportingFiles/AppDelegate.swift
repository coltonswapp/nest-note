//
//  AppDelegate.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        FirebaseApp.configure()
        
        // Configure global navigation bar appearance with SF Rounded font
        configureNavigationBarAppearance()
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Set messaging delegate
        Messaging.messaging().delegate = self
        
        return true
    }
    
    // MARK: - UI Configuration
    private func configureNavigationBarAppearance() {
        // Configure navigation bar appearance with SF Rounded font
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // Set title font to SF Rounded
        if let roundedFont = UIFont(name: "SFRounded-Semibold", size: 17) {
            appearance.titleTextAttributes = [.font: roundedFont]
        } else {
            // Fallback to system rounded font if SFRounded-Semibold is not available
            let roundedFont = UIFont.systemFont(ofSize: 17, weight: .semibold).rounded()
            appearance.titleTextAttributes = [.font: roundedFont]
        }
        
        // Set large title font to SF Rounded
        if let largeTitleFont = UIFont(name: "SFRounded-Bold", size: 34) {
            appearance.largeTitleTextAttributes = [.font: largeTitleFont]
        } else {
            // Fallback to system rounded font if SFRounded-Bold is not available
            let largeTitleFont = UIFont.systemFont(ofSize: 34, weight: .bold).rounded()
            appearance.largeTitleTextAttributes = [.font: largeTitleFont]
        }
        
        // Apply the appearance to all navigation bars
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    
    // MARK: - APNs Registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.log(level: .error, category: .general, message: "Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Logger.log(level: .info, category: .general, message: "Received FCM token: \(String(describing: fcmToken))")
        
        guard let fcmToken = fcmToken else {
            Logger.log(level: .error, category: .general, message: "FCM token is nil")
            return
        }
        
        Logger.log(level: .info, category: .general, message: "Attempting to update FCM token in Firestore...")
        
        Task {
            do {
                try await UserService.shared.updateFCMToken(fcmToken)
                try await UserService.shared.updateNotificationPreferences(.init(sessionNotifications: true, otherNotifications: true))
                Logger.log(level: .info, category: .general, message: "Successfully updated FCM token in Firestore")
            } catch {
                Logger.log(level: .error, category: .general, message: "Failed to update FCM token: \(error.localizedDescription)")
                Logger.log(level: .error, category: .general, message: "Detailed error: \(error)")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Handle foreground notifications
        handleNotificationContent(notification.request.content)
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification response when app is in background
        handleNotificationContent(response.notification.request.content)
        
        // Always refresh data when app is opened via notification tap
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationCenter.default.post(name: .sessionDidChange, object: nil)
            NotificationCenter.default.post(name: .sessionStatusDidChange, object: nil)
        }
        
        completionHandler()
    }
    
    // MARK: - Notification Handling
    private func handleNotificationContent(_ content: UNNotificationContent) {
        // Extract userInfo from the notification content
        let userInfo = content.userInfo
        
        // Check if this is a session status change notification
        if let type = userInfo["type"] as? String, type == "session_status_change",
           let sessionId = userInfo["sessionId"] as? String, !sessionId.isEmpty,
           let newStatus = userInfo["newStatus"] as? String {
            
            // Post a local notification to update the UI
            NotificationCenter.default.post(
                name: .sessionStatusDidChange,
                object: nil,
                userInfo: [
                    "sessionId": sessionId,
                    "newStatus": newStatus,
                    "timestamp": userInfo["timestamp"] as? String ?? "",
                    "userRole": userInfo["userRole"] as? String ?? ""
                ]
            )
            
            // Log the notification handling
            Logger.log(
                level: .info,
                category: .general,
                message: "Handled session status change notification: \(sessionId) - \(newStatus)"
            )
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

