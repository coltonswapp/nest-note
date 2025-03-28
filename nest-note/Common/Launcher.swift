import Foundation

extension Notification.Name {
    static let appDidReset = Notification.Name("appDidReset")
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
            }
        }
        
        Logger.log(level: .info, category: .launcher, message: "Service configuration complete ✅")
    }
    
    /// Resets all services - useful for sign out scenarios
    func reset() async {
        Logger.log(level: .info, category: .launcher, message: "Resetting service configuration...")
        
        // Reset ModeManager first
        ModeManager.shared.resetToDefaultMode()
        
        // Reset NestService next
        await NestService.shared.reset()
        
        // Reset UserService last
        await UserService.shared.reset()
        
        // Post notification on main thread that app has reset
        await MainActor.run {
            NotificationCenter.default.post(name: .appDidReset, object: nil)
        }
        
        Logger.log(level: .info, category: .launcher, message: "Service configuration reset complete ✅")
    }
} 
