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
        case userProfileCreated = "userProfileCreated"
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
        
        // MARK: - App Lifecycle Events
        case appBackgroundReturn = "app_background_return"
        
        // MARK: - Referral Related Events
        case referralCodeEntered = "referralCodeEntered"
        case referralRecorded = "referralRecorded"
        case referralValidationFailed = "referralValidationFailed"

        // MARK: - Onboarding Step-Specific Events
        case onboardingStepStarted = "onboardingStepStarted"
        case userProfileCreationFailed = "userProfileCreationFailed"
        case nestCreationFailed = "nestCreationFailed"
        case surveySubmissionFailed = "surveySubmissionFailed"
        case referralRecordingFailed = "referralRecordingFailed"
        case onboardingCompletionFailed = "onboardingCompletionFailed"
        case authStateRecoveryAttempted = "authStateRecoveryAttempted"
        case authStateRecoverySucceeded = "authStateRecoverySucceeded"
        case authStateRecoveryFailed = "authStateRecoveryFailed"

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

    // MARK: - Onboarding Step Tracking
    func trackOnboardingStep(_ step: String, result: Bool = true, error: String? = nil, additionalInfo: [String: Any]? = nil) {
        var parameters: [String: Any] = [
            "step": step,
            "timestamp": Date().timeIntervalSince1970
        ]

        // Add user context
        if let userEmail = cachedUserEmail {
            parameters["user_email"] = userEmail
        }

        if let userID = cachedUserID {
            parameters["user_id"] = userID
        }

        // Add error info
        if let error = error {
            parameters["error"] = error
        }

        // Add any additional step-specific info
        if let additionalInfo = additionalInfo {
            parameters.merge(additionalInfo) { _, new in new }
        }

        let eventName = result ? "onboarding_step_success" : "onboarding_step_failure"
        Analytics.logEvent(eventName, parameters: parameters)

        // Also track the specific step event
        track(.onboardingStepStarted, result: result, error: error)
    }
    
    // MARK: - App Background Return Event
    func trackAppBackgroundReturn(backgroundDurationMinutes: Int, requiresRefresh: Bool) {
        var parameters: [String: Any] = [
            "background_duration_minutes": backgroundDurationMinutes,
            "requires_refresh": requiresRefresh
        ]
        
        // Add user context
        if let userEmail = cachedUserEmail {
            parameters["user_email"] = userEmail
        }
        
        if let userID = cachedUserID {
            parameters["user_id"] = userID
        }
        
        if let nestId = NestService.shared.currentNest?.id {
            parameters["nest_id"] = nestId
        }
        
        Analytics.logEvent(NNEventName.appBackgroundReturn.rawValue, parameters: parameters)
    }
}
