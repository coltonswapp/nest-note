import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

final class UserService {
    
    // MARK: - Properties
    static let shared = UserService()
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    private(set) var currentUser: NestUser?
    var isSignedIn: Bool {
        return currentUser != nil
    }
    private(set) var isAuthenticated: Bool = false
    
    // Store pending FCM token
    private var pendingFCMToken: String?
    
    // Flag to prevent duplicate profile fetches
    private var isSettingUp: Bool = false
    
    // MARK: - Initialization
    private init() {
        setupAuthStateListener()
    }
    
    // MARK: - Auth State Management
    private func handleAuthStateChange(firebaseUser: User?) async {
        if let firebaseUser = firebaseUser {
            do {
                let nestUser = try await fetchUserProfile(userId: firebaseUser.uid)
                self.currentUser = nestUser
                self.isAuthenticated = true
                
                // Try to save any pending FCM token
//                if let token = pendingFCMToken {
//                    try await updateFCMToken(token)
//                    pendingFCMToken = nil
//                }
                
                Logger.log(level: .info, category: .userService, message: "Auth state changed - User logged in: \(nestUser)")
            } catch {
                self.currentUser = nil
                self.isAuthenticated = false
                Logger.log(level: .error, category: .userService, message: "Auth state changed - Failed to fetch profile: \(error.localizedDescription)")
            }
        } else {
            self.currentUser = nil
            self.isAuthenticated = false
            Logger.log(level: .info, category: .userService, message: "Auth state changed - User logged out")
        }
    }
    
    /// Sets up the UserService and returns when initialization is complete
    /// - Returns: SetupResult containing authentication state
    func setup() async -> SetupResult {
        Logger.log(level: .info, category: .userService, message: "Beginning UserService setup...")
        
        // Prevent duplicate setup
        guard !isSettingUp else {
            Logger.log(level: .info, category: .userService, message: "UserService already setting up, returning current state")
            return SetupResult(isSignedIn: isSignedIn)
        }
        
        isSettingUp = true
        defer { isSettingUp = false }
        
        // Check for current Firebase user
        guard let firebaseUser = auth.currentUser else {
            Logger.log(level: .info, category: .userService, message: "No Firebase user found, UserService setup complete.")
            self.currentUser = nil
            self.isAuthenticated = false
            return SetupResult(isSignedIn: false)
        }
        
        await handleAuthStateChange(firebaseUser: firebaseUser)
        return SetupResult(isSignedIn: isSignedIn)
    }
    
    // Add auth state change listener separately
    private func setupAuthStateListener() {
        auth.addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }
            
