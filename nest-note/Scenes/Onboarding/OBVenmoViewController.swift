import UIKit

final class OBVenmoViewController: NNOnboardingViewController {

    private enum Layout {
        static let horizontalInset: CGFloat = 24
        static let fieldLabelContainerInset: CGFloat = 16
        static let subtitleToContentSpacing: CGFloat = 24
        static let sectionSpacing: CGFloat = 24
        static let fieldLabelToFieldSpacing: CGFloat = 8
    }

    private var isDebugMode = false
    private var selectedHourlyRateCents = SessionPaymentCalculator.defaultHourlyRateCents

    private let venmoFieldLabel: UILabel = {
        let label = UILabel()
        label.text = "Venmo Username".uppercased()
        label.font = .captionBoldS
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let venmoTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "username"
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.textContentType = .nickname
        textField.translatesAutoresizingMaskIntoConstraints = false
        VenmoPaymentHandler.applyUsernamePrefix(to: textField)
        return textField
    }()

    private let venmoHintLabel: UILabel = {
        let label = UILabel()
        label.text = "Optional—you can add this later in Profile."
        label.font = .bodyS
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let hourlyRateFieldLabel: UILabel = {
        let label = UILabel()
        label.text = "Hourly Rate".uppercased()
        label.font = .captionBoldS
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var hourlyRateSelector: HourlyRateSelectorView = {
        let selector = HourlyRateSelectorView(cents: selectedHourlyRateCents)
        selector.onValueChanged = { [weak self] cents in
            self?.selectedHourlyRateCents = cents
        }
        return selector
    }()

    private let skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Skip Venmo for now", for: .normal)
        button.titleLabel?.font = .bodyL
        button.setTitleColor(.systemGray, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupOnboarding(
            title: "Set your rate & how you get paid",
            subtitle: "Your hourly rate helps families pay you fairly. Add Venmo so they can pay in one tap—we'll remind them after sessions."
        )

        setupContent()
        addCTAButton(title: "Next")
        setupActions()

        venmoTextField.delegate = self
        ctaButton?.isEnabled = true
        hourlyRateSelector.applyFilledFieldStyle()
        hourlyRateSelector.configure(cents: selectedHourlyRateCents)
    }

    func enableDebugMode() {
        isDebugMode = true
    }

    override func reset() {
        venmoTextField.text = ""
        venmoTextField.layer.borderWidth = 0
        selectedHourlyRateCents = SessionPaymentCalculator.defaultHourlyRateCents
        hourlyRateSelector.resetToDefault()
        ctaButton?.isEnabled = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        venmoTextField.layer.borderWidth = 0
        venmoTextField.layer.cornerRadius = 8
    }

    override func setupContent() {
        view.addSubview(venmoFieldLabel)
        view.addSubview(venmoTextField)
        view.addSubview(venmoHintLabel)
        view.addSubview(hourlyRateFieldLabel)
        view.addSubview(hourlyRateSelector)
        view.addSubview(skipButton)

        NSLayoutConstraint.activate([
            venmoFieldLabel.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: Layout.subtitleToContentSpacing),
            venmoFieldLabel.leadingAnchor.constraint(equalTo: venmoTextField.leadingAnchor, constant: Layout.fieldLabelContainerInset),
            venmoFieldLabel.trailingAnchor.constraint(lessThanOrEqualTo: venmoTextField.trailingAnchor, constant: -Layout.fieldLabelContainerInset),

            venmoTextField.topAnchor.constraint(equalTo: venmoFieldLabel.bottomAnchor, constant: Layout.fieldLabelToFieldSpacing),
            venmoTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Layout.horizontalInset),
            venmoTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Layout.horizontalInset),
            venmoTextField.heightAnchor.constraint(equalToConstant: 50),

            venmoHintLabel.topAnchor.constraint(equalTo: venmoTextField.bottomAnchor, constant: 8),
            venmoHintLabel.leadingAnchor.constraint(equalTo: venmoTextField.leadingAnchor, constant: Layout.fieldLabelContainerInset),
            venmoHintLabel.trailingAnchor.constraint(equalTo: venmoTextField.trailingAnchor, constant: -Layout.fieldLabelContainerInset),

            hourlyRateFieldLabel.topAnchor.constraint(equalTo: venmoHintLabel.bottomAnchor, constant: Layout.sectionSpacing),
            hourlyRateFieldLabel.leadingAnchor.constraint(equalTo: hourlyRateSelector.leadingAnchor, constant: Layout.fieldLabelContainerInset),
            hourlyRateFieldLabel.trailingAnchor.constraint(lessThanOrEqualTo: hourlyRateSelector.trailingAnchor, constant: -Layout.fieldLabelContainerInset),

            hourlyRateSelector.topAnchor.constraint(equalTo: hourlyRateFieldLabel.bottomAnchor, constant: Layout.fieldLabelToFieldSpacing),
            hourlyRateSelector.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Layout.horizontalInset),
            hourlyRateSelector.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Layout.horizontalInset),

            skipButton.topAnchor.constraint(equalTo: hourlyRateSelector.bottomAnchor, constant: 16),
            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
    }

    @objc private func nextButtonTapped() {
        if isDebugMode {
            dismiss(animated: true)
            return
        }

        guard let coordinator = coordinator as? OnboardingCoordinator else { return }

        let raw = venmoTextField.text ?? ""
        let venmoUsername = VenmoPaymentHandler.isValidInput(raw)
            ? VenmoPaymentHandler.normalizeUsername(raw)
            : nil
        coordinator.updateVenmoUsername(venmoUsername)
        coordinator.updateHourlyRate(selectedHourlyRateCents)
        coordinator.next()
    }

    @objc private func skipButtonTapped() {
        if isDebugMode {
            dismiss(animated: true)
            return
        }

        guard let coordinator = coordinator as? OnboardingCoordinator else { return }
        coordinator.updateVenmoUsername(nil)
        coordinator.updateHourlyRate(selectedHourlyRateCents)
        coordinator.next()
    }
}

extension OBVenmoViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
