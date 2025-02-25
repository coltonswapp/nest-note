//
//  NestViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 10/17/24.
//

import UIKit

class NestViewController: NNViewController, NestLoadable {
    var loadingIndicator: UIActivityIndicatorView!
    var hasLoadedInitialData: Bool = false
    var refreshControl: UIRefreshControl!
    
    private enum Section: Int, CaseIterable {
        case address
        case main
        case routine
    }
    
    private struct Item: Hashable {
        let title: String
        let icon: String
        var entries: [BaseEntry]?
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
        }
        
        static func == (lhs: Item, rhs: Item) -> Bool {
            return lhs.title == rhs.title
        }
    }
    
    private var dataSource: UICollectionViewDiffableDataSource<Section, AnyHashable>!
    var collectionView: UICollectionView!
    
    private var mainItems: [Item] {
        guard let categories = NestService.shared.currentNest?.categories else { return [] }
        
        return categories
            .sorted { cat1, cat2 in
                if cat1.name == "Other" { return false }
                if cat2.name == "Other" { return true }
                return cat1.name < cat2.name
            }
            .map { category in
                Item(
                    title: category.name,
                    icon: category.symbolName,
                    entries: entries?[category.name]
                )
            }
    }
    
    private let routineItems: [Item] = [
        Item(title: "Wake Up", icon: "sunrise.fill"),
        Item(title: "Night Time", icon: "moon.stars.fill"),
        Item(title: "School", icon: "backpack.fill"),
        Item(title: "Extra Curricular", icon: "figure.run")
    ]
    
    private var entries: [String: [BaseEntry]]?
    
    private let sectionHeaders = ["", "Information Categories", "Routines"]
    
    private var newCategoryButton: NNPrimaryLabeledButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Nest"
        configureCollectionView()
        setupLoadingIndicator()
        setupRefreshControl()
        configureDataSource()
        setupNavigationBar()
        setupNewCategoryButton()
        collectionView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !hasLoadedInitialData {
            Task {
                await loadEntries()
            }
        }
    }
    
    func handleLoadedEntries(_ groupedEntries: [String: [BaseEntry]]) {
        self.entries = groupedEntries
        applyInitialSnapshots()
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshEntries), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    @objc private func refreshEntries() {
        Task {
            do {
                async let categoriesTask = NestService.shared.fetchCategories()
                async let entriesTask = NestService.shared.refreshEntries()
                
                let (_, groupedEntries) = try await (categoriesTask, entriesTask)
                await MainActor.run {
                    self.entries = groupedEntries
                    self.applyInitialSnapshots()
                    self.refreshControl.endRefreshing()
                }
            } catch {
                Logger.log(level: .error, category: .nestService, message: "Failed to refresh: \(error)")
                await MainActor.run {
                    self.refreshControl.endRefreshing()
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func configureCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)
        
        collectionView.register(AddressCell.self, forCellWithReuseIdentifier: AddressCell.reuseIdentifier)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnvironment in
            guard let self = self else { return nil }
            
            let section = Section(rawValue: sectionIndex)!
            
            switch section {
            case .address:
                // Create custom layout for address section
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(60) // Adjust this value as needed
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(60)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: 8,
                    leading: 18,
                    bottom: 0, // Reduced bottom spacing
                    trailing: 18
                )
                
                return section
                
            case .main, .routine:
                // Use existing insetGrouped layout for other sections
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
        }
    }
    
    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, indexPath, item in
            var content = cell.defaultContentConfiguration()
            content.text = item.title
            
            let symbolConfiguration = UIImage.SymbolConfiguration(weight: .bold)
            let image = UIImage(systemName: item.icon, withConfiguration: symbolConfiguration)?
                .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
            content.image = image
            
            content.imageProperties.tintColor = NNColors.primary
            content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
            content.imageToTextPadding = 16
            
            content.directionalLayoutMargins.top = 16
            content.directionalLayoutMargins.bottom = 16
            
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
        }
        
        let addressRegistration = UICollectionView.CellRegistration<AddressCell, String> { [weak self] cell, indexPath, address in
            cell.configure(address: address)
            cell.delegate = self
        }
        
        let headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] (headerView, string, indexPath) in
            guard let self = self else { return }
            headerView.configure(title: self.sectionHeaders[indexPath.section])
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, AnyHashable>(collectionView: collectionView) { collectionView, indexPath, item in
            if indexPath.section == Section.address.rawValue {
                return collectionView.dequeueConfiguredReusableCell(
                    using: addressRegistration,
                    for: indexPath,
                    item: item as? String
                )
            } else {
                return collectionView.dequeueConfiguredReusableCell(
                    using: cellRegistration,
                    for: indexPath,
                    item: item as? Item
                )
            }
        }
        
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }
    
    private func setupNavigationBar() {
    }
    
    @objc private func addButtonTapped() {
        let buttonFrame = newCategoryButton.convert(newCategoryButton.bounds, to: nil)
        let categoryVC = CategoryDetailViewController(sourceFrame: buttonFrame)
        categoryVC.categoryDelegate = self
        present(categoryVC, animated: true)
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, AnyHashable>()
        snapshot.appendSections([.address, .main, .routine])
        
        if let address = NestService.shared.currentNest?.address {
            snapshot.appendItems([address], toSection: .address)
        }
        
        snapshot.appendItems(mainItems, toSection: .main)
        snapshot.appendItems(routineItems, toSection: .routine)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func setupNewCategoryButton() {
        newCategoryButton = NNPrimaryLabeledButton(title: "New Category", image: UIImage(systemName: "plus"))
        newCategoryButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        newCategoryButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        
        let buttonHeight: CGFloat = 55
        let buttonPadding: CGFloat = 10
        let totalInset = buttonHeight + buttonPadding * 2
        collectionView.contentInset.bottom = totalInset
        collectionView.verticalScrollIndicatorInsets.bottom = totalInset
    }
}

extension NestViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        // Skip navigation for address section
        if indexPath.section == Section.address.rawValue { return }
        
        // Cast the item to Item type for category sections
        guard let categoryItem = item as? Item else { return }
        let nestCategoryViewController = NestCategoryViewController(category: categoryItem.title)
        navigationController?.pushViewController(nestCategoryViewController, animated: true)
    }
}

extension NestViewController: CategoryDetailViewControllerDelegate {
    func categoryDetailViewController(_ controller: CategoryDetailViewController, didSaveCategory category: String?) {
        guard let categoryName = category else { return }
        
        Task {
            do {
                // Create and save the new category
                let newCategory = NestCategory(name: categoryName, symbolName: "folder")
                try await NestService.shared.createCategory(newCategory)
                
                // Refresh the categories
                async let categoriesTask = NestService.shared.fetchCategories()
                async let entriesTask = NestService.shared.refreshEntries()
                
                let (_, groupedEntries) = try await (categoriesTask, entriesTask)
                
                await MainActor.run {
                    self.entries = groupedEntries
                    self.applyInitialSnapshots()
                    self.showToast(text: "Category Created")
                }
            } catch {
                Logger.log(level: .error, category: .nestService, message: "Failed to create category: \(error)")
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
}

extension NestViewController: AddressCellDelegate {
    func addressCell(_ cell: AddressCell, didTapAddress address: String) {
        // We don't have coordinates for the nest address, so we'll let
        // AddressActionHandler handle the geocoding
        AddressActionHandler.presentAddressOptions(
            from: self,
            sourceView: cell,
            address: address,
            onCopy: { [weak cell] in
                cell?.showCopyFeedback()
            }
        )
    }
}

extension NestViewController {
    func handleLoadedData() {
        return
    }
}
