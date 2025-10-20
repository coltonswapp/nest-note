//
//  ReferralAnalyticsViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 9/9/25.
//

import UIKit

final class ReferralAnalyticsViewController: NNViewController, UICollectionViewDelegate {

    // MARK: - Properties
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<NNSectionHeaderView>!

    private var analytics: ReferralAnalytics?
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Referral Analytics"
        view.backgroundColor = .systemGroupedBackground

        configureCollectionView()
        configureDataSource()
        configureActivityIndicator()
        loadReferralData()

        collectionView.delegate = self
    }

    // MARK: - Setup
    private func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        view.addSubview(collectionView)
    }

    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnvironment in
            guard let self = self,
                  let sectionIdentifier = self.dataSource?.snapshot().sectionIdentifiers[safe: sectionIndex] else {
                // Default list configuration
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.headerMode = .supplementary
                return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
            }

            switch sectionIdentifier {
            case .summary:
                return self.createSummarySection()
            case .topCodes, .recentReferrals:
                return self.createListSection()
            }
        }
    }

    private func createSummarySection() -> NSCollectionLayoutSection {
        // Create item
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(120))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        // Create group
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(120))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        // Create section
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)

        return section
    }

    private func createListSection() -> NSCollectionLayoutSection {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary

        let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: NSCollectionLayoutEnvironment(container: collectionView, traitCollection: traitCollection))

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

    private func configureDataSource() {
        // Header registration
        headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] (headerView, string, indexPath) in
            guard let section = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            headerView.configure(title: section.title)
        }

        // Cell registrations
        let summaryCellRegistration = UICollectionView.CellRegistration<SummaryCell, Item> { cell, indexPath, item in
            if case let .summaryCard(totalReferrals, activeCodes, thisMonth) = item {
                cell.configure(totalReferrals: totalReferrals, activeCodes: activeCodes, thisMonth: thisMonth)
            }
        }

        let topCodeCellRegistration = UICollectionView.CellRegistration<TopCodeCell, Item> { cell, indexPath, item in
            if case let .topCode(rank, code, count) = item {
                cell.configure(rank: rank, code: code, count: count)
            }
        }

        let recentReferralCellRegistration = UICollectionView.CellRegistration<RecentReferralCell, Item> { cell, indexPath, item in
            if case let .recentReferral(code, date, email) = item {
                cell.configure(code: code, date: date, email: email)
            }
        }

        // Data source
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .summaryCard:
                return collectionView.dequeueConfiguredReusableCell(using: summaryCellRegistration, for: indexPath, item: item)
            case .topCode:
                return collectionView.dequeueConfiguredReusableCell(using: topCodeCellRegistration, for: indexPath, item: item)
            case .recentReferral:
                return collectionView.dequeueConfiguredReusableCell(using: recentReferralCellRegistration, for: indexPath, item: item)
            }
        }

        dataSource.supplementaryViewProvider = { [weak self] (collectionView, kind, indexPath) in
            return collectionView.dequeueConfiguredReusableSupplementary(using: self!.headerRegistration, for: indexPath)
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

    // MARK: - Data Loading
    private func loadReferralData() {
        Task {
            do {
                let analytics = try await ReferralService.shared.getAllReferralsAnalytics()

                await MainActor.run {
                    self.analytics = analytics
                    self.applySnapshot(with: analytics)
                    self.loadingIndicator.stopAnimating()
                    self.loadingIndicator.isHidden = true
                }
            } catch {
                await MainActor.run {
                    Logger.log(level: .error, category: .referral, message: "Failed to load referrals analytics: \(error)")
                    self.loadingIndicator.stopAnimating()
                    self.loadingIndicator.isHidden = true
                }
            }
        }
    }

    private func applySnapshot(with analytics: ReferralAnalytics) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()

        // Add sections
        snapshot.appendSections([.summary, .topCodes, .recentReferrals])

        // Summary section
        let summaryItem = Item.summaryCard(
            totalReferrals: analytics.totalReferrals,
            activeCodes: analytics.totalActiveCodes,
            thisMonth: analytics.thisMonthReferrals
        )
        snapshot.appendItems([summaryItem], toSection: .summary)

        // Top codes section
        let topCodeItems = analytics.topCodes.enumerated().map { index, codeData in
            Item.topCode(rank: index + 1, code: codeData.code, count: codeData.count)
        }
        snapshot.appendItems(topCodeItems, toSection: .topCodes)

        // Recent referrals section - take 25 most recent
        let recentItems = analytics.recentReferrals.prefix(25).map { referral in
            Item.recentReferral(code: referral.referralCode, date: referral.date, email: referral.userEmail)
        }
        snapshot.appendItems(recentItems, toSection: .recentReferrals)

        dataSource.apply(snapshot, animatingDifferences: true)
    }

    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }

    // MARK: - Types

    enum Section: Hashable {
        case summary, topCodes, recentReferrals

        var title: String {
            switch self {
            case .summary: return ""
            case .topCodes: return "Top Performing Codes"
            case .recentReferrals: return "Recent Referrals"
            }
        }
    }

    enum Item: Hashable {
        case summaryCard(totalReferrals: Int, activeCodes: Int, thisMonth: Int)
        case topCode(rank: Int, code: String, count: Int)
        case recentReferral(code: String, date: Date, email: String)
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

    private let totalReferralsLabel: UILabel = {
        let label = UILabel()
        label.text = "Total Referrals"
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private let totalReferralsCountLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private let activeCodesLabel: UILabel = {
        let label = UILabel()
        label.text = "Active Codes"
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private let activeCodesCountLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .systemGreen
        label.textAlignment = .center
        return label
    }()

    private let thisMonthLabel: UILabel = {
        let label = UILabel()
        label.text = "This Month"
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private let thisMonthCountLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .systemBlue
        label.textAlignment = .center
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
        contentView.addSubview(cardView)
        cardView.addSubview(summaryStackView)

        // Create summary sections
        let totalSection = createSummarySection(titleLabel: totalReferralsLabel, countLabel: totalReferralsCountLabel)
        let activeSection = createSummarySection(titleLabel: activeCodesLabel, countLabel: activeCodesCountLabel)
        let monthSection = createSummarySection(titleLabel: thisMonthLabel, countLabel: thisMonthCountLabel)

        summaryStackView.addArrangedSubview(totalSection)
        summaryStackView.addArrangedSubview(activeSection)
        summaryStackView.addArrangedSubview(monthSection)

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

    private func createSummarySection(titleLabel: UILabel, countLabel: UILabel) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, countLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .center
        return stackView
    }

    func configure(totalReferrals: Int, activeCodes: Int, thisMonth: Int) {
        totalReferralsCountLabel.text = "\(totalReferrals)"
        activeCodesCountLabel.text = "\(activeCodes)"
        thisMonthCountLabel.text = "\(thisMonth)"
    }
}

private class TopCodeCell: UICollectionViewListCell {

    private let rankLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .left
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private let codeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .left
        return label
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = .systemBlue
        label.textAlignment = .right
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [rankLabel, codeLabel, countLabel])
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
        contentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -4)
        ])
    }

    func configure(rank: Int, code: String, count: Int) {
        // Use medal emojis for top 3
        let rankEmoji = ["🥇", "🥈", "🥉"]
        let rankText = rank <= 3 ? rankEmoji[rank - 1] : "\(rank)."

        rankLabel.text = rankText
        codeLabel.text = code
        countLabel.text = "\(count) uses"
    }
}

private class RecentReferralCell: UICollectionViewListCell {

    private let codeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private let emailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemGreen
        label.textAlignment = .right
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private lazy var leftStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [codeLabel, emailLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        return stack
    }()

    private lazy var mainStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [leftStackView, dateLabel])
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
            mainStackView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -4)
        ])
    }

    func configure(code: String, date: Date, email: String) {
        codeLabel.text = code
        emailLabel.text = email

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateLabel.text = dateFormatter.string(from: date)
    }
}

// MARK: - Array Extension for Safe Access
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
