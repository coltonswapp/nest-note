//
//  OBReferralViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 9/9/25.
//

import UIKit
import Combine

final class OBReferralViewController: NNOnboardingViewController {
    
    // MARK: - UI Elements
    private let referralTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Referral Code (Optional)"
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Skip", for: .normal)
        button.titleLabel?.font = .bodyL
        button.setTitleColor(.systemGray, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var isReferralCodeValid = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "Got a referral code?",
            subtitle: "Support a creator by entering their code."
        )
        
        setupContent()
        addCTAButton(title: "Next")
        setupActions()
        setupValidation()
        
        referralTextField.delegate = self
        
        // Start with enabled CTA button since referral is optional
        ctaButton?.isEnabled = true
    }
    
    override func setupContent() {
        view.addSubview(referralTextField)
        view.addSubview(skipButton)
        
        NSLayoutConstraint.activate([
            referralTextField.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 32),
            referralTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            referralTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            referralTextField.heightAnchor.constraint(equalToConstant: 50),
            
            skipButton.topAnchor.constraint(equalTo: referralTextField.bottomAnchor, constant: 16),
            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
    }
    
    private func setupValidation() {
        referralTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    @objc private func textFieldDidChange() {
        let referralCode = referralTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if referralCode.isEmpty {
            // Empty is valid (optional field)
            isReferralCodeValid = true
            ctaButton?.isEnabled = true
            referralTextField.layer.borderWidth = 0
        } else {
            // Validate the referral code format only (for immediate UI feedback)
            isReferralCodeValid = ReferralService.shared.validateReferralCodeFormat(referralCode) != nil
            ctaButton?.isEnabled = isReferralCodeValid
            
            // Update UI feedback
            if isReferralCodeValid {
                referralTextField.layer.borderColor = UIColor.systemGreen.cgColor
                referralTextField.layer.borderWidth = 1.0
            } else {
                referralTextField.layer.borderColor = UIColor.systemRed.cgColor
                referralTextField.layer.borderWidth = 1.0
            }
        }
    }
    
    @objc private func nextButtonTapped() {
        let referralCode = referralTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update coordinator with referral code (can be nil/empty)
        (coordinator as? OnboardingCoordinator)?.updateReferralCode(referralCode)
        
        // Continue to next step
        (coordinator as? OnboardingCoordinator)?.next()
    }
    
    @objc private func skipButtonTapped() {
        // Clear any referral code and continue
        referralTextField.text = ""
        (coordinator as? OnboardingCoordinator)?.updateReferralCode(nil)
        (coordinator as? OnboardingCoordinator)?.next()
    }
    
    override func reset() {
        referralTextField.text = ""
        referralTextField.layer.borderWidth = 0
        isReferralCodeValid = false
        ctaButton?.isEnabled = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        referralTextField.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Reset border styling when view appears
        referralTextField.layer.borderWidth = 0
        referralTextField.layer.cornerRadius = 8
    }
}

// MARK: - UITextFieldDelegate
extension OBReferralViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Allow only alphanumeric characters and some special characters for referral codes
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let characterSet = CharacterSet(charactersIn: string)
        
        return allowedCharacters.isSuperset(of: characterSet)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        nextButtonTapped()
        return true
    }
}
