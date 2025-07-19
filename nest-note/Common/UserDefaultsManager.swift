import Foundation

final class UserDefaultsManager {
    // MARK: - Shared Instance
    static let shared = UserDefaultsManager()
    
    // MARK: - Keys
    private struct Keys {
        static let placesListGridIsShowing = "placesListGridIsShowing"
        static let savedAppMode = "savedAppMode"
    }
    
    // MARK: - Properties
    private let defaults = UserDefaults.standard
    
    // MARK: - Places List Layout
    var isPlacesListGridShowing: Bool {
        get {
            defaults.bool(forKey: Keys.placesListGridIsShowing)
        }
        set {
            defaults.set(newValue, forKey: Keys.placesListGridIsShowing)
        }
    }
    
    // MARK: - App Mode
    var savedAppMode: AppMode? {
        get {
            guard let rawValue = defaults.string(forKey: Keys.savedAppMode) else { return nil }
            return AppMode(rawValue: rawValue)
        }
        set {
            defaults.set(newValue?.rawValue, forKey: Keys.savedAppMode)
        }
    }
    
    // MARK: - Initialization
    private init() {
    }
} 
