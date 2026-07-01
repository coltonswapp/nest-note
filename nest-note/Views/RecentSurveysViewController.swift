import UIKit

class RecentSurveysViewController: NNViewController {

    // MARK: - Properties
    private let surveyService = SurveyService.shared
    private var recentSurveyRows: [RecentSurveyRow] = []
    private var displayLimit: RecentSurveyLimit = .current

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, RecentSurveyRow>!
    private lazy var limitSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: RecentSurveyLimit.allCases.map(\.title))
        control.selectedSegmentIndex = RecentSurveyLimit.allCases.firstIndex(of: displayLimit) ?? 0
        control.addTarget(self, action: #selector(limitChanged), for: .valueChanged)
        return control
    }()

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

        limitSegmentedControl.widthAnchor.constraint(equalToConstant: 132).isActive = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: limitSegmentedControl)
    }

    @objc private func limitChanged() {
        let selected = RecentSurveyLimit.allCases[limitSegmentedControl.selectedSegmentIndex]
        guard selected != displayLimit else { return }

        displayLimit = selected
        RecentSurveyLimit.current = selected

        Task {
            await loadRecentSurveys()
        }
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
        let cellRegistration = UICollectionView.CellRegistration<SurveyResponseCell, RecentSurveyRow> { cell, indexPath, row in
            cell.configure(with: row)
        }

        dataSource = UICollectionViewDiffableDataSource<Section, RecentSurveyRow>(collectionView: collectionView) { collectionView, indexPath, row in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: row)
        }
    }

    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, RecentSurveyRow>()
        snapshot.appendSections([.main])
        snapshot.appendItems(recentSurveyRows, toSection: .main)
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
            let surveys = try await surveyService.getRecentSurveyResponses(limit: displayLimit.rawValue)
            let userIds = surveys.compactMap { $0.metadata["userId"] }
            let subscriptionSnapshots = await UserService.shared.fetchSubscriptionSnapshots(userIds: userIds)
            let rows = surveys.map { survey in
                let userId = survey.metadata["userId"] ?? ""
                let liveSnapshot = userIds.isEmpty ? nil : subscriptionSnapshots[userId]
                let status = SurveySubscriptionStatus.resolve(survey: survey, liveSnapshot: liveSnapshot)
                return RecentSurveyRow(survey: survey, subscriptionStatus: status)
            }

            await MainActor.run {
                self.recentSurveyRows = rows
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
        var snapshot = NSDiffableDataSourceSnapshot<Section, RecentSurveyRow>()
        snapshot.appendSections([.main])
        snapshot.appendItems(recentSurveyRows, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

// MARK: - UICollectionViewDelegate
extension RecentSurveysViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let row = dataSource.itemIdentifier(for: indexPath) else { return }

        // Show detailed survey view
        let detailVC = SurveyResponseDetailViewController(survey: row.survey)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Types
extension RecentSurveysViewController {
    enum Section {
        case main
    }

    struct RecentSurveyRow: Hashable {
        let survey: SurveyResponse
        let subscriptionStatus: SurveySubscriptionStatus
    }

    enum RecentSurveyLimit: Int, CaseIterable {
        case twenty = 20
        case forty = 40
        case eighty = 80

        static let userDefaultsKey = "recentSurveyDisplayLimit"

        static var current: RecentSurveyLimit {
            get {
                let stored = UserDefaults.standard.integer(forKey: userDefaultsKey)
                return RecentSurveyLimit(rawValue: stored) ?? .twenty
            }
            set {
                UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
            }
        }

        var title: String { "\(rawValue)" }
    }
}

// MARK: - Custom Cell
private class SurveyResponseCell: UICollectionViewListCell {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
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

    private let subscriptionLabel: PaddedTagLabel = {
        let label = PaddedTagLabel()
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textAlignment = .center
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.textInsets = UIEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let titleRowSpacer: UIView = {
        let view = UIView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }()

    private lazy var contentStack: UIStackView = {
        let titleStack = UIStackView(arrangedSubviews: [titleLabel, titleRowSpacer, subscriptionLabel, referralLabel])
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

    func configure(with row: RecentSurveysViewController.RecentSurveyRow) {
        let survey = row.survey
        let metadata = survey.metadata
        let name = metadata["name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let roleLabel = survey.surveyType == .parentSurvey ? "Parent Survey" : "Sitter Survey"
        let userIdPrefix = metadata["userId"].map { String($0.prefix(5)) }

        if let name, !name.isEmpty {
            titleLabel.text = name
        } else if let userIdPrefix {
            titleLabel.text = "\(roleLabel) · \(userIdPrefix)"
        } else {
            titleLabel.text = roleLabel
        }

        let email = metadata["email"] ?? "No email"
        let phone = metadata["phone"] ?? "No phone"
        let discoveryMethod = metadata["discovery_method"]
            ?? survey.responses.first(where: { $0.questionId == "discovery_method" })?.answers.first
            ?? "Not specified"

        var subtitleParts: [String] = []
        if let name, !name.isEmpty {
            if let userIdPrefix {
                subtitleParts.append("\(roleLabel) · \(userIdPrefix)")
            } else {
                subtitleParts.append(roleLabel)
            }
        }
        subtitleParts.append(contentsOf: [email, phone, discoveryMethod])
        subtitleLabel.text = subtitleParts.joined(separator: " • ")

        // Format timestamp (without discovery method)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        timestampLabel.text = formatter.string(from: survey.timestamp)

        let status = row.subscriptionStatus
        let tagStyle = status.tagStyle
        subscriptionLabel.text = status.shortLabel
        subscriptionLabel.textColor = tagStyle.textColor
        subscriptionLabel.backgroundColor = tagStyle.backgroundColor
        subscriptionLabel.font = .systemFont(ofSize: 10, weight: status.isOutlier ? .heavy : .bold)

        // Show referral source if available
        if let referralSource = survey.metadata["referralSource"] ?? survey.metadata["referral_code"] {
            referralLabel.text = referralSource.uppercased()
            referralLabel.isHidden = false
        } else {
            referralLabel.isHidden = true
        }
    }
}

private final class PaddedTagLabel: UILabel {
    var textInsets = UIEdgeInsets.zero {
        didSet { invalidateIntrinsicContentSize() }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + textInsets.left + textInsets.right,
            height: size.height + textInsets.top + textInsets.bottom
        )
    }
}