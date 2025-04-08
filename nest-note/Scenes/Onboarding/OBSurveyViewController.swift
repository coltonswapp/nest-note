import UIKit

class OBSurveyViewController: NNOnboardingViewController {
    
    // MARK: - Properties
    private var questions: [SurveyQuestion] = []
    private var currentQuestionIndex: Int = 0
    private var surveyResponses: [String: [String]] = [:]  // [questionId: [answers]]
    private var surveyVC: NNOnboardingSurveyViewController?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        loadQuestions()
        showCurrentQuestion()
    }
    
    // MARK: - Setup
    private func loadQuestions() {
        guard let config = SurveyConfiguration.loadLocal(),
              let coordinator = coordinator as? OnboardingCoordinator else {
            return
        }
        
        // Filter questions based on role
        switch coordinator.currentRole {
        case .nestOwner:
            // Parents see usage, information, and communication questions
            self.questions = config.questions.filter {
                $0.category == "usage" ||
                $0.category == "information" ||
                $0.category == "communication"
            }.sorted { $0.order ?? 0 < $1.order ?? 0 }
            
        case .sitter:
            // Sitters see preferences and communication questions
            self.questions = config.questions.filter {
                $0.category == "preferences" ||
                $0.category == "communication"
            }.sorted { $0.order ?? 0 < $1.order ?? 0 }
        }
        
        print("Loaded \(questions.count) questions for role: \(coordinator.currentRole)")
    }
    
    private func showCurrentQuestion() {
        guard currentQuestionIndex < questions.count else {
            // We're done with all questions, proceed with onboarding
            coordinator?.next()
            return
        }
        
        let question = questions[currentQuestionIndex]
        
        // Create and configure the survey view controller
        let surveyVC = NNOnboardingSurveyViewController()
        surveyVC.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(surveyVC)
        view.addSubview(surveyVC.view)
        
        NSLayoutConstraint.activate([
            surveyVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            surveyVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surveyVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surveyVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        surveyVC.didMove(toParent: self)
        surveyVC.configure(with: question)
        
        // Set up the CTA button
        surveyVC.addCTAButton(title: "Next", image: UIImage(systemName: "arrow.right"))
        surveyVC.ctaButton?.addTarget(self, action: #selector(handleNextTapped), for: .touchUpInside)
        
        self.surveyVC = surveyVC
        
        // Update progress
        if let coordinator = coordinator {
            let progress = Float(currentQuestionIndex) / Float(questions.count)
            coordinator.updateProgressTo(progress)
        }
    }
    
    // MARK: - Actions
    @objc private func handleNextTapped() {
        // Validate that at least one option is selected
        guard let response = surveyVC?.getCurrentQuestionResponse(),
              !response.answers.isEmpty else {
            showToast(text: "Please select an option", sentiment: .negative)
            return
        }
        
        // Save current responses
        surveyResponses[response.questionId] = response.answers
        
        // Remove current survey VC
        surveyVC?.willMove(toParent: nil)
        surveyVC?.view.removeFromSuperview()
        surveyVC?.removeFromParent()
        
        // Move to next question or finish
        currentQuestionIndex += 1
        if currentQuestionIndex < questions.count {
            showCurrentQuestion()
        } else {
            // Update coordinator with responses and continue onboarding
            if let coordinator = coordinator as? OnboardingCoordinator {
                coordinator.updateSurveyResponses(surveyResponses)
            }
            coordinator?.next()
        }
    }
    
    override func reset() {
        currentQuestionIndex = 0
        surveyResponses.removeAll()
        surveyVC?.willMove(toParent: nil)
        surveyVC?.view.removeFromSuperview()
        surveyVC?.removeFromParent()
        showCurrentQuestion()
    }
} 
