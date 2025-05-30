import UIKit

class SurveyDetailViewController: NNViewController {
    
    // MARK: - Properties
    private let surveyType: SurveyResponse.SurveyType
    private let metrics: SurveyMetrics
    
    // MARK: - UI Elements
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h1
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let responsesLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 14.0, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let lastUpdatedLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 14.0, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    init(surveyType: SurveyResponse.SurveyType, metrics: SurveyMetrics) {
        self.surveyType = surveyType
        self.metrics = metrics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = surveyType == .parentSurvey ? "Parent Survey" : "Sitter Survey"
        setupUI()
        configureHeader()
        createQuestionViews()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func configureHeader() {
        contentStackView.addArrangedSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(responsesLabel)
        headerView.addSubview(lastUpdatedLabel)
        
        NSLayoutConstraint.activate([
            headerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            responsesLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            responsesLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 4),
            responsesLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            lastUpdatedLabel.topAnchor.constraint(equalTo: responsesLabel.bottomAnchor, constant: 4),
            lastUpdatedLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 4),
            lastUpdatedLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            lastUpdatedLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -24)
        ])
        
        titleLabel.text = surveyType == .parentSurvey ? "Parent Survey Results" : "Sitter Survey Results"
        responsesLabel.text = "\(metrics.totalResponses) total responses"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        lastUpdatedLabel.text = "Last updated: \(dateFormatter.string(from: metrics.lastUpdated))"
    }
    
    private func createQuestionViews() {
        for (questionId, questionMetrics) in metrics.questionMetrics {
            let questionView = createQuestionView(questionId: questionId, metrics: questionMetrics)
            contentStackView.addArrangedSubview(questionView)
            NSLayoutConstraint.activate([
                questionView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 12),
                questionView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -12),
            ])
        }
    }
    
    private func createQuestionView(questionId: String, metrics: SurveyMetrics.QuestionMetric) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.systemGray5.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        // Add question text
        let questionLabel = UILabel()
        questionLabel.font = .h4
        questionLabel.textColor = .label
        questionLabel.numberOfLines = 0
        questionLabel.text = getQuestionText(for: questionId)
        stackView.addArrangedSubview(questionLabel)
        
        // Add answer distribution views
        for (answer, count) in metrics.answerDistribution {
            let percentage = metrics.percentages[answer] ?? 0
            let answerView = createAnswerView(answer: answer, count: count, percentage: percentage, total: metrics.totalResponses)
            stackView.addArrangedSubview(answerView)
        }
        
        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -2)
        ])
        
        return containerView
    }
    
    // Helper method to get question text based on ID
    private func getQuestionText(for questionId: String) -> String {
        
        return "\(questionId)"
    }
    
    private func createAnswerView(answer: String, count: Int, percentage: Double, total: Int) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let answerLabel = UILabel()
        answerLabel.font = .systemFont(ofSize: 14)
        answerLabel.textColor = .label
        answerLabel.text = answer
        answerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let countLabel = UILabel()
        countLabel.font = UIFont.monospacedSystemFont(ofSize: 14.0, weight: .regular)
        countLabel.textColor = .secondaryLabel
        countLabel.text = "\(count) (\(Int(percentage))%)"
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let progressView = UIProgressView(progressViewStyle: .bar)
        progressView.progress = Float(percentage / 100.0)
        progressView.progressTintColor = NNColors.primary
        progressView.trackTintColor = UIColor.systemGray5
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(answerLabel)
        containerView.addSubview(countLabel)
        containerView.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 40),
            
            answerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            answerLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            
            countLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            countLabel.centerYAnchor.constraint(equalTo: answerLabel.centerYAnchor),
            
            progressView.topAnchor.constraint(equalTo: answerLabel.bottomAnchor, constant: 4),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 4)
        ])
        
        return containerView
    }
} 
