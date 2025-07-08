import Foundation
import UserNotifications

// Define setup step types for more modular completion checking
enum SetupStepType: Int, CaseIterable {
    case createAccount = 0
    case setupNest = 1
    case addFirstEntry = 2
    case addFirstPlace = 3
    case exploreVisibilityLevels = 4
    case enableNotifications = 5
    case feedback = 6
    case finalStep = 7
    
    var title: String {
        switch self {
        case .createAccount:
            return "Create your account"
        case .setupNest:
            return "Setup your Nest"
        case .addFirstEntry:
            return "Add your first entry"
        case .addFirstPlace:
            return "Add your first place"
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
            return "Add a nest name and address."
        case .addFirstEntry:
            return "Garage codes, wifi passwords, and other general information make great entries. These are what your sitter will see."
        case .addFirstPlace:
            return "Places are locations that would be important for sitters to know about. Grandma's house, favorite park, etc."
        case .exploreVisibilityLevels:
            return "Decide what information you'd like to keep situational."
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
            // Check if user has at least one entry
            // This would need to be implemented based on your data model
            return checkIfUserHasEntries()
            
        case .addFirstPlace:
            // Check if user has at least one place
            return checkIfUserHasPlaces()
            
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
    
    private func checkIfUserHasPlaces() -> Bool {
        // Check if user has at least one non-temporary place
        return PlacesService.shared.places.filter { !$0.isTemporary }.count > 0
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
