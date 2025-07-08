final class OBFinishViewController: NNOnboardingViewController {
    
    private lazy var activityIndicator: NNLoadingSpinner = {
        let indicator = NNLoadingSpinner()
        indicator.configure(with: NNColors.primaryAlt)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private lazy var successImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(systemName: "checkmark")
        imageView.tintColor = .systemGreen
        imageView.isHidden = true
        imageView.alpha = 0
        return imageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "Finishing up...",
            subtitle: "Beep boop, crunching bits"
        )
        
        setupContent()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        beginFinishFlow()
    }
    
    private func beginFinishFlow() {
        Task {
            do {
                // Signal to coordinator we're ready to finish
                try await (coordinator as? OnboardingCoordinator)?.finishSetup()
                
                // If we get here, signup was successful
                activityIndicator.animateState(success: true) {
                    (self.coordinator as? OnboardingCoordinator)?.updateProgressTo(1.0)
                    self.playSuccessTransition()
                }
            } catch {
                // Hide loading state
                activityIndicator.animateState(success: false)
                (coordinator as? OnboardingCoordinator)?.handleErrorNavigation(error)
            }
        }
    }
    
    override func setupContent() {
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 44),
            activityIndicator.heightAnchor.constraint(equalToConstant: 100),
            activityIndicator.widthAnchor.constraint(equalToConstant: 100),
        ])

        view.addSubview(successImageView)
        
        NSLayoutConstraint.activate([
            successImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            successImageView.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 44),
            successImageView.heightAnchor.constraint(equalToConstant: 100),
            successImageView.widthAnchor.constraint(equalToConstant: 100),
        ])
    }
    
    private func playSuccessTransition() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            (self.coordinator as? OnboardingCoordinator)?.completeOnboarding()
        }
    }
}