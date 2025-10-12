import UIKit

class RecentSurveysViewController: NNViewController {

    // MARK: - Properties
    private let surveyService = SurveyService.shared
    private var recentSurveys: [SurveyResponse] = []

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, SurveyResponse>!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        configureCollectionView()
        configureDataSource()
        applyInitialSnapshot()

        Task {
            await loadRecentSurveys()
        }
    }

    override func setupNavigationBarButtons() {
        title = "Recent Surveys"

        // Add a close button to go back
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        backButton.tintColor = .label
        navigationItem.leftBarButtonItem = backButton
    }

    // MARK: - Actions
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Collection View Setup
    private func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        view.addSubview(collectionView)

        // Add refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    private func createLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .none

        return UICollectionViewCompositionalLayout.list(using: config)
    }

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<SurveyResponseCell, SurveyResponse> { cell, indexPath, survey in
            cell.configure(with: survey)
        }

        dataSource = UICollectionViewDiffableDataSource<Section, SurveyResponse>(collectionView: collectionView) { collectionView, indexPath, survey in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: survey)
        }
    }

    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, SurveyResponse>()
        snapshot.appendSections([.main])
        snapshot.appendItems(recentSurveys, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    @objc private func refreshData() {
        Task {
            await loadRecentSurveys()
            collectionView.refreshControl?.endRefreshing()
        }
    }

    private func loadRecentSurveys() async {
        do {
            let surveys = try await surveyService.getRecentSurveyResponses(limit: 25)

            await MainActor.run {
                self.recentSurveys = surveys
                applySnapshot()
            }
        } catch {
            Logger.log(level: .error, category: .general, message: "Error loading recent surveys: \(error.localizedDescription)")
            await MainActor.run {
                showToast(text: "Failed to load surveys")
            }
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, SurveyResponse>()
        snapshot.appendSections([.main])
        snapshot.appendItems(recentSurveys, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

// MARK: - UICollectionViewDelegate
extension RecentSurveysViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let survey = dataSource.itemIdentifier(for: indexPath) else { return }

        // Show detailed survey view
        let detailVC = SurveyResponseDetailViewController(survey: survey)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Types
extension RecentSurveysViewController {
    enum Section {
        case main
    }
}

// MARK: - Custom Cell
private class SurveyResponseCell: UICollectionViewListCell {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyS
        label.textColor = .secondaryLabel
        return label
    }()

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()

    private let referralLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = NNColors.primary
        return label
    }()

    private lazy var contentStack: UIStackView = {
        let titleStack = UIStackView(arrangedSubviews: [titleLabel, referralLabel])
        titleStack.axis = .horizontal
        titleStack.spacing = 8
        titleStack.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleStack, subtitleLabel, timestampLabel])
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

    func configure(with survey: SurveyResponse) {
        // Set title based on survey type
        titleLabel.text = survey.surveyType == .parentSurvey ? "Parent Survey" : "Sitter Survey"

        // Create subtitle with user ID (limited to 6 chars), role, and discovery method
        let userId = survey.metadata["userId"] ?? "Unknown"
        let truncatedUserId = String(userId.prefix(6))
        let role = survey.metadata["role"] ?? "Unknown"

        // Find discovery method from survey responses
        let discoveryMethod = survey.responses.first(where: { $0.questionId == "discovery_method" })?.answers.first ?? "Not specified"

        subtitleLabel.text = "\(truncatedUserId) • \(role) • \(discoveryMethod)"

        // Format timestamp (without discovery method)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        timestampLabel.text = formatter.string(from: survey.timestamp)

        // Show referral source if available
        if let referralSource = survey.metadata["referralSource"] {
            referralLabel.text = referralSource.uppercased()
            referralLabel.isHidden = false
        } else {
            referralLabel.isHidden = true
        }
    }
}