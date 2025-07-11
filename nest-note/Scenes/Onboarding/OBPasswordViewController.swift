import UIKit

final class OBPasswordViewController: NNOnboardingViewController {
    
    // MARK: - UI Elements
    private let passwordTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Password"
        textField.isSecureTextEntry = true
        textField.isPasswordTextField = true
        textField.returnKeyType = .next
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.smartQuotesType = .no
        textField.smartDashesType = .no
        textField.smartInsertDeleteType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let confirmPasswordTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Confirm Password"
        textField.isSecureTextEntry = true
        textField.isPasswordTextField = true
        textField.returnKeyType = .done
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.smartQuotesType = .no
        textField.smartDashesType = .no
        textField.smartInsertDeleteType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let requirementsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var lengthRequirement = createRequirementView(text: "Minimum 6 characters")
    private lazy var capitalRequirement = createRequirementView(text: "1 capital letter")
    private lazy var numberRequirement = createRequirementView(text: "1 number")
    private lazy var symbolRequirement = createRequirementView(text: "1 symbol")
    private lazy var passwordMatchRequirement = createRequirementView(text: "Passwords match")
    
    private func createRequirementView(text: String) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "circle")
        imageView.tintColor = .systemGray3
        imageView.contentMode = .scaleAspectFit
        imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        let label = UILabel()
        label.text = text
        label.textColor = .systemGray
        label.font = .bodyM
        
        stack.addArrangedSubview(imageView)
        stack.addArrangedSubview(label)
        
        return stack
    }

    override func loadView() {
        super.loadView()
        shouldHandleKeyboard = false
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "Create a password"
        )
        
        setupContent()
        addCTAButton(title: "Next")
        setupActions()
        setupValidation()
        
        ctaButton?.isEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        passwordTextField.becomeFirstResponder()
        passwordTextField.delegate = self
        confirmPasswordTextField.delegate = self
    }
    
    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }
    
    @objc private func nextButtonTapped() {
        (coordinator as? OnboardingCoordinator)?.next()
    }
    
    // MARK: - Setup
    override func setupContent() {
        view.addSubview(passwordTextField)
        view.addSubview(confirmPasswordTextField)
        view.addSubview(requirementsStack)
        
        // Add requirement views to stack
        requirementsStack.addArrangedSubview(lengthRequirement)
        requirementsStack.addArrangedSubview(capitalRequirement)
        requirementsStack.addArrangedSubview(numberRequirement)
        requirementsStack.addArrangedSubview(symbolRequirement)
        requirementsStack.addArrangedSubview(passwordMatchRequirement)
        
        NSLayoutConstraint.activate([
            passwordTextField.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 32),
            passwordTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            passwordTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            passwordTextField.heightAnchor.constraint(equalToConstant: 50),
            
            confirmPasswordTextField.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 16),
            confirmPasswordTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            confirmPasswordTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            confirmPasswordTextField.heightAnchor.constraint(equalToConstant: 50),
            
            requirementsStack.topAnchor.constraint(equalTo: confirmPasswordTextField.bottomAnchor, constant: 24),
            requirementsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            requirementsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    private func setupValidation() {
        (coordinator as? OnboardingCoordinator)?.passwordValidation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] validation in
                self?.ctaButton?.isEnabled = validation.isValid
                self?.updateRequirement(self?.lengthRequirement, isValid: validation.hasMinLength)
                self?.updateRequirement(self?.capitalRequirement, isValid: validation.hasCapital)
                self?.updateRequirement(self?.numberRequirement, isValid: validation.hasNumber)
                self?.updateRequirement(self?.symbolRequirement, isValid: validation.hasSymbol)
                self?.updateRequirement(self?.passwordMatchRequirement, isValid: validation.passwordsMatch)
            }
            .store(in: &cancellables)
        
        // Add text change handlers
        passwordTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        confirmPasswordTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    @objc private func textFieldDidChange() {
        (coordinator as? OnboardingCoordinator)?.validatePassword(
            password: passwordTextField.text ?? "",
            confirmPassword: confirmPasswordTextField.text ?? ""
        )
    }
    
    private func updateRequirement(_ requirementView: UIStackView?, isValid: Bool) {
        guard let requirementView = requirementView else { return }
        
        UIView.animate(withDuration: 0.2) {
            if let imageView = requirementView.arrangedSubviews.first as? UIImageView,
               let label = requirementView.arrangedSubviews.last as? UILabel {
                imageView.image = UIImage(systemName: isValid ? "checkmark.circle.fill" : "circle")
                imageView.tintColor = isValid ? .systemGreen : .systemGray3
                label.textColor = isValid ? .systemGreen : .systemGray
            }
        }
    }
}

extension OBPasswordViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
//        validateInput()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == passwordTextField {
            confirmPasswordTextField.becomeFirstResponder()
        } else if textField == confirmPasswordTextField {
            textField.resignFirstResponder()
        }
        return true
    }
}

