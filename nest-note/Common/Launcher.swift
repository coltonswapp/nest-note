import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let appDidReset = Notification.Name("appDidReset")
    static let modeDidChange = Notification.Name("modeDidChange")
}

/// Responsible for launching and configuring core app services
final class Launcher {
    
    // MARK: - Properties
    static let shared = Launcher()
    
    private init() {}
    
    // MARK: - Configuration
    func configure() async throws {
        Logger.log(level: .info, category: .launcher, message: "Beginning service configuration...")
        
        // Setup UserService first
        let userSetupResult = await UserService.shared.setup()
        
        // Only reset ModeManager if no user is signed in
        // This preserves the saved mode between launches for signed in users
        if !userSetupResult.isSignedIn {
            ModeManager.shared.resetToDefaultMode()
        }
        
        // Only setup NestService if user is signed in
        if userSetupResult.isSignedIn {
            do {
                try await NestService.shared.setup()
            } catch {
                Logger.log(level: .error, category: .launcher, message: "Failed to setup NestService: \(error)")
                // We might want to handle this differently depending on the error
                // For now, we'll only log it and not throw
                throw error
            }
        }
        
        registerForNotificationsIfAuthorized()
        
        Logger.log(level: .info, category: .launcher, message: "Service configuration complete ✅")
    }
    
    /// Resets all services - useful for sign out scenarios
    func reset() async {
        Logger.log(level: .info, category: .launcher, message: "Resetting service configuration...")
        
        // Reset ModeManager first
        ModeManager.shared.resetToDefaultMode()
        
        // Reset NestService
        await NestService.shared.reset()
        // Reset SessionService
        await SessionService.shared.reset()
        
        // Reset UserService last
        do {
            try await UserService.shared.reset()
        } catch {
            Logger.log(level: .info, category: .launcher, message: "There was an issue resetting the UserService... ❌")
        }
        
        // Post notification on main thread that app has reset
        await MainActor.run {
            NotificationCenter.default.post(name: .appDidReset, object: nil)
        }
        
        Logger.log(level: .info, category: .launcher, message: "Service configuration reset complete ✅")
    }
    
    /// Registers for remote notifications if already authorized, without requesting permission
    /// This ensures we register for push notifications on app launch for existing users
    /// without bombarding fresh install users with permission prompts
    private func registerForNotificationsIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            // Only register if already authorized - don't request permission
            if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    Logger.log(level: .info, category: .launcher, message: "Registered for remote notifications (already authorized)")
                }
            } else {
                Logger.log(level: .info, category: .launcher, message: "Notification permissions not authorized, skipping registration. Status: \(settings.authorizationStatus.rawValue)")
            }
        }
    }
}
