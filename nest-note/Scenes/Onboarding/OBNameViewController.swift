import UIKit
import Combine
import AuthenticationServices
import CryptoKit

final class OBNameViewController: NNOnboardingViewController {
    
    // MARK: - UI Elements
    private let nameTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Full Name"
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "Lets get your name",
            subtitle: "Don't worry, this is for display purposes only."
        )
        
        setupContent()
        addCTAButton(title: "Next")
        setupActions()
        
        // Disable button initially
        ctaButton?.isEnabled = false
        
        // Add text field delegate
        nameTextField.delegate = self
        nameTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        setupValidation()
    }
    
    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }
    
    @objc private func nextButtonTapped() {
        guard let name = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        (coordinator as? OnboardingCoordinator)?.updateUserName(name)
        (coordinator as? OnboardingCoordinator)?.next()
    }
    
    // MARK: - Setup
    override func setupContent() {
        view.addSubview(nameTextField)
        
        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 32),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            nameTextField.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Validation
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameTextField.becomeFirstResponder()
    }
    
    private func setupValidation() {
        (coordinator as? OnboardingCoordinator)?.nameValidation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isValid in
                self?.ctaButton?.isEnabled = isValid
            }
            .store(in: &cancellables)
        
        nameTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    @objc private func textFieldDidChange() {
        (coordinator as? OnboardingCoordinator)?.validateName(nameTextField.text ?? "")
    }
}

// MARK: - UITextFieldDelegate
extension OBNameViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        (coordinator as? OnboardingCoordinator)?.validateName(nameTextField.text ?? "")
    }
}
