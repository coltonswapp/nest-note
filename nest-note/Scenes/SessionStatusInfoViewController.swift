import UIKit

final class SessionStatusInfoViewController: NNViewController {
    
    // MARK: - Properties
    private let topImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .rectanglePattern)
        view.alpha = 0.4
        return view
    }()
    
    private let infoView: NNBulletStack
    
    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Session Statuses"
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Understand the different states a caregiving session can be in, from scheduling to completion."
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let footnoteLabel: UILabel = {
        let label = UILabel()
        label.text = "Sessions are automatically archived 7 days after completion. Archived sessions are read-only and associated events will no longer be visible."
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var gotItButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Got It")
        button.addTarget(self, action: #selector(gotItTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    init() {
        let items = [
            NNBulletItem(
                title: "Upcoming",
                description: "Scheduled session awaiting start",
                iconName: "calendar.badge.clock"
            ),
            NNBulletItem(
                title: "In-Progress",
                description: "Active care session (automatically marked as In-Progress when within 10 minutes of start time)",
                iconName: "calendar.badge.checkmark"
            ),
            NNBulletItem(
                title: "Extended",
                description: "Session continuing beyond scheduled end time (automatically marked as Extended when end time passes)",
                iconName: "timer.circle.fill"
            ),
            NNBulletItem(
                title: "Completed",
                description: "Finalized session with all activities concluded (automatically marked as Completed after 2 hours in Extended state)",
                iconName: "checkmark.circle.fill"
            )
        ]
        self.infoView = NNBulletStack(items: items)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    // MARK: - Setup
    private func setupView() {
        view.backgroundColor = .systemBackground
        
        // Setup scroll view
        view.addSubview(topImageView)
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(infoView)
        containerView.addSubview(footnoteLabel)
        
        infoView.translatesAutoresizingMaskIntoConstraints = false
        
        // Pin the Got It button to the bottom
        gotItButton.pinToBottom(of: view, addBlurEffect: true)
        topImageView.pinToTop(of: view)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topImageView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: gotItButton.topAnchor),
            
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            infoView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            infoView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 36),
            infoView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -36),
            
            footnoteLabel.topAnchor.constraint(equalTo: infoView.bottomAnchor, constant: 24),
            footnoteLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            footnoteLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            footnoteLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Actions
    @objc private func gotItTapped() {
        dismiss(animated: true)
    }
} 
