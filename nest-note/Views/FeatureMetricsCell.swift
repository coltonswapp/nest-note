import UIKit

class FeatureMetricsCell: UICollectionViewCell {
    static let reuseIdentifier = "FeatureMetricsCell"
    
    // MARK: - UI Elements
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray5.cgColor
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
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let votePercentageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = NNColors.primary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let voteCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
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
    
    private let chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.right")
        imageView.tintColor = .tertiaryLabel
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(votePercentageLabel)
        containerView.addSubview(voteCountLabel)
        containerView.addSubview(progressView)
        containerView.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -8),
            
            votePercentageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            votePercentageLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            votePercentageLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -8),
            
            progressView.topAnchor.constraint(equalTo: votePercentageLabel.bottomAnchor, constant: 4),
            progressView.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            progressView.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -8),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            voteCountLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 4),
            voteCountLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            voteCountLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -8),
            voteCountLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            chevronImageView.widthAnchor.constraint(equalToConstant: 13),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    // MARK: - Configuration
    func configure(with feature: SurveyService.Feature, metrics: FeatureMetrics) {
        iconImageView.image = UIImage(systemName: feature.iconName)
        titleLabel.text = feature.title
        votePercentageLabel.text = "\(Int(metrics.votePercentage))% in favor"
        voteCountLabel.text = "\(metrics.votesFor) votes for, \(metrics.votesAgainst) votes against"
        progressView.progress = Float(metrics.votePercentage / 100.0)
    }
} 