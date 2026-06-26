import UIKit

final class OBPhoneViewController: NNOnboardingViewController {

    private let phoneTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Phone Number"
        textField.keyboardType = .phonePad
        textField.textContentType = .telephoneNumber
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        let role = (coordinator as? OnboardingCoordinator)?.currentRole ?? .nestOwner
        let subtitle: String
        switch role {
        case .nestOwner:
            subtitle = "So sitters and your family can reach you when it matters."
        case .sitter:
            subtitle = "So families you sit for can reach you."
        }

        setupOnboarding(
            title: "What's your phone number?",
            subtitle: subtitle
        )

        setupContent()
        addCTAButton(title: "Next")
        setupActions()
        setupValidation()

        phoneTextField.delegate = self
        phoneTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        ctaButton?.isEnabled = false
    }

    override func reset() {
        ctaButton?.isEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        phoneTextField.becomeFirstResponder()
    }

    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }

    @objc private func nextButtonTapped() {
        guard let digits = normalizedDigits(from: phoneTextField.text ?? ""),
              (9...10).contains(digits.count) else { return }
        (coordinator as? OnboardingCoordinator)?.updatePhone(digits)
        (coordinator as? OnboardingCoordinator)?.next()
    }

    override func setupContent() {
        view.addSubview(phoneTextField)

        NSLayoutConstraint.activate([
            phoneTextField.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 32),
            phoneTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            phoneTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            phoneTextField.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func setupValidation() {
        (coordinator as? OnboardingCoordinator)?.phoneValidation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isValid in
                self?.ctaButton?.isEnabled = isValid
            }
            .store(in: &cancellables)
    }

    @objc private func textFieldDidChange() {
        let digits = normalizedDigits(from: phoneTextField.text ?? "") ?? ""
        let formatted = Self.formattedDisplay(for: digits)
        if phoneTextField.text != formatted {
            phoneTextField.text = formatted
        }
        (coordinator as? OnboardingCoordinator)?.validatePhone(formatted)
    }

    private func normalizedDigits(from input: String) -> String? {
        let digits = PhoneNumberFormatter.digits(from: input)
        guard !digits.isEmpty else { return nil }
        return digits
    }

    private static func formattedDisplay(for digits: String) -> String {
        PhoneNumberFormatter.formattedDisplay(for: digits)
    }
}

extension OBPhoneViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
