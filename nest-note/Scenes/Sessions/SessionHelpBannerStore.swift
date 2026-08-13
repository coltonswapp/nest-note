import Foundation

enum SessionHelpBannerStore {
    private static let dismissedKey = "EditSession.sessionHelpBanner.dismissed"
    private static let debugForceShowKey = "EditSession.sessionHelpBanner.debugForceShow"

    static var isDismissed: Bool {
        get { UserDefaults.standard.bool(forKey: dismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: dismissedKey) }
    }

    static func dismiss() {
        isDismissed = true
        #if DEBUG
        debugForceShow = false
        #endif
    }

    static func resetDismissal() {
        isDismissed = false
    }

    #if DEBUG
    static var debugForceShow: Bool {
        get { UserDefaults.standard.bool(forKey: debugForceShowKey) }
        set { UserDefaults.standard.set(newValue, forKey: debugForceShowKey) }
    }

    /// Clears dismissal and enables a DEBUG override so the banner appears on the next
    /// new-session create screen even when the nest already has sessions.
    static func enableDebugPreview() {
        resetDismissal()
        debugForceShow = true
    }
    #endif
}
