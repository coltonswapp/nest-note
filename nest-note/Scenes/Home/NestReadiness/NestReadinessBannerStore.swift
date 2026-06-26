import Foundation

enum NestReadinessBannerStore {
    private static let dismissedNestIDsKey = "nest_readiness_home_banner_dismissed_nest_ids"

    static func isHomeBannerDismissed(for nestID: String) -> Bool {
        guard !nestID.isEmpty else { return false }
        let dismissedIDs = UserDefaults.standard.stringArray(forKey: dismissedNestIDsKey) ?? []
        return dismissedIDs.contains(nestID)
    }

    static func dismissHomeBanner(for nestID: String) {
        guard !nestID.isEmpty else { return }
        var dismissedIDs = Set(UserDefaults.standard.stringArray(forKey: dismissedNestIDsKey) ?? [])
        dismissedIDs.insert(nestID)
        UserDefaults.standard.set(Array(dismissedIDs), forKey: dismissedNestIDsKey)
    }

    static func restoreHomeBanner(for nestID: String) {
        guard !nestID.isEmpty else { return }
        var dismissedIDs = Set(UserDefaults.standard.stringArray(forKey: dismissedNestIDsKey) ?? [])
        dismissedIDs.remove(nestID)
        UserDefaults.standard.set(Array(dismissedIDs), forKey: dismissedNestIDsKey)
    }

    static func setHomeBannerVisible(_ isVisible: Bool, for nestID: String) {
        if isVisible {
            restoreHomeBanner(for: nestID)
        } else {
            dismissHomeBanner(for: nestID)
        }
    }
}
