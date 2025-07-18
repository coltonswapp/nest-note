import UIKit
import Foundation

protocol AddSitterViewControllerDelegate: AnyObject {
    func addSitterViewController(_ controller: EditSitterViewController, didAddSitter sitter: SitterItem)
    func addSitterViewControllerDidCancel(_ controller: EditSitterViewController)
}

class EditSitterViewController: NNViewController {
    
    weak var delegate: AddSitterViewControllerDelegate?
    private var existingSitter: SitterItem?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h2
        label.textAlignment = .center
        label.textColor = .label
        label.text = "Add New Sitter" // Will be updated in setup if editing
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.bodyL
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Once you've added a sitter, they can be invited to your sessions." // Will be updated in setup if editing
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
        let button = NNLoadingButton(title: "Add Sitter", titleColor: .white, fillStyle: .fill(NNColors.primary)) // Will be updated in setup if editing
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
    
    // MARK: - Initialization
    convenience init(sitter: SitterItem) {
        self.init()
        self.existingSitter = sitter
    }
    
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
        
        // Configure UI based on whether we're editing or adding
        if let sitter = existingSitter {
            // Editing mode
            titleLabel.text = "Edit Sitter"
            descriptionLabel.text = "Update your sitter's information below."
            addButton.setTitle("Save Changes")
            
            // Populate fields
            nameTextField.text = sitter.name
            emailTextField.text = sitter.email
            
            // Update button state
            updateAddButtonState()
        } else {
            // Adding mode (default)
            titleLabel.text = "Add New Sitter"
            descriptionLabel.text = "Once you've added a sitter, they can be invited to your sessions."
            addButton.setTitle("Add Sitter")
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
        
        if let existingSitter = existingSitter {
            // Update existing sitter
            let updatedSitter = SitterItem(
                id: existingSitter.id,
                name: name,
                email: email
            )
            
            Task {
                do {
                    // Delete the old sitter and add the updated one
                    try await NestService.shared.deleteSavedSitter(existingSitter.toSavedSitter())
                    try await NestService.shared.addSavedSitter(updatedSitter.toSavedSitter())
                    
                    try await Task.sleep(for: .seconds(1))
                    
                    await MainActor.run {
                        addButton.stopLoading()
                        showToast(text: "Sitter updated successfully")
                        delegate?.addSitterViewController(self, didAddSitter: updatedSitter)
                    }
                } catch {
                    await MainActor.run {
                        addButton.stopLoading()
                        showToast(text: "Failed to update sitter: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // Add new sitter
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
    }
    
    
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        updateAddButtonState()
    }
    
    private func updateAddButtonState() {
        let name = nameTextField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        let email = emailTextField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        
        let isValidEmail = email.contains("@") && email.contains(".")
        let hasValidData = !name.isEmpty && !email.isEmpty && isValidEmail
        
        if let existingSitter = existingSitter {
            // In edit mode, only enable if there are changes AND data is valid
            let hasChanges = name != existingSitter.name || email != existingSitter.email
            addButton.isEnabled = hasValidData && hasChanges
        } else {
            // In add mode, enable if data is valid
            addButton.isEnabled = hasValidData
        }
    }
}

// MARK: - UITextFieldDelegate
extension EditSitterViewController: UITextFieldDelegate {
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
