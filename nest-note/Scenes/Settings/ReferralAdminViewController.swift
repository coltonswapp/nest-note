//
//  ReferralAdminViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 9/9/25.
//

import UIKit

final class ReferralAdminViewController: NNViewController, UICollectionViewDelegate {

    // MARK: - Properties

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<NNSectionHeaderView>!

    private var referralCodes: [ReferralCodeRecord] = []
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        configureCollectionView()
        configureDataSource()
        configureActivityIndicator()

        super.viewDidLoad()

        title = "Referral Admin"
        view.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self

        Task {
            await loadReferralCodes(showLoading: true)
        }
    }

    // MARK: - Setup

    private func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        view.addSubview(collectionView)

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    private func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnvironment in
            guard let self,
                  let sectionIdentifier = self.dataSource?.snapshot().sectionIdentifiers[safe: sectionIndex] else {
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.headerMode = .supplementary
                return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
            }

            switch sectionIdentifier {
            case .summary:
                return self.createSummarySection()
            case .actions, .existingCodes:
                return self.createListSection(layoutEnvironment: layoutEnvironment)
            }
        }
    }

    private func createSummarySection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(120))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(120))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        return section
    }

    private func createListSection(layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary

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

    private func configureDataSource() {
        headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] headerView, _, indexPath in
            guard let section = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            headerView.configure(title: section.title)
        }

        let summaryCellRegistration = UICollectionView.CellRegistration<SummaryCell, Item> { cell, _, item in
            if case let .summaryCard(total, active, inactive) = item {
                cell.configure(totalCodes: total, activeCodes: active, inactiveCodes: inactive)
            }
        }

        let createActionCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, _ in
            var content = cell.defaultContentConfiguration()
            content.text = "Create New Referral Code"
            content.secondaryText = "Add a creator code for paywall attribution"
            content.directionalLayoutMargins.top = 16
            content.directionalLayoutMargins.bottom = 16
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
        }

        let referralCodeCellRegistration = UICollectionView.CellRegistration<ReferralCodeCell, Item> { cell, _, item in
            if case let .referralCode(record) = item {
                cell.configure(with: record)
            }
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .summaryCard:
                return collectionView.dequeueConfiguredReusableCell(using: summaryCellRegistration, for: indexPath, item: item)
            case .createAction:
                return collectionView.dequeueConfiguredReusableCell(using: createActionCellRegistration, for: indexPath, item: item)
            case .referralCode:
                return collectionView.dequeueConfiguredReusableCell(using: referralCodeCellRegistration, for: indexPath, item: item)
            }
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: self!.headerRegistration, for: indexPath)
        }
    }

    private func configureActivityIndicator() {
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        loadingIndicator.startAnimating()
    }

    // MARK: - Data

    @objc private func refreshData() {
        Task {
            await loadReferralCodes(showLoading: false)
            await MainActor.run {
                collectionView.refreshControl?.endRefreshing()
            }
        }
    }

    private func loadReferralCodes(showLoading: Bool) async {
        do {
            let codes = try await ReferralService.shared.getAllReferralCodes()
            let records = codes
                .map(ReferralCodeRecord.init)
                .sorted { $0.createdAt > $1.createdAt }

            await MainActor.run {
                referralCodes = records
                applySnapshot()
                if showLoading {
                    loadingIndicator.stopAnimating()
                    loadingIndicator.isHidden = true
                }
            }
        } catch {
            await MainActor.run {
                Logger.log(level: .error, category: .referral, message: "Failed to load referral codes: \(error)")
                if showLoading {
                    loadingIndicator.stopAnimating()
                    loadingIndicator.isHidden = true
                }
                showToast(text: "Failed to load referral codes", sentiment: .negative)
            }
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.summary, .actions, .existingCodes])

        let activeCount = referralCodes.filter(\.isActive).count
        let inactiveCount = referralCodes.count - activeCount
        snapshot.appendItems([
            .summaryCard(total: referralCodes.count, active: activeCount, inactive: inactiveCount)
        ], toSection: .summary)

        snapshot.appendItems([.createAction], toSection: .actions)

        let codeItems = referralCodes.map { Item.referralCode($0) }
        snapshot.appendItems(codeItems, toSection: .existingCodes)

        dataSource.apply(snapshot, animatingDifferences: true)
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .createAction:
            let createVC = ReferralCodeCreateViewController { [weak self] in
                Task {
                    await self?.loadReferralCodes(showLoading: false)
                }
            }
            navigationController?.pushViewController(createVC, animated: true)

        case .referralCode(let record):
            presentCodeDetail(for: record)

        case .summaryCard:
            break
        }
    }

    private func presentCodeDetail(for record: ReferralCodeRecord) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let statusText = record.isActive ? "Active" : "Inactive"
        let emailText = record.creatorEmail.isEmpty ? "None" : record.creatorEmail

        let alert = UIAlertController(
            title: record.code,
            message: """
            Creator: \(record.creatorName)
            Email: \(emailText)
            Status: \(statusText)
            Created: \(dateFormatter.string(from: record.createdAt))
            """,
            preferredStyle: .alert
        )

        if record.isActive {
            alert.addAction(UIAlertAction(title: "Deactivate", style: .destructive) { [weak self] _ in
                self?.deactivateCode(record.code)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func deactivateCode(_ code: String) {
        Task {
            do {
                try await ReferralService.shared.deactivateReferralCode(code)
                await MainActor.run {
                    showToast(text: "Referral code deactivated")
                    Task {
                        await self.loadReferralCodes(showLoading: false)
                    }
                }
            } catch {
                await MainActor.run {
                    showToast(text: "Failed to deactivate code", sentiment: .negative)
                }
            }
        }
    }
}

// MARK: - Types

private extension ReferralAdminViewController {
    struct ReferralCodeRecord: Hashable {
        let code: String
        let creatorName: String
        let creatorEmail: String
        let isActive: Bool
        let createdAt: Date

        init(code: String, creatorName: String, creatorEmail: String, isActive: Bool, createdAt: Date) {
            self.code = code
            self.creatorName = creatorName
            self.creatorEmail = creatorEmail
            self.isActive = isActive
            self.createdAt = createdAt
        }

        init(tuple: (code: String, creatorName: String, creatorEmail: String, isActive: Bool, createdAt: Date)) {
            self.init(
                code: tuple.code,
                creatorName: tuple.creatorName,
                creatorEmail: tuple.creatorEmail,
                isActive: tuple.isActive,
                createdAt: tuple.createdAt
            )
        }
    }

    enum Section: Hashable {
        case summary
        case actions
        case existingCodes

        var title: String {
            switch self {
            case .summary: return ""
            case .actions: return "Actions"
            case .existingCodes: return "Existing Referral Codes"
            }
        }
    }

    enum Item: Hashable {
        case summaryCard(total: Int, active: Int, inactive: Int)
        case createAction
        case referralCode(ReferralCodeRecord)
    }
}

// MARK: - Create Form

private final class ReferralCodeCreateViewController: NNViewController {

    private let onCreated: (() -> Void)?

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Create a referral code for a creator or partner. Codes are used during onboarding and paywall attribution."
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let codeTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Code (e.g., HEIDI, SYDNEY)"
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .allCharacters
        return textField
    }()

    private let creatorNameTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Creator Name"
        textField.autocorrectionType = .no
        return textField
    }()

    private let creatorEmailTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Creator Email (Optional)"
        textField.keyboardType = .emailAddress
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        return textField
    }()

    private let notesTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Notes (Optional)"
        textField.autocorrectionType = .no
        return textField
    }()

    private let createButton: NNPrimaryLabeledButton = {
        NNPrimaryLabeledButton(title: "Create Referral Code")
    }()

    init(onCreated: (() -> Void)? = nil) {
        self.onCreated = onCreated
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Create Code"
        view.backgroundColor = .systemGroupedBackground

        setupUI()
        setupConstraints()
        createButton.addTarget(self, action: #selector(createButtonTapped), for: .touchUpInside)
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        [descriptionLabel, codeTextField, creatorNameTextField, creatorEmailTextField, notesTextField, createButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentStackView.addArrangedSubview($0)
        }
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48),

            codeTextField.heightAnchor.constraint(equalToConstant: 50),
            creatorNameTextField.heightAnchor.constraint(equalToConstant: 50),
            creatorEmailTextField.heightAnchor.constraint(equalToConstant: 50),
            notesTextField.heightAnchor.constraint(equalToConstant: 50),
            createButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc private func createButtonTapped() {
        guard let code = codeTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty,
              let creatorName = creatorNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !creatorName.isEmpty else {
            showToast(text: "Enter both code and creator name", sentiment: .negative)
            return
        }

        let creatorEmail = creatorEmailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = notesTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        createButton.isEnabled = false

        Task {
            do {
                try await ReferralService.shared.createReferralCode(
                    code,
                    creatorName: creatorName,
                    creatorEmail: creatorEmail?.isEmpty == true ? nil : creatorEmail,
                    notes: notes?.isEmpty == true ? nil : notes
                )

                await MainActor.run {
                    showToast(text: "Referral code created")
                    onCreated?()
                    navigationController?.popViewController(animated: true)
                }
            } catch {
                await MainActor.run {
                    showToast(text: "Failed to create code", sentiment: .negative)
                    createButton.isEnabled = true
                }
            }
        }
    }
}