            Task {
                // Skip if we're already setting up
                guard !self.isSettingUp else {
                    Logger.log(level: .info, category: .userService, message: "Skipping auth state change - setup in progress")
                    return
                }
                
                await self.handleAuthStateChange(firebaseUser: user)
            }
        }
    }
    
    // MARK: - FCM Token Management
    func updateFCMToken(_ token: String?) async throws {
        guard let token = token else {
            Logger.log(level: .error, category: .userService, message: "Received nil FCM token")
            return
        }
        
        // If we don't have a current user, store the token for later
        guard let currentUser = currentUser else {
            Logger.log(level: .info, category: .userService, message: "No current user, storing FCM token for later")
            pendingFCMToken = token
            return
        }
        
        Logger.log(level: .info, category: .userService, message: "Updating FCM token for user: \(currentUser.id)")
        
        // Update in Firestore
        let docRef = db.collection("users").document(currentUser.id)
        do {
            let snapshot = try await docRef.getDocument()
            var fcmTokens = snapshot.data()? ["fcmTokens"] as? [[String: Any]] ?? []
            
            // Check if the token already exists
            if !fcmTokens.contains(where: { $0["token"] as? String == token }) {
                fcmTokens.append(["token": token, "uploadedDate": Timestamp(date: Date())])
            }
            
            try await docRef.updateData([
                "fcmTokens": fcmTokens,
                "updatedAt": Timestamp(date: Date())
            ])
            Logger.log(level: .info, category: .userService, message: "Successfully updated FCM tokens in Firestore")
        } catch {
            Logger.log(level: .error, category: .userService, message: "Failed to update FCM tokens in Firestore: \(error.localizedDescription)")
            Logger.log(level: .error, category: .userService, message: "Detailed error: \(error)")
            throw error
        }
    }
    
    // MARK: - Authentication Methods
    func login(email: String, password: String) async throws -> AuthDataResult {
        Logger.log(level: .info, category: .userService, message: "Attempting login for email: \(email)")
        do {
            // Only perform Firebase authentication
            let result = try await auth.signIn(withEmail: email, password: password)
            Logger.log(level: .debug, category: .userService, message: "Firebase auth successful")
            return result
            
        } catch let error as NSError {
            Logger.log(level: .error, category: .userService, message: "Login failed - Error: \(error.localizedDescription)")
            switch error.code {
            case AuthErrorCode.wrongPassword.rawValue,
                 AuthErrorCode.invalidEmail.rawValue,
                 AuthErrorCode.userNotFound.rawValue:
                throw AuthError.invalidCredentials
            case AuthErrorCode.networkError.rawValue:
                throw AuthError.networkError
            default:
                throw AuthError.unknown
            }
        }
    }
    
    func signUp(with info: OnboardingCoordinator.UserOnboardingInfo) async throws -> NestUser {
        Logger.log(level: .info, category: .userService, message: "Attempting signup for email: \(info.email)")
        do {
            
            // Create Firebase user
            let result = try await auth.createUser(withEmail: info.email, password: info.password)
            Logger.log(level: .debug, category: .userService, message: "Firebase user created successfully")
            
            let firebaseUser = result.user
            
            // Set display name
            let changeRequest = firebaseUser.createProfileChangeRequest()
            changeRequest.displayName = info.fullName
            try await changeRequest.commitChanges()
            Logger.log(level: .debug, category: .userService, message: "Display name set successfully")
            
            // Create default nest for user
            let defaultNest = try await NestService.shared.createNest(
                ownerId: firebaseUser.uid,
                name: info.nestInfo.name,
                address: info.nestInfo.address
            )
            
            // Create NestUser with access to their nest
            let user = NestUser(
                id: firebaseUser.uid,
                personalInfo: .init(
                    name: info.fullName,
                    email: info.email,
                    notificationPreferences: .default
                ),
                primaryRole: info.role,
                roles: .init(nestAccess: [.init(nestId: defaultNest.id, accessLevel: .owner, grantedAt: Date())])
            )
            
            // Save user profile to Firestore
            try await saveUserProfile(user)
            Logger.log(level: .debug, category: .userService, message: "User profile saved to Firestore")
            
            // Update state
            self.currentUser = user
            self.isAuthenticated = true
            Logger.log(level: .info, category: .userService, message: "Signup successful - User: \(user.personalInfo.name)")
            
            // Save authentication state
            saveAuthState()
            
            return user
            
        } catch let error as NSError {
            Logger.log(level: .error, category: .userService, message: "Signup failed - Error: \(error.localizedDescription)")
            switch error.code {
            case AuthErrorCode.emailAlreadyInUse.rawValue:
                throw AuthError.emailAlreadyInUse
            case AuthErrorCode.invalidEmail.rawValue:
                throw AuthError.emailInvalid
            case AuthErrorCode.weakPassword.rawValue:
                throw AuthError.passwordTooWeak
            case AuthErrorCode.networkError.rawValue:
                throw AuthError.networkError
            default:
                throw AuthError.unknown
            }
        }
    }
    
    // MARK: - Sign out & reset
    func logout(currentDeviceToken: String?) async throws {
        do {
            // Delete the FCM token from Firebase Messaging
            try await Messaging.messaging().deleteToken()
            Logger.log(level: .info, category: .userService, message: "FCM token deleted from Firebase Messaging")
            
            // If we have a current user, remove the token from their Firestore document
            if let currentDeviceToken {
                if let currentUser = currentUser {
                    let docRef = db.collection("users").document(currentUser.id)
                    let snapshot = try await docRef.getDocument()
                    
                    if var fcmTokens = snapshot.data()?["fcmTokens"] as? [[String: Any]] {
                        // Filter out the current token
                        fcmTokens.removeAll { tokenData in
                            return tokenData["token"] as? String == currentDeviceToken
                        }
                        
                        // Update the document with the filtered tokens
                        try await docRef.updateData([
                            "fcmTokens": fcmTokens,
                            "updatedAt": Timestamp(date: Date())
                        ])
                        
                        Logger.log(level: .info, category: .userService, message: "FCM token removed from user document in Firestore")
                    }
                }
            }
            
            // Sign out from Firebase Auth
            try auth.signOut()
            currentUser = nil
            isAuthenticated = false
            clearAuthState()
            
            Logger.log(level: .info, category: .userService, message: "User logged out successfully")
        } catch {
            Logger.log(level: .error, category: .userService, message: "Logout failed: \(error.localizedDescription)")
            throw AuthError.unknown
        }
    }
    
    func reset() async throws {
        Logger.log(level: .info, category: .userService, message: "Resetting UserService...")
        do {
            try await logout(currentDeviceToken: Messaging.messaging().fcmToken)
        } catch {
            throw error
        }
    }
    
    // MARK: - State Management
    private func saveAuthState() {
        guard let user = currentUser,
              let userData = try? JSONEncoder().encode(user) else {
            return
        }
        
        UserDefaults.standard.set(userData, forKey: "userData")
    }
    
    private func clearAuthState() {
        UserDefaults.standard.removeObject(forKey: "userData")
    }
    
    // MARK: - Firestore Methods
    private func fetchUserProfile(userId: String) async throws -> NestUser {
        Logger.log(level: .debug, category: .userService, message: "Fetching user profile for ID: \(userId)")
        
        let docRef = db.collection("users").document(userId)
        let snapshot = try await docRef.getDocument()
        
        guard let data = snapshot.data(),
              let userProfile = try? Firestore.Decoder().decode(NestUser.self, from: data) else {
            Logger.log(level: .error, category: .userService, message: "Failed to decode user profile ❌")
            throw AuthError.invalidUserData
        }
        
        Logger.log(level: .debug, category: .userService, message: "User Profile fetched ✅")
        return userProfile
    }
    
    private func saveUserProfile(_ user: NestUser) async throws {
        Logger.log(level: .debug, category: .userService, message: "Saving user profile for ID: \(user.id)")
        
        let docRef = db.collection("users").document(user.id)
        try await docRef.setData(try Firestore.Encoder().encode(user))
    }
    
    // MARK: - User Update Methods
    func updateName(_ newName: String) async throws {
        guard let currentUser = currentUser else {
            throw AuthError.invalidUserData
        }
        
        // Update in Firestore
        let docRef = db.collection("users").document(currentUser.id)
        try await docRef.updateData([
            "personalInfo.name": newName,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Update local state
        self.currentUser?.personalInfo.name = newName
        
        // Update Firebase display name
        if let firebaseUser = auth.currentUser {
            let changeRequest = firebaseUser.createProfileChangeRequest()
            changeRequest.displayName = newName
            try await changeRequest.commitChanges()
        }
        
        // Save updated state
        saveAuthState()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .userInformationUpdated, object: nil)
        
        Logger.log(level: .info, category: .userService, message: "User name updated successfully to: \(newName)")
    }
    
    func updateNotificationPreferences(_ preferences: NestUser.NotificationPreferences) async throws {
        guard let currentUser = currentUser else {
            throw AuthError.invalidUserData
        }
        
        // Update in Firestore
        let docRef = db.collection("users").document(currentUser.id)
        try await docRef.updateData([
            "personalInfo.notificationPreferences": try Firestore.Encoder().encode(preferences),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Update local state
        self.currentUser?.personalInfo.notificationPreferences = preferences
        
        // Save updated state
        saveAuthState()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .userInformationUpdated, object: nil)
        
        Logger.log(level: .info, category: .userService, message: "Notification preferences updated successfully")
    }
}

// MARK: - Types
enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError
    case unknown
    case invalidUserData
    case emailAlreadyInUse
    case weakPassword
    case emailInvalid
    case passwordTooWeak
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Unable to connect. Please check your internet connection"
        case .invalidUserData:
            return "Invalid user data received"
        case .emailAlreadyInUse:
            return "This email is already registered"
        case .weakPassword:
            return "Password should be at least 6 characters"
        case .unknown:
            return "An unknown error occurred"
        case .emailInvalid:
            return "Please enter a valid email address"
        case .passwordTooWeak:
            return "Password must be at least 6 characters"
        }
    }
}

// Add this struct at the bottom of the file
struct SetupResult {
    let isSignedIn: Bool
}

