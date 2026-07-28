import Foundation
import UIKit
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

    var isAuthenticatedWithApple: Bool {
        guard let user = auth.currentUser else { return false }
        return user.providerData.contains { $0.providerID == AuthProviderID.apple.rawValue }
    }

    var currentFirebaseUserID: String? {
        auth.currentUser?.uid
    }

    var currentFirebaseUserEmail: String? {
        auth.currentUser?.email
    }
    
    // Store pending FCM token
    private var pendingFCMToken: String?
    private var lastDeliveredFCMToken: String?
    private var lastAPNSError: Error?
    private var fetchFCMTokenTask: Task<Void, Error>?
    
    // Flags to prevent duplicate operations
    private var isSettingUp: Bool = false
    private var isFetchingProfile: Bool = false
    
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
                    Task {
                        do {
                            _ = try await RevenueCatAttributeService.shared.logIn(appUserID: nestUser.id)
                            await SubscriptionService.shared.refreshCustomerInfo()
                            RevenueCatAttributeService.shared.syncFromUser(nestUser)
                        } catch {
                            Logger.log(level: .error, category: .userService, message: "RevenueCat login error: \(error.localizedDescription)")
                        }
                    }
                } else {
                    Logger.log(level: .info, category: .userService, message: "🔄 AUTH STATE: RevenueCat already logged in with correct user ID: \(nestUser.id)")
                    RevenueCatAttributeService.shared.syncFromUser(nestUser)
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
                
                await self.handleAuthStateChange(firebaseUser: user)
            }
        }
    }
    
    // MARK: - FCM Token Management
    private static let maxStoredFCMTokens = 5
    private static let pushRegistrationTimeout: TimeInterval = 15

    enum PushRegistrationError: LocalizedError {
        case apnsTimeout
        case apnsRegistrationFailed(String)
        case fcmUnavailable
        case simulatorUnavailable

        var errorDescription: String? {
            switch self {
            case .apnsTimeout:
                return "Timed out waiting for APNS registration"
            case .apnsRegistrationFailed(let message):
                return "APNS registration failed: \(message)"
            case .fcmUnavailable:
                return "FCM token is unavailable"
            case .simulatorUnavailable:
                return "Push token registration is unavailable on the iOS Simulator. Use a physical device to test FCM tokens and live push delivery."
            }
        }
    }

    private enum PushRegistrationWaitResult {
        case apnsReady
        case fcmToken(String)
        case failed(Error)
        case timeout
    }

    func handleAPNSTokenRegistered() {
        lastAPNSError = nil
        NotificationCenter.default.post(name: .apnsTokenDidRegister, object: nil)
    }

    func handleAPNSRegistrationFailed(_ error: Error) {
        lastAPNSError = error
        Logger.log(level: .error, category: .userService, message: "APNS registration failed: \(error.localizedDescription)")
        NotificationCenter.default.post(name: .apnsTokenRegistrationFailed, object: error)
    }

    func handleFCMTokenDelivered(_ token: String) {
        lastDeliveredFCMToken = token
        NotificationCenter.default.post(name: .fcmTokenDidUpdate, object: token)
    }

    /// Ensures APNS registration has completed, fetches the current FCM token, and persists it.
    func fetchAndPersistFCMToken() async throws {
        if let existingTask = fetchFCMTokenTask {
            try await existingTask.value
            return
        }

        let task = Task<Void, Error> {
            try await self.performFetchAndPersistFCMToken()
        }
        fetchFCMTokenTask = task
        defer { fetchFCMTokenTask = nil }
        try await task.value
    }

    private func performFetchAndPersistFCMToken() async throws {
        if let lastDeliveredFCMToken {
            try await updateFCMToken(lastDeliveredFCMToken)
            return
        }

        if Messaging.messaging().apnsToken != nil {
            let token = try await Messaging.messaging().token()
            try await updateFCMToken(token)
            return
        }

        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }

        switch await waitForPushRegistration() {
        case .fcmToken(let token):
            try await updateFCMToken(token)
        case .apnsReady:
            let token = try await Messaging.messaging().token()
            try await updateFCMToken(token)
        case .failed(let error):
            throw PushRegistrationError.apnsRegistrationFailed(error.localizedDescription)
        case .timeout:
            #if targetEnvironment(simulator)
            throw PushRegistrationError.simulatorUnavailable
            #else
            throw PushRegistrationError.apnsTimeout
            #endif
        }
    }

    private func waitForPushRegistration() async -> PushRegistrationWaitResult {
        if let lastDeliveredFCMToken {
            return .fcmToken(lastDeliveredFCMToken)
        }
        if Messaging.messaging().apnsToken != nil {
            return .apnsReady
        }
        if let lastAPNSError {
            return .failed(lastAPNSError)
        }

        let deadline = Date().addingTimeInterval(Self.pushRegistrationTimeout)

        return await withTaskGroup(of: PushRegistrationWaitResult.self) { group in
            group.addTask {
                for await _ in NotificationCenter.default.notifications(named: .apnsTokenDidRegister) {
                    return .apnsReady
                }
                return .timeout
            }
            group.addTask {
                for await notification in NotificationCenter.default.notifications(named: .fcmTokenDidUpdate) {
                    if let token = notification.object as? String {
                        return .fcmToken(token)
                    }
                }
                return .timeout
            }
            group.addTask {
                for await notification in NotificationCenter.default.notifications(named: .apnsTokenRegistrationFailed) {
                    if let error = notification.object as? Error {
                        return .failed(error)
                    }
                }
                return .timeout
            }
            group.addTask {
                while Date() < deadline {
                    if let token = self.lastDeliveredFCMToken {
                        return .fcmToken(token)
                    }
                    if Messaging.messaging().apnsToken != nil {
                        return .apnsReady
                    }
                    if let error = self.lastAPNSError {
                        return .failed(error)
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                return .timeout
            }

            let result = await group.next() ?? .timeout
            group.cancelAll()
            return result
        }
    }

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
            let now = Timestamp(date: Date())

            if let existingIndex = fcmTokens.firstIndex(where: { $0["token"] as? String == token }) {
                fcmTokens[existingIndex]["uploadedDate"] = now
            } else {
                fcmTokens.append(["token": token, "uploadedDate": now])
            }

            if fcmTokens.count > Self.maxStoredFCMTokens {
                fcmTokens.sort { lhs, rhs in
                    let lhsDate = (lhs["uploadedDate"] as? Timestamp)?.dateValue() ?? .distantPast
                    let rhsDate = (rhs["uploadedDate"] as? Timestamp)?.dateValue() ?? .distantPast
                    return lhsDate > rhsDate
                }
                fcmTokens = Array(fcmTokens.prefix(Self.maxStoredFCMTokens))
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
    @discardableResult
    func ensureNotificationsRegisteredForSessionAlerts() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            return false
        }

        do {
            let prefs = currentUser?.personalInfo.notificationPreferences
            if prefs?.sessionNotifications != true || prefs?.otherNotifications != true {
                try await updateNotificationPreferences(.default)
            }
            try await fetchAndPersistFCMToken()
            Logger.log(level: .info, category: .userService, message: "Session notification registration refreshed successfully")
            return true
        } catch {
            Logger.log(level: .error, category: .userService, message: "Failed to register session notifications: \(error.localizedDescription)")
            return false
        }
    }

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
            try? await fetchAndPersistFCMToken()
            Logger.log(level: .info, category: .userService, message: "Updated FCM token after login")
            
            Tracker.shared.track(.regularLoginSucceeded)
            TikTokTracker.shared.trackLogin()

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
        Logger.log(level: .info, category: .userService, message: "Attempting signup for email: \(info.email)")
        Tracker.shared.track(.regularSignUpAttempted)

        do {
            let firebaseUser: User
            if let existingUser = auth.currentUser {
                Logger.log(
                    level: .info,
                    category: .userService,
                    message: "Existing Firebase session found (\(existingUser.uid)) — resuming profile creation"
                )
                firebaseUser = existingUser
            } else {
                let result = try await auth.createUser(withEmail: info.email, password: info.password)
                Logger.log(level: .debug, category: .userService, message: "Firebase user created successfully")
                firebaseUser = result.user
            }

            let user = try await finishSignUpProfile(firebaseUser: firebaseUser, info: info)
            Logger.log(level: .info, category: .userService, message: "Signup successful - User: \(user.personalInfo.name)")
            TikTokTracker.shared.trackRegistration()
            return user

        } catch {
            Logger.log(level: .error, category: .userService, message: "Signup failed - Error: \(error.localizedDescription)")
            Tracker.shared.track(.regularSignUpAttempted, result: false, error: error.localizedDescription)

            if let nsError = error as NSError?,
               nsError.code == AuthErrorCode.emailAlreadyInUse.rawValue,
               let existingUser = auth.currentUser {
                Logger.log(
                    level: .info,
                    category: .userService,
                    message: "Email already in use but session exists — resuming profile creation"
                )
                let user = try await finishSignUpProfile(firebaseUser: existingUser, info: info)
                TikTokTracker.shared.trackRegistration()
                return user
            }

            throw mapSignUpAuthError(error)
        }
    }
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> (user: NestUser, isNewUser: Bool, isIncompleteSignup: Bool) {
        // Use email from credential or create timestamp-based identifier
        let identifier = credential.email ?? "apple_signin_\(Int(Date().timeIntervalSince1970))"
        
        // Start capturing logs for this Apple Sign In attempt
        SignupLogService.shared.startCapturing(identifier: identifier)
        
        Logger.log(level: .info, category: .userService, message: "Attempting Apple Sign In")
        Tracker.shared.track(.appleSignInAttempted)
        
        do {
            // Create Firebase credential from Apple credential
            guard let nonce = self.currentNonce else {
                await SignupLogService.shared.stopCaptureAndUpload(result: .failure, identifier: identifier, error: "No nonce available")
                throw AuthError.unknown
            }
            
            guard let appleIDToken = credential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                await SignupLogService.shared.stopCaptureAndUpload(result: .failure, identifier: identifier, error: "Invalid Apple ID token")
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
                    
                    // Profile exists - they're truly an existing user
                    self.currentUser = user
                    self.isAuthenticated = true
                    
                    Logger.log(level: .info, category: .userService, message: "Apple Sign In completed for existing user")
                    Tracker.shared.track(.appleSignInSucceeded)
                    TikTokTracker.shared.trackLogin()

                    // Stop log capture and upload (success) - existing user logged in, no onboarding needed
                    await SignupLogService.shared.stopCaptureAndUpload(result: .success, identifier: identifier)

                    return (user: user, isNewUser: false, isIncompleteSignup: false)
                } catch {
                    // Profile doesn't exist - they authenticated before but never completed onboarding
                    Logger.log(level: .info, category: .userService, message: "Firebase user exists but no profile found - treating as new user for onboarding")
                    
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

                    // Note: Don't stop log capture here - incomplete signup will continue to onboarding
                    // This ensures we capture the completion of the signup process
                    Logger.log(level: .info, category: .userService, message: "📋 LOG CAPTURE: Incomplete Apple signup continuing to onboarding - keeping capture active")

                    return (user: tempUser, isNewUser: true, isIncompleteSignup: true)
                }
            }
            
        } catch {
            Logger.log(level: .error, category: .userService, message: "Apple Sign In failed: \(error)")
            Tracker.shared.track(.appleSignInAttempted, result: false, error: error.localizedDescription)
            
            // Stop log capture and upload (failure) - Apple Sign In failed
            await SignupLogService.shared.stopCaptureAndUpload(result: .failure, identifier: identifier, error: error.localizedDescription)
            
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
                    email: email,
                    phone: info.phone.isEmpty ? nil : info.phone,
                    venmoUsername: info.venmoUsername,
                    hourlyRateCents: info.hourlyRateCents
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
            TikTokTracker.shared.trackRegistration()

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
        Logger.log(level: .info, category: .userService, message: "Completing Apple Sign In profile setup")

        guard let firebaseUser = auth.currentUser else {
            throw AuthError.unknown
        }

        do {
            let user = try await finishSignUpProfile(firebaseUser: firebaseUser, info: info)
            Logger.log(level: .info, category: .userService, message: "Apple Sign In profile setup completed successfully")
            TikTokTracker.shared.trackRegistration()
            return user
        } catch {
            Logger.log(level: .error, category: .userService, message: "Apple Sign In profile setup failed: \(error)")
            throw error
        }
    }

    private func finishSignUpProfile(
        firebaseUser: User,
        info: OnboardingCoordinator.UserOnboardingInfo
    ) async throws -> NestUser {
        let displayName = info.fullName.isEmpty ? (firebaseUser.displayName ?? "") : info.fullName
        if !displayName.isEmpty {
            let changeRequest = firebaseUser.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            Logger.log(level: .debug, category: .userService, message: "Display name set successfully")
        }

        var defaultNest: NestItem?
        if let nestName = info.nestInfo?.name,
           let nestAddress = info.nestInfo?.address {
            defaultNest = try await setupNestForUser(
                userId: firebaseUser.uid,
                nestName: nestName,
                nestAddress: nestAddress,
                surveyResponses: info.surveyResponses
            )
        }

        let email = firebaseUser.email ?? info.email
        let user = NestUser(
            id: firebaseUser.uid,
            personalInfo: .init(
                name: displayName,
                email: email,
                phone: info.phone.isEmpty ? nil : info.phone,
                venmoUsername: info.venmoUsername,
                hourlyRateCents: info.hourlyRateCents,
                notificationPreferences: .default
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

        try await saveUserProfile(user)

        self.currentUser = user
        self.isAuthenticated = true
        saveAuthState()

        return user
    }

    private func mapSignUpAuthError(_ error: Error) -> Error {
        guard let nsError = error as NSError? else { return error }

        switch nsError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return AuthError.emailAlreadyInUse
        case AuthErrorCode.invalidEmail.rawValue:
            return AuthError.emailInvalid
        case AuthErrorCode.weakPassword.rawValue:
            return AuthError.passwordTooWeak
        case AuthErrorCode.networkError.rawValue:
            return AuthError.networkError
        default:
            return error
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
            pendingFCMToken = nil
            lastDeliveredFCMToken = nil
            lastAPNSError = nil
            fetchFCMTokenTask?.cancel()
            fetchFCMTokenTask = nil
            clearAuthState()
            
            // Optionally clear saved credentials from keychain
            if clearSavedCredentials {
                _ = KeychainService.shared.deleteAllCredentials()
            }
            
            Logger.log(level: .info, category: .userService, message: "User logged out successfully")
            Tracker.shared.track(.userLoggedOut)
            TikTokTracker.shared.logout()
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
            if let ownedNestId = currentUser.roles.nestAccess.first(where: { $0.accessLevel == .owner })?.nestId {
                Logger.log(level: .info, category: .userService, message: "Deleting owned nest: \(ownedNestId)")
                try await deleteNest(nestId: ownedNestId)
                Logger.log(level: .info, category: .userService, message: "Nest deleted successfully")
            }

            Logger.log(level: .info, category: .userService, message: "Deleting user document from Firestore")
            let userDocRef = db.collection("users").document(currentUser.id)
            try await userDocRef.delete()
            Logger.log(level: .info, category: .userService, message: "User document deleted successfully")

            Logger.log(level: .info, category: .userService, message: "Deleting Firebase Auth user")
            try await deleteFirebaseUserWithReauth(firebaseUser)
            Logger.log(level: .info, category: .userService, message: "Firebase Auth user deleted successfully")

            self.currentUser = nil
            self.isAuthenticated = false
            clearAuthState()

            Purchases.shared.logOut { (customerInfo, error) in
                if let error = error {
                    Logger.log(level: .error, category: .userService, message: "RevenueCat logout error: \(error.localizedDescription)")
                }
            }

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
            try await firebaseUser.delete()
        } catch let error as NSError {
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                Logger.log(level: .info, category: .userService, message: "Credential too old - reauthentication required")

                guard let providerData = firebaseUser.providerData.first else {
                    Logger.log(level: .error, category: .userService, message: "No provider data found for reauthentication")
                    throw AuthError.unknown
                }

                switch providerData.providerID {
                case "password":
                    try await reauthenticateWithEmailPassword(firebaseUser)
                case "apple.com":
                    try await reauthenticateWithApple(firebaseUser)
                default:
                    Logger.log(level: .error, category: .userService, message: "Unsupported provider for reauthentication: \(providerData.providerID)")
                    throw AuthError.unknown
                }

                try await firebaseUser.delete()
            } else {
                throw error
            }
        }
    }

    private func reauthenticateWithEmailPassword(_ firebaseUser: User) async throws {
        guard let email = firebaseUser.email else {
            throw AuthError.invalidUserData
        }
        Logger.log(level: .error, category: .userService, message: "Email/password reauthentication requires user interaction")
        throw ReauthenticationError.passwordPromptRequired(email: email)
    }

    private func reauthenticateWithApple(_ firebaseUser: User) async throws {
        Logger.log(level: .error, category: .userService, message: "Apple Sign In reauthentication requires user interaction")
        throw ReauthenticationError.appleSignInRequired
    }

    func reauthenticateAndDeleteAccount(password: String) async throws {
        guard currentUser != nil else {
            throw AuthError.invalidUserData
        }

        guard let firebaseUser = auth.currentUser, let email = firebaseUser.email else {
            throw AuthError.invalidUserData
        }

        Logger.log(level: .info, category: .userService, message: "Reauthenticating user with email/password for account deletion")

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await firebaseUser.reauthenticate(with: credential)
        Logger.log(level: .info, category: .userService, message: "User reauthenticated successfully")

        try await deleteAccount()
    }

    func reauthenticateAndDeleteAccount(appleCredential: ASAuthorizationAppleIDCredential) async throws {
        guard currentUser != nil else {
            throw AuthError.invalidUserData
        }

        guard let firebaseUser = auth.currentUser else {
            throw AuthError.invalidUserData
        }

        Logger.log(level: .info, category: .userService, message: "Reauthenticating user with Apple Sign In for account deletion")

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

        try await firebaseUser.reauthenticate(with: firebaseCredential)
        Logger.log(level: .info, category: .userService, message: "User reauthenticated successfully")

        try await deleteAccount()
    }

    private func deleteNest(nestId: String) async throws {
        Logger.log(level: .info, category: .userService, message: "Deleting nest and all associated data: \(nestId)")

        let nestRef = db.collection("nests").document(nestId)
        let subcollections = ["entries", "nestCategories", "savedSitters", "sessions", "items"]

        for subcollection in subcollections {
            let collectionRef = nestRef.collection(subcollection)
            let snapshot = try await collectionRef.getDocuments()

            var batch = db.batch()
            var batchCount = 0

            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
                batchCount += 1

                if batchCount >= 500 {
                    try await batch.commit()
                    batch = db.batch()
                    batchCount = 0
                }
            }

            if batchCount > 0 {
                try await batch.commit()
            }

            Logger.log(level: .info, category: .userService, message: "Deleted \(snapshot.documents.count) documents from \(subcollection)")
        }

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

    func fetchSubscriptionSnapshot(userId: String) async -> UserSubscriptionSnapshot? {
        do {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            guard snapshot.exists else { return nil }
            return UserSubscriptionSnapshot.parse(from: snapshot.data())
        } catch {
            Logger.log(
                level: .error,
                category: .userService,
                message: "Failed to fetch subscription snapshot for \(userId): \(error.localizedDescription)"
            )
            return nil
        }
    }

    func fetchSubscriptionSnapshots(userIds: [String]) async -> [String: UserSubscriptionSnapshot] {
        let uniqueIds = Array(Set(userIds.filter { !$0.isEmpty }))
        guard !uniqueIds.isEmpty else { return [:] }

        return await withTaskGroup(of: (String, UserSubscriptionSnapshot?).self) { group in
            for userId in uniqueIds {
                group.addTask {
                    let snapshot = await self.fetchSubscriptionSnapshot(userId: userId)
                    return (userId, snapshot)
                }
            }

            var results: [String: UserSubscriptionSnapshot] = [:]
            for await (userId, snapshot) in group {
                if let snapshot {
                    results[userId] = snapshot
                }
            }
            return results
        }
    }
    
    private func saveUserProfile(_ user: NestUser) async throws {
        Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: Saving user profile for ID: \(user.id)")
        Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: User name: '\(user.personalInfo.name)'")
        Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: User email: '\(user.personalInfo.email)'")

        do {
            let docRef = db.collection("users").document(user.id)
            let existingDoc = try await docRef.getDocument()
            var encodedUser = try Firestore.Encoder().encode(user)
            if !existingDoc.exists {
                encodedUser["createdAt"] = FieldValue.serverTimestamp()
            }
            try await docRef.setData(encodedUser)

            Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: ✅ User profile saved to Firestore successfully!")

            // Track successful user profile creation
            Tracker.shared.track(.userProfileCreated)

            // Immediately log in to RevenueCat with the user ID after profile creation
            // This ensures any purchases made during onboarding get properly attributed
            Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: Logging in to RevenueCat with user ID: \(user.id)")

            do {
                _ = try await RevenueCatAttributeService.shared.logIn(appUserID: user.id)
                Logger.log(level: .info, category: .userService, message: "💾 SAVE PROFILE: ✅ RevenueCat login successful for user: \(user.id)")
                await SubscriptionService.shared.refreshCustomerInfo()
                RevenueCatAttributeService.shared.syncFromUser(user)
            } catch {
                Logger.log(level: .error, category: .userService, message: "💾 SAVE PROFILE: RevenueCat login error: \(error.localizedDescription)")
            }

        } catch {
            Logger.log(level: .error, category: .userService, message: "💾 SAVE PROFILE: ❌ Failed to save user profile: \(error.localizedDescription)")
            Logger.log(level: .error, category: .userService, message: "💾 SAVE PROFILE: ❌ Error type: \(type(of: error))")
            Logger.log(level: .error, category: .userService, message: "💾 SAVE PROFILE: ❌ Full error: \(error)")
            Logger.log(level: .error, category: .userService, message: "💾 SAVE PROFILE: ❌ User ID: \(user.id), Name: '\(user.personalInfo.name)'")

            // Track user profile creation failure
            Tracker.shared.track(.userProfileCreated, result: false, error: error.localizedDescription)

            throw error
        }
    }

    func markOnboardingComplete(userId: String, lastSurveyResponseId: String?) async throws {
        var updateData: [String: Any] = [
            "onboardingCompletedAt": FieldValue.serverTimestamp()
        ]
        if let lastSurveyResponseId, !lastSurveyResponseId.isEmpty {
            updateData["lastSurveyResponseId"] = lastSurveyResponseId
        } else {
            updateData["lastSurveyResponseId"] = FieldValue.delete()
        }

        let docRef = db.collection("users").document(userId)
        try await docRef.updateData(updateData)
        Logger.log(level: .info, category: .userService, message: "Marked onboarding complete for user: \(userId)")
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

    /// Whether the current user has already completed their one free fully-featured session.
    var hasUsedFreeSession: Bool {
        currentUser?.hasUsedFreeSession ?? false
    }

    /// Marks the user's one free fully-featured session as used after session completion.
    func markFreeSessionUsed() async throws {
        guard let currentUser = currentUser else {
            throw AuthError.invalidUserData
        }

        guard currentUser.hasUsedFreeSession != true else { return }

        let docRef = db.collection("users").document(currentUser.id)
        try await docRef.updateData([
            "hasUsedFreeSession": true,
            "updatedAt": FieldValue.serverTimestamp()
        ])

        self.currentUser?.hasUsedFreeSession = true
        saveAuthState()
        NotificationCenter.default.post(name: .userInformationUpdated, object: nil)

        Logger.log(level: .info, category: .userService, message: "Marked free session as used for user: \(currentUser.id)")
    }
    
    func updatePhone(_ rawPhone: String) async throws {
        guard let currentUser = currentUser else {
            throw AuthError.invalidUserData
        }
        
        let digits = PhoneNumberFormatter.digits(from: rawPhone)
        guard PhoneNumberFormatter.isValid(digits) else {
            throw AuthError.invalidUserData
        }
        
        let docRef = db.collection("users").document(currentUser.id)
        try await docRef.updateData([
            "personalInfo.phone": digits,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        self.currentUser?.personalInfo.phone = digits
        saveAuthState()
        
        if let user = self.currentUser {
            RevenueCatAttributeService.shared.syncFromUser(user)
        }
        
        NotificationCenter.default.post(name: .userInformationUpdated, object: nil)
        
        Logger.log(level: .info, category: .userService, message: "User phone updated successfully")
    }
    
    func updateVenmoUsername(_ rawUsername: String) async throws {
        guard let currentUser = currentUser else {
            throw AuthError.invalidUserData
        }
        
        let trimmed = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized: String?
        if trimmed.isEmpty {
            normalized = nil
        } else if let value = VenmoPaymentHandler.normalizeUsername(trimmed) {
            normalized = value
        } else {
            throw AuthError.invalidUserData
        }
        
        let docRef = db.collection("users").document(currentUser.id)
        if let normalized {
            try await docRef.updateData([
                "personalInfo.venmoUsername": normalized,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } else {
            try await docRef.updateData([
                "personalInfo.venmoUsername": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }
        
        self.currentUser?.personalInfo.venmoUsername = normalized
        saveAuthState()
        
        try await patchVenmoUsernameOnAssignedSessions(userId: currentUser.id, venmoUsername: normalized)
        
        NotificationCenter.default.post(name: .userInformationUpdated, object: nil)
        
        Logger.log(level: .info, category: .userService, message: "Venmo username updated successfully")
    }

    func updateHourlyRate(_ hourlyRateCents: Int?) async throws {
        guard let currentUser = currentUser else {
            throw AuthError.invalidUserData
        }

        if let hourlyRateCents {
            guard (SessionPaymentCalculator.minimumHourlyRateCents...SessionPaymentCalculator.maximumHourlyRateCents).contains(hourlyRateCents) else {
                throw AuthError.invalidUserData
            }
        }

        let docRef = db.collection("users").document(currentUser.id)
        if let hourlyRateCents {
            try await docRef.updateData([
                "personalInfo.hourlyRateCents": hourlyRateCents,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } else {
            try await docRef.updateData([
                "personalInfo.hourlyRateCents": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }

        self.currentUser?.personalInfo.hourlyRateCents = hourlyRateCents
        saveAuthState()

        try await patchHourlyRateOnAssignedSessions(userId: currentUser.id, hourlyRateCents: hourlyRateCents)

        NotificationCenter.default.post(name: .userInformationUpdated, object: nil)

        Logger.log(level: .info, category: .userService, message: "Hourly rate updated successfully")
    }

    private func patchHourlyRateOnAssignedSessions(userId: String, hourlyRateCents: Int?) async throws {
        let sitterSessionsRef = db.collection("users").document(userId).collection("sitterSessions")
        let snapshot = try await sitterSessionsRef.getDocuments()

        for document in snapshot.documents {
            guard let sitterSession = try? document.data(as: SitterSession.self) else { continue }

            let sessionRef = db.collection("nests").document(sitterSession.nestID)
                .collection("sessions").document(sitterSession.id)

            let sessionSnapshot = try await sessionRef.getDocument()
            guard sessionSnapshot.exists,
                  let sessionData = sessionSnapshot.data(),
                  let assignedSitterData = sessionData["assignedSitter"] as? [String: Any],
                  let assignedUserID = assignedSitterData["userID"] as? String,
                  assignedUserID == userId else {
                continue
            }

            if let hourlyRateCents {
                try await sessionRef.updateData(["assignedSitter.hourlyRateCents": hourlyRateCents])
            } else {
                try await sessionRef.updateData(["assignedSitter.hourlyRateCents": FieldValue.delete()])
            }
        }
    }
    
    private func patchVenmoUsernameOnAssignedSessions(userId: String, venmoUsername: String?) async throws {
        let sitterSessionsRef = db.collection("users").document(userId).collection("sitterSessions")
        let snapshot = try await sitterSessionsRef.getDocuments()
        
        for document in snapshot.documents {
            guard let sitterSession = try? document.data(as: SitterSession.self) else { continue }
            
            let sessionRef = db.collection("nests").document(sitterSession.nestID)
                .collection("sessions").document(sitterSession.id)
            
            let sessionSnapshot = try await sessionRef.getDocument()
            guard sessionSnapshot.exists,
                  let sessionData = sessionSnapshot.data(),
                  let assignedSitterData = sessionData["assignedSitter"] as? [String: Any],
                  let assignedUserID = assignedSitterData["userID"] as? String,
                  assignedUserID == userId else {
                continue
            }
            
            if let venmoUsername {
                try await sessionRef.updateData(["assignedSitter.venmoUsername": venmoUsername])
            } else {
                try await sessionRef.updateData(["assignedSitter.venmoUsername": FieldValue.delete()])
            }
        }
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

