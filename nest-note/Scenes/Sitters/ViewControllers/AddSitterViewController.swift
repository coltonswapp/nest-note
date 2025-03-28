import UIKit
import Foundation

protocol AddSitterViewControllerDelegate: AnyObject {
    func addSitterViewController(_ controller: AddSitterViewController, didAddSitter sitter: SitterItem)
    func addSitterViewControllerDidCancel(_ controller: AddSitterViewController)
}

class AddSitterViewController: NNViewController {
    
    weak var delegate: AddSitterViewControllerDelegate?
    
    private lazy var nameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Sitter's Name"
        textField.autocapitalizationType = .words
        textField.returnKeyType = .next
        textField.delegate = self
        textField.borderStyle = .roundedRect
        textField.backgroundColor = .secondarySystemGroupedBackground
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private lazy var emailTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Sitter's Email"
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.returnKeyType = .done
        textField.delegate = self
        textField.borderStyle = .roundedRect
        textField.backgroundColor = .secondarySystemGroupedBackground
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private var addButton: NNPrimaryLabeledButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupAddButton()
        
        // Set up text field delegates
        nameTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        emailTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    override func setup() {
        title = "Add New Sitter"
        view.backgroundColor = .systemGroupedBackground
    }
    
    override func setupNavigationBarButtons() {
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        closeButton.tintColor = .label
        navigationItem.rightBarButtonItem = closeButton
    }
    
    override func addSubviews() {
        view.addSubview(nameTextField)
        view.addSubview(emailTextField)
        
        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            nameTextField.heightAnchor.constraint(equalToConstant: 56),
            
            emailTextField.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 16),
            emailTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            emailTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            emailTextField.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func setupAddButton() {
        addButton = NNPrimaryLabeledButton(title: "Add Sitter")
        
        addButton.isEnabled = false
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        
        addButton.pinToBottom(
            of: view,
            addBlurEffect: true,
            blurRadius: 16,
            blurMaskImage: UIImage(named: "testBG3")
        )
    }
    
    @objc private func addButtonTapped() {
        guard let name = nameTextField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
              let email = emailTextField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
              !name.isEmpty, !email.isEmpty else {
            return
        }
        
        // Create new sitter (email encoding is handled in toSavedSitter())
        let newSitter = SitterItem(
            id: UUID().uuidString,
            name: name,
            email: email
        )
        
        // Save to Firestore
        Task {
            do {
                try await NestService.shared.addSavedSitter(newSitter.toSavedSitter())
                
                await MainActor.run {
                    delegate?.addSitterViewController(self, didAddSitter: newSitter)
                }
            } catch {
                await MainActor.run {
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to add sitter: \(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
    
    @objc override func closeButtonTapped() {
        delegate?.addSitterViewControllerDidCancel(self)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        updateAddButtonState()
    }
    
    private func updateAddButtonState() {
        let name = nameTextField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        let email = emailTextField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        
        let isValidEmail = email.contains("@") && email.contains(".")
        addButton.isEnabled = !name.isEmpty && !email.isEmpty && isValidEmail
        
        // Debug print
        print("Updating button state - name: \(name), email: \(email), enabled: \(addButton.isEnabled)")
    }
}

// MARK: - UITextFieldDelegate
extension AddSitterViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Schedule button state update for next run loop to ensure text is updated
        DispatchQueue.main.async {
            self.updateAddButtonState()
        }
        return true
    }
    
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
