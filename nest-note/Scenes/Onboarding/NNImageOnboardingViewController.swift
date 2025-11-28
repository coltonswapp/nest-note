import UIKit

enum OnboardingScreenContent {
    case aboutNestNote
    case createSessions
    case pickAndChoose
    case inviteWithEase
    
    var title: String {
        switch self {
        case .aboutNestNote:
            return "About NestNote"
        case .createSessions:
            return "Create Sessions"
        case .pickAndChoose:
            return "Pick & Choose"
        case .inviteWithEase:
            return "Share with Ease"
        }
    }
    
    var subtitle: String {
        switch self {
        case .aboutNestNote:
            return "NestNote will help keep your sitters informed. You'll add entries, places, & routines to your nest."
        case .createSessions:
            return "Pick a title, add when your session will take place, then add any relevant details such as calendar events, etc."
        case .pickAndChoose:
            return "Select all of the information that you want your sitter to have access to. Babysitters get baby information, and pet sitters get, you know, pet information. It's up to you!"
        case .inviteWithEase:
            return "Sitters gain access to your nest through invite codes. You can also export the session information as a PDF that can be printed or sent to a sitter."
        }
    }
    
    var imageName: String {
        switch self {
        case .aboutNestNote:
            return "OB1"
        case .createSessions:
            return "OB2"
        case .pickAndChoose:
            return "OB3"
        case .inviteWithEase:
            return "OB4"
        }
    }
    
    var ctaTitle: String {
        switch self {
        case .inviteWithEase:
            "Let's Go!"
        default:
            "Continue"
        }
    }
}

final class NNImageOnboardingViewController: NNOnboardingViewController {
    
    // MARK: - UI Elements
    // Container view for shadow (unclipped)
    private let imageContainer: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.alpha = 0
        container.transform = CGAffineTransform(translationX: 0, y: 300)
        
        // Shadow on container (not clipped)
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.3
        container.layer.shadowOffset = CGSize(width: 4, height: 8)
        container.layer.shadowRadius = 8
        container.layer.masksToBounds = false
        
        return container
    }()
    
    // Inner image view for content (clipped)
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 20
        imageView.layer.borderWidth = 6
        imageView.layer.borderColor = UIColor.systemBackground.cgColor
        imageView.backgroundColor = .systemBackground
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private var content: OnboardingScreenContent?
    private var dynamicTitle: String?
    private var dynamicSubtitle: String?
    private var dynamicImageName: String?
    private var dynamicCTAText: String?

    // MARK: - Initialization
    init(content: OnboardingScreenContent) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    init(title: String, subtitle: String, imageName: String, ctaText: String) {
        self.dynamicTitle = title
        self.dynamicSubtitle = subtitle
        self.dynamicImageName = imageName
        self.dynamicCTAText = ctaText
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        let title: String
        let subtitle: String
        let imageName: String
        let ctaTitle: String

        if let dynamicTitle = dynamicTitle,
           let dynamicSubtitle = dynamicSubtitle,
           let dynamicImageName = dynamicImageName,
           let dynamicCTAText = dynamicCTAText {
            // Use dynamic configuration
            title = dynamicTitle
            subtitle = dynamicSubtitle
            imageName = dynamicImageName
            ctaTitle = dynamicCTAText
        } else if let content = content {
            // Use enum configuration
            title = content.title
            subtitle = content.subtitle
            imageName = content.imageName
            ctaTitle = content.ctaTitle
        } else {
            // Fallback (should not happen)
            return
        }

        setupOnboarding(title: title, subtitle: subtitle)
        setupContent()
        addCTAButton(title: ctaTitle)
        setupActions()

        imageView.image = UIImage(named: imageName)

        // Initially hide the button
        ctaButton?.alpha = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateImageAppearance()
    }
    
    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
    }
    
    @objc private func continueButtonTapped() {
        (coordinator as? OnboardingCoordinator)?.next()
    }
    
    private func animateImageAppearance() {
        // Play light haptic feedback when animation starts
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Animate container with snappier spring effect
        UIView.animate(withDuration: 0.4, delay: 0.05, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.8) {
            self.imageContainer.alpha = 1
            self.imageContainer.transform = .identity
        } completion: { _ in
            // Show continue button after image animation completes
            UIView.animate(withDuration: 0.2, delay: 0.05) {
                self.ctaButton?.alpha = 1
            }
        }
    }
    
    // MARK: - Setup Content
    override func setupContent() {
        view.addSubview(imageContainer)
        imageContainer.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            // Container constraints
            imageContainer.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 48),
            imageContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageContainer.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            imageContainer.heightAnchor.constraint(equalTo: imageContainer.widthAnchor, multiplier: 1.25),
            
            // Image view fills container
            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor)
        ])
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Set shadow path on container for better performance and visibility
        let shadowPath = UIBezierPath(roundedRect: imageContainer.bounds, cornerRadius: 20)
        imageContainer.layer.shadowPath = shadowPath.cgPath
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Update border color when trait changes (light/dark mode)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            imageView.layer.borderColor = UIColor.white.cgColor
        }
    }
}
