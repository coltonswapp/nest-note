import Foundation
import FirebaseAnalytics

class Tracker {
    
    // MARK: - Shared Instance
    static let shared = Tracker()
    
    // MARK: - User Context
    private var cachedUserEmail: String?
    private var cachedUserID: String?
    
    private init() {}
    
    enum NNEventName: String {
        // MARK: - Nest Related Events
        case nestCreated = "nestCreated"
        case nestAddressUpdated = "nestAddressUpdated"
        case nestNameUpdated = "nestNameUpdated"
        case nestCategoryAdded = "nestCategoryAdded"
        case nestCategoryDeleted = "nestCategoryDeleted"
        case nestPlaceAdded = "nestPlaceAdded"
        
        // MARK: - Entry Related Events
        case entryCreated = "entryCreated"
        case entryUpdated = "entryUpdated"
        case entryDeleted = "entryDeleted"
        
        // MARK: - Routine Related Events
        case routineCreated = "routineCreated"
        case routineUpdated = "routineUpdated"
        case routineDeleted = "routineDeleted"
        
        // MARK: - Session Related Events
        case sessionCreated = "sessionCreated"
        case sessionUpdated = "sessionUpdated"
        case sessionEventAdded = "sessionEventAdded"
        
        // When user attaches a place to an event
        case sessionEventPlaceAttached = "sessionEventPlaceAttached"
        
        case sessionEventDeleted = "sessionEventDeleted"
        case sessionSitterAdded = "sessionSitterAdded"
        case sessionInviteCreated = "sessionInviteCreated"
        case sessionInviteAccepted = "sessionInviteAccepted"
    
        // MARK: - Profile Related Events
        case nameUpdated = "nameUpdated"
        case modeSwitched = "modeSwitched"
        
        // MARK: - Authentication Related Events
        case appleSignInAttempted = "appleSignInAttempted"
        case appleSignInSucceeded = "appleSignInSucceeded"
        case appleSignUpAttempted = "appleSignUpAttempted"
        case appleSignUpSucceeded = "appleSignUpSucceeded"
        case regularLoginAttempted = "regularLoginAttempted"
        case regularLoginSucceeded = "regularLoginSucceeded"
        case regularSignUpAttempted = "regularSignUpAttempted"
        case regularSignUpSucceeded = "regularSignUpSucceeded"
        case userLoggedOut = "userLoggedOut"
        
        // MARK: - Misc
        case pinnedCategoriesUpdated = "pinnedCategoriesUpdated"
    }
    
    // MARK: - User Context Management
    func setUserContext(email: String?, userID: String?) {
        self.cachedUserEmail = email
        self.cachedUserID = userID
    }
    
    func clearUserContext() {
        self.cachedUserEmail = nil
        self.cachedUserID = nil
    }
    
    // MARK: - Event Logging Method
    func track(_ event: NNEventName, result: Bool = true, error: String? = nil) {
        let eventName = result ? event.rawValue : "\(event.rawValue)_failure"
        
        var parameters: [String: Any] = [:]
        
        // Use provided parameters or fall back to cached values
        let finalUserEmail = cachedUserEmail
        let finalUserID = cachedUserID
        
        if let finalUserEmail = finalUserEmail {
            parameters["user_email"] = finalUserEmail
        }
        
        if let finalUserID = finalUserID {
            parameters["user_id"] = finalUserID
        }
        
        if let nestId = NestService.shared.currentNest?.id {
            parameters["nest_id"] = nestId
        }
        
        if let error = error {
            parameters["error"] = error
        }
        
        Analytics.logEvent(eventName, parameters: parameters)
    }
}
