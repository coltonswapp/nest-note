import UIKit
import AuthenticationServices
import CryptoKit

protocol AuthenticationDelegate: AnyObject {
    func authenticationComplete()
    func signUpTapped()
    func signUpComplete()
}

final class LoginViewController: NNViewController {
    // MARK: - UI Elements
    private let topImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .rectanglePatternSmall, with: NNColors.primary)
        view.alpha = 0.4
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome to NestNote"
        label.font = .h1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Sign in to continue managing your nest."
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var emailField: NNTextField = {
        let field = NNTextField()
        field.placeholder = "Email"
        field.returnKeyType = .next
        field.keyboardType = .emailAddress
        field.textContentType = .username
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.delegate = self
        field.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        return field
    }()
    
    private lazy var passwordField: NNTextField = {
        let field = NNTextField()
        field.borderStyle = .none
        field.placeholder = "Password"
        field.isSecureTextEntry = true
        field.isPasswordTextField = true
        field.returnKeyType = .default
        field.textContentType = .password
        field.delegate = self
        field.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        return field
    }()
    
    private lazy var loginButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Login", titleColor: .white, fillStyle: .fill(NNColors.primary), transitionStyle: .rightHide)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var orDividerView: UIView = {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let leftLine = UIView()
        leftLine.backgroundColor = .systemGray4
        leftLine.translatesAutoresizingMaskIntoConstraints = false
        
        let rightLine = UIView()
        rightLine.backgroundColor = .systemGray4
        rightLine.translatesAutoresizingMaskIntoConstraints = false
        
        let orLabel = UILabel()
        orLabel.text = "or"
        orLabel.font = .bodyS
        orLabel.textColor = .secondaryLabel
        orLabel.textAlignment = .center
        orLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(leftLine)
        containerView.addSubview(rightLine)
        containerView.addSubview(orLabel)
        
        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 24),
            
            orLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            orLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            orLabel.widthAnchor.constraint(equalToConstant: 24),
            
            leftLine.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            leftLine.trailingAnchor.constraint(equalTo: orLabel.leadingAnchor, constant: -8),
            leftLine.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            leftLine.heightAnchor.constraint(equalToConstant: 1),
            
            rightLine.leadingAnchor.constraint(equalTo: orLabel.trailingAnchor, constant: 8),
            rightLine.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            rightLine.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            rightLine.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        return containerView
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
    
    private lazy var forgotPasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Forgot Password?", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(NNColors.primary, for: .normal)
        button.titleLabel?.font = .bodyS
        button.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var signUpButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Don't have an account? Sign Up", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(NNColors.primary, for: .normal)
        button.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var bottomStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [forgotPasswordButton, signUpButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    weak var delegate: AuthenticationDelegate?
    private var loginButtonBottomConstraint: NSLayoutConstraint?
    private var mainStackTopConstraint: NSLayoutConstraint?
    
    private let loginStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        return stack
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupKeyboardObservers()
        setupNavBar()
        updateLoginButtonState()
    }
    
    override func addSubviews() {
        loginStack.addArrangedSubview(emailField)
        loginStack.addArrangedSubview(passwordField)
        loginStack.addArrangedSubview(orDividerView)
        loginStack.addArrangedSubview(signInWithAppleButton)
        view.addSubview(topImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(loginStack)
        view.addSubview(loginButton)
        view.addSubview(bottomStack)
    }
    
    override func constrainSubviews() {
        topImageView.pinToTop(of: view)
        
        loginButtonBottomConstraint = loginButton.bottomAnchor.constraint(equalTo: bottomStack.topAnchor, constant: -16)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            
            loginStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            loginStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            loginStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            emailField.heightAnchor.constraint(equalToConstant: 55),
            emailField.widthAnchor.constraint(equalTo: loginStack.widthAnchor),
            passwordField.heightAnchor.constraint(equalToConstant: 55),
            passwordField.widthAnchor.constraint(equalTo: loginStack.widthAnchor),
            orDividerView.widthAnchor.constraint(equalTo: loginStack.widthAnchor),
            signInWithAppleButton.heightAnchor.constraint(equalToConstant: 55),
            signInWithAppleButton.widthAnchor.constraint(equalTo: loginStack.widthAnchor),
            
            loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            loginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            loginButton.heightAnchor.constraint(equalToConstant: 55),
            loginButtonBottomConstraint!,
            
            bottomStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            bottomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupNavBar() {
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func textFieldDidChange() {
        updateLoginButtonState()
    }
    
    private func updateLoginButtonState() {
        let emailHasText = !(emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let passwordHasText = !(passwordField.text?.isEmpty ?? true)
        loginButton.isEnabled = emailHasText && passwordHasText
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardObservers() {
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
            self.loginButtonBottomConstraint?.constant = -keyboardHeight + 64
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        UIView.animate(withDuration: duration) {
            self.loginButtonBottomConstraint?.constant = -16
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Actions
    @objc private func loginTapped() {
        handleRegularLogin()
    }
    
    @objc private func signInWithAppleTapped() {
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
    
    @objc private func signUpTapped() {
        self.dismiss(animated: true) {
            self.delegate?.signUpTapped()
        }
    }
    
    @objc private func forgotPasswordTapped() {
        showForgotPasswordAlert()
    }
    
    private func showForgotPasswordAlert() {
        let alert = UIAlertController(
            title: "Reset Password",
            message: "Enter your email address and we'll send you a link to reset your password.",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Email"
            textField.keyboardType = .emailAddress
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
            textField.text = self.emailField.text // Pre-fill with current email if available
        }
        
        let sendAction = UIAlertAction(title: "Send Reset Link", style: .default) { _ in
            guard let email = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !email.isEmpty else {
                self.showErrorAlert(message: "Please enter a valid email address.")
                return
            }
            
            self.sendPasswordResetEmail(to: email)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(sendAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func sendPasswordResetEmail(to email: String) {
        Task {
            do {
                try await UserService.shared.sendPasswordReset(to: email)
                await MainActor.run {
                    self.showSuccessAlert(message: "Password reset email sent! Please check your inbox and follow the instructions to reset your password.")
                }
            } catch {
                await MainActor.run {
                    self.showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showSuccessAlert(message: String) {
        let alert = UIAlertController(
            title: "Success",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
    
    private func handleRegularLogin() {
        Task {
            do {
                guard let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let password = passwordField.text,
                      !email.isEmpty, !password.isEmpty else {
                    throw AuthError.invalidCredentials
                }
                loginButton.startLoading()
                passwordField.resignFirstResponder()
                _ = try await UserService.shared.login(email: email, password: password)
                try await Launcher.shared.configure()
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                await MainActor.run {
                    loginButton.stopLoading(withSuccess: true)
                    Logger.log(level: .info, category: .general, message: "Successfully signed in")
                    
                    // Prompt to save password to iCloud Keychain
                    self.promptToSavePassword(email: email, password: password)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.delegate?.authenticationComplete()
                        self.dismiss(animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.loginButton.stopLoading(withSuccess: false)
                        let alert = UIAlertController(
                            title: "Authentication Failed",
                            message: error.localizedDescription,
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    private func promptToSavePassword(email: String, password: String) {
        // Check if password is already saved to avoid duplicate prompts
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: "nestnote.app",
            kSecAttrAccount as String: email,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        // If password is not already saved, prompt to save it
        if status == errSecItemNotFound {
            let savePasswordQuery: [String: Any] = [
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrServer as String: "nestnote.app",
                kSecAttrAccount as String: email,
                kSecValueData as String: password.data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            let saveStatus = SecItemAdd(savePasswordQuery as CFDictionary, nil)
            if saveStatus == errSecSuccess {
                Logger.log(level: .info, category: .general, message: "Password saved to iCloud Keychain")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITextFieldDelegate
extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        let text: String = textField.text ?? ""
        
        switch textField {
        case emailField:
            if text.isEmpty {
                textField.resignFirstResponder()
                return true
            }
            passwordField.becomeFirstResponder()
        case passwordField:
            if text.isEmpty {
                textField.resignFirstResponder()
                return true
            }
            textField.resignFirstResponder()
            loginTapped()
            return true
        default:
            textField.resignFirstResponder()
        }
        return true
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension LoginViewController: ASAuthorizationControllerDelegate {
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
                        let alert = UIAlertController(
                            title: "Sign In Failed",
                            message: error.localizedDescription,
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let alert = UIAlertController(
            title: "Sign In Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func startAppleOnboardingFlow(credential: ASAuthorizationAppleIDCredential) {
        self.dismiss(animated: true) {
            if let delegate = self.delegate as? LaunchCoordinator {
                delegate.startAppleSignInOnboarding(with: credential)
            } else {
                self.delegate?.signUpTapped()
            }
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
                self.dismiss(animated: true)
            }
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}

// MARK: - NNTextField
class NNTextField: UITextField {
    var textInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12) {
        didSet { setNeedsDisplay() }
    }
    
    var isPasswordTextField: Bool = false {
        didSet {
            if isPasswordTextField {
                setupPasswordToggle()
            } else {
                rightView = nil
                rightViewMode = .never
            }
        }
    }
    
    private lazy var passwordToggleButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "eye.slash"), for: .normal)
        button.setImage(UIImage(systemName: "eye"), for: .selected)
        button.tintColor = .systemGray2
        button.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTextField()
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupTextField()
    }
    convenience init(frame: CGRect = .zero, showClearButton: Bool = false) {
        self.init(frame: frame)
        if showClearButton {
            textInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 24)
            clearButtonMode = .always
        }
    }
    private func setupTextField() {
        backgroundColor = NNColors.NNSystemBackground6
        layer.cornerRadius = 18
    }
    
    private func setupPasswordToggle() {
        rightView = passwordToggleButton
        rightViewMode = .always
        textInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 52)
    }
    
    override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        let rightViewRect = super.rightViewRect(forBounds: bounds)
        return CGRect(
            x: rightViewRect.origin.x - 12,
            y: rightViewRect.origin.y,
            width: rightViewRect.width,
            height: rightViewRect.height
        )
    }
    
    @objc private func togglePasswordVisibility() {
        isSecureTextEntry.toggle()
        passwordToggleButton.isSelected = !isSecureTextEntry
        HapticsHelper.lightHaptic()
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textInsets)
    }
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textInsets)
    }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textInsets)
    }
    @objc private func clearButtonTapped() {
        text = ""
        HapticsHelper.lightHaptic()
    }
    func setPadding(_ padding: CGFloat) {
        textInsets = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
    }
    func setHorizontalPadding(_ padding: CGFloat) {
        textInsets.left = padding
        textInsets.right = padding
        setNeedsDisplay()
    }
    func setVerticalPadding(_ padding: CGFloat) {
        textInsets.top = padding
        textInsets.bottom = padding
        setNeedsDisplay()
    }
} 
