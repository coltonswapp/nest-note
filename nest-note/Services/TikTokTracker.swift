import Foundation
import TikTokBusinessSDK

final class TikTokTracker {
    
    static let shared = TikTokTracker()
    
    private init() {}
    
    // MARK: - SDK Initialization
    
    func configure() {
        let config = TikTokConfig(
            accessToken: "TTco2ohwW4zwptrz0qHxgYe6ZH9f9Ico",
            appId: "6744369370",
            tiktokAppId: "7623137017106415636"
        )
        #if DEBUG
        config?.enableDebugMode()
        #endif
        config?.setDelayForATTUserAuthorizationInSeconds(30)
        TikTokBusiness.initializeSdk(config) { success, error in
            if success {
                Logger.log(level: .info, category: .general, message: "TikTok SDK initialized successfully")
            } else if let error = error {
                Logger.log(level: .error, category: .general, message: "TikTok SDK initialization failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Event Tracking
    
    func trackRegistration() {
        let event = TikTokBaseEvent(eventName: TTEventName.registration.rawValue)
        TikTokBusiness.trackTTEvent(event)
    }
    
    func trackLogin() {
        let event = TikTokBaseEvent(eventName: TTEventName.login.rawValue)
        TikTokBusiness.trackTTEvent(event)
    }
    
    func trackLaunchApp() {
        let event = TikTokBaseEvent(eventName: TTEventName.launchAPP.rawValue)
        TikTokBusiness.trackTTEvent(event)
    }
    
    func trackStartTrial() {
        let event = TikTokBaseEvent(eventName: TTEventName.startTrial.rawValue)
        TikTokBusiness.trackTTEvent(event)
    }
    
    func trackSubscribe() {
        let event = TikTokBaseEvent(eventName: TTEventName.subscribe.rawValue)
        TikTokBusiness.trackTTEvent(event)
    }
    
    // MARK: - User Identity
    
    func logout() {
        TikTokBusiness.logout()
    }
}
