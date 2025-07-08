final class OBRoleViewController: NNOnboardingViewController {
    
    // MARK: - UI Elements
    private let parentButton: UIButton = {
        let button = UIButton()
        button.setTitle("Parent", for: .normal)
        button.setTitleColor(.systemGray, for: .normal)
        button.titleLabel?.font = .h3
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.tertiarySystemFill.cgColor
        button.backgroundColor = UIColor.tertiarySystemFill
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.semanticContentAttribute = .forceRightToLeft
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        return button
    }()
    
    private let sitterButton: UIButton = {
        let button = UIButton()
        button.setTitle("Sitter", for: .normal)
        button.setTitleColor(.systemGray, for: .normal)
        button.titleLabel?.font = .h3
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.tertiarySystemFill.cgColor
        button.backgroundColor = UIColor.tertiarySystemFill
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.semanticContentAttribute = .forceRightToLeft
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        return button
    }()
    
    private let parentFootnoteLabel: UILabel = {
        let label = UILabel()
        label.text = "Create a Nest with emergency contacts, house rules, routines, & more"
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .footnote)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    private let sitterFootnoteLabel: UILabel = {
        let label = UILabel()
        label.text = "Receive access to important information regarding families you care for"
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .footnote)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "To be or not to be?",
            subtitle: "Are you signing up primarily as a Parent or a Sitter?"
        )
        
        setupContent()
        addCTAButton(title: "Next")
        setupActions()
        setupValidation()
        
        ctaButton?.isEnabled = false
    }
    
    private func setupValidation() {
        (coordinator as? OnboardingCoordinator)?.roleValidation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isValid in
                self?.ctaButton?.isEnabled = isValid
            }
            .store(in: &cancellables)
    }
    
    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        parentButton.addTarget(self, action: #selector(roleButtonTapped(_:)), for: .touchUpInside)
        sitterButton.addTarget(self, action: #selector(roleButtonTapped(_:)), for: .touchUpInside)
    }
    
    @objc private func nextButtonTapped() {
        (coordinator as? OnboardingCoordinator)?.next()
    }
    
    @objc private func roleButtonTapped(_ sender: UIButton) {
        let role: NestUser.UserType = sender == parentButton ? .nestOwner : .sitter
        (coordinator as? OnboardingCoordinator)?.validateRole(role)
        updateSelection(role)
    }
    
    private func updateSelection(_ role: NestUser.UserType) {
        UIView.animate(withDuration: 0.3) {
            // Update parent button
            self.parentButton.backgroundColor = role == .nestOwner ? .systemBlue : .tertiarySystemFill
            self.parentButton.setTitleColor(role == .nestOwner ? .white : .systemGray, for: .normal)
            self.parentButton.setImage(
                role == .nestOwner ? UIImage(systemName: "checkmark")?.withTintColor(.white, renderingMode: .alwaysOriginal) : nil,
                for: .normal
            )
            
            // Update sitter button
            self.sitterButton.backgroundColor = role == .sitter ? .systemBlue : .tertiarySystemFill
            self.sitterButton.setTitleColor(role == .sitter ? .white : .systemGray, for: .normal)
            self.sitterButton.setImage(
                role == .sitter ? UIImage(systemName: "checkmark")?.withTintColor(.white, renderingMode: .alwaysOriginal) : nil,
                for: .normal
            )
        }
    }
    
    // MARK: - Setup
    override func setupContent() {
        view.addSubview(parentButton)
        view.addSubview(sitterButton)
        view.addSubview(parentFootnoteLabel)
        view.addSubview(sitterFootnoteLabel)
        
        NSLayoutConstraint.activate([
            parentButton.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 32),
            parentButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            parentButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            parentButton.heightAnchor.constraint(equalToConstant: 56),
            
            parentFootnoteLabel.topAnchor.constraint(equalTo: parentButton.bottomAnchor, constant: 8),
            parentFootnoteLabel.leadingAnchor.constraint(equalTo: parentButton.leadingAnchor, constant: 8),
            parentFootnoteLabel.trailingAnchor.constraint(equalTo: parentButton.trailingAnchor, constant: -8),
            
            sitterButton.topAnchor.constraint(equalTo: parentFootnoteLabel.bottomAnchor, constant: 24),
            sitterButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            sitterButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            sitterButton.heightAnchor.constraint(equalToConstant: 56),
            
            sitterFootnoteLabel.topAnchor.constraint(equalTo: sitterButton.bottomAnchor, constant: 8),
            sitterFootnoteLabel.leadingAnchor.constraint(equalTo: sitterButton.leadingAnchor, constant: 8),
            sitterFootnoteLabel.trailingAnchor.constraint(equalTo: sitterButton.trailingAnchor, constant: -8)
        ])
    }
}