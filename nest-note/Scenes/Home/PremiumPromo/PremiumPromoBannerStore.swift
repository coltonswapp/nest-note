import Foundation

/// Persists home-screen premium promo dismissal and re-shows the banner every 3 app launches.
enum PremiumPromoBannerStore {
    private static let launchCountKey = "premium_promo_home.launch_count"
    private static let hiddenUntilLaunchKey = "premium_promo_home.hidden_until_launch"
    private static let relaunchInterval = 3

    static func recordAppLaunch() {
        let nextCount = UserDefaults.standard.integer(forKey: launchCountKey) + 1
        UserDefaults.standard.set(nextCount, forKey: launchCountKey)
    }

    static var shouldShowHomeBanner: Bool {
        let hiddenUntil = UserDefaults.standard.integer(forKey: hiddenUntilLaunchKey)
        guard hiddenUntil > 0 else { return true }
        return currentLaunchCount >= hiddenUntil
    }

    static func dismissHomeBanner() {
        let hiddenUntil = currentLaunchCount + relaunchInterval
        UserDefaults.standard.set(hiddenUntil, forKey: hiddenUntilLaunchKey)
    }

    static func resetHomeBannerDismissal() {
        UserDefaults.standard.removeObject(forKey: hiddenUntilLaunchKey)
    }

    private static var currentLaunchCount: Int {
        UserDefaults.standard.integer(forKey: launchCountKey)
    }
}
