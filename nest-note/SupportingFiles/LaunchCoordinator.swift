import UIKit
import FirebaseAuth
import AuthenticationServices

// MARK: - Timeout Helper
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        // Add the main operation
        group.addTask {
            try await operation()
        }

        // Add timeout task
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }

        // Return the first result (either success or timeout)
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

struct TimeoutError: LocalizedError {
    var errorDescription: String? {
        return "Operation timed out"
    }
}

enum UserType {
    case owner
    case sitter
    case none
}

final class LaunchCoordinator {
    // MARK: - Properties
    private weak var window: UIWindow?
    private weak var navigationController: UINavigationController?
    private var userType: UserType?
    private var currentOnboardingCoordinator: OnboardingCoordinator?
    
    // MARK: - Shared Instance
    static private(set) var shared: LaunchCoordinator?
    
    // MARK: - Initialization
    init(window: UIWindow) {
        self.window = window
        setupObservers()
        // Make this instance available as shared instance
        LaunchCoordinator.shared = self
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppReset),
            name: .appDidReset,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleModeChange),
            name: .modeDidChange,
            object: nil
        )
    }
    
    @objc private func handleAppReset() {
        guard let navigationController = self.navigationController else { return }
        
        // Clear user type since we're resetting
        self.userType = nil
        
        // Set loading placeholder before showing auth flow
        UIView.transition(with: navigationController.view,
                         duration: 0.3,
                         options: .transitionCrossDissolve,
                         animations: {
            navigationController.setViewControllers([LoadingViewController()], animated: false)
        }) { _ in
            self.showAuthenticationFlow()
        }
    }
    
    @objc private func handleModeChange() {
        guard let navigationController = self.navigationController else { return }
        
        // Set loading placeholder before showing auth flow
        UIView.transition(with: navigationController.view,
                         duration: 0.3,
                         options: .transitionCrossDissolve,
                         animations: {
            navigationController.setViewControllers([LoadingViewController()], animated: false)
        })
    }
    
    // MARK: - Public Methods
    func start() async throws {
        Logger.log(level: .info, category: .launcher, message: "🚀 LAUNCH: Starting app launch sequence")

        do {
            // Configure services with timeout to prevent infinite loading
            Logger.log(level: .info, category: .launcher, message: "🚀 LAUNCH: Configuring services...")

            try await withTimeout(seconds: 10) {
                try await Launcher.shared.configure()
            }

            Logger.log(level: .info, category: .launcher, message: "🚀 LAUNCH: ✅ Services configured successfully")

        } catch {
            Logger.log(level: .error, category: .launcher, message: "🚀 LAUNCH: ❌ Service configuration failed: \(error)")
            Logger.log(level: .error, category: .launcher, message: "🚀 LAUNCH: ❌ Falling back to authentication flow")

            // If service configuration fails, force user to re-authenticate
            await MainActor.run {
                let navigationController = UINavigationController(rootViewController: LoadingViewController())
                self.navigationController = navigationController
                window?.rootViewController = navigationController
                window?.makeKeyAndVisible()

                // Force show auth flow on configuration failure
                showAuthenticationFlow()
            }
            return
        }

        await MainActor.run {
            // Create initial navigation controller with loading placeholder
            let navigationController = UINavigationController(rootViewController: LoadingViewController())
            self.navigationController = navigationController

            // Set as root and make visible
            window?.rootViewController = navigationController
            window?.makeKeyAndVisible()

            Logger.log(level: .info, category: .launcher, message: "🚀 LAUNCH: Determining user state...")
            Logger.log(level: .info, category: .launcher, message: "🚀 LAUNCH: UserService.isSignedIn = \(UserService.shared.isSignedIn)")
            Logger.log(level: .info, category: .launcher, message: "🚀 LAUNCH: UserService.isAuthenticated = \(UserService.shared.isAuthenticated)")

            // Show auth flow if needed or configure for current user
            if !UserService.shared.isSignedIn {
                Logger.log(level: .info, category: .launcher, message: "🚀 LAUNCH: User not signed in, showing auth flow")
                showAuthenticationFlow()
            } else {
                Logger.log(level: .info, category: .launcher, message: "🚀 LAUNCH: User signed in, configuring for current user...")
                // If already signed in, determine user type and set correct home view controller
                Task {
                    do {
                        try await withTimeout(seconds: 5) {
                            try await self.configureForCurrentUser()
                        }
                        Logger.log(level: .info, category: .launcher, message: "🚀 LAUNCH: ✅ User configuration complete")
                    } catch {
                        Logger.log(level: .error, category: .launcher, message: "🚀 LAUNCH: ❌ User configuration failed: \(error)")
                        Logger.log(level: .error, category: .launcher, message: "🚀 LAUNCH: ❌ Forcing re-authentication")

                        // If user configuration fails, force re-authentication
                        await MainActor.run {
                            self.showAuthenticationFlow()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func showAuthenticationFlow() {
        guard let navigationController = self.navigationController else { return }
        
        let landingVC = LandingViewController()
        landingVC.delegate = self
        
        // Wrap in navigation controller to enable push navigation
        let authNavController = UINavigationController(rootViewController: landingVC)
        authNavController.isModalInPresentation = true // Prevent dismissal by swipe
        
        navigationController.present(authNavController, animated: true)
    }
    
    private func handleAuthenticationError(_ error: Error, presentingFrom viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Setup Error",
            message: "Failed to complete setup. Please try again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }
    
    private func configureForCurrentUser() async throws {
        // Determine user type from UserService's currentUser
        let userType: UserType
        let savedMode = ModeManager.shared.currentMode
        switch savedMode {
        case .nestOwner:
            userType = .owner
        case .sitter:
            userType = .sitter
        }
        
        self.userType = userType
        
        await MainActor.run {
            guard let navigationController = self.navigationController else {
                Logger.log(level: .error, category: .launcher, message: "Could not configure for current user ❌")
                return }
            
            // Create the appropriate home view controller
            let homeVC: UIViewController
            switch userType {
            case .owner:
                homeVC = OwnerHomeViewController()
            case .sitter:
                homeVC = SitterHomeViewController()
            case .none:
                // This shouldn't happen if we're signed in, but handle it anyway
                let initialVC = HomeViewControllerFactory.createHomeViewController()
                if let navVC = initialVC as? UINavigationController {
                    homeVC = navVC.viewControllers[0]
                } else {
                    homeVC = initialVC
                }
            }
            
            // Smoothly set the new root view controller of the navigation controller
            UIView.transition(with: navigationController.view,
                             duration: 0.3,
                             options: .transitionCrossDissolve,
                             animations: {
                navigationController.setViewControllers([homeVC], animated: false)
            })
        }
    }
    
    private func reconfigureAfterAuthentication() async throws {
        do {
            // Only reconfigure if we actually need to - avoid redundant calls
            // The auth state listener may have already configured services
            if !UserService.shared.isSignedIn {
                Logger.log(level: .debug, category: .launcher, message: "User not signed in during reconfigure, running full configuration")
                try await Launcher.shared.configure()
            } else {
                Logger.log(level: .debug, category: .launcher, message: "User already signed in, skipping redundant service configuration")
            }
            
            // Configure for the current user type
            try await configureForCurrentUser()
        } catch {
            print("Errors! reconfigureAfterAuthentication: \(error)")
            throw error
        }
    }
    
    // MARK: - Mode Switching
    func switchMode(to newMode: AppMode) async throws {
        // Log the operation
        Logger.log(level: .info, category: .launcher, message: "Switching to mode: \(newMode.rawValue)")
        
        do {
            // Reconfigure services with the new mode (same as after authentication)
            try await reconfigureAfterAuthentication()
        } catch {
            throw error
        }
    }
}

// MARK: - AuthenticationDelegate
extension LaunchCoordinator: AuthenticationDelegate {
    func authenticationComplete() {
        Task {
            do {
                // Get the auth navigation controller and landing view controller
                guard let navigationController = self.navigationController,
                      let authNavController = navigationController.presentedViewController as? UINavigationController,
                      let landingVC = authNavController.viewControllers.first as? LandingViewController else {
                    return
                }
                
                // Dismiss and reconfigure
                await MainActor.run {
                    authNavController.dismiss(animated: true) {
                        Task {
                            do {
                                try await self.reconfigureAfterAuthentication()
                            } catch {
                                Logger.log(level: .error, category: .launcher, message: "Post-login configuration failed: \(error)")
                                self.handleAuthenticationError(error, presentingFrom: navigationController)
                            }
                        }
                    }
                }
            } catch {
                Logger.log(level: .error, category: .launcher, message: "Authentication completion failed: \(error)")
            }
        }
    }
    
    func signUpTapped() {
        guard let navigationController = self.navigationController else {
            return
        }
        
        let onboardingCoordinator = OnboardingCoordinator()
        self.currentOnboardingCoordinator = onboardingCoordinator
        let containerVC = onboardingCoordinator.start()
        onboardingCoordinator.authenticationDelegate = self
        (containerVC as? OnboardingContainerViewController)?.delegate = self
        
        // Present the container view controller modally
        containerVC.modalPresentationStyle = .fullScreen
        navigationController.present(containerVC, animated: true)
    }
    
    func startAppleSignInOnboarding(with credential: ASAuthorizationAppleIDCredential) {
        guard let navigationController = self.navigationController else {
            return
        }
        
        let onboardingCoordinator = OnboardingCoordinator()
        self.currentOnboardingCoordinator = onboardingCoordinator
        
        // Pre-configure the coordinator with Apple credential
        onboardingCoordinator.handleAppleSignIn(credential: credential)
        
        let containerVC = onboardingCoordinator.start()
        onboardingCoordinator.authenticationDelegate = self
        (containerVC as? OnboardingContainerViewController)?.delegate = self
        
        // Present the container view controller modally
        containerVC.modalPresentationStyle = .fullScreen
        navigationController.present(containerVC, animated: true)
    }
    
    func signUpComplete() {
        Logger.log(level: .info, category: .launcher, message: "Sign up complete, moving to Launcher...")
        
        Task {
            // Get the view controllers
            guard let navigationController = self.navigationController else {
                return
            }
            
            Logger.log(level: .info, category: .launcher, message: "Attempting to reconfigure after sign up...")
            
            Task {
                do {
                    try await self.reconfigureAfterAuthentication()
                } catch {
                    Logger.log(level: .error, category: .launcher, message: "Post-signup configuration failed: \(error)")
                    self.handleAuthenticationError(error, presentingFrom: navigationController)
                }
            }
            
            
        }
    }
}

// MARK: - OnboardingContainerDelegate
extension LaunchCoordinator: OnboardingContainerDelegate {
    func onboardingContainerDidRequestSkipSurvey(_ container: OnboardingContainerViewController) {
        // Delegate the skip survey request to the OnboardingCoordinator
        currentOnboardingCoordinator?.onboardingContainerDidRequestSkipSurvey(container)
    }
    
    func onboardingContainerDidRequestAbort(_ container: OnboardingContainerViewController) {
        // Dismiss the onboarding container
        container.dismiss(animated: true) { [weak self] in
            // Show the login screen
            self?.showAuthenticationFlow()
        }
    }
}
