import UIKit

class InviteSitterViewController: NNViewController {

    // MARK: - UI Components
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
        label.text = "Invite by Code"
        label.font = .h1
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "They'll have everything they need—from emergency contacts to bedtime routines—ensuring consistent care while you're away"
        label.font = .bodyL
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let labelStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()
    
    private let titleStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 24
        return stack
    }()
    
    private let sectionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Sitter Email".uppercased()
        label.font = .bodyM
        label.textColor = .lightGray
        return label
    }()
    
    private let emailTextField: RoundedTextField = {
        let field = RoundedTextField(placeholder: "Sitter Email")
        field.textField.keyboardType = .emailAddress
        field.translatesAutoresizingMaskIntoConstraints = false
        field.isUserInteractionEnabled = false
        return field
    }()
    
    private let emailStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        return stack
    }()
    
    private var sendInviteButton: NNLoadingButton!
    
    // MARK: - Properties
    
    weak var delegate: InviteSitterViewControllerDelegate?
    private let sitter: SitterItem?
    private let session: SessionItem?
    
    // MARK: - Initialization
    
    init(sitter: SitterItem, session: SessionItem) {
        self.sitter = sitter
        self.session = session
        super.init(nibName: nil, bundle: nil)
        emailTextField.text = sitter.email
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        super.loadView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupInviteButton()
        setupActions()
    }
    
    // MARK: - Setup
    
    override func setupNavigationBarButtons() {
        let dismissButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        navigationItem.rightBarButtonItems = [dismissButton]
        navigationController?.navigationBar.tintColor = .label
    }
    
    override func addSubviews() {
        titleStack.addArrangedSubview(logoImageView)
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(descriptionLabel)
        titleStack.addArrangedSubview(labelStack)
        view.addSubview(titleStack)
        
        emailStack.addArrangedSubview(sectionLabel)
        emailStack.addArrangedSubview(emailTextField)
        view.addSubview(emailStack)
    }
    
    override func constrainSubviews() {
        // Layout constraints
        NSLayoutConstraint.activate([
            
            // Title Stack
            logoImageView.widthAnchor.constraint(equalToConstant: 40).with(priority: .defaultHigh),
            logoImageView.heightAnchor.constraint(equalToConstant: 40).with(priority: .defaultHigh),
            
            titleStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            titleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            emailTextField.heightAnchor.constraint(equalToConstant: 60),
            emailTextField.widthAnchor.constraint(equalTo: emailStack.widthAnchor),
            
            emailStack.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 40),
            emailStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emailStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }
    
    private func setupInviteButton() {
        sendInviteButton = NNLoadingButton(title: "Send Invite", titleColor: .white, fillStyle: .fill(NNColors.primary))
        sendInviteButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        sendInviteButton.addTarget(self, action: #selector(sendInviteButtonTapped), for: .touchUpInside)
        
    }
    
    private func setupActions() {
        // Add text field delegate
        emailTextField.delegate = self
    }
    
    // MARK: - Actions
    
    @objc private func sendInviteButtonTapped() {
        guard let sitter = sitter, let session = session else { return }
        
        // Start loading state
        sendInviteButton.startLoading()
        
        Task {
            do {
                // Create invite for sitter
                let inviteCode = try await SessionService.shared.createInviteForSitter(
                    sessionID: session.id,
                    sitter: sitter
                )
                
                let assignedSitter: AssignedSitter = AssignedSitter(
                    id: sitter.id,
                    name: sitter.name,
                    email: sitter.email,
                    userID: nil,
                    inviteStatus: .invited,
                    inviteID: "invite-\(inviteCode)"
                )
                
                // Update the session's assignedSitter property
                session.updateAssignedSitter(with: assignedSitter)
                
                await MainActor.run {
                    // Stop loading
                    sendInviteButton.stopLoading()
                    
                    // Notify delegate that invite was sent and UI should be reloaded
                    delegate?.inviteSitterViewControllerDidSendInvite(to: SitterItem(
                        id: assignedSitter.id,
                        name: assignedSitter.name,
                        email: assignedSitter.email
                    ))
                    
                    // Show invite details
                    let inviteDetailVC = InviteDetailViewController()
                    inviteDetailVC.delegate = delegate
                    let sitterItem = SitterItem(id: assignedSitter.id, name: assignedSitter.name, email: assignedSitter.email)
                    inviteDetailVC.configure(with: inviteCode, sessionID: session.id, sitter: sitterItem)  // Pass just the code without prefix
                    
                    // Configure back button title
                    let backItem = UIBarButtonItem()
                    backItem.title = "Back"
                    navigationItem.backBarButtonItem = backItem
                    
                    // Replace current view controller with invite detail
                    if let navigationController = self.navigationController {
                        var viewControllers = navigationController.viewControllers
                        viewControllers.removeLast() // Remove InviteSitterViewController
                        viewControllers.append(inviteDetailVC) // Add InviteDetailViewController
                        navigationController.setViewControllers(viewControllers, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    // Stop loading
                    sendInviteButton.stopLoading()
                    
                    // Show error alert
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to create invite: \(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
    
    @objc override func closeButtonTapped() {
        delegate?.inviteSitterViewControllerDidCancel(self)
        dismiss(animated: true)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Helpers
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func showInvalidEmailAlert() {
        let alert = UIAlertController(
            title: "Invalid Email",
            message: "Please enter a valid email address.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITextFieldDelegate

extension InviteSitterViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Limit email length to a reasonable size
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        return updatedText.count <= 100
    }
}


