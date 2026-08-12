import Foundation

enum AttachmentsIntroStore {
    private static let seenKey = "Attachments.hasSeenAboutAttachments"
    private static let debugForceShowKey = "Attachments.debugForceShowAboutAttachments"

    static var hasSeen: Bool {
        get { UserDefaults.standard.bool(forKey: seenKey) }
        set { UserDefaults.standard.set(newValue, forKey: seenKey) }
    }

    static var shouldShow: Bool {
        #if DEBUG
        if debugForceShow { return true }
        #endif
        return !hasSeen
    }

    static func markSeen() {
        hasSeen = true
        #if DEBUG
        debugForceShow = false
        #endif
    }

    static func reset() {
        hasSeen = false
    }

    #if DEBUG
    static var debugForceShow: Bool {
        get { UserDefaults.standard.bool(forKey: debugForceShowKey) }
        set { UserDefaults.standard.set(newValue, forKey: debugForceShowKey) }
    }

    /// Clears the seen flag and forces the intro on the next Attach Items presentation.
    static func enableDebugPreview() {
        reset()
        debugForceShow = true
    }
    #endif
}
