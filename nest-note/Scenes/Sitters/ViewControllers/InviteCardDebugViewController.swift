import UIKit

class InviteCardDebugViewController: NNViewController {
    
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
    
    private let inviteCard: SessionInviteCardView = {
        let card = SessionInviteCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureWithDebugData()
    }
    
    override func setup() {
        title = "Invite Card Debug"
    }
    
    override func addSubviews() {
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        // Add card at the top
        stackView.addArrangedSubview(inviteCard)
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
            
            inviteCard.heightAnchor.constraint(equalToConstant: view.frame.height * 0.4)
        ])
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
} 
