import UIKit

class InviteCardDebugViewController: NNViewController {
    
    // MARK: - UI
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Container for the card
    private let cardContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 12
        v.layer.masksToBounds = false
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.25
        v.layer.shadowOffset = CGSize(width: 0, height: 6)
        v.layer.shadowRadius = 10
        return v
    }()

    private let inviteCard: SessionInviteCardView = {
        let card = SessionInviteCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 12
        return card
    }()

    private var cardTopConstraint: NSLayoutConstraint?
    private var cardCenterConstraint: NSLayoutConstraint?
    private var hasAnimatedIn = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureWithDebugData()
        setupNavButtons()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasAnimatedIn {
            hasAnimatedIn = true
            animateCardIntoCenter()
        }
    }
    
    override func setup() {
        title = "Invite Card Debug"
    }
    
    override func addSubviews() {
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        // Add card container directly so we can animate constraints cleanly
        view.addSubview(cardContainer)
        cardContainer.addSubview(inviteCard)
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40),
            
            // Scroll container constraints (kept for layout stability)
            
            // Card container initial constraints
            cardContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cardContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cardContainer.heightAnchor.constraint(equalToConstant: view.frame.height * 0.45),
            
            inviteCard.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            inviteCard.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            inviteCard.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            inviteCard.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor)
        ])

        // Off-screen start and resting center constraints
        cardTopConstraint = cardContainer.topAnchor.constraint(equalTo: view.bottomAnchor, constant: 20)
        cardTopConstraint?.isActive = true
        cardCenterConstraint = cardContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor)
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
            nestName: "The Swapp Nest",
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

    // MARK: - Actions
    private func setupNavButtons() {
        let flipButton = UIBarButtonItem(title: "Flip", style: .plain, target: self, action: #selector(flipTapped))
        let resetButton = UIBarButtonItem(title: "Reset", style: .plain, target: self, action: #selector(resetTapped))
        navigationItem.rightBarButtonItems = [flipButton, resetButton]
    }
    
    @objc private func flipTapped() {
        animateCardIntoCenter()
    }
    
    @objc private func resetTapped() {
        // Reset to offscreen
        cardCenterConstraint?.isActive = false
        cardTopConstraint?.isActive = true
        view.layoutIfNeeded()
    }

    private func animateCardIntoCenter() {
        // Ensure starting state
        view.layoutIfNeeded()

        // Move constraints to center
        cardTopConstraint?.isActive = false
        cardCenterConstraint?.isActive = true

        // Simple slide animation
        UIView.animate(withDuration: 0.75, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.6, options: [.curveEaseOut]) {
            self.view.layoutIfNeeded()
        }
    }
} 
