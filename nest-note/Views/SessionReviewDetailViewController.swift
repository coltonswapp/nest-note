import UIKit

// ADMIN
class SessionReviewDetailViewController: NNViewController {

    // MARK: - Properties
    private let review: SessionReview
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    // MARK: - Initialization
    init(review: SessionReview) {
        self.review = review
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        configureCollectionView()
        configureDataSource()
        applySnapshot()
    }

    override func setupNavigationBarButtons() {
        title = "Review Details"

        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        backButton.tintColor = .label
        navigationItem.leftBarButtonItem = backButton
    }

    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Collection View Setup
    private func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        view.addSubview(collectionView)
    }

    private func createLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary

        return UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)

            // Add header
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
        // Header registration
        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] (headerView, string, indexPath) in
            guard let section = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }

            var content = headerView.defaultContentConfiguration()
            content.text = section.title
            content.textProperties.font = .boldSystemFont(ofSize: 16)
            content.textProperties.color = .label
            headerView.contentConfiguration = content
        }

        // Basic info cell registration
        let basicInfoCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, indexPath, item in
            if case let .basicInfo(title, value) = item {
                var content = cell.defaultContentConfiguration()
                content.text = title
                content.secondaryText = value
                content.secondaryTextProperties.color = .secondaryLabel
                content.directionalLayoutMargins.top = 12
                content.directionalLayoutMargins.bottom = 12
                cell.contentConfiguration = content
            }
        }

        // Rating cell registration
        let ratingCellRegistration = UICollectionView.CellRegistration<RatingCell, Item> { cell, indexPath, item in
            if case let .rating(title, rating) = item {
                cell.configure(title: title, rating: rating)
            }
        }

        // Feedback cell registration
        let feedbackCellRegistration = UICollectionView.CellRegistration<FeedbackCell, Item> { cell, indexPath, item in
            if case let .feedback(text) = item {
                cell.configure(text: text)
            }
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .basicInfo:
                return collectionView.dequeueConfiguredReusableCell(using: basicInfoCellRegistration, for: indexPath, item: item)
            case .rating:
                return collectionView.dequeueConfiguredReusableCell(using: ratingCellRegistration, for: indexPath, item: item)
            case .feedback:
                return collectionView.dequeueConfiguredReusableCell(using: feedbackCellRegistration, for: indexPath, item: item)
            }
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()

        // Basic Info Section
        snapshot.appendSections([.basicInfo])
        let basicInfoItems: [Item] = [
            .basicInfo(title: "Review ID", value: review.id),
            .basicInfo(title: "User", value: review.userName),
            .basicInfo(title: "Email", value: review.userEmail),
            .basicInfo(title: "Role", value: review.userRole.rawValue.capitalized),
            .basicInfo(title: "Session ID", value: review.sessionId ?? "N/A"),
            .basicInfo(title: "Nest ID", value: review.nestId ?? "N/A"),
            .basicInfo(title: "Timestamp", value: DateFormatter.localizedString(from: review.timestamp, dateStyle: .full, timeStyle: .medium))
        ]
        snapshot.appendItems(basicInfoItems, toSection: .basicInfo)

        // Ratings Section
        snapshot.appendSections([.ratings])
        let ratingItems: [Item] = [
            .rating(title: "Session Rating", rating: review.sessionRating.rawValue),
            .rating(title: "Ease of Use", rating: review.easeOfUse.rawValue),
            .rating(title: "Future Use", rating: review.futureUse.rawValue)
        ]
        snapshot.appendItems(ratingItems, toSection: .ratings)

        // Feedback Section
        if let feedback = review.additionalFeedback, !feedback.isEmpty {
            snapshot.appendSections([.feedback])
            let feedbackItems = [Item.feedback(feedback)]
            snapshot.appendItems(feedbackItems, toSection: .feedback)
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - Types
extension SessionReviewDetailViewController {
    enum Section: Hashable {
        case basicInfo
        case ratings
        case feedback

        var title: String {
            switch self {
            case .basicInfo:
                return "Basic Information"
            case .ratings:
                return "Ratings"
            case .feedback:
                return "Additional Feedback"
            }
        }
    }

    enum Item: Hashable {
        case basicInfo(title: String, value: String)
        case rating(title: String, rating: String)
        case feedback(String)
    }
}

// MARK: - Custom Rating Cell
private class RatingCell: UICollectionViewListCell {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .label
        return label
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textAlignment = .right
        return label
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, ratingLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
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
            contentStack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -12)
        ])
    }

    func configure(title: String, rating: String) {
        titleLabel.text = title
        ratingLabel.text = rating

        // Set color based on rating
        if title == "Session Rating" {
            switch rating {
            case "Superb":
                ratingLabel.textColor = .systemGreen
            case "Good":
                ratingLabel.textColor = .systemBlue
            case "Bad":
                ratingLabel.textColor = .systemOrange
            case "Catastrophic":
                ratingLabel.textColor = .systemRed
            default:
                ratingLabel.textColor = .label
            }
        } else {
            // For other ratings, use a simple positive/negative color scheme
            switch rating {
            case "Yes, super!", "Yes", "Of course!", "Probably":
                ratingLabel.textColor = .systemGreen
            case "No", "Not at all":
                ratingLabel.textColor = .systemRed
            default:
                ratingLabel.textColor = .systemOrange
            }
        }
    }
}

// MARK: - Custom Feedback Cell
private class FeedbackCell: UICollectionViewListCell {

    private let feedbackLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyS
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(feedbackLabel)
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            feedbackLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            feedbackLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            feedbackLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 12),
            feedbackLabel.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -12)
        ])
    }

    func configure(text: String) {
        feedbackLabel.text = text
    }
}
