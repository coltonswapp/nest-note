//
//  SessionManager.swift
//  NestNote
//
//  Created by Colton Swapp on 1/15/25.
//

import UIKit

final class SessionManager {
    
    // MARK: - Properties
    
    static let shared = SessionManager()
    private(set) var isSessionBarVisible = false
    private let sessionBarHeight: CGFloat = 62
    private let bottomInset: CGFloat = 74 // sessionBarHeight + some padding
    
    private weak var homeViewController: HomeViewController?
    
    // MARK: - UI Elements
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.font = .h4
        label.text = "Finch Family Session"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.textColor = .secondaryLabel
        label.font = .h5
        label.text = "Dec. 4-6"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let birdImageView: UIImageView = {    
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "bird")
        imageView.tintColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let labelStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var sessionBar: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add shadow
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.3
        
        // Important: This helps with shadow performance
        view.layer.shouldRasterize = true
        view.layer.rasterizationScale = UIScreen.main.scale
        
        view.backgroundColor = .systemGray6
        
        // Add subviews
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(durationLabel)
        view.addSubview(labelStack)
        view.addSubview(birdImageView)
        
        return view
    }()
    
    private var sessionBarBottomConstraint: NSLayoutConstraint?
    
    private var visualEffectView: UIVisualEffectView?
    private let blurRadius: Double = 16
    private let blurMaskImage = UIImage(named: "testBG3")
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    func setHomeViewController(_ viewController: HomeViewController) {
        self.homeViewController = viewController
    }
    
    func showSessionBar(animated: Bool = true) {
        guard let homeVC = homeViewController else { return }
        
        // Add delay for debugging
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !self.isSessionBarVisible {
                self.setupSessionBar(in: homeVC.view)
            }
            
            self.isSessionBarVisible = true
            self.sessionBarBottomConstraint?.constant = 0
            
            // Post notification
            NotificationCenter.default.post(name: NSNotification.Name("SessionBarVisibilityChanged"), object: nil)
            
            if animated {
                UIView.animate(
                    withDuration: 0.5,
                    delay: 0,
                    usingSpringWithDamping: 0.8,
                    initialSpringVelocity: 0.5,
                    options: .curveEaseInOut
                ) {
                    homeVC.view.layoutIfNeeded()
                }
            } else {
                homeVC.view.layoutIfNeeded()
            }
        }
    }
    
    func hideSessionBar(animated: Bool = true) {
        guard isSessionBarVisible, let homeVC = homeViewController else { return }
        
        isSessionBarVisible = false
        sessionBarBottomConstraint?.constant = sessionBarHeight + 100
        
        NotificationCenter.default.post(name: NSNotification.Name("SessionBarVisibilityChanged"), object: nil)
        
        if animated {
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: .curveEaseInOut
            ) {
                homeVC.view.layoutIfNeeded()
            } completion: { _ in
                self.sessionBar.removeFromSuperview()
                self.visualEffectView?.removeFromSuperview()
            }
        } else {
            homeVC.view.layoutIfNeeded()
            sessionBar.removeFromSuperview()
            visualEffectView?.removeFromSuperview()
        }
    }
    
    func getRequiredBottomInset() -> CGFloat {
        return isSessionBarVisible ? bottomInset : 0
    }
    
    // MARK: - Private Methods
    private func setupSessionBar(in view: UIView) {
        sessionBar.removeFromSuperview()
        
        // First add the session bar to the view hierarchy
        view.addSubview(sessionBar)
        
        let bottomConstraint = sessionBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        sessionBarBottomConstraint = bottomConstraint
        
        NSLayoutConstraint.activate([
            // Session bar constraints
            sessionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            sessionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            sessionBar.heightAnchor.constraint(equalToConstant: sessionBarHeight),
            bottomConstraint,
            
            // Label stack constraints
            labelStack.leadingAnchor.constraint(equalTo: sessionBar.leadingAnchor, constant: 20),
            labelStack.centerYAnchor.constraint(equalTo: sessionBar.centerYAnchor),
            
            // Bird image constraints
            birdImageView.trailingAnchor.constraint(equalTo: sessionBar.trailingAnchor, constant: -20),
            birdImageView.centerYAnchor.constraint(equalTo: sessionBar.centerYAnchor),
            birdImageView.widthAnchor.constraint(equalToConstant: 30),
            birdImageView.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        if !isSessionBarVisible {
            bottomConstraint.constant = sessionBarHeight + 100
            view.layoutIfNeeded()
        }
    }
    
    private func addBlurredEffect(in view: UIView) {
        visualEffectView?.removeFromSuperview()
        
        // Create and setup blur effect view
        visualEffectView = UIVisualEffectView()
        guard let visualEffectView = visualEffectView else { return }
        
        if let maskImage = blurMaskImage {
            visualEffectView.effect = UIBlurEffect.variableBlurEffect(radius: blurRadius, maskImage: maskImage)
        } else {
            visualEffectView.effect = UIBlurEffect(style: .regular)
        }
        
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(visualEffectView, belowSubview: sessionBar)
        
        NSLayoutConstraint.activate([
            // Blur view constraints
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            visualEffectView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                                constant: -(sessionBarHeight + 50))
            ])
    }
}
