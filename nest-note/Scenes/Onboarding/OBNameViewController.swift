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
            title: "First, lets get your name",
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

final class OBEmailViewController: NNOnboardingViewController {
    // MARK: - UI Elements
    private let emailTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Email"
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let confirmEmailTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Confirm Email"
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let signInWithAppleButton: ASAuthorizationAppleIDButton = {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.cornerRadius = 8
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
        confirmEmailTextField.delegate = self
        
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
        confirmEmailTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    @objc private func textFieldDidChange() {
        (coordinator as? OnboardingCoordinator)?.validateEmail(
            email: emailTextField.text ?? "",
            confirmEmail: confirmEmailTextField.text ?? ""
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        emailTextField.becomeFirstResponder()
    }
    
    override func reset() {
        confirmEmailTextField.text = ""
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
        view.addSubview(confirmEmailTextField)
        
        NSLayoutConstraint.activate([
            emailTextField.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 24),
            emailTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emailTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),
            
            confirmEmailTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 16),
            confirmEmailTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            confirmEmailTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            confirmEmailTextField.heightAnchor.constraint(equalToConstant: 50),
            
            orDividerView.topAnchor.constraint(equalTo: confirmEmailTextField.bottomAnchor, constant: 24),
            orDividerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            orDividerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            orDividerView.heightAnchor.constraint(equalToConstant: 20),
            
            signInWithAppleButton.topAnchor.constraint(equalTo: orDividerView.bottomAnchor, constant: 32),
            signInWithAppleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            signInWithAppleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            signInWithAppleButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }
}

// MARK: - UITextFieldDelegate
extension OBEmailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailTextField {
            confirmEmailTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension OBEmailViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            (coordinator as? OnboardingCoordinator)?.handleAppleSignInMidFlow(credential: appleIDCredential)
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

final class OBPasswordViewController: NNOnboardingViewController {
    
    // MARK: - UI Elements
    private let passwordTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Password"
        textField.isSecureTextEntry = true
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

final class OBRoleViewController: NNOnboardingViewController {
    
    // MARK: - UI Elements
    private let parentButton: UIButton = {
        let button = UIButton()
        button.setTitle("Parent", for: .normal)
        button.setTitleColor(.systemGray, for: .normal)
        button.titleLabel?.font = .h3
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.tertiarySystemFill.cgColor
        button.backgroundColor = UIColor.tertiarySystemFill
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.semanticContentAttribute = .forceRightToLeft
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        return button
    }()
    
    private let sitterButton: UIButton = {
        let button = UIButton()
        button.setTitle("Sitter", for: .normal)
        button.setTitleColor(.systemGray, for: .normal)
        button.titleLabel?.font = .h3
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.tertiarySystemFill.cgColor
        button.backgroundColor = UIColor.tertiarySystemFill
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.semanticContentAttribute = .forceRightToLeft
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        return button
    }()
    
    private let parentFootnoteLabel: UILabel = {
        let label = UILabel()
        label.text = "Create a Nest with emergency contacts, house rules, routines, & more"
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .footnote)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    private let sitterFootnoteLabel: UILabel = {
        let label = UILabel()
        label.text = "Receive access to important information regarding families you care for"
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .footnote)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "To be or not to be?",
            subtitle: "Are you signing up primarily as a Parent or a Sitter?"
        )
        
        setupContent()
        addCTAButton(title: "Next")
        setupActions()
        setupValidation()
        
        ctaButton?.isEnabled = false
    }
    
    private func setupValidation() {
        (coordinator as? OnboardingCoordinator)?.roleValidation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isValid in
                self?.ctaButton?.isEnabled = isValid
            }
            .store(in: &cancellables)
    }
    
    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        parentButton.addTarget(self, action: #selector(roleButtonTapped(_:)), for: .touchUpInside)
        sitterButton.addTarget(self, action: #selector(roleButtonTapped(_:)), for: .touchUpInside)
    }
    
    @objc private func nextButtonTapped() {
        (coordinator as? OnboardingCoordinator)?.next()
    }
    
    @objc private func roleButtonTapped(_ sender: UIButton) {
        let role: NestUser.UserType = sender == parentButton ? .nestOwner : .sitter
        (coordinator as? OnboardingCoordinator)?.validateRole(role)
        updateSelection(role)
    }
    
    private func updateSelection(_ role: NestUser.UserType) {
        UIView.animate(withDuration: 0.3) {
            // Update parent button
            self.parentButton.backgroundColor = role == .nestOwner ? .systemBlue : .tertiarySystemFill
            self.parentButton.setTitleColor(role == .nestOwner ? .white : .systemGray, for: .normal)
            self.parentButton.setImage(
                role == .nestOwner ? UIImage(systemName: "checkmark")?.withTintColor(.white, renderingMode: .alwaysOriginal) : nil,
                for: .normal
            )
            
            // Update sitter button
            self.sitterButton.backgroundColor = role == .sitter ? .systemBlue : .tertiarySystemFill
            self.sitterButton.setTitleColor(role == .sitter ? .white : .systemGray, for: .normal)
            self.sitterButton.setImage(
                role == .sitter ? UIImage(systemName: "checkmark")?.withTintColor(.white, renderingMode: .alwaysOriginal) : nil,
                for: .normal
            )
        }
    }
    
    // MARK: - Setup
    override func setupContent() {
        view.addSubview(parentButton)
        view.addSubview(sitterButton)
        view.addSubview(parentFootnoteLabel)
        view.addSubview(sitterFootnoteLabel)
        
        NSLayoutConstraint.activate([
            parentButton.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 32),
            parentButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            parentButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            parentButton.heightAnchor.constraint(equalToConstant: 56),
            
            parentFootnoteLabel.topAnchor.constraint(equalTo: parentButton.bottomAnchor, constant: 8),
            parentFootnoteLabel.leadingAnchor.constraint(equalTo: parentButton.leadingAnchor, constant: 8),
            parentFootnoteLabel.trailingAnchor.constraint(equalTo: parentButton.trailingAnchor, constant: -8),
            
            sitterButton.topAnchor.constraint(equalTo: parentFootnoteLabel.bottomAnchor, constant: 24),
            sitterButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            sitterButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            sitterButton.heightAnchor.constraint(equalToConstant: 56),
            
            sitterFootnoteLabel.topAnchor.constraint(equalTo: sitterButton.bottomAnchor, constant: 8),
            sitterFootnoteLabel.leadingAnchor.constraint(equalTo: sitterButton.leadingAnchor, constant: 8),
            sitterFootnoteLabel.trailingAnchor.constraint(equalTo: sitterButton.trailingAnchor, constant: -8)
        ])
    }
}

