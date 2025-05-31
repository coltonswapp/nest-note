import Foundation
import UserNotifications

// Define setup step types for more modular completion checking
enum SetupStepType: Int, CaseIterable {
    case createAccount = 0
    case setupNest = 1
    case addFirstEntry = 2
    case exploreVisibilityLevels = 3
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
            return "Add your first entry"
        case .exploreVisibilityLevels:
            return "Explore Visibility Levels"
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
            return "This one is already complete as well!"
        case .addFirstEntry:
            return "Entries live on your nest"
        case .exploreVisibilityLevels:
            return "Share as much or as litte..."
        case .enableNotifications:
            return "Stay in the know"
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
        static let hasCompletedSetup = "hasCompletedSetup"
        static let completedSteps = "completedSteps"
    }
    
    private let defaults = UserDefaults.standard
    
    private init() {
        // Initialize with first two steps completed by default
        if defaults.object(forKey: Keys.completedSteps) == nil {
            markStepComplete(.createAccount)
            markStepComplete(.setupNest)
        }
    }
    
    var hasCompletedSetup: Bool {
        get {
            return defaults.bool(forKey: Keys.hasCompletedSetup)
        }
        set {
            defaults.set(newValue, forKey: Keys.hasCompletedSetup)
        }
    }
    
    // Get all completed step indices
    private var completedStepIndices: [Int] {
        get {
            return defaults.array(forKey: Keys.completedSteps) as? [Int] ?? []
        }
        set {
            defaults.set(newValue, forKey: Keys.completedSteps)
            
            // Check if all steps are complete
            if Set(newValue).count == SetupStepType.allCases.count {
                hasCompletedSetup = true
            }
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
        
        // Check if user has entries - if they do, they're already familiar with the app
        do {
            let groupedEntries = try await NestService.shared.fetchEntries()
            let totalEntries = groupedEntries.values.flatMap { $0 }.count
            
            // If user has entries, mark the addFirstEntry step as complete
            if totalEntries > 0 {
                markStepComplete(.addFirstEntry)
                
                // If they have more than a few entries, they're probably familiar with the app
                // Mark setup as complete and don't show the flow
                if totalEntries >= 3 {
                    hasCompletedSetup = true
                    return false
                }
            }
            
            // Otherwise, show the setup flow
            return true
        } catch {
            // If there's an error fetching entries, default to UserDefaults value
            Logger.log(level: .error, category: .general, message: "Error checking entries for setup flow: \(error.localizedDescription)")
            return !hasCompletedSetup
        }
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
            // Check if user has at least one entry
            // This would need to be implemented based on your data model
            return checkIfUserHasEntries()
            
        case .exploreVisibilityLevels:
            // Check if user has explored visibility levels
            // This would need to be implemented based on your app's behavior
            return checkIfUserExploredVisibilityLevels()
            
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
    private func checkIfUserHasEntries() -> Bool {
        // Placeholder - implement based on your data model
        // Example: return EntryService.shared.entriesCount > 0
        return isStepComplete(.addFirstEntry)
    }
    
    private func checkIfUserExploredVisibilityLevels() -> Bool {
        // Placeholder - implement based on your app behavior
        return isStepComplete(.exploreVisibilityLevels)
    }
    
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
    
    // Check and update all steps' completion status
    func refreshStepCompletionStatus() {
        let previouslyCompleted = Set(completedStepIndices)
        
        for step in SetupStepType.allCases {
            if checkStepCompletion(step) {
                let wasAlreadyComplete = previouslyCompleted.contains(step.rawValue)
                markStepComplete(step)
                
                // If this step was newly completed during refresh, post notification
                if !wasAlreadyComplete && isStepComplete(step) {
                    let userInfo: [String: Any] = [
                        "step": step,
                        "completedSteps": completedStepIndices.count,
                        "totalSteps": SetupStepType.allCases.count
                    ]
                    NotificationCenter.default.post(name: .setupStepDidComplete, object: nil, userInfo: userInfo)
                }
            }
        }
    }
} 
