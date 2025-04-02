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
    
    // MARK: - Initialization
    init(window: UIWindow) {
        self.window = window
        setupObservers()
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
        if let primaryRole = UserService.shared.currentUser?.primaryRole {
            switch primaryRole {
            case .nestOwner:
                userType = .owner
            case .sitter:
                userType = .sitter
            }
        } else {
            userType = .none
        }
        self.userType = userType
        
        await MainActor.run {
            guard let navigationController = self.navigationController else { return }
            
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
        // Reconfigure services with the new user
        try await Launcher.shared.configure()
        
        // Configure for the current user type
        try await configureForCurrentUser()
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
        let containerVC = onboardingCoordinator.start()
        onboardingCoordinator.authenticationDelegate = self
        (containerVC as? OnboardingContainerViewController)?.delegate = self
        
        // Present the container view controller modally
        containerVC.modalPresentationStyle = .fullScreen
        navigationController.present(containerVC, animated: true)
    }
    
    func signUpComplete() {
        Task {
            // Get the view controllers
            guard let navigationController = self.navigationController,
                  let landingVC = navigationController.presentedViewController as? LandingViewController else {
                return
            }
            
            // Dismiss landing VC and reconfigure
            await MainActor.run {
                landingVC.dismiss(animated: true) {
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
    }
}

// MARK: - OnboardingContainerDelegate
extension LaunchCoordinator: OnboardingContainerDelegate {
    func onboardingContainerDidRequestAbort(_ container: OnboardingContainerViewController) {
        // Dismiss the onboarding container
        container.dismiss(animated: true) { [weak self] in
            // Show the login screen
            self?.showAuthenticationFlow()
        }
    }
}

// MARK: - Loading Placeholder
private class LoadingViewController: UIViewController {
    private let birdImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "bird.fill"))
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label
        imageView.preferredSymbolConfiguration = .init(pointSize: 80, weight: .regular)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        view.addSubview(birdImageView)
        NSLayoutConstraint.activate([
            birdImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            birdImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            birdImageView.widthAnchor.constraint(equalToConstant: 120),
            birdImageView.heightAnchor.constraint(equalTo: birdImageView.widthAnchor)
        ])
    }
} 
