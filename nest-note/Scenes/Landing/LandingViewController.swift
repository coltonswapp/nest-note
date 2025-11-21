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
        // Handle Apple Sign In
        // You can implement Apple Sign In logic here
        print("Apple Sign In tapped")
    }

    @objc private func loginTapped() {
        let loginVC = LoginViewController()
        loginVC.delegate = self.delegate
        self.navigationController?.pushViewController(loginVC, animated: true)
    }

    @objc private func signUpTapped() {
        // Navigate to sign up flow
        // You can implement sign up navigation here
        print("Sign Up tapped")
    }
}