class OBCreateNestViewController: NNOnboardingViewController {
    private let nestNameField: NNTextField = {
        let field = NNTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "Smith Nest"
        return field
    }()
    
    private let addressField: NNTextField = {
        let field = NNTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "321 Eagle Nest Ct, Birdsville CA"
        return field
    }()
    
    private let addressFootnoteLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Your address is only shared with sitters during sessions."
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .caption1)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "Create your Nest",
            subtitle: "Give your nest a name & an address."
        )
        
        setupContent()
        addCTAButton(title: "Next")
        setupActions()
        setupValidation()
        
        nestNameField.delegate = self
        addressField.delegate = self
        
        ctaButton?.isEnabled = false
    }
    
    private func setupValidation() {
        (coordinator as? OnboardingCoordinator)?.nestValidation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isValid in
                self?.ctaButton?.isEnabled = isValid
            }
            .store(in: &cancellables)
        
        // Add text change handlers
        nestNameField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        addressField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    @objc private func textFieldDidChange() {
        (coordinator as? OnboardingCoordinator)?.validateNest(
            name: nestNameField.text ?? "",
            address: addressField.text ?? ""
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nestNameField.becomeFirstResponder()
    }
    
    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }
    
    @objc private func nextButtonTapped() {
        (coordinator as? OnboardingCoordinator)?.next()
    }
    
    // MARK: - Setup
    override func setupContent() {
        view.addSubview(nestNameField)
        view.addSubview(addressField)
        view.addSubview(addressFootnoteLabel)
        
        NSLayoutConstraint.activate([
            nestNameField.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 32),
            nestNameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            nestNameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            nestNameField.heightAnchor.constraint(equalToConstant: 56),
            
            addressField.topAnchor.constraint(equalTo: nestNameField.bottomAnchor, constant: 16),
            addressField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            addressField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            addressField.heightAnchor.constraint(equalToConstant: 56),
            
            addressFootnoteLabel.topAnchor.constraint(equalTo: addressField.bottomAnchor, constant: 8),
            addressFootnoteLabel.leadingAnchor.constraint(equalTo: addressField.leadingAnchor, constant: 8),
            addressFootnoteLabel.trailingAnchor.constraint(equalTo: addressField.trailingAnchor, constant: -8)
        ])
    }
}

// MARK: - UITextFieldDelegate
extension OBCreateNestViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nestNameField {
            addressField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}

final class OBFinishViewController: NNOnboardingViewController {
    
    private lazy var activityIndicator: NNLoadingSpinner = {
        let indicator = NNLoadingSpinner()
        indicator.configure(with: NNColors.primaryAlt)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private lazy var successImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(systemName: "checkmark")
        imageView.tintColor = .systemGreen
        imageView.isHidden = true
        imageView.alpha = 0
        return imageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "Finishing up...",
            subtitle: "Beep boop, crunching bits"
        )
        
        setupContent()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        beginFinishFlow()
    }
    
    private func beginFinishFlow() {
        Task {
            do {
                // Signal to coordinator we're ready to finish
                try await (coordinator as? OnboardingCoordinator)?.finishSetup()
                
                // If we get here, signup was successful
                activityIndicator.animateState(success: true) {
                    (self.coordinator as? OnboardingCoordinator)?.updateProgressTo(1.0)
                    self.playSuccessTransition()
                }
            } catch {
                // Hide loading state
                activityIndicator.animateState(success: false)
                (coordinator as? OnboardingCoordinator)?.handleErrorNavigation(error)
            }
        }
    }
    
    override func setupContent() {
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 44),
            activityIndicator.heightAnchor.constraint(equalToConstant: 100),
            activityIndicator.widthAnchor.constraint(equalToConstant: 100),
        ])

        view.addSubview(successImageView)
        
        NSLayoutConstraint.activate([
            successImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            successImageView.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 44),
            successImageView.heightAnchor.constraint(equalToConstant: 100),
            successImageView.widthAnchor.constraint(equalToConstant: 100),
        ])
    }
    
    private func playSuccessTransition() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            (self.coordinator as? OnboardingCoordinator)?.completeOnboarding()
        }
    }
}




