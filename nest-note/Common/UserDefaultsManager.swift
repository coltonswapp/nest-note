import Foundation

final class UserDefaultsManager {
    // MARK: - Shared Instance
    static let shared = UserDefaultsManager()
    
    // MARK: - Keys
    private struct Keys {
        static let placesListGridIsShowing = "placesListGridIsShowing"
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
    
    // MARK: - Initialization
    private init() {
    }
} 