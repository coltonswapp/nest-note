import UIKit

class SurveyDashboardViewController: NNViewController {
    
    // MARK: - Properties
    private let surveyService = SurveyService.shared
    private var surveyMetrics: [SurveyResponse.SurveyType: SurveyMetrics] = [:]
    private var featureMetrics: [SurveyService.Feature: FeatureMetrics] = [:]
    private var feedbackMetrics: FeedbackMetrics?
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<NNSectionHeaderView>!
    
    // MARK: - Initialization
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        
        configureCollectionView()
        configureDataSource()
        applyInitialSnapshots()
        
        super.viewDidLoad()
        Task {
            await loadData()
        }
    }
    
    override func setupNavigationBarButtons() {
        
        title = "Survey Data"
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        closeButton.tintColor = .label
        navigationItem.rightBarButtonItem = closeButton
    }
    
    private func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        view.addSubview(collectionView)
        
        // Register cells
        collectionView.register(FeatureCell.self, forCellWithReuseIdentifier: FeatureCell.reuseIdentifier)
        collectionView.register(SectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: SectionHeaderView.reuseIdentifier)
        
        // Add refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    private func createLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        
        return UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
            
            // Standardize header size to match SettingsViewController
            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(32))
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]
            
            return section
        }
    }
    
    private func configureDataSource() {
        headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] (headerView, string, indexPath) in
            guard let section = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            headerView.configure(title: section.title)
        }
        
        let surveyCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, indexPath, item in
            if case let .surveyResult(type, metrics) = item {
                var content = cell.defaultContentConfiguration()
                
                // Set the title based on survey type
                content.text = type == .parentSurvey ? "Parent Survey" : "Sitter Survey"
                
                // Add a secondary text for the number of responses
                let responsesString = String(AttributedString(
                    localized: "^[\(metrics.totalResponses) \("response")](inflect: true)"
                ).characters)
                content.secondaryText = responsesString
                
                // Set layout margins
                content.directionalLayoutMargins.top = 16
                content.directionalLayoutMargins.bottom = 16
                
                cell.contentConfiguration = content
                cell.accessories = [.disclosureIndicator()]
            }
        }
        
        let featureCellRegistration = UICollectionView.CellRegistration<FeatureCell, Item> { cell, indexPath, item in
            if case let .featureVote(feature, metrics) = item {
                cell.configure(feature: feature, metrics: metrics)
            }
        }
        
        let feedbackCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, indexPath, item in
            if case let .feedback(metrics) = item {
                var content = cell.defaultContentConfiguration()
                content.text = "User Feedback"
                
                // Add a secondary text for the number of submissions
                let submissionsString = String(AttributedString(
                    localized: "^[\(metrics.totalSubmissions) \("submission")](inflect: true)"
                ).characters)
                content.secondaryText = submissionsString
                
                // Set layout margins
                content.directionalLayoutMargins.top = 16
                content.directionalLayoutMargins.bottom = 16
                
                cell.contentConfiguration = content
                cell.accessories = [.disclosureIndicator()]
            }
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .surveyResult:
                return collectionView.dequeueConfiguredReusableCell(using: surveyCellRegistration, for: indexPath, item: item)
            case .featureVote:
                return collectionView.dequeueConfiguredReusableCell(using: featureCellRegistration, for: indexPath, item: item)
            case .feedback:
                return collectionView.dequeueConfiguredReusableCell(using: feedbackCellRegistration, for: indexPath, item: item)
            }
        }
        
        dataSource.supplementaryViewProvider = { [weak self] (collectionView, kind, indexPath) in
            collectionView.dequeueConfiguredReusableSupplementary(using: self!.headerRegistration, for: indexPath)
        }
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.surveyResults, .featureVotes, .feedback])
        
        // Add survey results
        let surveyItems = surveyMetrics.map { Item.surveyResult(type: $0.key, metrics: $0.value) }
        snapshot.appendItems(surveyItems, toSection: .surveyResults)
        
        // Add feature votes
        let featureItems = featureMetrics.map { Item.featureVote(feature: $0.key, metrics: $0.value) }
        snapshot.appendItems(featureItems, toSection: .featureVotes)
        
        // Add feedback
        if let feedbackMetrics = feedbackMetrics {
            let feedbackItems = [Item.feedback(metrics: feedbackMetrics)]
            snapshot.appendItems(feedbackItems, toSection: .feedback)
        }
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    @objc private func refreshData() {
        Task {
            await loadData()
            collectionView.refreshControl?.endRefreshing()
        }
    }
    
    private func loadData() async {
        do {
            // Fetch survey metrics
            let parentMetrics = try await surveyService.getSurveyMetrics(type: .parentSurvey)
            let sitterMetrics = try await surveyService.getSurveyMetrics(type: .sitterSurvey)
            
            // Fetch feature metrics
            let nestMembersMetrics = try await surveyService.getFeatureMetrics(featureId: SurveyService.Feature.nestMembers.rawValue)
            
            // Fetch feedback metrics
            let feedbackMetrics = try await surveyService.getFeedbackMetrics()
            
            await MainActor.run {
                // Update survey metrics
                surveyMetrics[.parentSurvey] = parentMetrics
                surveyMetrics[.sitterSurvey] = sitterMetrics
                
                // Update feature metrics
                featureMetrics[.nestMembers] = nestMembersMetrics
                
                // Update feedback metrics
                self.feedbackMetrics = feedbackMetrics
                
                // Apply new snapshot
                applyInitialSnapshots()
            }
        } catch {
            Logger.log(level: .error, category: .general, message: "Error loading metrics: \(error.localizedDescription)")
            await MainActor.run {
                showToast(text: "Failed to load metrics")
            }
        }
    }
}

