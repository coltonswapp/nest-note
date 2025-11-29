//
//  JoinSessionViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 3/1/25.
//

import UIKit
import Foundation
import AVFoundation

protocol JoinSessionViewControllerDelegate: AnyObject {
    func joinSessionViewController(didAcceptInvite session: SitterSession)
}

class JoinSessionViewController: NNViewController {
    
    weak var delegate: JoinSessionViewControllerDelegate?
    
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

    private var scanButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Scan", image: UIImage(systemName: "qrcode.viewfinder"), backgroundColor: NNColors.primary.withAlphaComponent(0.15), foregroundColor: NNColors.primary)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        return button
    }()

    private var findSessionButton: NNLoadingButton!
    private var buttonBottomConstraint: NSLayoutConstraint?
    private var buttonStack: UIStackView!
    
    private let inviteCardView: SessionInviteCardView = {
        let view = SessionInviteCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0 // Start hidden
        return view
    }()

    // Glow effect behind the card - creates actual glowing effect with shadows
    private lazy var glowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.clear
        view.alpha = 0

        view.layer.shadowColor = NNColors.primary.cgColor
        view.layer.shadowOffset = CGSize.zero
        view.layer.shadowRadius = 40
        view.layer.shadowOpacity = 0.8
        view.layer.masksToBounds = false

        return view
    }()

    // Secondary glow layer with larger radius
    private lazy var glowView2: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.clear
        view.alpha = 0

        view.layer.shadowColor = NNColors.primary.cgColor
        view.layer.shadowOffset = CGSize.zero
        view.layer.shadowRadius = 80
        view.layer.shadowOpacity = 0.6
        view.layer.masksToBounds = false

        return view
    }()

    // Outermost glow layer for maximum effect
    private lazy var glowView3: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.clear
        view.alpha = 0

        view.layer.shadowColor = NNColors.primary.cgColor
        view.layer.shadowOffset = CGSize.zero
        view.layer.shadowRadius = 120
        view.layer.shadowOpacity = 0.4
        view.layer.masksToBounds = false

        return view
    }()

    private var inviteCardBottomConstraint: NSLayoutConstraint?
    private var glowCenterYConstraint: NSLayoutConstraint?
    private var glow2CenterYConstraint: NSLayoutConstraint?
    private var glow3CenterYConstraint: NSLayoutConstraint?
    
    private var currentInviteCode: String?
    private var currentSession: SessionItem?
    private var currentInvite: Invite?
    private var isDebugMode = false
    
    override func loadView() {
        super.loadView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFindSessionButton()
        setupInviteCard()
        setupKeyboardObservers()
        setupTextFieldObserver()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateGlowShadowPaths()
    }
    
    private func updateGlowShadowPaths() {
        // Update shadow paths to match actual view bounds (centered)
        glowView.layer.shadowPath = UIBezierPath(ovalIn: glowView.bounds).cgPath
        glowView2.layer.shadowPath = UIBezierPath(ovalIn: glowView2.bounds).cgPath
        glowView3.layer.shadowPath = UIBezierPath(ovalIn: glowView3.bounds).cgPath
    }
    
    override func addSubviews() {
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
            titleStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            titleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            codeTextField.heightAnchor.constraint(equalToConstant: 60),
            codeTextField.widthAnchor.constraint(equalTo: codeStack.widthAnchor),
            
            codeStack.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 24),
            codeStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            codeStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    @objc private func scanButtonTapped() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentScanner()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.presentScanner()
                    } else {
                        self.presentCameraDeniedAlert()
                    }
                }
            }
        case .denied, .restricted:
            presentCameraDeniedAlert()
        @unknown default:
            presentCameraDeniedAlert()
        }
    }

    private func presentScanner() {
        let scanner = QRScannerViewController()
        scanner.onCodeScanned = { [weak self] value in
            guard let self else { return }
            // Extract first 6 digits from scanned value
            let digits = value.filter { $0.isNumber }
            if digits.count >= 6 {
                let code = String(digits.prefix(6))
                self.codeTextField.textField.text = self.formatCodeWithDash(code)
                self.codeTextFieldDidChange()
                self.findSessionButtonTapped()
            } else {
                self.showToast(delay: 0.0, text: "QR does not contain a valid code", sentiment: .negative)
            }
        }
        scanner.modalPresentationStyle = .fullScreen
        present(scanner, animated: true)
    }

    private func presentCameraDeniedAlert() {
        let alert = UIAlertController(
            title: "Camera Access Needed",
            message: "Enable camera access in Settings to scan QR codes.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            if UIApplication.shared.canOpenURL(settingsURL) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func setupInviteCard() {
        // Add glow layers in proper order (back to front)
        view.addSubview(glowView3)
        view.addSubview(glowView2)
        view.addSubview(glowView)
        
        // Add invite card view (on top of glow)
        view.addSubview(inviteCardView)
        
        // Add invite card constraints - start offscreen
        inviteCardBottomConstraint = inviteCardView.topAnchor.constraint(equalTo: view.bottomAnchor)
        
        // Card dimensions for sizing
        let cardHeight = view.frame.height * 0.4
        
        // Glow center constraints - will be updated when card animates
        // Shadow paths are set in viewDidLayoutSubviews() after layout is complete
        glowCenterYConstraint = glowView.centerYAnchor.constraint(equalTo: view.bottomAnchor, constant: cardHeight / 2)
        glow2CenterYConstraint = glowView2.centerYAnchor.constraint(equalTo: view.bottomAnchor, constant: cardHeight / 2)
        glow3CenterYConstraint = glowView3.centerYAnchor.constraint(equalTo: view.bottomAnchor, constant: cardHeight / 2)
        
        NSLayoutConstraint.activate([
            inviteCardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            inviteCardView.heightAnchor.constraint(equalToConstant: cardHeight),
            inviteCardView.widthAnchor.constraint(equalToConstant: cardHeight * 0.8),
            inviteCardBottomConstraint!,
            
            // Core glow view - centered on card
            glowView.centerXAnchor.constraint(equalTo: inviteCardView.centerXAnchor),
            glowCenterYConstraint!,
            glowView.widthAnchor.constraint(equalTo: inviteCardView.widthAnchor, multiplier: 1.05),
            glowView.heightAnchor.constraint(equalTo: inviteCardView.heightAnchor, multiplier: 0.6),
            
            // Secondary glow view
            glowView2.centerXAnchor.constraint(equalTo: inviteCardView.centerXAnchor),
            glow2CenterYConstraint!,
            glowView2.widthAnchor.constraint(equalTo: inviteCardView.widthAnchor, multiplier: 1.1),
            glowView2.heightAnchor.constraint(equalTo: inviteCardView.heightAnchor, multiplier: 0.7),
            
            // Outer glow view
            glowView3.centerXAnchor.constraint(equalTo: inviteCardView.centerXAnchor),
            glow3CenterYConstraint!,
            glowView3.widthAnchor.constraint(equalTo: inviteCardView.widthAnchor, multiplier: 1.15),
            glowView3.heightAnchor.constraint(equalTo: inviteCardView.heightAnchor, multiplier: 0.8)
        ])
    }
    
    private func setupFindSessionButton() {
        findSessionButton = NNLoadingButton(title: "Find Session", titleColor: .white, fillStyle: .fill(NNColors.primary), transitionStyle: .rightHide)
        findSessionButton.translatesAutoresizingMaskIntoConstraints = false
        findSessionButton.addTarget(self, action: #selector(findSessionButtonTapped), for: .touchUpInside)
        findSessionButton.isEnabled = false

        buttonStack = UIStackView(arrangedSubviews: [findSessionButton, scanButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.alignment = .fill
        buttonStack.distribution = .fill
        buttonStack.spacing = 12

        view.addSubview(buttonStack)

        buttonBottomConstraint = buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)

        NSLayoutConstraint.activate([
            // Stack constraints
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            buttonBottomConstraint!,

            // Button heights
            scanButton.heightAnchor.constraint(equalToConstant: 55),
            findSessionButton.heightAnchor.constraint(equalToConstant: 55),

            // Width ratio 3:7 (~30% / 70%)
            scanButton.widthAnchor.constraint(equalTo: findSessionButton.widthAnchor, multiplier: 3.0/7.0)
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
        
        UIView.animate(withDuration: 0.2) {
            self.scanButton.isHidden = true
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
                    self.findSessionButton.isEnabled = true
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
        // First make card and glow visible
        inviteCardView.alpha = 1
        glowView.alpha = 1.0
        glowView2.alpha = 1.0
        glowView3.alpha = 1.0
        
        inviteCardView.transform = CGAffineTransform(rotationAngle: 2 * .pi / 180)
        
        // Remove current constraint and add new one
        inviteCardBottomConstraint?.isActive = false
        inviteCardBottomConstraint = inviteCardView.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 24)
        inviteCardBottomConstraint?.isActive = true
        
        // Update glow constraints to follow the card
        glowCenterYConstraint?.isActive = false
        glow2CenterYConstraint?.isActive = false
        glow3CenterYConstraint?.isActive = false
        
        glowCenterYConstraint = glowView.centerYAnchor.constraint(equalTo: inviteCardView.centerYAnchor)
        glow2CenterYConstraint = glowView2.centerYAnchor.constraint(equalTo: inviteCardView.centerYAnchor)
        glow3CenterYConstraint = glowView3.centerYAnchor.constraint(equalTo: inviteCardView.centerYAnchor)
        
        glowCenterYConstraint?.isActive = true
        glow2CenterYConstraint?.isActive = true
        glow3CenterYConstraint?.isActive = true
        
        // Animate it up from the bottom with spring effect
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.view.layoutIfNeeded()
        }
        
        // Trigger explosion effect shortly after card starts animating
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            ExplosionManager.trigger(.atomic, at: CGPoint(x: view.center.x, y: view.frame.maxY))
            HapticsHelper.lightHaptic()
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
    
    private func setupTextFieldObserver() {
        codeTextField.textField.addTarget(self, action: #selector(codeTextFieldDidChange), for: .editingChanged)
    }
    
    @objc private func codeTextFieldDidChange() {
        let text = codeTextField.textField.text?.replacingOccurrences(of: "-", with: "") ?? ""
        findSessionButton.isEnabled = text.count == 6 && text.allSatisfy({ $0.isNumber })
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func formatCodeWithDash(_ code: String) -> String {
        let digits = code.filter { $0.isNumber }
        let first = String(digits.prefix(3))
        let second = String(digits.dropFirst(3).prefix(3))
        if second.isEmpty { return first }
        return first + "-" + second
    }

    // MARK: - Debug Mode
    
    func enableDebugMode() {
        isDebugMode = true
        
        // Trigger the animation after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showDebugAnimation()
        }
    }
    
    private func showDebugAnimation() {
        // Update UI to show success state
        titleLabel.text = "Session Found!"
        descriptionLabel.text = "Review the details of the session below; tapping 'Accept Invite' will add this to your list of upcoming sessions."
        
        // Configure the invite card with mock data
        let mockSession = SessionItem(
            id: "debug-123",
            title: "Evening Babysitting",
            startDate: Date().addingTimeInterval(86400), // Tomorrow
            endDate: Date().addingTimeInterval(86400 + 14400), // Tomorrow + 4 hours
            status: .upcoming,
            nestID: "nest-456"
        )
        
        let mockInvite = Invite(
            id: "invite-789",
            nestID: "nest-456",
            nestName: "The Johnson Family",
            sessionID: "debug-123",
            sitterEmail: "test@example.com",
            status: .pending,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(86400 * 7),
            createdBy: "owner-123"
        )
        
        inviteCardView.configure(with: mockSession, invite: mockInvite)
        animateInviteCard()
        
        // Hide the code entry field
        UIView.animate(withDuration: 0.3) {
            self.codeStack.alpha = 0
            self.buttonStack.alpha = 0
        }
    }
}
