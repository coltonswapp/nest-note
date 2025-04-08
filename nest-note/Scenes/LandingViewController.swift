//
//  LandingViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 11/2/24.
//

import UIKit

protocol AuthenticationDelegate: AnyObject {
    func authenticationComplete()
    func signUpTapped()
    func signUpComplete()
}

final class LandingViewController: NNViewController {
    
    // MARK: - UI Elements
    private let topImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .halfMoonTop)
        return view
    }()
    
    private let mainStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 40
        return stack
    }()
    
    private let titleStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()
    
    private let titleImage: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "bird.fill")
        imageView.tintColor = .label
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome to NestNote"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "All Your Caregiving Needs, One Secure App"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var loginStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        return stack
    }()
    
    private lazy var emailField: NNTextField = {
        let field = NNTextField()
        field.placeholder = "Email"
        field.returnKeyType = .next
        field.keyboardType = .emailAddress
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.delegate = self
        return field
    }()
    
    private lazy var passwordField: NNTextField = {
        let field = NNTextField()
        field.borderStyle = .none
        field.placeholder = "Password"
        field.isSecureTextEntry = true
        field.returnKeyType = .default
        field.delegate = self
        return field
    }()
    
    private lazy var loginButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Login", titleColor: .white, fillStyle: .fill(NNColors.primary), transitionStyle: .rightHide)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var signUpButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Don't have an account? Sign Up", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        return button
    }()
    
    // Keep delegate and keyboard constraint
    weak var delegate: AuthenticationDelegate?
    private var loginButtonBottomConstraint: NSLayoutConstraint?
    private var mainStackTopConstraint: NSLayoutConstraint?
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardObservers()
        #if DEBUG
        setupDebugMode()
        #endif
    }
    
    override func addSubviews() {
        view.addSubview(topImageView)
        
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(subtitleLabel)
        
        loginStack.addArrangedSubview(emailField)
        loginStack.addArrangedSubview(passwordField)
        
        mainStack.addArrangedSubview(titleStack)
        mainStack.addArrangedSubview(loginStack)
        view.addSubview(mainStack)
        
        view.addSubview(loginButton)
        view.addSubview(signUpButton)
    }
    
    override func constrainSubviews() {
        topImageView.pinToTop(of: view)
        
        mainStackTopConstraint = mainStack.topAnchor.constraint(equalTo: topImageView.bottomAnchor, constant: 0)
        mainStackTopConstraint?.isActive = true
        
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            emailField.heightAnchor.constraint(equalToConstant: 55),
            passwordField.heightAnchor.constraint(equalToConstant: 55),
        ])
        
        loginButtonBottomConstraint = loginButton.bottomAnchor.constraint(equalTo: signUpButton.topAnchor, constant: -16)
        
        NSLayoutConstraint.activate([
            loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            loginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            loginButton.heightAnchor.constraint(equalToConstant: 55),
            loginButtonBottomConstraint!,
            
            signUpButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            signUpButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    @objc private func signUpTapped() {
        self.dismiss(animated: true) {
            self.delegate?.signUpTapped()
        }
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
            self.mainStackTopConstraint?.constant = -keyboardHeight * 0.25
            self.topImageView.alpha = 0.2
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        UIView.animate(withDuration: duration) {
            self.loginButtonBottomConstraint?.constant = -16
            self.mainStackTopConstraint?.constant = -12
            self.topImageView.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Actions
    @objc private func loginTapped() {
        Task {
            do {
                guard let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let password = passwordField.text,
                      !email.isEmpty, !password.isEmpty else {
                    throw AuthError.invalidCredentials
                }
                
                loginButton.startLoading()
                passwordField.resignFirstResponder()
                
                // Just authenticate with Firebase
                _ = try await UserService.shared.login(email: email, password: password)
                // Let Launcher handle the rest
                try await Launcher.shared.configure()
                
                // Set onboarding completion flag for existing users
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                
                await MainActor.run {
                    loginButton.stopLoading(withSuccess: true)
                    Logger.log(level: .info, category: .general, message: "Successfully signed in")
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Debug Mode
    private var debugTapCount = 0
    private let debugTapThreshold = 3
    private var debugTimer: Timer?
    
    private func setupDebugMode() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDebugTap))
        titleImage.isUserInteractionEnabled = true
        titleImage.addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleDebugTap() {
        debugTapCount += 1
        debugTimer?.invalidate()
        
        if debugTapCount >= debugTapThreshold {
            debugTapCount = 0
            presentDebugOptions()
        } else {
            debugTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                self?.debugTapCount = 0
            }
        }
    }
    
    private func presentDebugOptions() {
        let alert = UIAlertController(title: "Debug Mode", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Default Account", style: .default) { [weak self] _ in
            self?.emailField.text = "coltonbswapp@gmail.com"
            self?.passwordField.text = "Test123!"
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension LandingViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case emailField:
            passwordField.becomeFirstResponder()
        case passwordField:
            textField.resignFirstResponder()
            guard ((textField.text?.isEmpty) != nil) else { return false }
            loginTapped()
            return true
        default:
            textField.resignFirstResponder()
        }
        return true
    }
}

import UIKit

class NNTextField: UITextField {
    
    // MARK: - Properties
    
    /// The inset or padding for the text rectangle
    var textInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTextField()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupTextField()
    }
    
    /// Initializes a text field with an optional clear button
    /// - Parameters:
    ///   - frame: The frame of the text field
    ///   - showClearButton: Whether to show a clear button on the right side
    convenience init(frame: CGRect = .zero, showClearButton: Bool = false) {
        self.init(frame: frame)
        if showClearButton {
            textInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 24)
            clearButtonMode = .always // Disable the default clear button
        }
    }
    
    // MARK: - Setup
    
    private func setupTextField() {
        // Default setup code if needed
        backgroundColor = NNColors.NNSystemBackground6
        layer.cornerRadius = 18
    }
    
    // MARK: - Text Rectangle Overrides
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textInsets)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textInsets)
    }
    
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textInsets)
    }
    
    // MARK: - Actions
    
    @objc private func clearButtonTapped() {
        text = ""
        HapticsHelper.lightHaptic()
    }
    
    // MARK: - Convenience Methods
    
    /// Sets the padding (insets) for all edges at once
    func setPadding(_ padding: CGFloat) {
        textInsets = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
    }
    
    /// Sets horizontal padding (left and right)
    func setHorizontalPadding(_ padding: CGFloat) {
        textInsets.left = padding
        textInsets.right = padding
        setNeedsDisplay()
    }
    
    /// Sets vertical padding (top and bottom)
    func setVerticalPadding(_ padding: CGFloat) {
        textInsets.top = padding
        textInsets.bottom = padding
        setNeedsDisplay()
    }
}

