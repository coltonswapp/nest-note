//
//  LandingViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 11/2/24.
//

import UIKit
import AuthenticationServices
import CryptoKit
import SwiftUI

final class LandingViewController: NNViewController {
    
    // SwiftUI Host
    lazy var introHost: UIHostingController = UIHostingController(rootView: IntroPage(
        onGetStarted: { self.getStartedTapped() },
        onAppleSignIn: { self.appleSignInTapped() },
        onLogin: { self.loginTapped() },
        onSignUp: { self.signUpTapped() }
    ))
    
    // Keep delegate and keyboard constraint
    weak var delegate: AuthenticationDelegate?
    private var mainStackTopConstraint: NSLayoutConstraint?
    
    override func loadView() {
        super.loadView()
        self.navigationController?.isNavigationBarHidden = true
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func addSubviews() {
        introHost.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(introHost.view)
    }
    
    override func constrainSubviews() {
        
        NSLayoutConstraint.activate([
            introHost.view.topAnchor.constraint(equalTo: view.topAnchor),
            introHost.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            introHost.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            introHost.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
    }
    
    @objc private func getStartedTapped() {
        // This now just triggers the animation to show auth buttons
    }

    @objc private func appleSignInTapped() {
        HapticsHelper.lightHaptic()

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let nonce = UserService.shared.generateNonce()
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    @objc private func loginTapped() {
        let loginVC = LoginViewController()
        loginVC.delegate = self.delegate
        self.navigationController?.pushViewController(loginVC, animated: true)
    }

    @objc private func signUpTapped() {
        let loginVC = LoginViewController()
        loginVC.delegate = self.delegate
        loginVC.shouldShowSignUpFlow = true
        self.navigationController?.pushViewController(loginVC, animated: true)
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

// MARK: - ASAuthorizationControllerDelegate
extension LandingViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            Task {
                do {
                    let result = try await UserService.shared.signInWithApple(credential: appleIDCredential)
                    await MainActor.run {
                        if result.isNewUser {
                            if result.isIncompleteSignup {
                                self.showIncompleteSignupAlert(credential: appleIDCredential)
                            } else {
                                self.startAppleOnboardingFlow(credential: appleIDCredential)
                            }
                        } else {
                            self.handleExistingAppleUser()
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.showAuthError(error)
                    }
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        showAuthError(error)
    }

    private func startAppleOnboardingFlow(credential: ASAuthorizationAppleIDCredential) {
        if let delegate = self.delegate as? LaunchCoordinator {
            delegate.startAppleSignInOnboarding(with: credential)
        } else {
            self.delegate?.signUpTapped()
        }
    }

    private func showIncompleteSignupAlert(credential: ASAuthorizationAppleIDCredential) {
        let alert = UIAlertController(
            title: "Welcome Back!",
            message: "Let's finish setting up your NestNote account.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Complete Setup", style: .default) { _ in
            self.startAppleOnboardingFlow(credential: credential)
        })
        present(alert, animated: true)
    }

    private func handleExistingAppleUser() {
        Task {
            try await Launcher.shared.configure()
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            await MainActor.run {
                Logger.log(level: .info, category: .general, message: "Successfully signed in with Apple")
                self.delegate?.authenticationComplete()
            }
        }
    }

    private func showAuthError(_ error: Error) {
        let alert = UIAlertController(
            title: "Sign In Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension LandingViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}
