import UIKit
import FirebaseAuth

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
        // Configure services
        try await Launcher.shared.configure()
        Logger.log(level: .info, category: .launcher, message: "Services configured successfully")
        
        await MainActor.run {
            // Create initial navigation controller with loading placeholder
            let navigationController = UINavigationController(rootViewController: LoadingViewController())
            self.navigationController = navigationController
            
            // Set as root and make visible
            window?.rootViewController = navigationController
            window?.makeKeyAndVisible()
            
            // Show auth flow if needed or configure for current user
            if !UserService.shared.isSignedIn {
                showAuthenticationFlow()
            } else {
                // If already signed in, determine user type and set correct home view controller
                Task {
                    try await self.configureForCurrentUser()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func showAuthenticationFlow() {
        guard let navigationController = self.navigationController else { return }
        
        let landingVC = LandingViewController()
        landingVC.delegate = self
        landingVC.isModalInPresentation = true // Prevent dismissal by swipe
        
        navigationController.present(landingVC, animated: true)
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
                // Get the landing view controller
                guard let navigationController = self.navigationController,
                      let landingVC = navigationController.presentedViewController as? LandingViewController else {
                    return
                }
                
                // Dismiss and reconfigure
                await MainActor.run {
                    landingVC.dismiss(animated: true) {
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
