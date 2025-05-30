//
//  InviteDetailViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 3/1/25.
//

import UIKit

class InviteDetailViewController: NNViewController {
    
    // Add delegate property
    weak var delegate: InviteSitterViewControllerDelegate?
    
    // Add properties for session and invite IDs
    private var sessionID: String?
    private var inviteID: String?
    
    private let bottomImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .halfMoonBottom)
        view.alpha = 0.4
        return view
    }()
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "bird")
        imageView.tintColor = NNColors.primary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Invite Created"
        label.font = .h1
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Instruct your sitter to enter this unique code to be able to accept the invite for this session.\n(Settings -> Sessions -> Enter Code)"
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
    
    private let codeSectionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Invite Code".uppercased()
        label.font = .bodyM
        label.textColor = .lightGray
        return label
    }()
    
    private let codeTextField: RoundedTextField = {
        let field = RoundedTextField(placeholder: "000-000")
        field.textField.keyboardType = .emailAddress
        field.textField.font = .h1
        field.textField.textAlignment = .center
        field.translatesAutoresizingMaskIntoConstraints = false
        field.isUserInteractionEnabled = false
        return field
    }()
    
    private let codeStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        return stack
    }()
    
    private let buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .top
        stack.spacing = 24
        return stack
    }()
    
    private lazy var copyButton = NNCircularIconButtonWithLabel(
        icon: UIImage(systemName: "doc.on.doc"),
        title: "Copy",
        backgroundColor: .tertiarySystemGroupedBackground,
        foregroundColor: .label
    )
    
    private lazy var messageButton = NNCircularIconButtonWithLabel(
        icon: UIImage(systemName: "message"),
        title: "Message",
        backgroundColor: .tertiarySystemGroupedBackground,
        foregroundColor: .label
    )
    
    private lazy var shareButton = NNCircularIconButtonWithLabel(
        icon: UIImage(systemName: "square.and.arrow.up"),
        title: "Share",
        backgroundColor: .tertiarySystemGroupedBackground,
        foregroundColor: .label
    )
    
    private lazy var deleteButton = NNCircularIconButtonWithLabel(
        icon: UIImage(systemName: "trash"),
        title: "Delete",
        backgroundColor: .systemRed.withAlphaComponent(0.15),
        foregroundColor: .systemRed
    )
    
    private var shouldShowDeleteButton: Bool = true
    
    private var inviteCode: String?
    
    init(showDeleteButton: Bool = true) {
        shouldShowDeleteButton = showDeleteButton
        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func addSubviews() {
        view.addSubview(bottomImageView)
        
        titleStack.addArrangedSubview(logoImageView)
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(descriptionLabel)
        titleStack.addArrangedSubview(labelStack)
        view.addSubview(titleStack)
        
        codeStack.addArrangedSubview(codeSectionLabel)
        codeStack.addArrangedSubview(codeTextField)
        view.addSubview(codeStack)
        
        buttonStack.addArrangedSubview(copyButton)
        buttonStack.addArrangedSubview(messageButton)
        buttonStack.addArrangedSubview(shareButton)
        if shouldShowDeleteButton {
            buttonStack.addArrangedSubview(deleteButton)
        }
        view.addSubview(buttonStack)
    }
    
    override func constrainSubviews() {
        bottomImageView.pinToBottom(of: view)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            
            // Title Stack
            logoImageView.widthAnchor.constraint(equalToConstant: 40).with(priority: .defaultHigh),
            logoImageView.heightAnchor.constraint(equalToConstant: 40).with(priority: .defaultHigh),
            
            titleStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            titleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            codeTextField.heightAnchor.constraint(equalToConstant: 60),
            codeTextField.widthAnchor.constraint(equalTo: codeStack.widthAnchor),
            
            codeStack.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 24),
            codeStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            codeStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            buttonStack.topAnchor.constraint(equalTo: codeStack.bottomAnchor, constant: 40),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            buttonStack.heightAnchor.constraint(equalToConstant: 90)
        ])
    }
    
    override func setup() {
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        messageButton.addTarget(self, action: #selector(messageButtonTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
    }
    
    func configure(with code: String, sessionID: String) {
        self.inviteCode = code
        self.inviteID = "invite-\(code)"
        self.sessionID = sessionID
        
        let formattedCode = String(code.prefix(3)) + "-" + String(code.suffix(3))
        codeTextField.textField.text = formattedCode
        titleLabel.text = "Invite Created!"
        descriptionLabel.text = "Share this code with your sitter to allow them to join this session."
    }
    
    @objc private func copyButtonTapped() {
        guard let code = inviteCode else { return }
        let url = "nestnote://invite?code=\(code)"
        UIPasteboard.general.string = url
        
        if let copyButton = copyButton.subviews.first as? UIButton {
            copyButton.bounce()
        }
        
        HapticsHelper.lightHaptic()
        
        showToast(delay: 0.0, text: "Invite link copied!")
    }
    
    @objc private func messageButtonTapped() {
        guard let code = inviteCode else { return }
        let url = "nestnote://invite?code=\(code)"
        let message = "You've been invited to a NestNote session!\n\nUse this link to join: \(url)"
        
        if let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let smsURL = URL(string: "sms:&body=\(encodedMessage)") {
            UIApplication.shared.open(smsURL)
        }
        
        HapticsHelper.lightHaptic()
    }
    
    @objc private func shareButtonTapped() {
        guard let code = inviteCode else { return }
        let url = "nestnote://invite?code=\(code)"
        let message = "You've been invited to a NestNote session!\n\nUse this link to join: \(url)"
        
        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        
        HapticsHelper.lightHaptic()
        
        // For iPad support
        if let popoverController = activityVC.popoverPresentationController {
            if let shareButton = shareButton.subviews.first as? UIButton {
                popoverController.sourceView = shareButton
                popoverController.sourceRect = shareButton.bounds
            }
        }
        
        present(activityVC, animated: true)
    }
    
    @objc private func deleteButtonTapped() {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Delete Invite?",
            message: "This will remove the sitter's access to this session. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self,
                  let inviteID = self.inviteID,
                  let sessionID = self.sessionID else { return }
            
            // Disable delete button during deletion
            self.deleteButton.alpha = 0.5
            self.deleteButton.isUserInteractionEnabled = false
            
            Task {
                do {
                    // Delete invite and update session
                    try await SessionService.shared.deleteInvite(inviteID: inviteID, sessionID: sessionID)
                    
                    await MainActor.run {
                        // Re-enable delete button
                        self.deleteButton.alpha = 1.0
                        self.deleteButton.isUserInteractionEnabled = true
                        
                        // Show success toast
                        self.showToast(text: "Invite deleted successfully")
                        
                        // Notify delegate
                        self.delegate?.inviteDetailViewControllerDidDeleteInvite()
                        
                        // Pop back to previous screen
                        self.navigationController?.dismiss(animated: true)
                    }
                } catch {
                    await MainActor.run {
                        // Re-enable delete button
                        self.deleteButton.alpha = 1.0
                        self.deleteButton.isUserInteractionEnabled = true
                        
                        // Show error alert
                        let alert = UIAlertController(
                            title: "Error",
                            message: "Failed to delete invite: \(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
}
