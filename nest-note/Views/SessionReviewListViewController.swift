import UIKit

// ADMIN
class SessionReviewListViewController: NNViewController {

    // MARK: - Properties
    private let sessionReviewService = SessionReviewService.shared
    private var sessionReviews: [SessionReview] = []

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
        super.viewDidLoad()

        configureCollectionView()
        configureDataSource()
        applyInitialSnapshots()

        Task {
            await loadData()
        }
    }

    override func setupNavigationBarButtons() {
        title = "Session Reviews"

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

        let reviewCellRegistration = UICollectionView.CellRegistration<SessionReviewCell, Item> { cell, indexPath, item in
            if case let .sessionReview(review) = item {
                cell.configure(with: review)
            }
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .sessionReview:
                return collectionView.dequeueConfiguredReusableCell(using: reviewCellRegistration, for: indexPath, item: item)
            }
        }

        dataSource.supplementaryViewProvider = { [weak self] (collectionView, kind, indexPath) in
            collectionView.dequeueConfiguredReusableSupplementary(using: self!.headerRegistration, for: indexPath)
        }
    }

    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.reviews])

        // Add session reviews
        let reviewItems = sessionReviews.map { Item.sessionReview($0) }
        snapshot.appendItems(reviewItems, toSection: .reviews)

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
            let reviews = try await sessionReviewService.getReviews(limit: 100)

            await MainActor.run {
                sessionReviews = reviews
                applyInitialSnapshots()
            }
        } catch {
            Logger.log(level: .error, category: .general, message: "Error loading session reviews: \(error.localizedDescription)")
            await MainActor.run {
                showToast(text: "Failed to load reviews")
            }
        }
    }
}

// MARK: - UICollectionViewDelegate
extension SessionReviewListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .sessionReview(let review):
            let detailVC = SessionReviewDetailViewController(review: review)
            navigationController?.pushViewController(detailVC, animated: true)
        }

        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - Types
extension SessionReviewListViewController {
    enum Section: Hashable {
        case reviews

        var title: String {
            switch self {
            case .reviews: return "Session Reviews"
            }
        }
    }

    enum Item: Hashable {
        case sessionReview(SessionReview)

        func hash(into hasher: inout Hasher) {
            switch self {
            case .sessionReview(let review):
                hasher.combine(review.id)
            }
        }

        static func == (lhs: Item, rhs: Item) -> Bool {
            switch (lhs, rhs) {
            case let (.sessionReview(review1), .sessionReview(review2)):
                return review1.id == review2.id
            }
        }
    }
}

// MARK: - Session Review Cell
private class SessionReviewCell: UICollectionViewListCell {

    private let userLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.textColor = .label
        return label
    }()

    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyS
        label.textColor = .secondaryLabel
        return label
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textAlignment = .right
        return label
    }()

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()

    private let feedbackLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyS
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        return label
    }()

    private lazy var topStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [userLabel, ratingLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [topStack, roleLabel, timestampLabel, feedbackLabel])
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

    func configure(with review: SessionReview) {
        userLabel.text = review.userRole.rawValue.capitalized
        roleLabel.text = review.userEmail

        // Configure rating with color
        ratingLabel.text = review.sessionRating.rawValue
        switch review.sessionRating {
        case .superb:
            ratingLabel.textColor = .systemGreen
        case .good:
            ratingLabel.textColor = .systemBlue
        case .bad:
            ratingLabel.textColor = .systemOrange
        case .catastrophic:
            ratingLabel.textColor = .systemRed
        }

        // Format timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        timestampLabel.text = dateFormatter.string(from: review.timestamp)

        // Show feedback preview if available
        if let feedback = review.additionalFeedback, !feedback.isEmpty {
            feedbackLabel.text = feedback
            feedbackLabel.isHidden = false
        } else {
            feedbackLabel.isHidden = true
        }

        // Add disclosure indicator
        accessories = [.disclosureIndicator()]
    }
}
