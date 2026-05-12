import Foundation
import UserNotifications

// Define setup step types for more modular completion checking
enum SetupStepType: Int, CaseIterable {
    case createAccount = 0
    case setupNest = 1
    case addFirstEntry = 2
    case enableNotifications = 4
    case feedback = 5
    case finalStep = 6
    
    var title: String {
        switch self {
        case .createAccount:
            return "Create your account"
        case .setupNest:
            return "Setup your Nest"
        case .addFirstEntry:
            return "Add your first item"
        case .enableNotifications:
            return "Enable Notifications"
        case .feedback:
            return "How to share feedback"
        case .finalStep:
            return "One last thing..."
        }
    }
    
    var subtitle: String {
        switch self {
        case .createAccount:
            return "You already did this one!"
        case .setupNest:
            return "Add a nest name and address."
        case .addFirstEntry:
            return "Items are pieces of information related to your nest. These can be entries (plain text), important places, or routines"
        case .enableNotifications:
            return "Stay in the know."
        case .feedback:
            return "We value your opinion!"
        case .finalStep:
            return "You're almost there!"
        }
    }
}

final class SetupService {
    static let shared = SetupService()
    
    private enum Keys {
        static func hasCompletedSetup(for userID: String) -> String {
            return "hasCompletedSetup_\(userID)"
        }
        
        static func completedSteps(for userID: String) -> String {
            return "completedSteps_\(userID)"
        }
    }
    
    private let defaults = UserDefaults.standard
    
    private var currentUserID: String? {
        return UserService.shared.currentUser?.id
    }
    
    private init() {
        // Initialization will be handled when a user is present
        // The first time setup is accessed for a user, we'll initialize their steps
    }
    
    var hasCompletedSetup: Bool {
        get {
            guard let userID = currentUserID else { return false }
            initializeUserSetupIfNeeded(userID: userID)
            return defaults.bool(forKey: Keys.hasCompletedSetup(for: userID))
        }
        set {
            guard let userID = currentUserID else { return }
            initializeUserSetupIfNeeded(userID: userID)
            defaults.set(newValue, forKey: Keys.hasCompletedSetup(for: userID))
        }
    }
    
    // Get all completed step indices
    private var completedStepIndices: [Int] {
        get {
            guard let userID = currentUserID else { return [] }
            initializeUserSetupIfNeeded(userID: userID)
            return defaults.array(forKey: Keys.completedSteps(for: userID)) as? [Int] ?? []
        }
        set {
            guard let userID = currentUserID else { return }
            initializeUserSetupIfNeeded(userID: userID)
            defaults.set(newValue, forKey: Keys.completedSteps(for: userID))
            
            // Check if all steps are complete
            if Set(newValue).count == SetupStepType.allCases.count {
                hasCompletedSetup = true
            }
        }
    }
    
    // Initialize setup for a new user if needed
    private func initializeUserSetupIfNeeded(userID: String) {
        let completedStepsKey = Keys.completedSteps(for: userID)
        
        // Check if this user already has setup data
        if defaults.object(forKey: completedStepsKey) == nil {
            // This is a new user, initialize with first two steps completed
            var initialSteps: [Int] = []
            initialSteps.append(SetupStepType.createAccount.rawValue)
            initialSteps.append(SetupStepType.setupNest.rawValue)
            defaults.set(initialSteps, forKey: completedStepsKey)
        }
    }
    
    // Check if a specific step is complete
    func isStepComplete(_ step: SetupStepType) -> Bool {
        return completedStepIndices.contains(step.rawValue)
    }
    
    // Mark a specific step as complete
    func markStepComplete(_ step: SetupStepType) {
        var currentCompleted = completedStepIndices
        if !currentCompleted.contains(step.rawValue) {
            currentCompleted.append(step.rawValue)
            completedStepIndices = currentCompleted
            
            // Post notification that a step was completed
            let userInfo: [String: Any] = [
                "step": step,
                "completedSteps": currentCompleted.count,
                "totalSteps": SetupStepType.allCases.count
            ]
            NotificationCenter.default.post(name: .setupStepDidComplete, object: nil, userInfo: userInfo)
        }
    }
    
    // Check if setup should be shown
    func shouldShowSetupFlow() async -> Bool {
        // If setup is already marked as complete in UserDefaults, don't show it
        if hasCompletedSetup {
            return false
        }
        
        // Check if user has nest content (entries, places, or routines) matching onboarding copy
        do {
            let itemCount = try await NestService.shared.countOnboardingFirstItems()

            if itemCount > 0 {
                markStepComplete(.addFirstEntry)

                // If they have several items, they're probably familiar with the app — hide the sticky flow entirely
                if itemCount >= 3 {
                    hasCompletedSetup = true
                    return false
                }
            }
            
            // Otherwise, show the setup flow
            return true
        } catch {
            Logger.log(level: .error, category: .general, message: "Error checking nest items for setup flow: \(error.localizedDescription)")
            return !hasCompletedSetup
        }
    }
    
