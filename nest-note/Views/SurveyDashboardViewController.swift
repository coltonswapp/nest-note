import UIKit

class SurveyDashboardViewController: NNViewController {
    
    // MARK: - Properties
    private let surveyService = SurveyService.shared
    private var surveyMetrics: [SurveyResponse.SurveyType: SurveyMetrics] = [:]
    private var survey30DayCounts: [SurveyResponse.SurveyType: Int] = [:]
    private var featureMetrics: [SurveyService.Feature: FeatureMetrics] = [:]
    private var feedbackMetrics: FeedbackMetrics?
    private var todaySignupStats: SignupPeriodStats = .empty
    private var weekSignupStats: SignupPeriodStats = .empty
    
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
        
        let surveyCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, indexPath, item in
            if case let .surveyResult(type, metrics) = item {
                var content = cell.defaultContentConfiguration()

                // Set the title based on survey type
                content.text = type == .parentSurvey ? "Parent Survey" : "Sitter Survey"

                // Add a secondary text for the number of responses with 30-day count
                let responsesString = String(AttributedString(
                    localized: "^[\(metrics.totalResponses) \("response")](inflect: true)"
                ).characters)

                // Add 30-day count if available
                var secondary = ""
                if let thirtyDayCount = self?.survey30DayCounts[type] {
                    secondary = "\(responsesString) (\(thirtyDayCount) in last 30 days)"
                } else {
                    secondary = responsesString
                }
                if type == .parentSurvey, let paywall = metrics.paywallDwell, paywall.count > 0 {
                    let avg = Int(round(paywall.avgSeconds))
                    secondary += "\nAvg. paywall time: \(avg)s (\(paywall.count) with data)"
                }
                content.secondaryText = secondary
                content.secondaryTextProperties.numberOfLines = 0

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

        let recentSurveysCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, indexPath, item in
            if case .recentSurveysView = item {
                var content = cell.defaultContentConfiguration()
                content.text = "View Recent Surveys"
                content.secondaryText = "Browse recent survey responses"

                // Set layout margins
                content.directionalLayoutMargins.top = 16
                content.directionalLayoutMargins.bottom = 16

                cell.contentConfiguration = content
                cell.accessories = [.disclosureIndicator()]
            }
        }

        let signupSummaryCellRegistration = UICollectionView.CellRegistration<SignupSummaryCell, Item> { cell, indexPath, item in
            if case let .signupSummary(today, week) = item {
                cell.configure(today: today, week: week)
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
            case .recentSurveysView:
                return collectionView.dequeueConfiguredReusableCell(using: recentSurveysCellRegistration, for: indexPath, item: item)
            case .signupSummary:
                return collectionView.dequeueConfiguredReusableCell(using: signupSummaryCellRegistration, for: indexPath, item: item)
            }
        }
        
