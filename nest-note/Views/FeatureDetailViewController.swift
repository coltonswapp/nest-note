import UIKit

class FeatureDetailViewController: NNViewController {
    
    // MARK: - Properties
    private let feature: SurveyService.Feature
    private let metrics: FeatureMetrics
    
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
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = NNColors.primary
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h1.rounded()
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let voteContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray5.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let votePercentageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 36, weight: .bold)
        label.textColor = NNColors.primary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let voteCountLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .bar)
        progress.progressTintColor = NNColors.primary
        progress.trackTintColor = UIColor.systemGray5
        progress.layer.cornerRadius = 2
        progress.clipsToBounds = true
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()
    
    private let lastUpdatedLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    init(feature: SurveyService.Feature, metrics: FeatureMetrics) {
        self.feature = feature
        self.metrics = metrics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = feature.title
        setupUI()
        configureHeader()
        configureVoteContainer()
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
        headerView.addSubview(iconImageView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            headerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            iconImageView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 24),
            iconImageView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            descriptionLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            descriptionLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -24)
        ])
        
        iconImageView.image = UIImage(systemName: feature.iconName)
        titleLabel.text = feature.title
        descriptionLabel.text = feature.description
    }
    
    private func configureVoteContainer() {
        contentStackView.addArrangedSubview(voteContainerView)
        voteContainerView.addSubview(votePercentageLabel)
        voteContainerView.addSubview(voteCountLabel)
        voteContainerView.addSubview(progressView)
        voteContainerView.addSubview(lastUpdatedLabel)
        
        NSLayoutConstraint.activate([
            voteContainerView.heightAnchor.constraint(equalToConstant: 160),
            voteContainerView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 12),
            voteContainerView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -12),
            
            votePercentageLabel.topAnchor.constraint(equalTo: voteContainerView.topAnchor, constant: 24),
            votePercentageLabel.centerXAnchor.constraint(equalTo: voteContainerView.centerXAnchor),
            
            voteCountLabel.topAnchor.constraint(equalTo: votePercentageLabel.bottomAnchor, constant: 8),
            voteCountLabel.centerXAnchor.constraint(equalTo: voteContainerView.centerXAnchor),
            
            progressView.topAnchor.constraint(equalTo: voteCountLabel.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: voteContainerView.leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: voteContainerView.trailingAnchor, constant: -16),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            lastUpdatedLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            lastUpdatedLabel.centerXAnchor.constraint(equalTo: voteContainerView.centerXAnchor)
        ])
        
        votePercentageLabel.text = "\(Int(metrics.votePercentage))%"
        voteCountLabel.text = "\(metrics.votesFor) votes for, \(metrics.votesAgainst) votes against"
        progressView.progress = Float(metrics.votePercentage / 100.0)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        lastUpdatedLabel.text = "Last updated: \(dateFormatter.string(from: metrics.lastUpdated))"
    }
} 
