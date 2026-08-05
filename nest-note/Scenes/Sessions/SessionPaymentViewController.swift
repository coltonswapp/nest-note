import UIKit

final class SessionPaymentViewController: NNViewController {

    struct Configuration {
        let sessionId: String
        let nestId: String
        let sessionTitle: String
        let startDate: Date
        let scheduledHours: Double
        let defaultHourlyRateCents: Int?
        let venmoUsername: String?
        let sitterName: String

        static func from(session: SessionItem, nestId: String? = nil) -> Configuration? {
            guard let sitter = session.assignedSitter else { return nil }
            let resolvedNestId = nestId ?? NestService.shared.currentNest?.id ?? ""
            guard !resolvedNestId.isEmpty else { return nil }

            let hours = session.endDate.timeIntervalSince(session.startDate) / 3600
            let displayName = sitter.name.isEmpty ? (sitter.email.isEmpty ? "Sitter" : sitter.email) : sitter.name
            return Configuration(
                sessionId: session.id,
                nestId: resolvedNestId,
                sessionTitle: session.title,
                startDate: session.startDate,
                scheduledHours: max(0, hours),
                defaultHourlyRateCents: sitter.hourlyRateCents,
                venmoUsername: sitter.venmoUsername,
                sitterName: displayName
            )
        }
    }

    private enum Section: Hashable {
        case duration
        case hourlyRate
        case total
    }

    private enum Item: Hashable {
        case duration
        case hourlyRate
        case total
    }

