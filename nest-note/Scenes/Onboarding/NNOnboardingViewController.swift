//
// NNOnboardingViewController.swift
// nest-note
//
// Created by Colton Swapp on 11/3/24.
//

import UIKit
import Combine

class NNOnboardingViewController: UIViewController {
    
    // MARK: - UI Elements
    let labelStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    var ctaButton: NNBaseControl?
    var buttonBottomConstraint: NSLayoutConstraint?
    
    var coordinator: NSObject?
    var cancellables = Set<AnyCancellable>()
    
    var shouldHandleKeyboard: Bool = true
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupBaseUI()
        setupKeyboardObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup Methods
    private func setupBaseUI() {
        view.addSubview(labelStack)
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            labelStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            labelStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            labelStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36)
        ])
    }
    
    /// Configure the basic elements of the onboarding screen
    func setupOnboarding(title: String, subtitle: String? = nil) {
        titleLabel.text = title
        if let subtitle {
            subtitleLabel.text = subtitle   
        } else {
            subtitleLabel.isHidden = true
        }
    }
    
    /// Override this method in subclasses to add custom content
    func setupContent() {
        // To be overridden by subclasses
    }
    
    // MARK: - CTA Button
    func addCTAButton(title: String, image: UIImage? = nil) {
        let button = NNPrimaryLabeledButton(title: title, image: image)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        
        buttonBottomConstraint = button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            button.heightAnchor.constraint(equalToConstant: 56),
            buttonBottomConstraint!
        ])
        
        self.ctaButton = button
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardObservers() {
        guard shouldHandleKeyboard else { return }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        
        UIView.animate(withDuration: duration) {
            self.buttonBottomConstraint?.constant = -keyboardHeight
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        UIView.animate(withDuration: duration) {
            self.buttonBottomConstraint?.constant = -12
            self.view.layoutIfNeeded()
        }
    }

    func reset() {
        
    }
} 
