import Foundation

extension UserDefaults {
    private enum Keys {
        static let hasCompletedSetup = "hasCompletedSetup"
        static let setupProgress = "setupProgress"
    }
    
    var hasCompletedSetup: Bool {
        get {
            return bool(forKey: Keys.hasCompletedSetup)
        }
        set {
            set(newValue, forKey: Keys.hasCompletedSetup)
        }
    }
    
    var setupProgress: Int {
        get {
            return integer(forKey: Keys.setupProgress)
        }
        set {
            set(newValue, forKey: Keys.setupProgress)
            
            // If progress is at maximum (5), mark setup as completed
            if newValue >= 5 {
                hasCompletedSetup = true
            }
        }
    }
} 