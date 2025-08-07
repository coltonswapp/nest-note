import UIKit

final class RoutinesInfoViewController: NNViewController {
    
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
            title: "Step-by-Step Checklists",
            description: "Create detailed routines for common tasks like bedtime procedures, pet care, or house closing that your sitters can follow exactly as you prefer",
            iconName: "list.bullet.clipboard"
        ),
        
        NNBulletItem(
            title: "Real-Time Progress Tracking",
            description: "Sitters can check off completed steps with visual indicators showing how much of the routine is finished",
            iconName: "checkmark.circle.fill"
        ),
        
        NNBulletItem(
            title: "Nightly Reset",
            description: "Routine progress automatically clears at midnight so each new day starts with fresh checklists ready to go",
            iconName: "arrow.clockwise"
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
        label.text = "Routines"
        label.font = .h1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Keep your household running smoothly with customizable routines that ensure consistency and peace of mind."
        label.font = .bodyM
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
            infoView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Actions
    @objc private func gotItTapped() {
        dismiss(animated: true)
    }
}
