//
//  TipResetViewController.swift
//  nest-note
//
//  Debug screen to re-show individual tips or entire tip sections.
//

import UIKit

final class TipResetViewController: NNViewController, UICollectionViewDelegate {

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    private struct Section: Hashable {
        let title: String
        let tipCount: Int
        let dismissedCount: Int
    }

    private enum Item: Hashable {
        case resetSection(sectionTitle: String)
        /// `isDismissed` is part of identity so cells refresh after a reset.
        case tip(
            id: String,
            title: String,
            systemImageName: String,
            audience: String,
            criteria: String,
            isDismissed: Bool
        )
    }

    override func setup() {
        navigationItem.title = "Reset Tooltips"
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    override func setupNavigationBarButtons() {
        let resetAll = UIBarButtonItem(
            title: "Reset All",
            style: .plain,
            target: self,
            action: #selector(resetAllTapped)
        )
        resetAll.tintColor = .systemRed
        navigationItem.rightBarButtonItem = resetAll
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        configureDataSource()
        applySnapshot()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applySnapshot(animatingDifferences: false)
    }

    // MARK: - Collection View

    private func setupCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        config.footerMode = .none

        let layout = UICollectionViewCompositionalLayout.list(using: config)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, item in
            switch item {
            case .resetSection(let title):
                var content = cell.defaultContentConfiguration()
                content.text = "Reset “\(title)” Section"
                content.textProperties.color = .systemBlue
                content.image = UIImage(systemName: "arrow.counterclockwise")
                content.imageProperties.tintColor = .systemBlue
                cell.contentConfiguration = content
                cell.accessories = []

            case .tip(_, let title, let systemImageName, let audience, let criteria, let isDismissed):
                let status = isDismissed ? "Dismissed — tap to re-show" : "Not dismissed"
                var content = cell.defaultContentConfiguration()
                content.text = title
                content.secondaryText = "\(audience) · \(criteria)\n\(status)"
                content.secondaryTextProperties.color = isDismissed ? .systemOrange : .secondaryLabel
                content.secondaryTextProperties.numberOfLines = 0
                content.image = UIImage(systemName: systemImageName)
                content.imageProperties.tintColor = isDismissed ? .systemOrange : .secondaryLabel
                cell.contentConfiguration = content
                cell.accessories = [
                    .label(
                        text: isDismissed ? "Reset" : "Active",
                        options: .init(tintColor: isDismissed ? .systemBlue : .tertiaryLabel)
                    )
                ]
            }
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] headerView, _, indexPath in
            guard let section = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }

            var content = headerView.defaultContentConfiguration()
            content.text = section.title
            content.secondaryText = section.dismissedCount == 0
                ? "\(section.tipCount) tip\(section.tipCount == 1 ? "" : "s")"
                : "\(section.dismissedCount) of \(section.tipCount) dismissed"
            content.textProperties.font = .preferredFont(forTextStyle: .headline)
            content.secondaryTextProperties.color = .secondaryLabel
            headerView.contentConfiguration = content
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration,
                for: indexPath,
                item: item
            )
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionHeader else { return nil }
            return collectionView.dequeueConfiguredReusableSupplementary(
                using: headerRegistration,
                for: indexPath
            )
        }
    }

    private func applySnapshot(animatingDifferences: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        for catalogSection in NNTipCatalog.sections {
            let dismissedCount = catalogSection.tips.filter { NNTipManager.shared.isTipDismissed($0) }.count
            let section = Section(
                title: catalogSection.title,
                tipCount: catalogSection.tips.count,
                dismissedCount: dismissedCount
            )
            snapshot.appendSections([section])
            snapshot.appendItems([.resetSection(sectionTitle: catalogSection.title)], toSection: section)
            let tipItems = catalogSection.tips.map { tip in
                Item.tip(
                    id: tip.id,
                    title: tip.title,
                    systemImageName: tip.systemImageName,
                    audience: tip.audience.rawValue,
                    criteria: tip.criteria,
                    isDismissed: NNTipManager.shared.isTipDismissed(tip)
                )
            }
            snapshot.appendItems(tipItems, toSection: section)
        }
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    // MARK: - Actions

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath),
              let section = dataSource.sectionIdentifier(for: indexPath.section),
              let catalogSection = NNTipCatalog.sections.first(where: { $0.title == section.title }) else {
            return
        }

        switch item {
        case .resetSection:
            resetSection(catalogSection)
        case .tip(let id, let title, _, _, _, let isDismissed):
            guard let tip = catalogSection.tips.first(where: { $0.id == id }) else { return }
            resetTip(tip, title: title, isDismissed: isDismissed)
        }
    }

    private func resetTip(_ tip: NNTipModel, title: String, isDismissed: Bool) {
        guard isDismissed else {
            showToast(text: "Already eligible to show")
            return
        }
        NNTipManager.shared.resetTip(tip)
        applySnapshot()
        showToast(text: "“\(title)” will show again", sentiment: .positive)
    }

    private func resetSection(_ section: NNTipSection) {
        let dismissed = section.tips.filter { NNTipManager.shared.isTipDismissed($0) }
        guard !dismissed.isEmpty else {
            showToast(text: "No dismissed tips in \(section.title)")
            return
        }
        NNTipManager.shared.resetSection(section)
        applySnapshot()
        showToast(
            text: "Reset \(dismissed.count) tip\(dismissed.count == 1 ? "" : "s") in \(section.title)",
            sentiment: .positive
        )
    }

    @objc private func resetAllTapped() {
        let alert = UIAlertController(
            title: "Reset All Tooltips",
            message: "Clear every dismissed tip and visit/action tracking so tips can show again from scratch.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset All", style: .destructive) { [weak self] _ in
            NNTipManager.shared.resetAllTips()
            self?.applySnapshot()
            self?.showToast(text: "All tooltips reset", sentiment: .positive)
        })
        present(alert, animated: true)
    }
}