// MARK: - UICollectionViewDelegate
extension SurveyDashboardViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch item {
        case .surveyResult(let type, let metrics):
            let vc = SurveyDetailViewController(surveyType: type, metrics: metrics)
            navigationController?.pushViewController(vc, animated: true)
            
        case .featureVote(let feature, let metrics):
            let vc = FeatureDetailViewController(feature: feature, metrics: metrics)
            navigationController?.pushViewController(vc, animated: true)
            
        case .feedback(let metrics):
            let vc = FeedbackDetailViewController(metrics: metrics)
            navigationController?.pushViewController(vc, animated: true)
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - Types
extension SurveyDashboardViewController {
    enum Section: Hashable {
        case surveyResults
        case featureVotes
        case feedback
        
        var title: String {
            switch self {
            case .surveyResults: return "Survey Results"
            case .featureVotes: return "Feature Votes"
            case .feedback: return "User Feedback"
            }
        }
    }
    
    enum Item: Hashable {
        case surveyResult(type: SurveyResponse.SurveyType, metrics: SurveyMetrics)
        case featureVote(feature: SurveyService.Feature, metrics: FeatureMetrics)
        case feedback(metrics: FeedbackMetrics)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .surveyResult(let type, let metrics):
                hasher.combine(0) // Discriminator for surveyResult case
                hasher.combine(type)
                hasher.combine(metrics)
            case .featureVote(let feature, let metrics):
                hasher.combine(1) // Discriminator for featureVote case
                hasher.combine(feature)
                hasher.combine(metrics)
            case .feedback(let metrics):
                hasher.combine(2) // Discriminator for feedback case
                hasher.combine(metrics)
            }
        }
        
        static func == (lhs: Item, rhs: Item) -> Bool {
            switch (lhs, rhs) {
            case let (.surveyResult(type1, metrics1), .surveyResult(type2, metrics2)):
                return type1 == type2 && metrics1 == metrics2
            case let (.featureVote(feature1, metrics1), .featureVote(feature2, metrics2)):
                return feature1 == feature2 && metrics1 == metrics2
            case let (.feedback(metrics1), .feedback(metrics2)):
                return metrics1 == metrics2
            default:
                return false
            }
        }
    }
}

// MARK: - Feature Cell
private class FeatureCell: UICollectionViewListCell {
    
    static let reuseIdentifier: String = String(describing: FeatureCell.self)
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        return label
    }()
    
    private let percentageLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.textColor = NNColors.primary
        label.textAlignment = .right
        return label
    }()
    
    private let votesLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let lastUpdatedLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private lazy var titleStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, percentageLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()
    
    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleStack, votesLabel, lastUpdatedLabel])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(feature: SurveyService.Feature, metrics: FeatureMetrics) {
        titleLabel.text = feature.title
        percentageLabel.text = "\(Int(metrics.votePercentage))%"
        
        // Use inflection for vote counts
        let votesForString = String(AttributedString(
            localized: "^[\(metrics.votesFor) \("vote")](inflect: true)"
        ).characters)
        let votesAgainstString = String(AttributedString(
            localized: "^[\(metrics.votesAgainst) \("vote")](inflect: true)"
        ).characters)
        votesLabel.text = "\(votesForString) for, \(votesAgainstString) against"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        lastUpdatedLabel.text = "Updated \(dateFormatter.string(from: metrics.lastUpdated))"
    }
} 
