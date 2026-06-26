import UIKit
import Combine

final class OBVenmoViewController: NNOnboardingViewController {
    
    private let venmoTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "username"
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.textContentType = .username
        textField.translatesAutoresizingMaskIntoConstraints = false
        VenmoPaymentHandler.applyUsernamePrefix(to: textField)
        return textField
    }()
    
    private let skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Skip for now", for: .normal)
        button.titleLabel?.font = .bodyL
        button.setTitleColor(.systemGray, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "Add your Venmo username",
            subtitle: "Parents can pay you easily after a session ends."
        )
        
        setupContent()
        addCTAButton(title: "Next")
        setupActions()
        setupValidation()
        
        venmoTextField.delegate = self
        venmoTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        ctaButton?.isEnabled = true
    }
    
    override func reset() {
        venmoTextField.text = ""
        venmoTextField.layer.borderWidth = 0
        ctaButton?.isEnabled = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        venmoTextField.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        venmoTextField.layer.borderWidth = 0
        venmoTextField.layer.cornerRadius = 8
    }
    
    override func setupContent() {
        view.addSubview(venmoTextField)
        view.addSubview(skipButton)
        
        NSLayoutConstraint.activate([
            venmoTextField.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 32),
            venmoTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            venmoTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            venmoTextField.heightAnchor.constraint(equalToConstant: 50),
            
            skipButton.topAnchor.constraint(equalTo: venmoTextField.bottomAnchor, constant: 16),
            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
    }
    
    private func setupValidation() {
        (coordinator as? OnboardingCoordinator)?.venmoUsernameValidation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isValid in
                self?.ctaButton?.isEnabled = isValid
            }
            .store(in: &cancellables)
    }
    
    @objc private func textFieldDidChange() {
        (coordinator as? OnboardingCoordinator)?.validateVenmoUsername(venmoTextField.text ?? "")
    }
    
    @objc private func nextButtonTapped() {
        let raw = venmoTextField.text ?? ""
        let normalized = VenmoPaymentHandler.normalizeUsername(raw)
        (coordinator as? OnboardingCoordinator)?.updateVenmoUsername(normalized)
        (coordinator as? OnboardingCoordinator)?.next()
    }
    
    @objc private func skipButtonTapped() {
        venmoTextField.text = ""
        (coordinator as? OnboardingCoordinator)?.updateVenmoUsername(nil)
        (coordinator as? OnboardingCoordinator)?.next()
    }
}

extension OBVenmoViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if ctaButton?.isEnabled == true {
            nextButtonTapped()
        }
        return true
    }
}
