import Foundation

/// Represents the current operating mode of the app
enum AppMode: String {
    case nestOwner = "Nest Owner"
    case sitter = "Sitter"
    
    var icon: String {
        switch self {
        case .nestOwner:
            return "house.fill"
        case .sitter:
            return "person.2.fill"
        }
    }
}

/// Manages the current operating mode of the app
final class ModeManager {
    // MARK: - Shared Instance
    static let shared = ModeManager()
    
    // MARK: - Notifications
    static let modeDidChangeNotification = Notification.Name("ModeManagerDidChangeMode")
    
    // MARK: - Properties
    private let defaults = UserDefaultsManager.shared
    
    /// The current mode of the app
    var currentMode: AppMode {
        get {
            // If we have a saved mode, use it
            if let savedMode = defaults.savedAppMode {
                return savedMode
            }
            
            // Otherwise, default to the user's primary role
            if let primaryRole = UserService.shared.currentUser?.primaryRole {
                switch primaryRole {
                case .nestOwner:
                    return .nestOwner
                case .sitter:
                    return .sitter
                }
            }
            
            // Default to nest owner if no user or role
            return .nestOwner
        }
        set {
            defaults.savedAppMode = newValue
            NotificationCenter.default.post(name: Self.modeDidChangeNotification, object: nil)
        }
    }
    
    /// Whether the app is in sitter mode
    var isSitterMode: Bool {
        return currentMode == .sitter
    }
    
    /// Whether the app is in nest owner mode
    var isNestOwnerMode: Bool {
        return currentMode == .nestOwner
    }
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Methods
    
    /// Toggles between sitter and nest owner modes
    func toggleMode() {
        currentMode = currentMode == .sitter ? .nestOwner : .sitter
    }
    
    /// Resets the mode to match the user's primary role
    func resetToDefaultMode() {
        defaults.savedAppMode = nil
    }
} 