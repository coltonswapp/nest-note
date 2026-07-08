import UIKit

class SurveyResponseDetailViewController: NNViewController {

    // MARK: - Properties
    private let survey: SurveyResponse
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var contactName: String?
    private var contactPhone: String?

    private static let userProfileMetadataKeys: Set<String> = [
        "userId", "name", "email", "phone", "venmo_username", "nest_name",
        "referral_code", "is_apple_signin", "discovery_method", "created_at", "role",
        "paywall_converted", "paywall_started_trial", "onboarding_variant"
    ]

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
        collectionView.delegate = self

        Task {
            await loadAndApplySnapshot()
        }
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

        let messageButton = UIBarButtonItem(
            image: UIImage(systemName: "message"),
            style: .plain,
            target: self,
            action: #selector(messageButtonTapped)
        )
        messageButton.tintColor = .label
        navigationItem.rightBarButtonItem = messageButton
    }

    @objc private func messageButtonTapped() {
        let firstName = SurveySignupSMSComposer.firstName(from: contactName)
        let body = SurveySignupSMSComposer.welcomeMessage(firstName: firstName, surveyType: survey.surveyType)

        guard SurveySignupSMSComposer.openMessages(phone: contactPhone, body: body) else {
            let alert = UIAlertController(
                title: "Messages Not Available",
                message: contactPhone?.isEmpty == false ?
                    "Couldn't open Messages. Copy the welcome text and text them manually." :
                    "No phone number on file for this signup.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Copy Message", style: .default) { _ in
                UIPasteboard.general.string = body
            })
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
            return
        }
    }

    @objc private func backButtonTapped() {
        guard let navigationController else {
            dismiss(animated: true)
            return
        }

        if navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else {
            navigationController.dismiss(animated: true)
        }
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

        let questionCellRegistration = UICollectionView.CellRegistration<QuestionResponseCell, Item> { [weak self] cell, indexPath, item in
            if case let .questionResponse(questionId, answers) = item, let surveyType = self?.survey.surveyType {
                cell.configure(questionId: questionId, answers: answers, surveyType: surveyType)
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

    private func loadAndApplySnapshot() async {
        var profileItems = buildUserProfileItems(from: survey.metadata)
        var resolvedName = survey.metadata["name"]
        var resolvedPhone = survey.metadata["phone"]

        if let userId = survey.metadata["userId"],
           (metadataNeedsLiveProfile || profileItems.isEmpty),
           let user = try? await UserService.shared.fetchUserProfile(userId: userId) {
            profileItems = buildUserProfileItems(from: survey.metadata, user: user)
            resolvedName = resolvedName ?? user.personalInfo.name
            resolvedPhone = resolvedPhone ?? user.personalInfo.phone
        }

        var subscriptionSnapshot: UserSubscriptionSnapshot?
        if let userId = survey.metadata["userId"], !userId.isEmpty {
            subscriptionSnapshot = await UserService.shared.fetchSubscriptionSnapshot(userId: userId)
        }
        let subscriptionStatus = SurveySubscriptionStatus.resolve(
            survey: survey,
            liveSnapshot: subscriptionSnapshot
        )
        profileItems.insert(("Subscription", subscriptionStatus.detailLabel), at: 0)

        if resolvedName?.isEmpty != false {
            resolvedName = profileItems.first(where: { $0.title == "Name" })?.value
        }
        if resolvedPhone?.isEmpty != false {
            resolvedPhone = profileItems.first(where: { $0.title == "Phone" })?.value
        }

        await MainActor.run {
            contactName = resolvedName
            contactPhone = resolvedPhone
            applySnapshot(userProfileItems: profileItems)
        }
    }

    private var metadataNeedsLiveProfile: Bool {
        survey.metadata["email"]?.isEmpty != false && survey.metadata["name"]?.isEmpty != false
    }

    private func buildUserProfileItems(from metadata: [String: String], user: NestUser? = nil) -> [(title: String, value: String)] {
        var items: [(title: String, value: String)] = []

        func add(_ title: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            items.append((title, value))
        }

        add("Name", metadata["name"] ?? user?.personalInfo.name)
        add("Email", metadata["email"] ?? user?.personalInfo.email)
        add("Phone", metadata["phone"] ?? user?.personalInfo.phone)

        let role = metadata["role"] ?? user?.primaryRole.rawValue
        if let role {
            add("Role", role == NestUser.UserType.sitter.rawValue ? "Sitter" : "Parent")
        }

        add("Venmo", metadata["venmo_username"] ?? user?.personalInfo.venmoUsername)
        add("Nest Name", metadata["nest_name"])
        add("Referral Code", metadata["referral_code"])

        let discovery = metadata["discovery_method"]
            ?? survey.responses.first(where: { $0.questionId == "discovery_method" })?.answers.first
        add("Discovery Method", discovery)

        if let appleSignIn = metadata["is_apple_signin"] {
            add("Sign-In Method", appleSignIn == "true" ? "Apple" : "Email")
        }

        if let createdAt = metadata["created_at"] {
            add("Signup Date", createdAt)
        } else if let createdAt = user?.createdAt {
            add("Signup Date", DateFormatter.localizedString(from: createdAt, dateStyle: .medium, timeStyle: .short))
        }

        add("Firebase UID", metadata["userId"] ?? user?.id)

        return items
    }

    private func applySnapshot(userProfileItems: [(title: String, value: String)]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()

        if !userProfileItems.isEmpty {
            snapshot.appendSections([.userProfile])
            snapshot.appendItems(userProfileItems.map { .basicInfo(title: $0.title, value: $0.value) }, toSection: .userProfile)
        }

        snapshot.appendSections([.basicInfo])
        var basicInfoItems: [Item] = [
            .basicInfo(title: "Survey ID", value: survey.id),
            .basicInfo(title: "Survey Type", value: survey.surveyType == .parentSurvey ? "Parent Survey" : "Sitter Survey"),
            .basicInfo(title: "Version", value: survey.version),
            .basicInfo(title: "Timestamp", value: DateFormatter.localizedString(from: survey.timestamp, dateStyle: .full, timeStyle: .medium))
        ]

        if let duration = survey.duration {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            let durationString = minutes > 0
                ? String(format: "%d min %d sec", minutes, seconds)
                : String(format: "%d sec", seconds)
            basicInfoItems.append(.basicInfo(title: "Duration", value: durationString))
        }

        if let paywallSecStr = survey.metadata["paywall_dwell_seconds"],
           let paywallSec = TimeInterval(paywallSecStr), paywallSec > 0 {
            let whole = Int(round(paywallSec))
            let paywallFormatted = whole >= 60
                ? String(format: "%d min %d sec", whole / 60, whole % 60)
                : String(format: "%d sec", whole)
            basicInfoItems.append(.basicInfo(title: "Paywall time (onboarding)", value: paywallFormatted))
        }

        snapshot.appendItems(basicInfoItems, toSection: .basicInfo)

        let metadataItems = survey.metadata
            .filter { !Self.userProfileMetadataKeys.contains($0.key) && $0.key != "paywall_dwell_seconds" }
            .sorted(by: { $0.key < $1.key })
            .map { Item.metadata(key: $0.key, value: $0.value) }
        if !metadataItems.isEmpty {
            snapshot.appendSections([.metadata])
            snapshot.appendItems(metadataItems, toSection: .metadata)
        }

        if !survey.responses.isEmpty {
            snapshot.appendSections([.responses])
            let responseItems = survey.responses.map { response in
                Item.questionResponse(questionId: response.questionId, answers: response.answers)
            }
            snapshot.appendItems(responseItems, toSection: .responses)
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func copyableText(for item: Item) -> String? {
        switch item {
        case .basicInfo(_, let value), .metadata(_, let value):
            return value.isEmpty ? nil : value
        case .questionResponse(_, let answers):
            guard !answers.isEmpty else { return nil }
            return answers.joined(separator: "\n")
        }
    }

    private func copyItem(at indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              let text = copyableText(for: item) else { return }

        UIPasteboard.general.string = text
        if let cell = collectionView.cellForItem(at: indexPath) {
            cell.showCopyFeedback()
        }
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - UICollectionViewDelegate
extension SurveyResponseDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        copyItem(at: indexPath)
    }
}

// MARK: - Types
extension SurveyResponseDetailViewController {
    enum Section: Hashable {
        case userProfile
        case basicInfo
        case metadata
        case responses

        var title: String {
            switch self {
            case .userProfile:
                return "User Profile"
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

    func configure(questionId: String, answers: [String], surveyType: SurveyResponse.SurveyType) {
        questionLabel.text = SurveyQuestionCatalog.title(for: questionId, surveyType: surveyType)

        if answers.isEmpty {
            answersLabel.text = "No answer provided"
        } else if answers.count == 1 {
            answersLabel.text = answers.first
        } else {
            let bulletPoints = answers.map { "• \($0)" }
            answersLabel.text = bulletPoints.joined(separator: "\n")
        }
    }
}
