import UIKit

class NNFeaturePreviewViewController: NNViewController {
    
    // MARK: - Properties
    private let feature: SurveyService.Feature
    private let surveyService = SurveyService.shared
    
    // MARK: - UI Elements
    private let topImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(imageView, for: .rectanglePatternSmall)
        return imageView
    }()
    
    private let comingSoonLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.text = "COMING SOON?"
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h1
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "If that sounds like something you'd like to see added to NestNote sometime in the future, let us know below."
        label.font = .bodyM
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabel
        return label
    }()
    
    private lazy var usefulButton: NNSurveyOptionButton = {
        let button = NNSurveyOptionButton(title: "Yes, I'd use that!")
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(optionSelected(_:)), for: .valueChanged)
        return button
    }()
    
    private lazy var noThanksButton: NNSurveyOptionButton = {
        let button = NNSurveyOptionButton(title: "Not important to me")
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(optionSelected(_:)), for: .valueChanged)
        return button
    }()
    
    private let submitFeedbackButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Submit Feedback")
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var hasVoted: Bool = false
    
    // MARK: - Initialization
    init(feature: SurveyService.Feature) {
        self.feature = feature
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = feature.title
        descriptionLabel.text = feature.description
        
        // Check if user has already voted
        if surveyService.hasVotedForFeature(feature.id) {
            hasVoted = true
            disableVoting()
        }
        
        HapticsHelper.lightHaptic()
    }
    
    // MARK: - Setup
    override func addSubviews() {
        view.addSubview(topImageView)
        topImageView.pinToTop(of: view)

        view.addSubview(comingSoonLabel)
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(instructionLabel)
        view.addSubview(usefulButton)
        view.addSubview(noThanksButton)
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            comingSoonLabel.topAnchor.constraint(equalTo: topImageView.bottomAnchor, constant: 20),
            comingSoonLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: comingSoonLabel.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            instructionLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 24),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            usefulButton.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 24),
            usefulButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            usefulButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            usefulButton.heightAnchor.constraint(equalToConstant: 50),
            
            noThanksButton.topAnchor.constraint(equalTo: usefulButton.bottomAnchor, constant: 12),
            noThanksButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            noThanksButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            noThanksButton.heightAnchor.constraint(equalToConstant: 50),
        ])
        
        submitFeedbackButton.pinToBottom(of: view)
    }
    
    override func setup() {
        submitFeedbackButton.addTarget(self, action: #selector(submitFeedbackTapped), for: .touchUpInside)
        submitFeedbackButton.isEnabled = false
    }
    
    // MARK: - Actions
    @objc private func optionSelected(_ sender: NNSurveyOptionButton) {
        if sender === usefulButton {
            noThanksButton.setSelected(false)
        } else if sender === noThanksButton {
            usefulButton.setSelected(false)
        }
        
        submitFeedbackButton.isEnabled = !hasVoted && (noThanksButton.isOptionSelected || usefulButton.isOptionSelected)
    }
    
    @objc private func submitFeedbackTapped() {
        guard let userId = UserService.shared.currentUser?.id else {
            showToast(text: "Please sign in to submit feedback", sentiment: .negative)
            return
        }
        
        let vote = FeatureVote(
            id: UUID().uuidString,
            timestamp: Date(),
            featureId: feature.id,
            vote: usefulButton.isOptionSelected ? .forFeature : .againstFeature,
            userId: userId,
            comments: nil
        )
        
        Task {
            do {
                try await surveyService.submitFeatureVote(vote)
                HapticsHelper.lightHaptic()
                showToast(text: "Thank you for your feedback!", sentiment: .positive)
                dismiss(animated: true)
            } catch {
                showToast(text: error.localizedDescription, sentiment: .negative)
            }
        }
    }
    
    // MARK: - Private Methods
    private func disableVoting() {
        
        submitFeedbackButton.isEnabled = false
        instructionLabel.text = "Thank you for your feedback! You've already voted on this feature."
    }
} 
