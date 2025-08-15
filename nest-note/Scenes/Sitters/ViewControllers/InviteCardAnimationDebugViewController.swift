//
//  InviteCardAnimationDebugViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 3/5/25.
//

import UIKit

class InviteCardAnimationDebugViewController: NNViewController {
    
    private let inviteCard: SessionInviteCardView = {
        let card = SessionInviteCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.alpha = 0 // Start hidden
        return card
    }()
    
    private let buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 8
        return stack
    }()
    
    private let animateButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(title: "Animate", backgroundColor: .systemBlue.withAlphaComponent(0.2), foregroundColor: .systemBlue)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let resetButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(title: "Reset", backgroundColor: .systemRed.withAlphaComponent(0.2), foregroundColor: .systemRed)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var inviteCardTopConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureWithDebugData()
        resetCardPosition()
        setupActions()
    }
    
    override func setup() {
        title = "Invite Card Animation"
        view.backgroundColor = .systemBackground
    }
    
    override func addSubviews() {
        
        [inviteCard, buttonStack].forEach {
            view.addSubview($0)
        }
        
        buttonStack.addArrangedSubview(animateButton)
        buttonStack.addArrangedSubview(resetButton)
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            
            // Invite card
            inviteCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            inviteCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            inviteCard.heightAnchor.constraint(equalToConstant: 400),
            
            // Buttons
             buttonStack.leadingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
             buttonStack.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
             buttonStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
             buttonStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            
            animateButton.heightAnchor.constraint(equalToConstant: 46),
            resetButton.heightAnchor.constraint(equalToConstant: 46)
        ])
        
        // Set initial top constraint for invite card (off-screen)
        inviteCardTopConstraint = inviteCard.topAnchor.constraint(equalTo: view.bottomAnchor, constant: 20)
        inviteCardTopConstraint?.isActive = true
    }
    
    private func setupActions() {
        animateButton.addTarget(self, action: #selector(animateButtonTapped), for: .touchUpInside)
        resetButton.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
    }
    
    @objc private func animateButtonTapped() {
        print("🎬 Animate button tapped")
        animateInviteCard()
    }
    
    @objc private func resetButtonTapped() {
        resetCardPosition()
    }
    
    private func animateInviteCard() {
        print("🎬 Starting animation - current alpha: \(inviteCard.alpha)")
        
        // First make it visible
        inviteCard.alpha = 1
        
        // Remove current constraint and add new one
        inviteCardTopConstraint?.isActive = false
        inviteCardTopConstraint = inviteCard.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 0)
        inviteCardTopConstraint?.isActive = true
        
        print("🎬 Constraints updated, starting animation")
        
        // Animate it up from the bottom with spring effect
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.view.layoutIfNeeded()
        } completion: { finished in
            print("🎬 Animation completed: \(finished)")
        }
        
        HapticsHelper.successHaptic()
    }
    
    private func resetCardPosition() {
        // Hide the card and reset position
        inviteCard.alpha = 0
        
        // Remove current constraint and add new one (off-screen)
        inviteCardTopConstraint?.isActive = false
        inviteCardTopConstraint = inviteCard.topAnchor.constraint(equalTo: view.bottomAnchor, constant: 20)
        inviteCardTopConstraint?.isActive = true
        
        // Immediately update layout
        view.layoutIfNeeded()
    }
    
    private func configureWithDebugData() {
        // Create debug session
        let now = Date()
        let session = SessionItem(
            title: "Weekend Getaway",
            startDate: now.addingTimeInterval(24 * 60 * 60), // Tomorrow
            endDate: now.addingTimeInterval(3 * 24 * 60 * 60), // 3 days from now
            isMultiDay: true
        )
        
        // Create debug invite
        let invite = Invite(
            id: "invite-123456",
            nestID: "nest123",
            nestName: "Swapp Nest",
            sessionID: session.id,
            sitterEmail: "test@example.com",
            status: .pending,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(48 * 60 * 60),
            createdBy: "user123"
        )
        
        // Configure card
        inviteCard.configure(with: session, invite: invite)
    }
}
