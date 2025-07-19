import UIKit

final class VisibilityLevelInfoViewController: NNViewController {
    
    // MARK: - Properties
    private let topImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .rectanglePatternSmall, with: NNColors.primary)
        view.alpha = 0.4
        return view
    }()
    
    private let infoView = NNBulletStack(items: [
        NNBulletItem(
            title: "Always",
            description: "All the essential information that every sitter needs to know",
            iconName: "exclamationmark.shield.fill"
        ),
        
        NNBulletItem(
            title: "Half-Day",
            description: "Additional details for visits of 4+ hours (meals, schedules, routines)",
            iconName: "clock.fill"
        ),
        
        NNBulletItem(
            title: "Overnight",
            description: "Information relevant for staying overnight (perhaps instructions to lock doors & put children or pets to bed)",
            iconName: "moon.stars.fill"
        ),
        
        NNBulletItem(
            title: "Extended",
            description: "Complete household management information for multi-day sessions",
            iconName: "calendar.badge.clock"
        )
    ])
    
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
        label.text = "Visibility Levels"
        label.font = .h1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Shows sitters exactly what they need based on session length - essential details for short visits, complete guides for longer stays."
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let footerLabel: UILabel = {
        let label = UILabel()
        label.text = "Each level includes all previous levels - Overnight shows Always + Half-Day + Overnight entries."
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var gotItButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Got It")
        button.addTarget(self, action: #selector(gotItTapped), for: .touchUpInside)
        return button
    }()
    
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
        
        infoView.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Pin the Got It button to the bottom
        gotItButton.pinToBottom(of: view, addBlurEffect: true)
        view.addSubview(footerLabel)
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
            infoView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            
            footerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            footerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            footerLabel.bottomAnchor.constraint(equalTo: gotItButton.topAnchor, constant: -12)
        ])
    }
    
    // MARK: - Actions
    @objc private func gotItTapped() {
        dismiss(animated: true)
    }
} 
