import UIKit

enum EditUserInfoType: String {
    case name = "Name"
    case nestName = "Nest Name"
    case nestAddress = "Nest Address"
    
    var title: String {
        switch self {
        case .name: return "Edit Name"
        case .nestName: return "Edit Nest Name"
        case .nestAddress: return "Edit Nest Address"
        }
    }
    
    var description: String {
        switch self {
        case .name: return "Your name is how others on NestNote will see you. Full name is preferred."
        case .nestName: return "Changes will be reflected in new sessions going forward."
        case .nestAddress: return "It's important that your sitter have access to your address for emergencies & directions."
        }
    }
    
    var placeholder: String {
        switch self {
        case .name: return "Enter your name"
        case .nestName: return "Enter nest name"
        case .nestAddress: return "Enter nest address"
        }
    }
    
    var currentValue: String {
        switch self {
        case .name:
            return UserService.shared.currentUser?.personalInfo.name ?? ""
        case .nestName:
            return NestService.shared.currentNest?.name ?? ""
        case .nestAddress:
            return NestService.shared.currentNest?.address ?? ""
        }
    }
    
    var textContentType: UITextContentType {
        switch self {
        case .name: return .name
        case .nestAddress: return .fullStreetAddress
        case .nestName: return .familyName
        }
    }
}

class EditUserInfoViewController: NNViewController {
    
    private let type: EditUserInfoType
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = NNImage.primaryLogo
        imageView.tintColor = NNColors.primary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h2
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.bodyL
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let titleStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()
    
    private let fieldLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Invite Code".uppercased()
        label.font = .bodyM
        label.textColor = .lightGray
        return label
    }()
    
    private lazy var textField: NNTextField = {
        let field = NNTextField(showClearButton: true)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.delegate = self
        field.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        return field
    }()
    
    private let fieldStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        return stack
    }()
    
    private lazy var saveButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Save", titleColor: .white, fillStyle: .fill(NNColors.primaryAlt))
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        button.isEnabled = false // Disabled by default
        return button
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    init(type: EditUserInfoType) {
        self.type = type
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.isNavigationBarHidden = true
        setupKeyboardAvoidance()
    }
    
    private func setupKeyboardAvoidance() {
        // Create a bottom constraint for the save button
        let bottomConstraint = saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        bottomConstraint.isActive = true
        
        // Setup keyboard avoidance
        setupKeyboardAvoidance(
            for: saveButton,
            bottomConstraint: bottomConstraint,
            defaultBottomSpacing: 16
        )
    }
    
    deinit {
        removeKeyboardAvoidance(for: saveButton)
    }
    
    override func setup() {
        titleLabel.text = type.title
        descriptionLabel.text = type.description
        fieldLabel.text = type.rawValue.uppercased()
        textField.placeholder = type.placeholder
        textField.text = type.currentValue
        textField.textContentType = type.textContentType
        
        // Configure sheet presentation
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
        fieldStack.addArrangedSubview(fieldLabel)
        fieldStack.addArrangedSubview(textField)
        stackView.addArrangedSubview(fieldStack)
        view.addSubview(saveButton)
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            titleStack.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            titleStack.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            textField.heightAnchor.constraint(equalToConstant: 55),
            textField.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            saveButton.heightAnchor.constraint(equalToConstant: 55)
        ])
    }
    
    @objc private func textFieldDidChange() {
        updateSaveButtonState()
    }
    
    private func updateSaveButtonState() {
        let newValue = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let currentValue = type.currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Enable save button only if:
        // 1. The new value is not empty
        // 2. The new value is different from the current value
        saveButton.isEnabled = !newValue.isEmpty && newValue != currentValue
    }
    
    @objc private func saveButtonTapped() {
        guard let newValue = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !newValue.isEmpty else {
            return
        }
        
        saveButton.startLoading()
        
        Task {
            do {
                switch type {
                case .name:
                    try await UserService.shared.updateName(newValue)
                case .nestName:
                    if let currentNest = NestService.shared.currentNest {
                        try await NestService.shared.updateNestName(currentNest.id, newValue)
                    }
                case .nestAddress:
                    if let currentNest = NestService.shared.currentNest {
                        try await NestService.shared.updateNestAddress(currentNest.id, newValue)
                    }
                }
                
                try await Task.sleep(for: .seconds(1))
                
                await MainActor.run {
                    saveButton.stopLoading()
                    showToast(text: "Updated successfully")
                    dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    saveButton.stopLoading()
                    showToast(text: "Failed to update: \(error.localizedDescription)")
                }
            }
        }
    }
}

extension EditUserInfoViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
}
