class OBCreateNestViewController: NNOnboardingViewController {
    private let nestNameField: NNTextField = {
        let field = NNTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "Smith Nest"
        return field
    }()
    
    private let addressField: NNTextField = {
        let field = NNTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "321 Eagle Nest Ct, Birdsville CA"
        return field
    }()
    
    private let addressFootnoteLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Your address is only shared with sitters during sessions."
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .caption1)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "Create your Nest",
            subtitle: "Give your nest a name & an address."
        )
        
        setupContent()
        addCTAButton(title: "Next")
        setupActions()
        setupValidation()
        
        nestNameField.delegate = self
        addressField.delegate = self
        
        ctaButton?.isEnabled = false
    }
    
    private func setupValidation() {
        (coordinator as? OnboardingCoordinator)?.nestValidation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isValid in
                self?.ctaButton?.isEnabled = isValid
            }
            .store(in: &cancellables)
        
        // Add text change handlers
        nestNameField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        addressField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    @objc private func textFieldDidChange() {
        (coordinator as? OnboardingCoordinator)?.validateNest(
            name: nestNameField.text ?? "",
            address: addressField.text ?? ""
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nestNameField.becomeFirstResponder()
    }
    
    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }
    
    @objc private func nextButtonTapped() {
        (coordinator as? OnboardingCoordinator)?.next()
    }
    
    // MARK: - Setup
    override func setupContent() {
        view.addSubview(nestNameField)
        view.addSubview(addressField)
        view.addSubview(addressFootnoteLabel)
        
        NSLayoutConstraint.activate([
            nestNameField.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 32),
            nestNameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            nestNameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            nestNameField.heightAnchor.constraint(equalToConstant: 56),
            
            addressField.topAnchor.constraint(equalTo: nestNameField.bottomAnchor, constant: 16),
            addressField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            addressField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            addressField.heightAnchor.constraint(equalToConstant: 56),
            
            addressFootnoteLabel.topAnchor.constraint(equalTo: addressField.bottomAnchor, constant: 8),
            addressFootnoteLabel.leadingAnchor.constraint(equalTo: addressField.leadingAnchor, constant: 8),
            addressFootnoteLabel.trailingAnchor.constraint(equalTo: addressField.trailingAnchor, constant: -8)
        ])
    }
}

// MARK: - UITextFieldDelegate
extension OBCreateNestViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nestNameField {
            addressField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}