        dataSource.supplementaryViewProvider = { [weak self] (collectionView, kind, indexPath) in
            collectionView.dequeueConfiguredReusableSupplementary(using: self!.headerRegistration, for: indexPath)
        }
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.signUps, .surveyResults, .featureVotes, .feedback, .recentSurveys])

        snapshot.appendItems([.signupSummary(today: todaySignupStats, week: weekSignupStats)], toSection: .signUps)

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

        // Add recent surveys view
        let recentSurveysItems = [Item.recentSurveysView]
        snapshot.appendItems(recentSurveysItems, toSection: .recentSurveys)

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

            // Fetch 30-day survey counts
            let parent30DayCount = try await surveyService.getSurveyResponsesInLast30Days(type: .parentSurvey)
            let sitter30DayCount = try await surveyService.getSurveyResponsesInLast30Days(type: .sitterSurvey)

            // Fetch feature metrics
            let nestMembersMetrics = try await surveyService.getFeatureMetrics(featureId: SurveyService.Feature.nestMembers.rawValue)

            // Fetch feedback metrics
            let feedbackMetrics = try await surveyService.getFeedbackMetrics()

            let todayStats = try await surveyService.getSignupStats(period: .today)
            let weekStats = try await surveyService.getSignupStats(period: .thisWeek)

            await MainActor.run {
                // Update survey metrics
                surveyMetrics[.parentSurvey] = parentMetrics
                surveyMetrics[.sitterSurvey] = sitterMetrics

                // Update 30-day counts
                survey30DayCounts[.parentSurvey] = parent30DayCount
                survey30DayCounts[.sitterSurvey] = sitter30DayCount

                // Update feature metrics
                featureMetrics[.nestMembers] = nestMembersMetrics

                // Update feedback metrics
                self.feedbackMetrics = feedbackMetrics

                self.todaySignupStats = todayStats
                self.weekSignupStats = weekStats

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
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return true }
        if case .signupSummary = item { return false }
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch item {
        case .signupSummary:
            break

        case .surveyResult(let type, let metrics):
            let vc = SurveyDetailViewController(surveyType: type, metrics: metrics)
            navigationController?.pushViewController(vc, animated: true)

        case .featureVote(let feature, let metrics):
            let vc = FeatureDetailViewController(feature: feature, metrics: metrics)
            navigationController?.pushViewController(vc, animated: true)

        case .feedback(let metrics):
            let vc = FeedbackDetailViewController(metrics: metrics)
            navigationController?.pushViewController(vc, animated: true)

        case .recentSurveysView:
            let vc = RecentSurveysViewController()
            navigationController?.pushViewController(vc, animated: true)
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - Types
extension SurveyDashboardViewController {
    enum Section: Hashable {
        case signUps
        case surveyResults
        case featureVotes
        case feedback
        case recentSurveys

        var title: String {
            switch self {
            case .signUps: return "Sign Ups"
            case .surveyResults: return "Survey Results"
            case .featureVotes: return "Feature Votes"
            case .feedback: return "User Feedback"
            case .recentSurveys: return "Recent Surveys"
            }
        }
    }
    
    enum Item: Hashable {
        case signupSummary(today: SignupPeriodStats, week: SignupPeriodStats)
        case surveyResult(type: SurveyResponse.SurveyType, metrics: SurveyMetrics)
        case featureVote(feature: SurveyService.Feature, metrics: FeatureMetrics)
        case feedback(metrics: FeedbackMetrics)
        case recentSurveysView
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .signupSummary(let today, let week):
                hasher.combine(-1)
                hasher.combine(today)
                hasher.combine(week)
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
            case .recentSurveysView:
                hasher.combine(3) // Discriminator for recentSurveysView case
            }
        }
        
        static func == (lhs: Item, rhs: Item) -> Bool {
            switch (lhs, rhs) {
            case let (.signupSummary(today1, week1), .signupSummary(today2, week2)):
                return today1 == today2 && week1 == week2
            case let (.surveyResult(type1, metrics1), .surveyResult(type2, metrics2)):
                return type1 == type2 && metrics1 == metrics2
            case let (.featureVote(feature1, metrics1), .featureVote(feature2, metrics2)):
                return feature1 == feature2 && metrics1 == metrics2
            case let (.feedback(metrics1), .feedback(metrics2)):
                return metrics1 == metrics2
            case (.recentSurveysView, .recentSurveysView):
                return true
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

private class SignupSummaryCell: UICollectionViewListCell {
    private let todayColumn = SignupPeriodColumnView(title: "Today")
    private let weekColumn = SignupPeriodColumnView(title: "This Week")

    private let divider: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        var background = UIBackgroundConfiguration.listGroupedCell()
        background.backgroundColor = .secondarySystemGroupedBackground
        backgroundConfiguration = background

        let columnsStack = UIStackView(arrangedSubviews: [todayColumn, weekColumn])
        columnsStack.axis = .horizontal
        columnsStack.spacing = 16
        columnsStack.distribution = .fillEqually
        columnsStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(columnsStack)
        contentView.addSubview(divider)

        NSLayoutConstraint.activate([
            columnsStack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 12),
            columnsStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            columnsStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            columnsStack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -12),

            divider.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            divider.topAnchor.constraint(equalTo: columnsStack.topAnchor, constant: 4),
            divider.bottomAnchor.constraint(equalTo: columnsStack.bottomAnchor, constant: -4),
            divider.widthAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale)
        ])
    }

    func configure(today: SignupPeriodStats, week: SignupPeriodStats) {
        todayColumn.configure(stats: today)
        weekColumn.configure(stats: week)
    }
}

private final class SignupPeriodColumnView: UIView {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private let totalLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private let breakdownLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let stack = UIStackView(arrangedSubviews: [titleLabel, totalLabel, breakdownLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func configure(stats: SignupPeriodStats) {
        totalLabel.text = "\(stats.total)"

        let parentText = String(AttributedString(
            localized: "^[\(stats.parent) \("parent")](inflect: true)"
        ).characters)
        let sitterText = String(AttributedString(
            localized: "^[\(stats.sitter) \("sitter")](inflect: true)"
        ).characters)
        breakdownLabel.text = "\(parentText) · \(sitterText)"
    }
}