// MARK: - Custom Cells

private class SummaryCell: UICollectionViewCell {

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.label.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let summaryStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 20
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let totalTitleLabel = SummaryCell.makeTitleLabel("Total Codes")
    private let totalCountLabel = SummaryCell.makeCountLabel(color: .label)
    private let activeTitleLabel = SummaryCell.makeTitleLabel("Active")
    private let activeCountLabel = SummaryCell.makeCountLabel(color: .systemGreen)
    private let inactiveTitleLabel = SummaryCell.makeTitleLabel("Inactive")
    private let inactiveCountLabel = SummaryCell.makeCountLabel(color: .systemOrange)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(cardView)
        cardView.addSubview(summaryStackView)

        [
            makeSection(titleLabel: totalTitleLabel, countLabel: totalCountLabel),
            makeSection(titleLabel: activeTitleLabel, countLabel: activeCountLabel),
            makeSection(titleLabel: inactiveTitleLabel, countLabel: inactiveCountLabel)
        ].forEach { summaryStackView.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            cardView.heightAnchor.constraint(equalToConstant: 100),

            summaryStackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            summaryStackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            summaryStackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            summaryStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    private func makeSection(titleLabel: UILabel, countLabel: UILabel) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, countLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .center
        return stackView
    }

    func configure(totalCodes: Int, activeCodes: Int, inactiveCodes: Int) {
        totalCountLabel.text = "\(totalCodes)"
        activeCountLabel.text = "\(activeCodes)"
        inactiveCountLabel.text = "\(inactiveCodes)"
    }

    private static func makeTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }

    private static func makeCountLabel(color: UIColor) -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = color
        label.textAlignment = .center
        return label
    }
}

private class ReferralCodeCell: UICollectionViewListCell {

    private let codeLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.textColor = .label
        return label
    }()

    private let creatorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .right
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private let createdLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        return label
    }()

    private lazy var textStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [codeLabel, creatorLabel, createdLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        return stack
    }()

    private lazy var mainStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [textStackView, statusLabel])
        stack.axis = .horizontal
        stack.spacing = 12
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
        contentView.addSubview(mainStackView)
        mainStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mainStackView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            mainStackView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 8),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -8)
        ])

        accessories = [.disclosureIndicator()]
    }

    func configure(with record: ReferralAdminViewController.ReferralCodeRecord) {
        codeLabel.text = record.code
        creatorLabel.text = record.creatorName
        statusLabel.text = record.isActive ? "Active" : "Inactive"
        statusLabel.textColor = record.isActive ? .systemGreen : .systemOrange

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        createdLabel.text = "Created \(dateFormatter.string(from: record.createdAt))"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
