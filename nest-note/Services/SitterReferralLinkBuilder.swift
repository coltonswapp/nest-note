import Foundation

enum SitterReferralCopy {
    static let title = "Earn $10 per family"
    static let screenSubtitle = "Invite a family to NestNote. When they subscribe, you get $10 via Venmo."
    /// Short subtitle kept for any compact surfaces.
    static let subtitle = screenSubtitle
    static let ctaTitle = "Share Invite"
    static let settingsRowTitle = "Refer Families"
    static let missingVenmoNote = "Add your Venmo in Profile so we can pay you when a family subscribes."
}

enum SitterReferralLinkBuilder {
    static let appStoreURL = "https://apps.apple.com/us/app/sitting-guides-nestnote/id6744369370"

    static func inviteMessage(sitterName: String, code: String) -> String {
        """
        \(sitterName) invited you to NestNote!

        Download: \(appStoreURL)

        When you sign up, use referral code: \(code)

        (Already have the app? Open: nestnote://refer?code=\(code))
        """
    }

    static func deepLink(code: String) -> String {
        "nestnote://refer?code=\(code)"
    }
}
