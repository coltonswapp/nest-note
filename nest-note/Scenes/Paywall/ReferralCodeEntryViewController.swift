//
//  ReferralCodeEntryViewController.swift
//  nest-note
//

import UIKit

protocol ReferralCodeEntryPresenting: AnyObject {
    var referralCodeInput: String { get set }
    var referralCodeError: String? { get set }
    var isLoading: Bool { get }
    var onApplyReferralCode: (String) -> Void { get set }
}

final class ReferralCodeEntryViewController: UIViewController {

    private weak var presentingModel: ReferralCodeEntryPresenting?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter Referral Code"
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Have a code? Enter it here to apply your referral."
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let textField: UITextField = {
        let field = UITextField()
        field.placeholder = "Referral Code"
        field.autocapitalizationType = .allCharacters
        field.autocorrectionType = .no
        field.backgroundColor = .secondarySystemGroupedBackground
        field.layer.cornerRadius = 12
        field.layer.cornerCurve = .continuous
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 44))
        field.leftView = paddingView
        field.leftViewMode = .always
        return field
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = .captionBoldS
        label.textColor = .systemRed
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private lazy var applyButton: NNLoadingButton = {
        let button = NNLoadingButton(
            title: "Apply Code",
            titleColor: .white,
            fillStyle: .fill(NNColors.primary),
            transitionStyle: .rightHide
        )
        button.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        return button
    }()

    init(presenting: ReferralCodeEntryPresenting) {
        self.presentingModel = presenting
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }

    func refresh() {
        guard let presentingModel else { return }

        errorLabel.text = presentingModel.referralCodeError
        errorLabel.isHidden = presentingModel.referralCodeError == nil

        let trimmed = presentingModel.referralCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let canApply = !trimmed.isEmpty && !presentingModel.isLoading
        applyButton.isEnabled = canApply

        if presentingModel.isLoading {
            applyButton.startLoading()
        } else {
            applyButton.stopLoading()
        }
    }

    private func setupView() {
        view.backgroundColor = .systemBackground

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            textField,
            errorLabel,
            applyButton,
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        textField.translatesAutoresizingMaskIntoConstraints = false
        applyButton.translatesAutoresizingMaskIntoConstraints = false

        textField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -12),

            textField.heightAnchor.constraint(equalToConstant: 44),
            applyButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    @objc private func textFieldChanged() {
        presentingModel?.referralCodeInput = textField.text ?? ""
        refresh()
    }

    @objc private func applyTapped() {
        guard let presentingModel else { return }
        presentingModel.onApplyReferralCode(presentingModel.referralCodeInput)
    }
}
