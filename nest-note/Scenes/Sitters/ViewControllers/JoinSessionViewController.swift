//
//  JoinSessionViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 3/1/25.
//

import UIKit
import Foundation

protocol JoinSessionViewControllerDelegate: AnyObject {
    func joinSessionViewController(didAcceptInvite session: SitterSession)
}

class JoinSessionViewController: NNViewController {
    
    weak var delegate: JoinSessionViewControllerDelegate?
    
    private let topImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(imageView, for: .rectanglePatternSmall, with: NNColors.primary)
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Join a Session"
        label.font = .h1
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "If you've been invited to a session, enter your 6-digit invite code below to be connected to your session."
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
    
    let codeTextField: RoundedTextField = {
        let field = RoundedTextField(placeholder: "000-000")
        field.textField.keyboardType = .numberPad
        field.textField.font = .h1
        field.textField.textAlignment = .center
        field.translatesAutoresizingMaskIntoConstraints = false
        field.isUserInteractionEnabled = true
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

    private var findSessionButton: NNLoadingButton!
    private var buttonBottomConstraint: NSLayoutConstraint?
    
    private let inviteCardView: SessionInviteCardView = {
        let view = SessionInviteCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0 // Start hidden
        return view
    }()
    
    private var inviteCardBottomConstraint: NSLayoutConstraint?
    
    private var currentInviteCode: String?
    private var currentSession: SessionItem?
    private var currentInvite: Invite?
    
    override func loadView() {
        super.loadView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFindSessionButton()
        setupInviteCard()
        setupKeyboardObservers()
    }
    
    override func addSubviews() {
        view.addSubview(topImageView)
        topImageView.pinToTop(of: view)
        
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(descriptionLabel)
        titleStack.addArrangedSubview(labelStack)
        view.addSubview(titleStack)
        
        codeStack.addArrangedSubview(codeSectionLabel)
        codeStack.addArrangedSubview(codeTextField)
        view.addSubview(codeStack)
    }
    
    override func constrainSubviews() {
        // Layout constraints
        NSLayoutConstraint.activate([
            // Title Stack
            
            titleStack.topAnchor.constraint(equalTo: topImageView.bottomAnchor, constant: 24),
            titleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            codeTextField.heightAnchor.constraint(equalToConstant: 60),
            codeTextField.widthAnchor.constraint(equalTo: codeStack.widthAnchor),
            
            codeStack.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 24),
            codeStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            codeStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }
    
    private func setupInviteCard() {
        // Add invite card view
        view.addSubview(inviteCardView)
        
        // Add invite card constraints - start offscreen
        inviteCardBottomConstraint = inviteCardView.topAnchor.constraint(equalTo: view.bottomAnchor)
        
        NSLayoutConstraint.activate([
            inviteCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            inviteCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            inviteCardView.heightAnchor.constraint(equalToConstant: view.frame.height * 0.4),
            inviteCardBottomConstraint!
        ])
    }
    
    private func setupFindSessionButton() {
        findSessionButton = NNLoadingButton(title: "Find Session", titleColor: .white, fillStyle: .fill(NNColors.primary), transitionStyle: .rightHide)
        findSessionButton.translatesAutoresizingMaskIntoConstraints = false
        findSessionButton.addTarget(self, action: #selector(findSessionButtonTapped), for: .touchUpInside)
        view.addSubview(findSessionButton)
        
        buttonBottomConstraint = findSessionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        
        NSLayoutConstraint.activate([
            findSessionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            findSessionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            findSessionButton.heightAnchor.constraint(equalToConstant: 55),
            buttonBottomConstraint!
        ])
    }
    
    @objc func findSessionButtonTapped() {
        if findSessionButton.titleLabel.text == "Accept Invite" {
            acceptInvite()
            return
        }
        
        guard let code = codeTextField.textField.text?.replacingOccurrences(of: "-", with: "") else {
            showToast(delay: 0.0, text: "Please enter an invite code", sentiment: .negative)
            return
        }
        
        // Validate code format
        guard code.count == 6, code.allSatisfy({ $0.isNumber }) else {
            showToast(delay: 0.0, text: "Invalid code format", sentiment: .negative)
            return
        }
        
        findSessionButton.startLoading()
        currentInviteCode = code
        codeTextField.textField.resignFirstResponder()

        Task {
            do {
                // Only validate the invite, don't accept it yet
                let (session, invite) = try await SessionService.shared.validateInvite(code: code)
                self.currentSession = session
                self.currentInvite = invite
                
                try await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    // Update UI to show success state
                    self.titleLabel.text = "Session Found!"
                    self.descriptionLabel.text = "Review the details of the session below; tapping 'Accept Invite' will add this to your list of upcoming sessions."
                    
                    // Configure and show the invite card
                    self.inviteCardView.configure(with: session, invite: invite)
                    self.animateInviteCard()
                    
                    // Hide the code entry field
                    UIView.animate(withDuration: 0.3) {
                        self.codeStack.alpha = 0
                    }
                    
                    // Update button
                    self.findSessionButton.stopLoading(withSuccess: true)
                    self.findSessionButton.setTitle("Accept Invite")
                }
            } catch {
                showError(error.localizedDescription)
            }
        }
    }
    
    private func acceptInvite() {
        guard let code = currentInviteCode else { return }
        
        findSessionButton.startLoading()
        
        Task {
            do {
                let sitterSession = try await SessionService.shared.validateAndAcceptInvite(inviteID: code)
                
                await MainActor.run {
                    findSessionButton.stopLoading(withSuccess: true)
                    
                    // Show success alert
                    let alert = UIAlertController(
                        title: "Session Joined!",
                        message: "You've successfully joined the session. You can now view all the details in your upcoming sessions.",
                        preferredStyle: .alert
                    )
                    
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                        // Notify delegate
                        self?.delegate?.joinSessionViewController(didAcceptInvite: sitterSession)
                        self?.dismiss(animated: true)
                    })
                    
                    self.present(alert, animated: true)
                }
            } catch {
                showError(error.localizedDescription)
            }
        }
    }
    
    private func animateInviteCard() {
        // First make it visible
        inviteCardView.alpha = 1
        
        // Remove current constraint and add new one
        inviteCardBottomConstraint?.isActive = false
        inviteCardBottomConstraint = inviteCardView.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 24)
        inviteCardBottomConstraint?.isActive = true
        
        // Animate it up from the bottom with spring effect
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.view.layoutIfNeeded()
        }
        
        HapticsHelper.successHaptic()
    }
    
    @MainActor
    private func showError(_ message: String) {
        findSessionButton.stopLoading(withSuccess: false)
        
        // Show error alert
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        
        UIView.animate(withDuration: duration) {
            self.buttonBottomConstraint?.constant = -keyboardHeight + 16
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        UIView.animate(withDuration: duration) {
            self.buttonBottomConstraint?.constant = -16
            self.view.layoutIfNeeded()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
