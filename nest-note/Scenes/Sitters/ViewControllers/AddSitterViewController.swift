import UIKit
import Foundation

protocol AddSitterViewControllerDelegate: AnyObject {
    func addSitterViewController(_ controller: AddSitterViewController, didAddSitter sitter: SitterItem)
    func addSitterViewControllerDidCancel(_ controller: AddSitterViewController)
}

class AddSitterViewController: NNViewController {
    
    weak var delegate: AddSitterViewControllerDelegate?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h2
        label.textAlignment = .center
        label.textColor = .label
        label.text = "Add New Sitter"
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.bodyL
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Once you've added a sitter, they can be invited to your sessions."
        return label
    }()
    
    private let titleStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()
    
    private let nameFieldLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "NAME"
        label.font = .bodyM
        label.textColor = .lightGray
        return label
    }()
    
    private lazy var nameTextField: NNTextField = {
        let field = NNTextField(showClearButton: true)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.delegate = self
        field.placeholder = "Jane Sitter"
        field.autocapitalizationType = .words
        field.returnKeyType = .next
        field.textContentType = .name
        field.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        return field
    }()
    
    private let nameFieldStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        return stack
    }()
    
    private let emailFieldLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "EMAIL"
        label.font = .bodyM
        label.textColor = .lightGray
        return label
    }()
    
    private lazy var emailTextField: NNTextField = {
        let field = NNTextField(showClearButton: true)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.delegate = self
        field.placeholder = "janesitter@gmail.com"
        field.keyboardType = .emailAddress
        field.autocapitalizationType = .none
        field.returnKeyType = .done
        field.textContentType = .emailAddress
        field.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        return field
    }()
    
    private let emailFieldStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        return stack
    }()
    
    private lazy var addButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Add Sitter", titleColor: .white, fillStyle: .fill(NNColors.primaryAlt))
        button.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.isNavigationBarHidden = true
        setupKeyboardAvoidance()
    }
    
    private func setupKeyboardAvoidance() {
        let bottomConstraint = addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        bottomConstraint.isActive = true
        
        setupKeyboardAvoidance(
            for: addButton,
            bottomConstraint: bottomConstraint,
            defaultBottomSpacing: 16
        )
    }
    
    deinit {
        removeKeyboardAvoidance(for: addButton)
    }
    
    override func setup() {
        
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
    }
    
    
    override func addSubviews() {
        view.addSubview(stackView)
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(descriptionLabel)
        stackView.addArrangedSubview(titleStack)
        nameFieldStack.addArrangedSubview(nameFieldLabel)
        nameFieldStack.addArrangedSubview(nameTextField)
        stackView.addArrangedSubview(nameFieldStack)
        emailFieldStack.addArrangedSubview(emailFieldLabel)
        emailFieldStack.addArrangedSubview(emailTextField)
        stackView.addArrangedSubview(emailFieldStack)
        view.addSubview(addButton)
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            titleStack.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            titleStack.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            nameTextField.heightAnchor.constraint(equalToConstant: 55),
            nameTextField.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            
            emailTextField.heightAnchor.constraint(equalToConstant: 55),
            emailTextField.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            addButton.heightAnchor.constraint(equalToConstant: 55)
        ])
    }
    
    
    @objc private func addButtonTapped() {
        guard let name = nameTextField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
              let email = emailTextField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
              !name.isEmpty, !email.isEmpty else {
            return
        }
        
        addButton.startLoading()
        
        let newSitter = SitterItem(
            id: UUID().uuidString,
            name: name,
            email: email
        )
        
        Task {
            do {
                try await NestService.shared.addSavedSitter(newSitter.toSavedSitter())
                
                try await Task.sleep(for: .seconds(1))
                
                await MainActor.run {
                    addButton.stopLoading()
                    showToast(text: "Sitter added successfully")
                    delegate?.addSitterViewController(self, didAddSitter: newSitter)
                }
            } catch {
                await MainActor.run {
                    addButton.stopLoading()
                    showToast(text: "Failed to add sitter: \(error.localizedDescription)")
                }
            }
        }
    }
    
    
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        updateAddButtonState()
    }
    
    private func updateAddButtonState() {
        let name = nameTextField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        let email = emailTextField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        
        let isValidEmail = email.contains("@") && email.contains(".")
        addButton.isEnabled = !name.isEmpty && !email.isEmpty && isValidEmail
    }
}

// MARK: - UITextFieldDelegate
extension AddSitterViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameTextField {
            emailTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            if addButton.isEnabled {
                addButtonTapped()
            }
        }
        return true
    }
} 