    // Reset setup for the current user (clears all setup data)
    func resetSetupForCurrentUser() {
        guard let userID = currentUserID else {
            Logger.log(level: .error, category: .general, message: "Cannot reset setup - no current user")
            return
        }
        
        // Clear all setup data for this user
        defaults.removeObject(forKey: Keys.hasCompletedSetup(for: userID))
        defaults.removeObject(forKey: Keys.completedSteps(for: userID))
        
        Logger.log(level: .info, category: .general, message: "Setup reset for user: \(userID)")
        
        // Post notification that setup was reset
        NotificationCenter.default.post(name: .setupStepDidComplete, object: nil, userInfo: [
            "setupReset": true,
            "completedSteps": 0,
            "totalSteps": SetupStepType.allCases.count
        ])
    }
    
    // Mark a specific step as incomplete
    func markStepIncomplete(_ step: SetupStepType) {
        var currentCompleted = completedStepIndices
        if let index = currentCompleted.firstIndex(of: step.rawValue) {
            currentCompleted.remove(at: index)
            completedStepIndices = currentCompleted
            
            // Post notification that a step was marked incomplete
            let userInfo: [String: Any] = [
                "step": step,
                "completedSteps": currentCompleted.count,
                "totalSteps": SetupStepType.allCases.count
            ]
            NotificationCenter.default.post(name: .setupStepDidComplete, object: nil, userInfo: userInfo)
        }
    }
    
    // Check completion for a specific step based on app state
    func checkStepCompletion(_ step: SetupStepType) -> Bool {
        switch step {
        case .createAccount:
            // Always completed if user is viewing this screen
            return true
            
        case .setupNest:
            // Check if user has created a nest
            return NestService.shared.currentNest != nil
            
        case .addFirstEntry:
            return isStepComplete(.addFirstEntry)
            
        case .enableNotifications:
            // Check if user has enabled notifications
            // This would need to be implemented based on your app's behavior
            return checkIfUserEnabledNotifications()
            
        case .feedback:
            // show how to share feedback
            return checkIfUserExploredFeedback()
            
        case .finalStep:
            // Implement logic for final step
            return checkIfFinalStepComplete()
        }
    }
    
    // Helper methods for step completion checks
    
    private func checkIfUserExploredFeedback() -> Bool {
        // Placeholder - implement based on your app behavior
        return isStepComplete(.feedback)
    }
    
    private func checkIfUserEnabledNotifications() -> Bool {
        // If already marked as complete, return true
        if isStepComplete(.enableNotifications) {
            return true
        }
        
        // Otherwise, check the actual status
        var isEnabled = false
        
        // Use a semaphore to make this synchronous
        let semaphore = DispatchSemaphore(value: 0)
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            isEnabled = settings.authorizationStatus == .authorized || 
                       settings.authorizationStatus == .provisional
            semaphore.signal()
        }
        
        // Wait for the callback (with a timeout)
        _ = semaphore.wait(timeout: .now() + 1.0)
        
        // If notifications are enabled, mark the step as complete
        if isEnabled {
            markStepComplete(.enableNotifications)
        }
        
        return isEnabled
    }
    
    private func checkIfFinalStepComplete() -> Bool {
        // Placeholder - implement based on your app behavior
        return isStepComplete(.finalStep)
    }
    
    /// Re-evaluates setup progress from live app state. “Add first item” is synced from Nest (entries / places / routines).
    func refreshStepCompletionStatus() {
        Task { @MainActor in
            await syncAddFirstEntryFromNestIfNeeded()

            let previouslyCompleted = Set(self.completedStepIndices)

            for step in SetupStepType.allCases where step != .addFirstEntry {
                if self.checkStepCompletion(step) {
                    let wasAlreadyComplete = previouslyCompleted.contains(step.rawValue)
                    self.markStepComplete(step)

                    if !wasAlreadyComplete && self.isStepComplete(step) {
                        let userInfo: [String: Any] = [
                            "step": step,
                            "completedSteps": self.completedStepIndices.count,
                            "totalSteps": SetupStepType.allCases.count
                        ]
                        NotificationCenter.default.post(name: .setupStepDidComplete, object: nil, userInfo: userInfo)
                    }
                }
            }
        }
    }

    private func syncAddFirstEntryFromNestIfNeeded() async {
        do {
            let count = try await NestService.shared.countOnboardingFirstItems()
            if count > 0 {
                markStepComplete(.addFirstEntry)
            }
        } catch {
            Logger.log(level: .error, category: .general, message: "Failed to sync setup first-item step from nest: \(error.localizedDescription)")
        }
    }
} 
