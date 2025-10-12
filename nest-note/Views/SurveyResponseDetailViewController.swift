import UIKit

class SurveyResponseDetailViewController: NNViewController {

    // MARK: - Properties
    private let survey: SurveyResponse
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    // MARK: - Initialization
    init(survey: SurveyResponse) {
        self.survey = survey
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
        title = "Survey Details"

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

        // Metadata cell registration
        let metadataCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, indexPath, item in
            if case let .metadata(key, value) = item {
                var content = cell.defaultContentConfiguration()
                content.text = key.replacingOccurrences(of: "_", with: " ").capitalized
                content.secondaryText = value
                content.secondaryTextProperties.color = .secondaryLabel
                content.directionalLayoutMargins.top = 12
                content.directionalLayoutMargins.bottom = 12
                cell.contentConfiguration = content
            }
        }

        // Question response cell registration
        let questionCellRegistration = UICollectionView.CellRegistration<QuestionResponseCell, Item> { cell, indexPath, item in
            if case let .questionResponse(questionId, answers) = item {
                cell.configure(questionId: questionId, answers: answers)
            }
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .basicInfo:
                return collectionView.dequeueConfiguredReusableCell(using: basicInfoCellRegistration, for: indexPath, item: item)
            case .metadata:
                return collectionView.dequeueConfiguredReusableCell(using: metadataCellRegistration, for: indexPath, item: item)
            case .questionResponse:
                return collectionView.dequeueConfiguredReusableCell(using: questionCellRegistration, for: indexPath, item: item)
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
            .basicInfo(title: "Survey ID", value: survey.id),
            .basicInfo(title: "Survey Type", value: survey.surveyType == .parentSurvey ? "Parent Survey" : "Sitter Survey"),
            .basicInfo(title: "Version", value: survey.version),
            .basicInfo(title: "Timestamp", value: DateFormatter.localizedString(from: survey.timestamp, dateStyle: .full, timeStyle: .medium))
        ]
        snapshot.appendItems(basicInfoItems, toSection: .basicInfo)

        // Metadata Section
        if !survey.metadata.isEmpty {
            snapshot.appendSections([.metadata])
            let metadataItems = survey.metadata.sorted(by: { $0.key < $1.key }).map { key, value in
                Item.metadata(key: key, value: value)
            }
            snapshot.appendItems(metadataItems, toSection: .metadata)
        }

        // Survey Responses Section
        if !survey.responses.isEmpty {
            snapshot.appendSections([.responses])
            let responseItems = survey.responses.map { response in
                Item.questionResponse(questionId: response.questionId, answers: response.answers)
            }
            snapshot.appendItems(responseItems, toSection: .responses)
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - Types
extension SurveyResponseDetailViewController {
    enum Section: Hashable {
        case basicInfo
        case metadata
        case responses

        var title: String {
            switch self {
            case .basicInfo:
                return "Basic Information"
            case .metadata:
                return "Metadata"
            case .responses:
                return "Survey Responses"
            }
        }
    }

    enum Item: Hashable {
        case basicInfo(title: String, value: String)
        case metadata(key: String, value: String)
        case questionResponse(questionId: String, answers: [String])
    }
}

// MARK: - Custom Question Response Cell
private class QuestionResponseCell: UICollectionViewListCell {

    private let questionLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private let answersLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyS
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [questionLabel, answersLabel])
        stack.axis = .vertical
        stack.spacing = 8
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

    func configure(questionId: String, answers: [String]) {
        // Clean up question ID for display
        let displayQuestionId = questionId.replacingOccurrences(of: "_", with: " ").capitalized
        questionLabel.text = displayQuestionId

        // Format answers
        if answers.isEmpty {
            answersLabel.text = "No answer provided"
        } else if answers.count == 1 {
            answersLabel.text = answers.first
        } else {
            // Multiple answers - show as bullet points
            let bulletPoints = answers.map { "• \($0)" }
            answersLabel.text = bulletPoints.joined(separator: "\n")
        }
    }
}