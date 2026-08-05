import UIKit

protocol NestReadinessDetailViewControllerDelegate: AnyObject {
    func readinessDetailViewController(_ controller: NestReadinessDetailViewController, didSelectCategory category: String)
}

final class NestReadinessDetailViewController: NNViewController, UICollectionViewDelegate {
    weak var delegate: NestReadinessDetailViewControllerDelegate?

    private enum Section: String, Hashable, CaseIterable {
        case header = ""
        case nestSummary = "Nest Summary"
        case boost = "Boost your score"
    }

    private enum Item: Hashable {
        case header
        case component(NestReadinessComponentScore)
        case boost(NestReadinessBoostSuggestion)
        case boostEmpty
    }

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<NNSectionHeaderView>!

    private var result: NestReadinessResult?
    private var headerSubtitle = "Loading..."
    private var previousScore: Int?
    private var hasPlayedRingArrivalAnimation = false
    private var hasScheduledRingArrivalAnimation = false
    private static let ringAnimationDelay = NestReadinessRingAnimationConfig.production.startDelay

    private lazy var doneButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Done")
        button.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupRegistrations()
        configureDataSource()
        applySnapshot(result: nil, animated: false)
        reloadReadiness(animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playRingArrivalAnimationIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard hasPlayedRingArrivalAnimation else { return }
        reloadReadiness(animated: true)
    }

