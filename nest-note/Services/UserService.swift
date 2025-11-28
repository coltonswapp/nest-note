import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications
import RevenueCat
import AuthenticationServices
import CryptoKit

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
    private var currentNonce: String?
    
    // Store pending FCM token
    private var pendingFCMToken: String?
    
    // Flags to prevent duplicate operations
    private var isSettingUp: Bool = false
    private var isFetchingProfile: Bool = false
    private var isOnboardingInProgress: Bool = false
    
    // MARK: - Initialization
    private init() {
        setupAuthStateListener()
    }
    
    // MARK: - Auth State Management
    private func handleAuthStateChange(firebaseUser: User?) async {
        if let firebaseUser = firebaseUser {
            // Skip if we're already setting up and this is the same user
            if isSettingUp && currentUser?.id == firebaseUser.uid {
                Logger.log(level: .info, category: .userService, message: "Auth state change skipped - setup already in progress for user: \(firebaseUser.uid)")
                return
            }

            Logger.log(level: .info, category: .userService, message: "🔄 AUTH STATE: Handling auth state change for user: \(firebaseUser.uid)")

            do {
                let nestUser = try await fetchUserProfile(userId: firebaseUser.uid)
                self.currentUser = nestUser
                self.isAuthenticated = true

                Logger.log(level: .info, category: .userService, message: "🔄 AUTH STATE: ✅ User profile loaded successfully")

                // Set user context in Events service
                Tracker.shared.setUserContext(email: nestUser.personalInfo.email, userID: nestUser.id)

                // Log in to RevenueCat with user ID (if not already logged in with this ID)
                // This handles existing users logging in, while new users get logged in during profile creation
                if Purchases.shared.appUserID != nestUser.id {
                    Logger.log(level: .info, category: .userService, message: "🔄 AUTH STATE: RevenueCat user ID differs, logging in...")
                    Purchases.shared.logIn(nestUser.id) { (customerInfo, created, error) in
                        if let error = error {
                            Logger.log(level: .error, category: .userService, message: "RevenueCat login error: \(error.localizedDescription)")
                        } else {
                            Logger.log(level: .info, category: .userService, message: "RevenueCat login successful for user: \(nestUser.id)")
                            // Refresh subscription info after successful login
                            Task {
                                await SubscriptionService.shared.refreshCustomerInfo()
                            }
                        }
                    }
                } else {
                    Logger.log(level: .info, category: .userService, message: "🔄 AUTH STATE: RevenueCat already logged in with correct user ID: \(nestUser.id)")
                }

                // Try to save any pending FCM token
                if let token = pendingFCMToken {
                    try await updateFCMToken(token)
                    pendingFCMToken = nil
                }

                Logger.log(level: .info, category: .userService, message: "Auth state changed - User logged in: \(nestUser)")
            } catch {
                // Check if this is likely a new user whose profile hasn't been created yet
                if let authError = error as? AuthError, authError == .invalidUserData {
                    Logger.log(level: .info, category: .userService, message: "🔄 AUTH STATE: ⏳ User profile not found - likely new user during signup process")
                    Logger.log(level: .info, category: .userService, message: "🔄 AUTH STATE: ⏳ Keeping user authenticated but waiting for profile creation")

                    // Keep the user authenticated but without full profile
                    // This allows signup flow to continue without interference
                    self.isAuthenticated = true
                    self.currentUser = nil // Will be set later when profile is created

                    // Don't clear user context or set RevenueCat yet - wait for profile
                    Logger.log(level: .info, category: .userService, message: "🔄 AUTH STATE: ⏳ Auth state preserved for ongoing signup")
                } else {
                    // Other errors (network issues, permissions, etc.) should invalidate auth
                    Logger.log(level: .error, category: .userService, message: "🔄 AUTH STATE: ❌ Non-profile error during auth state change: \(error.localizedDescription)")
                    self.currentUser = nil
                    self.isAuthenticated = false
                    Tracker.shared.clearUserContext()
                    Logger.log(level: .error, category: .userService, message: "Auth state changed - Failed to fetch profile: \(error.localizedDescription)")
                }
            }
        } else {
            self.currentUser = nil
            self.isAuthenticated = false
            Tracker.shared.clearUserContext()
            
            // Log out from RevenueCat
            Purchases.shared.logOut { (customerInfo, error) in
                if let error = error {
                    Logger.log(level: .error, category: .userService, message: "RevenueCat logout error: \(error.localizedDescription)")
                } else {
                    Logger.log(level: .info, category: .userService, message: "RevenueCat logout successful")
                }
                // Clear subscription cache on logout
                SubscriptionService.shared.clearCache()
            }
            
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
                
                // Skip if onboarding is in progress to prevent interference
                guard !self.isOnboardingInProgress else {
                    Logger.log(level: .info, category: .userService, message: "Skipping auth state change - onboarding in progress")
                    return
                }
                
                await self.handleAuthStateChange(firebaseUser: user)
            }
        }
    }
    
    /// Sets onboarding progress flag to prevent auth state listener interference
    func setOnboardingInProgress(_ value: Bool) {
        isOnboardingInProgress = value
        Logger.log(level: .info, category: .userService, message: "Onboarding in progress flag set to: \(value)")
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
    
    // MARK: - FCM Token Retrieval
    func fetchStoredFCMTokens() async throws -> [(token: String, uploadedDate: Date)] {
        guard let currentUser = currentUser else {
            Logger.log(level: .error, category: .userService, message: "No current user when fetching FCM tokens")
            return []
        }
        
        Logger.log(level: .info, category: .userService, message: "Fetching stored FCM tokens for user: \(currentUser.id)")
        
        let docRef = db.collection("users").document(currentUser.id)
        do {
            let snapshot = try await docRef.getDocument()
            let fcmTokensData = snapshot.data()?["fcmTokens"] as? [[String: Any]] ?? []
            
            let fcmTokens: [(token: String, uploadedDate: Date)] = fcmTokensData.compactMap { tokenData in
                guard let token = tokenData["token"] as? String,
                      let uploadedTimestamp = tokenData["uploadedDate"] as? Timestamp else {
                    return nil
                }
                return (token: token, uploadedDate: uploadedTimestamp.dateValue())
            }
            
            Logger.log(level: .info, category: .userService, message: "Successfully fetched \(fcmTokens.count) FCM tokens from Firestore")
            return fcmTokens
        } catch {
            Logger.log(level: .error, category: .userService, message: "Failed to fetch FCM tokens from Firestore: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Notification Permissions
    func requestNotificationPermissions() async {
        Logger.log(level: .info, category: .userService, message: "Requesting notification permissions")
        
        return await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                if settings.authorizationStatus == .notDetermined {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        if granted {
                            DispatchQueue.main.async {
                                UIApplication.shared.registerForRemoteNotifications()
                                Logger.log(level: .info, category: .userService, message: "Notification permissions granted, registered for remote notifications")
                            }
                        } else if let error = error {
                            Logger.log(level: .error, category: .userService, message: "Failed to request notification authorization: \(error.localizedDescription)")
                        } else {
                            Logger.log(level: .info, category: .userService, message: "Notification permissions denied by user")
                        }
                        continuation.resume()
                    }
                } else if settings.authorizationStatus == .authorized {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                        Logger.log(level: .info, category: .userService, message: "Already authorized for notifications, registered for remote notifications")
                    }
                    continuation.resume()
                } else {
                    Logger.log(level: .info, category: .userService, message: "Notification permissions not available (status: \(settings.authorizationStatus.rawValue))")
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Authentication Methods
    func login(email: String, password: String) async throws -> AuthDataResult {
        let identifier = email
        
        Logger.log(level: .info, category: .userService, message: "Attempting login for email: \(email)")
        Tracker.shared.track(.regularLoginAttempted)
        do {
            // Only perform Firebase authentication
            let result = try await auth.signIn(withEmail: email, password: password)
            Logger.log(level: .debug, category: .userService, message: "Firebase auth successful")
            
            // Request notification permissions after successful login
//            await requestNotificationPermissions()
            
            // Try to get a fresh FCM token
            if let fcmToken = try? await Messaging.messaging().token() {
                try? await updateFCMToken(fcmToken)
                Logger.log(level: .info, category: .userService, message: "Updated FCM token after login")
            }
            
            Tracker.shared.track(.regularLoginSucceeded)

            return result
            
        } catch let error as NSError {
            Logger.log(level: .error, category: .userService, message: "Login failed - Error: \(error.localizedDescription)")
            Tracker.shared.track(.regularLoginAttempted, result: false, error: error.localizedDescription)
            
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
        let identifier = info.email
        
        // Start capturing logs for this signup attempt
        SignupLogService.shared.startCapturing(identifier: identifier)
        
        Logger.log(level: .info, category: .userService, message: "Attempting signup for email: \(info.email)")
        Tracker.shared.track(.regularSignUpAttempted)
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
            
            var defaultNest: NestItem?
            
            if let nestName = info.nestInfo?.name,
               let nestAddress = info.nestInfo?.address {
                // Create default nest for user
                defaultNest = try await setupNestForUser(userId: firebaseUser.uid, nestName: nestName, nestAddress: nestAddress, surveyResponses: info.surveyResponses)
            }
            
            // Create NestUser with access to their nest
            let user = NestUser(
                id: firebaseUser.uid,
                personalInfo: .init(
                    name: info.fullName,
                    email: info.email,
                    notificationPreferences: .default
                ),
                primaryRole: info.role,
                roles: .init(nestAccess: [])
            )
            
            if let defaultNest {
                user.roles = .init(nestAccess: [.init(nestId: defaultNest.id, accessLevel: .owner, grantedAt: Date())])
            }
            
            // Save user profile to Firestore
            try await saveUserProfile(user)
            Logger.log(level: .debug, category: .userService, message: "User profile saved to Firestore")
            
            // Update state
            self.currentUser = user
            self.isAuthenticated = true
            Logger.log(level: .info, category: .userService, message: "Signup successful - User: \(user.personalInfo.name)")
            Tracker.shared.track(.regularSignUpSucceeded)

            // Save authentication state
            saveAuthState()

            // Note: Don't stop log capture here - let OnboardingCoordinator handle final upload
            // This ensures we capture nest creation, survey submission, and final completion
            Logger.log(level: .info, category: .userService, message: "📋 LOG CAPTURE: Continuing capture for onboarding flow")

            return user
            
        } catch let error as NSError {
            Logger.log(level: .error, category: .userService, message: "Signup failed - Error: \(error.localizedDescription)")
            Tracker.shared.track(.regularSignUpAttempted, result: false, error: error.localizedDescription)
            
            // Stop log capture and upload (failure)
            await SignupLogService.shared.stopCaptureAndUpload(result: .failure, identifier: identifier, error: error.localizedDescription)
            
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
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> (user: NestUser, isNewUser: Bool, isIncompleteSignup: Bool) {
        // Use email from credential or create timestamp-based identifier
        let identifier = credential.email ?? "apple_signin_\(Int(Date().timeIntervalSince1970))"

        Logger.log(level: .info, category: .userService, message: "Attempting Apple Sign In")
        Tracker.shared.track(.appleSignInAttempted)

        do {
            // Create Firebase credential from Apple credential
            guard let nonce = self.currentNonce else {
                throw AuthError.unknown
            }

            guard let appleIDToken = credential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                throw AuthError.unknown
            }

            let firebaseCredential = OAuthProvider.credential(
                providerID: AuthProviderID.apple,
                idToken: idTokenString,
                rawNonce: nonce
            )

            // Sign in with Firebase
            let result = try await auth.signIn(with: firebaseCredential)
            let firebaseUser = result.user
            let isNewUser = result.additionalUserInfo?.isNewUser ?? false

            Logger.log(level: .debug, category: .userService, message: "Firebase Apple Sign In successful, isNewUser: \(isNewUser)")

            if isNewUser {
                // This is a new user - they need to complete onboarding
                // NOW start capturing logs for this Apple signup attempt since we know it's a new user
                SignupLogService.shared.startCapturing(identifier: identifier)

                // Return minimal user info and let onboarding handle the rest
                let tempUser = NestUser(
                    id: firebaseUser.uid,
                    personalInfo: .init(
                        name: credential.fullName?.formatted() ?? firebaseUser.displayName ?? "",
                        email: credential.email ?? firebaseUser.email ?? ""
                    ),
                    primaryRole: .nestOwner, // Default, will be updated in onboarding
                    roles: .init(ownedNestId: nil, nestAccess: [])
                )

                Tracker.shared.track(.appleSignInSucceeded)

                // Note: Don't stop log capture here - new users will continue to onboarding
                // This ensures we capture the full signup flow including nest creation
                Logger.log(level: .info, category: .userService, message: "📋 LOG CAPTURE: New Apple user continuing to onboarding - keeping capture active")

                return (user: tempUser, isNewUser: true, isIncompleteSignup: false)
            } else {
                // Firebase says existing user, but try to fetch their profile
                do {
                    let user = try await fetchUserProfile(userId: firebaseUser.uid)

                    // Profile exists - they're truly an existing user logging in (not signup)
                    self.currentUser = user
                    self.isAuthenticated = true

                    Logger.log(level: .info, category: .userService, message: "Apple Sign In completed for existing user - no signup logs needed")
                    Tracker.shared.track(.appleSignInSucceeded)

                    // No signup logs to upload since this was just a login, not signup
                    return (user: user, isNewUser: false, isIncompleteSignup: false)
                } catch {
                    // Profile doesn't exist - Firebase user exists but profile creation failed previously
                    // Start capturing logs since we need to complete their profile creation (signup process)
                    SignupLogService.shared.startCapturing(identifier: identifier)

                    Logger.log(level: .info, category: .userService, message: "Firebase user exists but no profile found - creating minimal profile to fix incomplete signup")

                    // Create a minimal profile for this existing Firebase user
                    let userWithMinimalProfile = NestUser(
                        id: firebaseUser.uid,
                        personalInfo: .init(
                            name: credential.fullName?.formatted() ?? firebaseUser.displayName ?? "Apple User",
                            email: credential.email ?? firebaseUser.email ?? ""
                        ),
                        primaryRole: .nestOwner, // Default
                        roles: .init(ownedNestId: nil, nestAccess: [])
                    )

                    // Save the minimal profile to Firestore
                    do {
                        try await saveUserProfile(userWithMinimalProfile)

                        // Set as current user
                        self.currentUser = userWithMinimalProfile
                        self.isAuthenticated = true

                        Logger.log(level: .info, category: .userService, message: "Successfully created minimal profile for incomplete Apple signup")
                        Tracker.shared.track(.appleSignInSucceeded)

                        // Stop log capture and upload (success) - profile creation completed
                        await SignupLogService.shared.stopCaptureAndUpload(result: .success, identifier: identifier)

                        // Return as existing user (profile now exists) but indicate incomplete signup
                        // This allows the UI to handle any additional setup if needed
                        return (user: userWithMinimalProfile, isNewUser: false, isIncompleteSignup: true)

                    } catch {
                        // If we still can't save the profile, fall back to onboarding flow
                        Logger.log(level: .error, category: .userService, message: "Failed to save minimal profile, falling back to onboarding: \(error.localizedDescription)")

                        let tempUser = NestUser(
                            id: firebaseUser.uid,
                            personalInfo: .init(
                                name: credential.fullName?.formatted() ?? firebaseUser.displayName ?? "",
                                email: credential.email ?? firebaseUser.email ?? ""
                            ),
                            primaryRole: .nestOwner,
                            roles: .init(ownedNestId: nil, nestAccess: [])
                        )

                        Tracker.shared.track(.appleSignInSucceeded)

                        // Note: Don't stop log capture here - onboarding will continue
                        Logger.log(level: .info, category: .userService, message: "📋 LOG CAPTURE: Profile save failed, continuing to onboarding - keeping capture active")

                        return (user: tempUser, isNewUser: true, isIncompleteSignup: true)
                    }
                }
            }

        } catch {
            Logger.log(level: .error, category: .userService, message: "Apple Sign In failed: \(error)")
            Tracker.shared.track(.appleSignInAttempted, result: false, error: error.localizedDescription)

            // Only stop log capture if it was started (check if we're currently capturing)
            if SignupLogService.shared.isCurrentlyCapturing {
                await SignupLogService.shared.stopCaptureAndUpload(result: .failure, identifier: identifier, error: error.localizedDescription)
            }

            let authError = error as NSError
            switch authError.code {
            case AuthErrorCode.networkError.rawValue:
                throw AuthError.networkError
            default:
                throw AuthError.unknown
            }
        }
    }
    
    func signUpWithApple(credential: ASAuthorizationAppleIDCredential, with info: OnboardingCoordinator.UserOnboardingInfo) async throws -> NestUser {
        let identifier = credential.email ?? info.email
        
        // Start capturing logs for this Apple signup attempt
        SignupLogService.shared.startCapturing(identifier: identifier)
        
        Logger.log(level: .info, category: .userService, message: "Attempting Apple Sign In signup")
        Tracker.shared.track(.appleSignUpAttempted)
        
        do {
            // Create Firebase credential from Apple credential
            guard let nonce = self.currentNonce else {
                throw AuthError.unknown
            }
            
            guard let appleIDToken = credential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                throw AuthError.unknown
            }
            
            let firebaseCredential = OAuthProvider.credential(
                providerID: AuthProviderID.apple,
                idToken: idTokenString,
                rawNonce: nonce
            )
            
            // Sign in with Firebase
            let result = try await auth.signIn(with: firebaseCredential)
            let firebaseUser = result.user
            
            Logger.log(level: .debug, category: .userService, message: "Firebase Apple Sign In successful")
            
            // Get user info from Apple credential
            let email = credential.email ?? firebaseUser.email ?? ""
            let fullName = credential.fullName?.formatted() ?? info.fullName
            
            // Set display name if available
            if !fullName.isEmpty {
                let changeRequest = firebaseUser.createProfileChangeRequest()
                changeRequest.displayName = fullName
                try await changeRequest.commitChanges()
            }
            
            var defaultNest: NestItem?
            
            if let nestName = info.nestInfo?.name,
               let nestAddress = info.nestInfo?.address {
                // Create default nest for user
                defaultNest = try await setupNestForUser(userId: firebaseUser.uid, nestName: nestName, nestAddress: nestAddress, surveyResponses: info.surveyResponses)
            }
            
            let user = NestUser(
                id: firebaseUser.uid,
                personalInfo: .init(
                    name: fullName,
                    email: email
                ),
                primaryRole: info.role,
                roles: .init(
                    ownedNestId: defaultNest?.id,
                    nestAccess: defaultNest != nil ? [.init(
                        nestId: defaultNest!.id,
                        accessLevel: .owner,
                        grantedAt: Date()
                    )] : []
                )
            )
            
            // Save user profile to Firestore
            try await saveUserProfile(user)
            
            // Update current user and authentication state
            self.currentUser = user
            self.isAuthenticated = true
            
//            // Update FCM token
//            try await updateFCMToken()
            
            Logger.log(level: .info, category: .userService, message: "Apple Sign In signup completed successfully")
            Tracker.shared.track(.appleSignUpSucceeded)

            // Note: Don't stop log capture here - let OnboardingCoordinator handle final upload
            // This ensures we capture nest creation and final completion
            Logger.log(level: .info, category: .userService, message: "📋 LOG CAPTURE: Continuing capture for onboarding flow")

            return user
            
        } catch {
            Logger.log(level: .error, category: .userService, message: "Apple Sign In signup failed: \(error)")
            Tracker.shared.track(.appleSignUpAttempted, result: false, error: error.localizedDescription)
            
            // Stop log capture and upload (failure)
            await SignupLogService.shared.stopCaptureAndUpload(result: .failure, identifier: identifier, error: error.localizedDescription)
            
            // Convert Firebase errors to custom errors
            let authError = error as NSError
            switch authError.code {
            case AuthErrorCode.networkError.rawValue:
                throw AuthError.networkError
            default:
                throw AuthError.unknown
            }
        }
    }
    
    func completeAppleSignUp(with info: OnboardingCoordinator.UserOnboardingInfo) async throws -> NestUser {
        // Use email as identifier, or fallback to a timestamp-based identifier
        let identifier = info.email.isEmpty ? "apple_signup_\(Int(Date().timeIntervalSince1970))" : info.email
        
        // Start capturing logs for this Apple signup completion
        SignupLogService.shared.startCapturing(identifier: identifier)
        
        Logger.log(level: .info, category: .userService, message: "Completing Apple Sign In profile setup")
        
        // User is already authenticated with Firebase, just need to create their profile
        guard let firebaseUser = auth.currentUser else {
            await SignupLogService.shared.stopCaptureAndUpload(result: .failure, identifier: identifier, error: "No Firebase user found")
            throw AuthError.unknown
        }
        
        do {
            // Get user info from Firebase user and onboarding info
            let email = firebaseUser.email ?? ""
            let fullName = firebaseUser.displayName ?? info.fullName
            
            var defaultNest: NestItem?
            
            if let nestName = info.nestInfo?.name,
               let nestAddress = info.nestInfo?.address {
                // Create default nest for user
                defaultNest = try await setupNestForUser(userId: firebaseUser.uid, nestName: nestName, nestAddress: nestAddress, surveyResponses: info.surveyResponses)
            }
            
            let user = NestUser(
                id: firebaseUser.uid,
                personalInfo: .init(
                    name: fullName,
                    email: email
                ),
                primaryRole: info.role,
                roles: .init(
                    ownedNestId: defaultNest?.id,
                    nestAccess: defaultNest != nil ? [.init(
                        nestId: defaultNest!.id,
                        accessLevel: .owner,
                        grantedAt: Date()
                    )] : []
                )
            )
            
            // Save user profile to Firestore
            try await saveUserProfile(user)
            
            // Update current user and authentication state
            self.currentUser = user
            self.isAuthenticated = true
            
            Logger.log(level: .info, category: .userService, message: "Apple Sign In profile setup completed successfully")
            Tracker.shared.track(.appleSignUpSucceeded)

            // Note: Don't stop log capture here - let OnboardingCoordinator handle final upload
            // This ensures we capture nest creation, survey submission, and final completion
            Logger.log(level: .info, category: .userService, message: "📋 LOG CAPTURE: Continuing capture for onboarding flow")

            return user
            
        } catch {
            Logger.log(level: .error, category: .userService, message: "Apple Sign In profile setup failed: \(error)")
            Tracker.shared.track(.appleSignUpSucceeded, result: false, error: error.localizedDescription)
            
            // Stop log capture and upload (failure)
            await SignupLogService.shared.stopCaptureAndUpload(result: .failure, identifier: identifier, error: error.localizedDescription)
            
            throw error
        }
    }
    
    /// Creates a nest for the specified user
    /// - Parameters:
    ///   - userId: The ID of the user who will own the nest
    ///   - nestName: The name for the new nest
    ///   - nestAddress: The address for the new nest
    ///   - updateCurrentUser: If true and the user is the current user, updates their roles
    /// - Returns: The created NestItem
    func setupNestForUser(userId: String, nestName: String, nestAddress: String, surveyResponses: [String: [String]]? = nil, updateCurrentUser: Bool = false) async throws -> NestItem {

        Logger.log(level: .info, category: .userService, message: "🏗️ SETUP NEST: Starting nest setup for user: \(userId)")
        Logger.log(level: .info, category: .userService, message: "🏗️ SETUP NEST: Nest name: '\(nestName)'")
        Logger.log(level: .info, category: .userService, message: "🏗️ SETUP NEST: Nest address: '\(nestAddress)'")
        Logger.log(level: .info, category: .userService, message: "🏗️ SETUP NEST: Survey responses keys: \(surveyResponses?.keys.sorted() ?? [])")
        Logger.log(level: .info, category: .userService, message: "🏗️ SETUP NEST: Update current user: \(updateCurrentUser)")

        do {
            // Step 1: Extract care responsibilities from survey responses
            Logger.log(level: .info, category: .userService, message: "🏗️ STEP 1: Extracting care responsibilities from survey...")
            let careResponsibilities = surveyResponses?["care_responsibilities"]
            Logger.log(level: .info, category: .userService, message: "🏗️ STEP 1: ✅ Care responsibilities extracted: \(careResponsibilities ?? [])")

            // Step 2: Call NestService to create nest
            Logger.log(level: .info, category: .userService, message: "🏗️ STEP 2: Calling NestService.createNest()...")
            Logger.log(level: .info, category: .userService, message: "🏗️ STEP 2: Parameters - ownerId: \(userId), name: '\(nestName)', address: '\(nestAddress)'")

            let nest = try await NestService.shared.createNest(
                ownerId: userId,
                name: nestName,
                address: nestAddress,
                careResponsibilities: careResponsibilities
            )

            Logger.log(level: .info, category: .userService, message: "🏗️ STEP 2: ✅ NestService.createNest() completed successfully")
            Logger.log(level: .info, category: .userService, message: "🏗️ STEP 2: ✅ Returned nest ID: \(nest.id)")
            Logger.log(level: .info, category: .userService, message: "🏗️ STEP 2: ✅ Returned nest name: '\(nest.name)'")

            Logger.log(level: .info, category: .userService, message: "🏗️ ✅ SETUP NEST COMPLETE: Successfully created nest '\(nest.name)' for user \(userId)")

            // Note: nestCreated event is tracked by NestService.createNest() to avoid duplicate events
            return nest

        } catch {
            Logger.log(level: .error, category: .userService, message: "🏗️ ❌ SETUP NEST FAILED: \(error.localizedDescription)")
            Logger.log(level: .error, category: .userService, message: "🏗️ ❌ Error type: \(type(of: error))")
            Logger.log(level: .error, category: .userService, message: "🏗️ ❌ Full error: \(error)")
            Logger.log(level: .error, category: .userService, message: "🏗️ ❌ Failed for user: \(userId), nest name: '\(nestName)', address: '\(nestAddress)'")

            // Track nest setup failure during signup
            Tracker.shared.track(.nestCreated, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    /// Adds nest access to a user's roles
    /// - Parameters:
    ///   - userId: The ID of the user to update
    ///   - nestId: The ID of the nest to add access to
    ///   - accessLevel: The level of access to grant (default: .owner)
    func addNestAccessToUser(nestId: String, accessLevel: NestUser.NestAccess.AccessLevel = .owner) async throws {
        guard let userId = currentUser?.id else {
            throw ServiceError.noCurrentUser
        }
        
        Logger.log(level: .info, category: .userService, message: "Adding \(accessLevel) access to nest \(nestId) for user \(userId)")
        
        // Update in Firestore first
        let docRef = db.collection("users").document(userId)
        let snapshot = try await docRef.getDocument()
        
        if snapshot.exists {
            // Create the new access object
            let nestAccess = NestUser.NestAccess(
                nestId: nestId,
                accessLevel: accessLevel,
                grantedAt: Date()
            )
            
            // Check if user already has this nest in their access list
            if let data = snapshot.data(),
               let rolesData = data["roles"] as? [String: Any],
               var nestAccessArray = rolesData["nestAccess"] as? [[String: Any]] {
                
                // Remove any existing access to this nest to avoid duplicates
                nestAccessArray.removeAll { ($0["nestId"] as? String) == nestId }
                
                // Add the new access
                let encoder = Firestore.Encoder()
                if let encodedAccess = try? encoder.encode(nestAccess),
                   let accessDict = encodedAccess as? [String: Any] {
                    nestAccessArray.append(accessDict)
                }
                
                // Update Firestore
                try await docRef.updateData([
                    "roles.nestAccess": nestAccessArray,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            } else {
                // User doesn't have existing roles, create new ones
                let roles = NestUser.UserRoles(nestAccess: [nestAccess])
                try await docRef.updateData([
                    "roles": try Firestore.Encoder().encode(roles),
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            }
            
            // If this is the current user, update local state
            if userId == currentUser?.id {
                // Check if current user already has access to this nest
                if let index = currentUser?.roles.nestAccess.firstIndex(where: { $0.nestId == nestId }) {
                    currentUser?.roles.nestAccess[index].accessLevel = accessLevel
                } else {
                    // Add new access
                    currentUser?.roles.nestAccess.append(nestAccess)
                }
                
                // Save updated state
                saveAuthState()
                
                // Post notification for UI updates
                NotificationCenter.default.post(name: .userInformationUpdated, object: nil)
            }
            
            Logger.log(level: .info, category: .userService, message: "Successfully added nest access for user")
        } else {
            Logger.log(level: .error, category: .userService, message: "User document not found")
            throw AuthError.invalidUserData
        }
    }
    
    func sendPasswordReset(to email: String) async throws {
        Logger.log(level: .info, category: .userService, message: "Attempting to send password reset email to: \(email)")
        do {
            try await auth.sendPasswordReset(withEmail: email)
            Logger.log(level: .info, category: .userService, message: "Password reset email sent successfully")
        } catch let error as NSError {
            Logger.log(level: .error, category: .userService, message: "Password reset failed - Error: \(error.localizedDescription)")
            switch error.code {
            case AuthErrorCode.userNotFound.rawValue:
                throw AuthError.userNotFound
            case AuthErrorCode.invalidEmail.rawValue:
                throw AuthError.emailInvalid
            case AuthErrorCode.networkError.rawValue:
                throw AuthError.networkError
            default:
                throw AuthError.unknown
            }
        }
    }
    
    // MARK: - Sign out & reset
    func logout(clearSavedCredentials: Bool = false) async throws {
        // Sign out from Firebase Auth
        do {
            try auth.signOut()
            currentUser = nil
            isAuthenticated = false
            clearAuthState()
            
            // Optionally clear saved credentials from keychain
            if clearSavedCredentials {
                _ = KeychainService.shared.deleteAllCredentials()
            }
            
            Logger.log(level: .info, category: .userService, message: "User logged out successfully")
            Tracker.shared.track(.userLoggedOut)
        } catch {
            Logger.log(level: .error, category: .userService, message: "Firebase Auth signOut failed: \(error.localizedDescription)")
            throw AuthError.unknown
        }
    }
    
    func reset() async throws {
        Logger.log(level: .info, category: .userService, message: "Resetting UserService...")
        do {
            try await logout()
            Tracker.shared.clearUserContext()
        } catch {
            throw error
        }
    }

    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let currentUser = currentUser else {
            throw AuthError.invalidUserData
        }

        guard let firebaseUser = auth.currentUser else {
            throw AuthError.invalidUserData
        }

        Logger.log(level: .info, category: .userService, message: "Starting account deletion for user: \(currentUser.id)")

        do {
            // Step 1: Delete user's nest if they have one
            if let ownedNestId = currentUser.roles.nestAccess.first(where: { $0.accessLevel == .owner })?.nestId {
                Logger.log(level: .info, category: .userService, message: "Deleting owned nest: \(ownedNestId)")
                try await deleteNest(nestId: ownedNestId)
                Logger.log(level: .info, category: .userService, message: "Nest deleted successfully")
            }

            // Step 2: Delete user document from Firestore
            Logger.log(level: .info, category: .userService, message: "Deleting user document from Firestore")
            let userDocRef = db.collection("users").document(currentUser.id)
            try await userDocRef.delete()
            Logger.log(level: .info, category: .userService, message: "User document deleted successfully")

            // Step 3: Delete Firebase Auth user (with reauthentication handling)
            Logger.log(level: .info, category: .userService, message: "Deleting Firebase Auth user")
            try await deleteFirebaseUserWithReauth(firebaseUser)
            Logger.log(level: .info, category: .userService, message: "Firebase Auth user deleted successfully")

            // Step 4: Clear local state
            self.currentUser = nil
            self.isAuthenticated = false
            clearAuthState()

            // Clear RevenueCat
            Purchases.shared.logOut { (customerInfo, error) in
                if let error = error {
                    Logger.log(level: .error, category: .userService, message: "RevenueCat logout error: \(error.localizedDescription)")
                }
            }

            // Clear Tracker context
            Tracker.shared.clearUserContext()

            Logger.log(level: .info, category: .userService, message: "Account deletion completed successfully")
            Tracker.shared.track(.accountDeleted)

        } catch {
            Logger.log(level: .error, category: .userService, message: "Account deletion failed: \(error.localizedDescription)")
            Tracker.shared.track(.accountDeleted, result: false, error: error.localizedDescription)
            throw error
        }
    }

    private func deleteFirebaseUserWithReauth(_ firebaseUser: User) async throws {
        do {
            // First attempt to delete the user directly
            try await firebaseUser.delete()
        } catch let error as NSError {
            // Check if this is a "credential too old" error that requires reauthentication
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                Logger.log(level: .info, category: .userService, message: "Credential too old - reauthentication required")

                // Determine the provider and reauthenticate accordingly
                guard let providerData = firebaseUser.providerData.first else {
                    Logger.log(level: .error, category: .userService, message: "No provider data found for reauthentication")
                    throw AuthError.unknown
                }

                switch providerData.providerID {
                case "password":
                    // Email/password authentication - need to prompt user for password
                    try await reauthenticateWithEmailPassword(firebaseUser)
                case "apple.com":
                    // Apple Sign In - need fresh Apple credentials
                    try await reauthenticateWithApple(firebaseUser)
                default:
                    Logger.log(level: .error, category: .userService, message: "Unsupported provider for reauthentication: \(providerData.providerID)")
                    throw AuthError.unknown
                }

                // After successful reauthentication, try deleting again
                try await firebaseUser.delete()
            } else {
                // Other error, rethrow
                throw error
            }
        }
    }

    private func reauthenticateWithEmailPassword(_ firebaseUser: User) async throws {
        guard let email = firebaseUser.email else {
            throw AuthError.invalidUserData
        }

        // This would need to be implemented with UI to prompt user for password
        // For now, throw an error indicating manual reauthentication is needed
        Logger.log(level: .error, category: .userService, message: "Email/password reauthentication requires user interaction - not implemented")
        throw ReauthenticationError.passwordPromptRequired(email: email)
    }

    private func reauthenticateWithApple(_ firebaseUser: User) async throws {
        // This would need to trigger Apple Sign In flow again
        // For now, throw an error indicating manual reauthentication is needed
        Logger.log(level: .error, category: .userService, message: "Apple Sign In reauthentication requires user interaction - not implemented")
        throw ReauthenticationError.appleSignInRequired
    }

    // MARK: - Public Reauthentication Methods
    /// Reauthenticates the current user with email and password, then attempts account deletion
    func reauthenticateAndDeleteAccount(password: String) async throws {
        guard let currentUser = currentUser else {
            throw AuthError.invalidUserData
        }

        guard let firebaseUser = auth.currentUser, let email = firebaseUser.email else {
            throw AuthError.invalidUserData
        }

        Logger.log(level: .info, category: .userService, message: "Reauthenticating user with email/password for account deletion")

        // Create email credential
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        // Reauthenticate
        try await firebaseUser.reauthenticate(with: credential)
        Logger.log(level: .info, category: .userService, message: "User reauthenticated successfully")

        // Now attempt account deletion
        try await deleteAccount()
    }

    /// Reauthenticates the current user with Apple Sign In, then attempts account deletion
    func reauthenticateAndDeleteAccount(appleCredential: ASAuthorizationAppleIDCredential) async throws {
        guard let currentUser = currentUser else {
            throw AuthError.invalidUserData
        }

        guard let firebaseUser = auth.currentUser else {
            throw AuthError.invalidUserData
        }

        Logger.log(level: .info, category: .userService, message: "Reauthenticating user with Apple Sign In for account deletion")

        // Create Firebase credential from Apple credential
        guard let nonce = self.currentNonce else {
            throw AuthError.unknown
        }

        guard let appleIDToken = appleCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.unknown
        }

        let firebaseCredential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: nonce
        )

        // Reauthenticate
        try await firebaseUser.reauthenticate(with: firebaseCredential)
        Logger.log(level: .info, category: .userService, message: "User reauthenticated successfully")

        // Now attempt account deletion
        try await deleteAccount()
    }

    private func deleteNest(nestId: String) async throws {
        Logger.log(level: .info, category: .userService, message: "Deleting nest and all associated data: \(nestId)")

        let nestRef = db.collection("nests").document(nestId)

        // Delete all subcollections first
        let subcollections = ["entries", "nestCategories", "savedSitters", "sessions", "items"]

        for subcollection in subcollections {
            let collectionRef = nestRef.collection(subcollection)
            let snapshot = try await collectionRef.getDocuments()

            // Delete documents in batches of 500 (Firestore limit)
            var batch = db.batch()
            var batchCount = 0

            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
                batchCount += 1

                if batchCount >= 500 {
                    try await batch.commit()
                    batch = db.batch() // Create fresh batch after commit
                    batchCount = 0
                }
            }

            // Commit any remaining documents
            if batchCount > 0 {
                try await batch.commit()
            }

            Logger.log(level: .info, category: .userService, message: "Deleted \(snapshot.documents.count) documents from \(subcollection)")
        }

        // Finally delete the nest document itself
        try await nestRef.delete()
        Logger.log(level: .info, category: .userService, message: "Nest document deleted successfully")
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
    
    // MARK: - Recovery Methods
    /// Directly sets the current user (for recovery purposes only)
    /// WARNING: This bypasses normal authentication flow and should only be used for state recovery
    func setCurrentUserDirectly(_ user: NestUser) {
        Logger.log(level: .info, category: .userService, message: "🔧 RECOVERY: Directly setting current user: \(user.personalInfo.name)")
        self.currentUser = user
        self.isAuthenticated = true

        // Set user context in Events service
        Tracker.shared.setUserContext(email: user.personalInfo.email, userID: user.id)

        // Save state
        saveAuthState()
    }

    // MARK: - Firestore Methods
    func fetchUserProfile(userId: String) async throws -> NestUser {
        // Check if we're already fetching this user's profile
        if isFetchingProfile && currentUser?.id == userId {
            Logger.log(level: .info, category: .userService, message: "Profile fetch already in progress for user: \(userId), skipping duplicate request")
            // Wait for the current fetch to complete and return current user
            while isFetchingProfile {
                try await Task.sleep(for: .milliseconds(50))
            }
            if let user = currentUser, user.id == userId {
                return user
            }
        }
        
        isFetchingProfile = true
        defer { isFetchingProfile = false }
        
        Logger.log(level: .info, category: .userService, message: "Fetching user profile for ID: \(userId)")
        
        let docRef = db.collection("users").document(userId)
        let snapshot = try await docRef.getDocument()
        
        guard let data = snapshot.data(),
              let userProfile = try? Firestore.Decoder().decode(NestUser.self, from: data) else {
            Logger.log(level: .error, category: .userService, message: "Failed to decode user profile ❌")
            throw AuthError.invalidUserData
        }
        
        Logger.log(level: .info, category: .userService, message: "User Profile fetched ✅")
        return userProfile
    }
    
    private func saveUserProfile(_ user: NestUser, retryCount: Int = 0) async throws {
        Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: Saving user profile for ID: \(user.id)")
        Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: User name: '\(user.personalInfo.name)'")
        Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: User email: '\(user.personalInfo.email)'")
        
        if retryCount > 0 {
            Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: Retry attempt \(retryCount)/3")
        }

        do {
            let docRef = db.collection("users").document(user.id)
            try await docRef.setData(try Firestore.Encoder().encode(user))

            Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: ✅ User profile saved to Firestore successfully!")

            // Verify profile was actually saved
            try await verifyProfileExists(userId: user.id)

            // Track successful user profile creation
            Tracker.shared.track(.userProfileCreated)

            // Immediately log in to RevenueCat with the user ID after profile creation
            // This ensures any purchases made during onboarding get properly attributed
            Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: Logging in to RevenueCat with user ID: \(user.id)")

            await withCheckedContinuation { continuation in
                Purchases.shared.logIn(user.id) { (customerInfo, created, error) in
                    if let error = error {
                        Logger.log(level: .error, category: .userService, message: "💾 SAVE PROFILE: RevenueCat login error: \(error.localizedDescription)")
                    } else {
                        Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: ✅ RevenueCat login successful for user: \(user.id)")
                        if created {
                            Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: New RevenueCat customer created")
                        } else {
                            Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: Existing RevenueCat customer found")
                        }

                        // Refresh subscription info after successful login
                        Task {
                            await SubscriptionService.shared.refreshCustomerInfo()
                        }
                    }
                    continuation.resume()
                }
            }

        } catch {
            Logger.log(level: .error, category: .userService, message: "💾 SAVE PROFILE: ❌ Failed to save user profile: \(error.localizedDescription)")
            Logger.log(level: .error, category: .userService, message: "💾 SAVE PROFILE: ❌ Error type: \(type(of: error))")
            Logger.log(level: .error, category: .userService, message: "💾 SAVE PROFILE: ❌ Full error: \(error)")
            Logger.log(level: .error, category: .userService, message: "💾 SAVE PROFILE: ❌ User ID: \(user.id), Name: '\(user.personalInfo.name)'")

            // Retry with exponential backoff for network errors
            let maxRetries = 3
            if retryCount < maxRetries && shouldRetry(error: error) {
                let delay = min(pow(2.0, Double(retryCount)), 10.0) // Max 10 seconds
                Logger.log(level: .info, category: .userService, 
                          message: "💾 SAVE PROFILE: Retrying in \(delay) seconds (attempt \(retryCount + 1)/\(maxRetries))")
                try await Task.sleep(for: .seconds(delay))
                try await saveUserProfile(user, retryCount: retryCount + 1)
                return
            }

            // Track user profile creation failure
            Tracker.shared.track(.userProfileCreated, result: false, error: error.localizedDescription)

            throw error
        }
    }
    
    /// Verifies that a profile was actually created in Firestore
    private func verifyProfileExists(userId: String) async throws {
        Logger.log(level: .info, category: .userService, message: "💾 VERIFY: Verifying profile exists for user: \(userId)")
        
        let verificationRef = db.collection("users").document(userId)
        let verificationDoc = try await verificationRef.getDocument()
        
        guard verificationDoc.exists else {
            Logger.log(level: .error, category: .userService, 
                      message: "💾 VERIFY: ❌ Profile verification failed - document doesn't exist")
            throw AuthError.invalidUserData
        }
        
        Logger.log(level: .info, category: .userService, 
                  message: "💾 VERIFY: ✅ Profile verified - document exists")
    }
    
    /// Determines if an error should trigger a retry
    private func shouldRetry(error: Error) -> Bool {
        // Retry on network errors and temporary Firestore errors
        if let nsError = error as NSError? {
            // Network errors
            if nsError.domain == NSURLErrorDomain {
                return true
            }
            // Firestore errors that should be retried
            if nsError.domain == "FIRFirestoreErrorDomain" {
                let firestoreErrorCode = nsError.code
                switch firestoreErrorCode {
                case 14: // UNAVAILABLE (temporary server issues)
                    return true
                case 4: // DEADLINE_EXCEEDED (timeout)
                    return true
                case 8: // RESOURCE_EXHAUSTED (quota exceeded temporarily)
                    return true
                case 10: // ABORTED (transaction conflicts)
                    return true
                case 13: // INTERNAL (internal server error)
                    return true
                default:
                    return false
                }
            }
        }
        return false
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

    // MARK: - Apple Sign In Helper Methods
    func generateNonce() -> String {
        let nonce = randomNonceString()
        self.currentNonce = nonce
        return nonce
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - Types
enum ReauthenticationError: LocalizedError {
    case passwordPromptRequired(email: String)
    case appleSignInRequired

    var errorDescription: String? {
        switch self {
        case .passwordPromptRequired(let email):
            return "Please re-enter your password to delete your account. Email: \(email)"
        case .appleSignInRequired:
            return "Please sign in with Apple again to delete your account."
        }
    }
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError
    case unknown
    case invalidUserData
    case emailAlreadyInUse
    case weakPassword
    case emailInvalid
    case passwordTooWeak
    case userNotFound
    
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
        case .userNotFound:
            return "No account found with this email address"
        }
    }
}

// Add this struct at the bottom of the file
struct SetupResult {
    let isSignedIn: Bool
}