    private let configuration: Configuration
    private var draft: SessionPaymentDraft

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    private lazy var payButton: NNLoadingButton = {
        let button = NNLoadingButton(
            title: "Pay Via Venmo",
            titleColor: .white,
            fillStyle: .fill(NNColors.primary)
        )
        let symbol = UIImage(
            systemName: "arrow.up.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        )
        button.setImage(symbol)
        // Trailing placement reads as an external / leave-app action
        button.stackView.insertArrangedSubview(button.titleLabel, at: 0)
        button.addTarget(self, action: #selector(payButtonTapped), for: .touchUpInside)
        return button
    }()

    private let venmoIconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "venmo-icon"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 22),
            imageView.heightAnchor.constraint(equalToConstant: 22)
        ])
        return imageView
    }()

    private let recipientLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var recipientStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [venmoIconView, recipientLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    init(configuration: Configuration) {
        self.configuration = configuration
        self.draft = SessionPaymentDraft.prefilled(
            hours: configuration.scheduledHours > 0 ? configuration.scheduledHours : 1,
            hourlyRateCents: configuration.defaultHourlyRateCents
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func addSubviews() {}

    override func constrainSubviews() {}

    override func setup() {
        navigationItem.title = "Payment"
    }

    override func setupNavigationBarButtons() {
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        closeButton.tintColor = .label
        navigationItem.rightBarButtonItem = closeButton
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        configureDataSource()
        applySnapshot()
        setupBottomChrome()
        updatePayButtonState()
    }

    private func setupBottomChrome() {
        payButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        configureRecipientRow()

        view.addSubview(recipientStack)
        NSLayoutConstraint.activate([
            recipientStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recipientStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            recipientStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            recipientStack.bottomAnchor.constraint(equalTo: payButton.topAnchor, constant: -12)
        ])
        view.bringSubviewToFront(recipientStack)
        view.bringSubviewToFront(payButton)
    }

    private func configureRecipientRow() {
        let username = configuration.venmoUsername?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if username.isEmpty {
            venmoIconView.alpha = 0.45
            recipientLabel.text = "\(configuration.sitterName) hasn't added Venmo yet"
            recipientLabel.textColor = .tertiaryLabel
        } else {
            venmoIconView.alpha = 1
            recipientLabel.text = "Paying \(VenmoPaymentHandler.displayUsername(username))"
            recipientLabel.textColor = .secondaryLabel
        }
    }

    // MARK: - Collection View

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.keyboardDismissMode = .interactive
        collectionView.delegate = self

        let bottomInset: CGFloat = 140
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset - 30, right: 0)

        view.addSubview(collectionView)
    }

    private func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, layoutEnvironment in
            var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            config.headerMode = .supplementary
            config.footerMode = .supplementary

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

            let footerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(44)
            )
            let footer = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: footerSize,
                elementKind: UICollectionView.elementKindSectionFooter,
                alignment: .bottom
            )

            section.boundarySupplementaryItems = [header, footer]
            return section
        }
    }

    private func sectionTitle(for section: Section) -> String {
        switch section {
        case .duration: return "Duration"
        case .hourlyRate: return "Hourly Rate"
        case .total: return "Total"
        }
    }

    private func sectionFooterText(for section: Section) -> String {
        switch section {
        case .total:
            return totalSectionFooterText()
        case .duration, .hourlyRate:
            return ""
        }
    }

    private func configureDataSource() {
        let headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] headerView, _, indexPath in
            guard let self, let section = dataSource.sectionIdentifier(for: indexPath.section) else { return }
            headerView.configure(title: sectionTitle(for: section))
        }

        let footerRegistration = UICollectionView.SupplementaryRegistration<SectionFooterView>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] footerView, _, indexPath in
            guard let self, let section = dataSource.sectionIdentifier(for: indexPath.section) else { return }
            let text = sectionFooterText(for: section)
            footerView.configure(text: text, isLink: false)
        }

        let durationRegistration = UICollectionView.CellRegistration<SessionPaymentDurationCell, Item> { [weak self] cell, _, _ in
            guard let self else { return }
            let minutes = SessionPaymentCalculator.minutes(fromHours: draft.hours)
            cell.onValueChanged = { [weak self] minutes in
                guard let self else { return }
                draft.hours = SessionPaymentCalculator.hours(fromMinutes: minutes)
                syncDraftFromFields()
                reloadSummaryItems()
            }
            cell.configure(minutes: minutes)
        }

        let hourlyRateRegistration = UICollectionView.CellRegistration<SessionPaymentHourlyRateCell, Item> { [weak self] cell, _, _ in
            guard let self else { return }
            cell.onValueChanged = { [weak self] cents in
                guard let self else { return }
                draft.hourlyRateCents = cents
                syncDraftFromFields()
                reloadSummaryItems()
            }
            cell.configure(cents: draft.hourlyRateCents)
        }

        let totalRegistration = UICollectionView.CellRegistration<SessionPaymentTotalCell, Item> { [weak self] cell, _, _ in
            guard let self else { return }
            cell.configure(
                breakdownText: summaryBreakdownText(),
                breakdownAmount: formattedTotal(),
                totalAmount: formattedTotal()
            )
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .duration:
                return collectionView.dequeueConfiguredReusableCell(using: durationRegistration, for: indexPath, item: item)
            case .hourlyRate:
                return collectionView.dequeueConfiguredReusableCell(using: hourlyRateRegistration, for: indexPath, item: item)
            case .total:
                return collectionView.dequeueConfiguredReusableCell(using: totalRegistration, for: indexPath, item: item)
            }
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            if kind == UICollectionView.elementKindSectionHeader {
                return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            }
            if kind == UICollectionView.elementKindSectionFooter {
                return collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
            }
            return nil
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.duration, .hourlyRate, .total])
        snapshot.appendItems([.duration], toSection: .duration)
        snapshot.appendItems([.hourlyRate], toSection: .hourlyRate)
        snapshot.appendItems([.total], toSection: .total)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func reloadSummaryItems() {
        var snapshot = dataSource.snapshot()
        if snapshot.itemIdentifiers.contains(.total) {
            snapshot.reloadItems([.total])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
        updatePayButtonState()
    }

    // MARK: - State

    private func formattedTotal() -> String {
        SessionPaymentCalculator.formatDollars(fromCents: draft.totalCents, includeCentsIfWhole: true)
    }

    private func summaryBreakdownText() -> String {
        let hours = SessionPaymentCalculator.formatHoursInput(draft.hours)
        guard draft.hourlyRateCents > 0 else { return "Set hourly rate" }
        let rate = SessionPaymentCalculator.formatCurrencyInput(draft.hourlyRateCents)
        return "\(hours) hrs × \(rate)/hr"
    }

    private func totalSectionFooterText() -> String {
        if let username = configuration.venmoUsername, !username.isEmpty {
            return "Opens Venmo with \(formattedTotal()) pre-filled."
        }
        return "\(configuration.sitterName) hasn't added Venmo yet."
    }

    private func syncDraftFromFields() {
        draft.mode = .hourly
        draft.numberOfKids = 1
        draft.extraPerAdditionalKidHourlyCents = 0
    }

    private func updatePayButtonState() {
        let hasVenmo = !(configuration.venmoUsername ?? "").isEmpty
        payButton.isEnabled = draft.totalCents > 0 && hasVenmo
        payButton.alpha = payButton.isEnabled ? 1 : 0.5
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func payButtonTapped() {
        guard let venmoUsername = configuration.venmoUsername, !venmoUsername.isEmpty else {
            showToast(text: "No Venmo username on file")
            return
        }

        syncDraftFromFields()
        guard draft.totalCents > 0 else {
            showToast(text: "Enter a payment amount")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let note = "NestNote: \(configuration.sessionTitle) – \(dateFormatter.string(from: configuration.startDate))"

        VenmoPaymentHandler.payWithVenmo(
            username: venmoUsername,
            note: note,
            amountCents: draft.totalCents
        )

        Task {
            try? await SessionService.shared.cancelPaymentReminder(
                nestID: configuration.nestId,
                sessionID: configuration.sessionId
            )
        }
    }
}

// MARK: - UICollectionViewDelegate

extension SessionPaymentViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        false
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}