    private func setupCollectionView() {
        view.backgroundColor = .systemGroupedBackground
        let layout = createLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        view.addSubview(collectionView)

        let bottomConstraint: NSLayoutConstraint
        if #available(iOS 26.0, *) {
            doneButton.pinToBottomEdgeContainer(of: view, scrollView: collectionView)
            // Extend under the Done button; inset keeps the resting position at the button's top
            // (button height 55 + bottom padding 10, relative to the safe area).
            bottomConstraint = collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            collectionView.contentInset.bottom = 65
            collectionView.verticalScrollIndicatorInsets.bottom = 65
        } else {
            doneButton.pinToBottom(of: view, addBlurEffect: true)
            bottomConstraint = collectionView.bottomAnchor.constraint(equalTo: doneButton.topAnchor)
        }

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint
        ])
    }

    private func setupRegistrations() {
        headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] headerView, _, indexPath in
            guard let self,
                  let section = self.dataSource.sectionIdentifier(for: indexPath.section),
                  !section.rawValue.isEmpty else { return }
            headerView.configure(title: section.rawValue)
        }
    }

    private func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnvironment in
            guard let self else { return nil }
            let section = self.dataSource.snapshot().sectionIdentifiers[sectionIndex]

            switch section {
            case .header:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(560)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0)
                return layoutSection

            case .nestSummary, .boost:
                return Self.makeListSection(layoutEnvironment: layoutEnvironment)
            }
        }
    }

    private static func makeListSection(layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(32)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        return section
    }

    private func configureDataSource() {
        let headerCellRegistration = UICollectionView.CellRegistration<NestReadinessDetailHeaderCell, Item> { [weak self] cell, _, item in
            guard case .header = item, let self else { return }
            cell.configure(subtitle: self.headerSubtitle)
        }

        let listCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, item in
            var content = cell.defaultContentConfiguration()

            switch item {
            case .component(let score):
                content.text = score.component.title
                if let status = score.statusSubtitle {
                    content.secondaryText = "\(score.detailText)\n\(status)"
                } else {
                    content.secondaryText = score.detailText
                }
                content.secondaryTextProperties.color = .secondaryLabel
                content.secondaryTextProperties.numberOfLines = 0
                content.image = Self.makeSymbolImage(named: score.component.symbolName)
                content.imageProperties.tintColor = NNColors.primary
                content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
                content.imageToTextPadding = 16
                content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
                cell.contentConfiguration = content
                cell.accessories = [
                    Self.makePointsAccessory(text: "\(score.earnedPoints)/\(score.maxPoints)")
                ]

            case .boost(let suggestion):
                content.text = suggestion.title
                content.secondaryText = suggestion.subtitle
                content.secondaryTextProperties.color = .secondaryLabel
                content.secondaryTextProperties.numberOfLines = 0
                content.image = Self.makeSymbolImage(named: suggestion.iconName)
                content.imageProperties.tintColor = NNColors.primary
                content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
                content.imageToTextPadding = 16
                content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
                cell.contentConfiguration = content
                cell.accessories = [
                    Self.makePointsAccessory(text: "+\(suggestion.pointsAvailable)"),
                    .disclosureIndicator()
                ]

            case .boostEmpty:
                content.text = "You're fully documented"
                content.secondaryText = "Keep your nest current with Nest Review."
                content.secondaryTextProperties.color = .secondaryLabel
                content.secondaryTextProperties.numberOfLines = 0
                content.image = Self.makeSymbolImage(named: "checkmark.seal.fill")
                content.imageProperties.tintColor = NNColors.primary
                content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
                content.imageToTextPadding = 16
                content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
                cell.contentConfiguration = content
                cell.accessories = []

            default:
                break
            }
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .header:
                return collectionView.dequeueConfiguredReusableCell(
                    using: headerCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .component, .boost, .boostEmpty:
                return collectionView.dequeueConfiguredReusableCell(
                    using: listCellRegistration,
                    for: indexPath,
                    item: item
                )
            }
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self,
                  kind == UICollectionView.elementKindSectionHeader,
                  let section = self.dataSource.sectionIdentifier(for: indexPath.section),
                  !section.rawValue.isEmpty else { return nil }
            return collectionView.dequeueConfiguredReusableSupplementary(
                using: self.headerRegistration,
                for: indexPath
            )
        }
    }

    private static func makeSymbolImage(named symbolName: String) -> UIImage? {
        let symbolConfiguration = UIImage.SymbolConfiguration(weight: .bold)
        return UIImage(systemName: symbolName, withConfiguration: symbolConfiguration)?
            .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
    }

    private static func makePointsAccessory(text: String) -> UICellAccessory {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        return .customView(configuration: .init(
            customView: label,
            placement: .trailing(displayed: .always)
        ))
    }

    private func applySnapshot(result: NestReadinessResult?, animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.header, .nestSummary, .boost])
        snapshot.appendItems([.header], toSection: .header)

        if let result {
            snapshot.appendItems(result.components.map { .component($0) }, toSection: .nestSummary)
            if result.boostSuggestions.isEmpty {
                snapshot.appendItems([.boostEmpty], toSection: .boost)
            } else {
                snapshot.appendItems(result.boostSuggestions.map { .boost($0) }, toSection: .boost)
            }
        }

        dataSource.apply(snapshot, animatingDifferences: animated)
    }

    func reloadReadiness(animated: Bool) {
        Task {
            do {
                NestReadinessService.shared.invalidateCache()
                let newResult = try await NestReadinessService.shared.calculateReadiness(forceRefresh: true)
                await MainActor.run {
                    applyResult(newResult, animated: animated)
                }
            } catch {
                Logger.log(level: .error, category: .general, message: "Failed to load nest readiness: \(error.localizedDescription)")
            }
        }
    }

    private func activeRingView() -> NestReadinessRingView? {
        collectionView.layoutIfNeeded()
        guard let cell = collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? NestReadinessDetailHeaderCell else {
            return nil
        }
        return cell.ringView
    }

    private func playRingArrivalAnimationIfNeeded() {
        guard !hasPlayedRingArrivalAnimation,
              !hasScheduledRingArrivalAnimation,
              view.window != nil,
              result != nil else { return }

        hasScheduledRingArrivalAnimation = true

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.ringAnimationDelay) { [weak self] in
            guard let self,
                  self.view.window != nil,
                  let result = self.result,
                  let ringView = self.activeRingView() else {
                self?.hasScheduledRingArrivalAnimation = false
                return
            }

            self.hasScheduledRingArrivalAnimation = false
            self.hasPlayedRingArrivalAnimation = true
            ringView.layoutIfNeeded()
            ringView.prepareForArrivalAnimation()
            ringView.configure(result: result, animated: true, celebrateCompletion: true)
        }
    }

    private func applyResult(_ newResult: NestReadinessResult, animated: Bool) {
        if let previousScore, newResult.totalScore > previousScore {
            NestReadinessPointsAnimator.showGain(newResult.totalScore - previousScore, in: view)
        }

        let scoreChanged = previousScore != newResult.totalScore
        previousScore = newResult.totalScore
        result = newResult

        let subtitle = "\(newResult.tierLabel) · \(newResult.totalScore) out of 100"
        headerSubtitle = subtitle
        applySnapshot(result: newResult, animated: animated)

        collectionView.layoutIfNeeded()
        if let headerCell = collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? NestReadinessDetailHeaderCell {
            headerCell.configure(subtitle: subtitle)
        }

        if hasPlayedRingArrivalAnimation {
            activeRingView()?.configure(result: newResult, animated: animated && scoreChanged)
        } else if hasScheduledRingArrivalAnimation {
            activeRingView()?.setScore(newResult.totalScore)
        } else {
            activeRingView()?.prepareForArrivalAnimation()
            activeRingView()?.setScore(newResult.totalScore)
            playRingArrivalAnimationIfNeeded()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if case let .boost(suggestion) = item {
            handleBoost(suggestion)
        }
    }

    private func handleBoost(_ suggestion: NestReadinessBoostSuggestion) {
        switch suggestion.kind {
        case .proSubscription:
            presentPremiumPaywall()
        case .notificationsEnabled:
            presentNotificationsPrompt()
        case .essential(let essential):
            presentCreationFlow(for: essential, category: suggestion.categoryName)
        case .missingItemType, .emptyCategory:
            delegate?.readinessDetailViewController(self, didSelectCategory: suggestion.categoryName)
        }
    }

    private func presentPremiumPaywall() {
        let paywall = FeatureInfoPaywallViewController()
        paywall.modalPresentationStyle = .pageSheet
        if let sheet = paywall.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(paywall, animated: true)
    }

    private func presentNotificationsPrompt() {
        SessionNotificationPrompt.presentIfNeeded(from: self) { [weak self] in
            self?.reloadReadiness(animated: true)
        }
    }

    private func presentCreationFlow(for essential: NestReadinessEssential, category: String) {
        switch essential.preferredItemType {
        case .entry, .contact:
            present(NoteDetailViewController(category: category, title: essential.title, content: ""), animated: true)
        case .routine:
            present(RoutineDetailViewController(category: category, routineName: essential.title), animated: true)
        case .place, .unknownDocument:
            delegate?.readinessDetailViewController(self, didSelectCategory: category)
        }
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }
}
