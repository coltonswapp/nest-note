//
//  OBEmailViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 7/8/25.
//
import UIKit
import AuthenticationServices
import CryptoKit

final class OBEmailViewController: NNOnboardingViewController {
    // MARK: - UI Elements
    private let emailTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Email"
        textField.keyboardType = .emailAddress
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textContentType = .emailAddress
        return textField
    }()
    
    private lazy var signInWithAppleButton: NNPrimaryLabeledButton = {
        let appleImage = UIImage(systemName: "apple.logo")
        let button = NNPrimaryLabeledButton(title: "Sign in with Apple", image: appleImage)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .label
        button.foregroundColor = .systemBackground
        button.addTarget(self, action: #selector(signInWithAppleTapped), for: .touchUpInside)
        return button
    }()
    
    private let orDividerView: UIView = {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let leftLine = UIView()
        leftLine.backgroundColor = UIColor.systemGray4
        leftLine.translatesAutoresizingMaskIntoConstraints = false
        
        let rightLine = UIView()
        rightLine.backgroundColor = UIColor.systemGray4
        rightLine.translatesAutoresizingMaskIntoConstraints = false
        
        let orLabel = UILabel()
        orLabel.text = "or"
        orLabel.textColor = UIColor.systemGray
        orLabel.font = UIFont.systemFont(ofSize: 14)
        orLabel.textAlignment = .center
        orLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(leftLine)
        containerView.addSubview(rightLine)
        containerView.addSubview(orLabel)
        
        NSLayoutConstraint.activate([
            leftLine.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            leftLine.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            leftLine.trailingAnchor.constraint(equalTo: orLabel.leadingAnchor, constant: -16),
            leftLine.heightAnchor.constraint(equalToConstant: 1),
            
            orLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            orLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            orLabel.widthAnchor.constraint(equalToConstant: 24),
            
            rightLine.leadingAnchor.constraint(equalTo: orLabel.trailingAnchor, constant: 16),
            rightLine.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            rightLine.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            rightLine.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        return containerView
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "Now, lets grab your email",
            subtitle: "This is how you will be identified on NestNote."
        )
        
        setupContent()
        addCTAButton(title: "Next")
        setupActions()
        setupValidation()
        
        emailTextField.delegate = self
        
        signInWithAppleButton.addTarget(self, action: #selector(signInWithAppleTapped), for: .touchUpInside)
        
        ctaButton?.isEnabled = false
    }
    
    private func setupValidation() {
        (coordinator as? OnboardingCoordinator)?.emailValidation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isValid in
                self?.ctaButton?.isEnabled = isValid
            }
            .store(in: &cancellables)
        
        // Add text change handlers
        emailTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    @objc private func textFieldDidChange() {
        (coordinator as? OnboardingCoordinator)?.validateEmail(
            email: emailTextField.text ?? ""
        )
    }
    
    override func reset() {
        ctaButton?.isEnabled = false
    }
    
    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }
    
    @objc private func nextButtonTapped() {
        (coordinator as? OnboardingCoordinator)?.next()
    }
    
    @objc private func signInWithAppleTapped() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        // Generate and set nonce for security
        let nonce = UserService.shared.generateNonce()
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // MARK: - Setup
    override func setupContent() {
        view.addSubview(signInWithAppleButton)
        view.addSubview(orDividerView)
        view.addSubview(emailTextField)
        
        NSLayoutConstraint.activate([
            emailTextField.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 24),
            emailTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emailTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),
            
            orDividerView.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 24),
            orDividerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            orDividerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            orDividerView.heightAnchor.constraint(equalToConstant: 20),
            
            signInWithAppleButton.topAnchor.constraint(equalTo: orDividerView.bottomAnchor, constant: 32),
            signInWithAppleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            signInWithAppleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            signInWithAppleButton.heightAnchor.constraint(equalToConstant: 55),
        ])
    }
}

// MARK: - UITextFieldDelegate
extension OBEmailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if ((textField.text?.isEmpty) != nil) {
            textField.resignFirstResponder()
            return true
        }
        
        if textField == emailTextField {
            textField.resignFirstResponder()
        }
        
        return true
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension OBEmailViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        // First, sign in with Apple via Firebase so we have a valid auth.currentUser
        Task {
            do {
                _ = try await UserService.shared.signInWithApple(credential: appleIDCredential)

                await MainActor.run {
                    // Update the email field with the Apple email if available
                    if let email = appleIDCredential.email {
                        self.emailTextField.text = email
                    }

                    // Now hand off to the onboarding coordinator to update flow state
                    (self.coordinator as? OnboardingCoordinator)?
                        .handleAppleSignInMidFlow(credential: appleIDCredential)
                }
            } catch {
                await MainActor.run {
                    self.showToast(
                        delay: 0.5,
                        text: "Sign in failed",
                        subtitle: error.localizedDescription,
                        sentiment: .negative
                    )
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        showToast(delay: 0.5, text: "Sign in failed", subtitle: error.localizedDescription, sentiment: .negative)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension OBEmailViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}
