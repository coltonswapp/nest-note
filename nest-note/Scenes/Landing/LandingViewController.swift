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
    lazy var introHost: UIHostingController = UIHostingController(rootView: IntroPage(onGetStarted: { self.getStartedTapped() } ))
    
    // Keep delegate and keyboard constraint
    weak var delegate: AuthenticationDelegate?
    private var mainStackTopConstraint: NSLayoutConstraint?
    
    override func loadView() {
        super.loadView()
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
        let loginVC = LoginViewController()
        loginVC.delegate = self.delegate
        self.navigationController?.pushViewController(loginVC, animated: true)
    }
}
