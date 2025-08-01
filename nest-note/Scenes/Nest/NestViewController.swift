//
//  NestViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 10/17/24.
//

import UIKit
import RevenueCat
import RevenueCatUI

class NestViewController: NNViewController, NestLoadable, PaywallPresentable, PaywallViewControllerDelegate, NNTippable {
    var loadingIndicator: UIActivityIndicatorView!
    var hasLoadedInitialData: Bool = false
    var refreshControl: UIRefreshControl!
    
    private enum Section: Int, CaseIterable {
        case address
        case main
    }
    
    private var dataSource: UICollectionViewDiffableDataSource<Section, AnyHashable>!
    var collectionView: UICollectionView!
    
    private var categories: [NestCategory] = []
    private var currentFolderPath: String = "" // Empty string means root level
    
    // MARK: - Folder Support
    private var folders: [FolderData] {
        return getFoldersForCurrentPath()
    }
    
    
    // MARK: - Folder Parsing Methods
    
    private func getFoldersForCurrentPath() -> [FolderData] {
        guard let entries = entries else { return [] }
        
        var folderItems: [FolderData] = []
        var folderCounts: [String: Int] = [:]
        
        // Get all unique folder paths at the current level
        var currentLevelFolders: Set<String> = []
        
        // Step 1: Add only top-level categories as potential folders at root level
        if currentFolderPath.isEmpty {
            // At root level, show only top-level categories (no "/" in name)
            for category in categories {
                if !category.name.contains("/") {
                    currentLevelFolders.insert(category.name)
                }
            }
        }
        
        // Step 2: Count all entries and places for each folder
        Logger.log(level: .info, category: .general, message: "FOLDER COUNT DEBUG: Counting items for currentFolderPath='\(currentFolderPath)'")
        
        // Count entries - iterate through ALL entries in ALL categories
        for (_, categoryEntries) in entries {
            for entry in categoryEntries {
                let entryCategory = entry.category
                
                if currentFolderPath.isEmpty {
                    // At root level, count entries that belong to top-level categories
                    if !entryCategory.contains("/") && currentLevelFolders.contains(entryCategory) {
                        folderCounts[entryCategory, default: 0] += 1
                        Logger.log(level: .info, category: .general, message: "FOLDER COUNT DEBUG: Entry '\(entry.title.prefix(20))' counted for root category '\(entryCategory)'")
                    }
                } else {
                    // For deeper levels, identify subfolders and count appropriately
                    if entryCategory.hasPrefix(currentFolderPath) {
                        let remainingPath = String(entryCategory.dropFirst(currentFolderPath.count + 1))
                        
                        if !remainingPath.isEmpty {
                            // This entry is in a subfolder
                            let nextFolderComponent = remainingPath.components(separatedBy: "/").first!
                            let nextFolderPath = "\(currentFolderPath)/\(nextFolderComponent)"
                            currentLevelFolders.insert(nextFolderPath)
                            
                            // Count entries that are DIRECTLY in this subfolder (not in deeper nests)
                            if entryCategory == nextFolderPath {
                                folderCounts[nextFolderPath, default: 0] += 1
                            }
                        } else if entryCategory == currentFolderPath {
                            // Count entries directly in the current folder (shouldn't happen at root)
                            folderCounts[currentFolderPath, default: 0] += 1
                        }
                    }
                }
            }
        }
        
        // Count places
        for place in places {
            let placeCategory = place.category
            Logger.log(level: .info, category: .general, message: "FOLDER COUNT DEBUG: Place '\(place.alias ?? "Unnamed")' has category '\(placeCategory)'")
            
            if currentFolderPath.isEmpty {
                // At root level, count places that belong to top-level categories
                if !placeCategory.contains("/") && currentLevelFolders.contains(placeCategory) {
                    folderCounts[placeCategory, default: 0] += 1
                    Logger.log(level: .info, category: .general, message: "FOLDER COUNT DEBUG: Place '\(place.alias ?? "Unnamed")' counted for root category '\(placeCategory)'")
                }
            } else {
                // For deeper levels, identify subfolders and count appropriately
                if placeCategory.hasPrefix(currentFolderPath) {
                    let remainingPath = String(placeCategory.dropFirst(currentFolderPath.count + 1))
                    
                    if !remainingPath.isEmpty {
                        // This place is in a subfolder
                        let nextFolderComponent = remainingPath.components(separatedBy: "/").first!
                        let nextFolderPath = "\(currentFolderPath)/\(nextFolderComponent)"
                        currentLevelFolders.insert(nextFolderPath)
                        
                        // Count places that are DIRECTLY in this subfolder
                        if placeCategory == nextFolderPath {
                            folderCounts[nextFolderPath, default: 0] += 1
                        }
                    } else if placeCategory == currentFolderPath {
                        // Count places directly in the current folder
                        folderCounts[currentFolderPath, default: 0] += 1
                    }
                }
            }
        }
        
        // Create FolderData objects for each folder
        Logger.log(level: .info, category: .general, message: "FOLDER COUNT DEBUG: Final folder counts: \(folderCounts)")
        for folderPath in currentLevelFolders.sorted() {
            let folderName = folderPath.components(separatedBy: "/").last ?? folderPath
            let category = findCategoryForFolder(folderPath: folderPath)
            let image = category?.symbolName != nil ? UIImage(systemName: category!.symbolName) : UIImage(systemName: "folder")
            
            let folderData = FolderData(
                title: folderName,
                image: image,
                itemCount: folderCounts[folderPath] ?? 0,
                fullPath: folderPath,
                category: category
            )
            Logger.log(level: .info, category: .general, message: "FOLDER COUNT DEBUG: Created folder '\(folderName)' with count \(folderCounts[folderPath] ?? 0)")
            folderItems.append(folderData)
        }
        
        return folderItems
    }
    
    private func parseFolderPath(from category: String) -> String {
        // For backward compatibility, if category doesn't contain "/", 
        // treat it as the folder path itself
        return category
    }
    
    private func findCategoryForFolder(folderPath: String) -> NestCategory? {
        // Find the category that matches the root folder name
        let rootFolderName = folderPath.components(separatedBy: "/").first ?? folderPath
        return categories.first { $0.name.lowercased() == rootFolderName.lowercased() }
    }
    
    private var entries: [String: [BaseEntry]]?
    private var places: [PlaceItem] = []
    
    private let sectionHeaders = ["", "Folders"]
    
    private var newCategoryButton: NNPrimaryLabeledButton?
    
    internal let entryRepository: EntryRepository
    
    // MARK: - PaywallPresentable
    var proFeature: ProFeature {
        return .customCategories
    }
    
    init(entryRepository: EntryRepository) {
        self.entryRepository = entryRepository
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = entryRepository is NestService ? "My Nest" : "The Nest"
        configureCollectionView()
        setupLoadingIndicator()
        setupNewCategoryButton()
        setupRefreshControl()
        configureDataSource()
        setupNavigationBar()
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
                Logger.log(level: .info, category: .nestService, message: "Refreshing entries, categories, and places")
                
                // Invalidate cache first for refresh
                if let nestService = entryRepository as? NestService {
                    nestService.invalidateItemsCache()
                }
                
                // Refresh categories
                let categories = try await entryRepository.refreshCategories()
                self.categories = categories
                
                // For NestService, use efficient combined fetch (cache already invalidated)
                if let nestService = entryRepository as? NestService {
                    do {
                        let (groupedEntries, places) = try await nestService.fetchEntriesAndPlaces()
                        Logger.log(level: .info, category: .nestService, message: "Efficient refresh complete - \(groupedEntries.count) entry groups, \(places.count) places")
                        
                        await MainActor.run {
                            self.entries = groupedEntries
                            self.places = places
                            self.applyInitialSnapshots()
                            self.refreshControl.endRefreshing()
                        }
                    } catch {
                        Logger.log(level: .error, category: .nestService, message: "Failed to refresh entries and places: \(error)")
                        // Fallback to separate refresh
                        let groupedEntries = try await entryRepository.refreshEntries()
                        
                        await MainActor.run {
                            self.entries = groupedEntries
                            self.places = []
                            self.applyInitialSnapshots()
                            self.refreshControl.endRefreshing()
                        }
                    }
                } else {
                    // For other repository types, refresh entries only
                    let groupedEntries = try await entryRepository.refreshEntries()
                    Logger.log(level: .info, category: .nestService, message: "Refreshed \(groupedEntries.count) entry groups")
                    
                    await MainActor.run {
                        self.entries = groupedEntries
                        self.places = []
                        self.applyInitialSnapshots()
                        self.refreshControl.endRefreshing()
                    }
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
        collectionView.register(FolderCollectionViewCell.self, forCellWithReuseIdentifier: FolderCollectionViewCell.reuseIdentifier)
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
                
            case .main:
                // Create 2-item grid layout for folders
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.5),
                    heightDimension: .fractionalHeight(1.0)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
                
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(144) // Height for folder cells (20% smaller than original 180)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])
                
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 16 // Add vertical spacing between rows
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: 8,
                    leading: 10,
                    bottom: 16,
                    trailing: 10
                )
                
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
        let addressRegistration = UICollectionView.CellRegistration<AddressCell, String> { [weak self] cell, indexPath, address in
            cell.configure(address: address)
            cell.delegate = self
        }
        
        let folderRegistration = UICollectionView.CellRegistration<FolderCollectionViewCell, FolderData> { cell, indexPath, folderData in
            cell.configure(with: folderData)
        }
        
        let headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] (headerView, string, indexPath) in
            guard let self = self else { return }
            headerView.configure(title: self.sectionHeaders[indexPath.section])
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, AnyHashable>(collectionView: collectionView) { collectionView, indexPath, item in
            let section = Section(rawValue: indexPath.section)!
            
            switch section {
            case .address:
                return collectionView.dequeueConfiguredReusableCell(
                    using: addressRegistration,
                    for: indexPath,
                    item: item as? String
                )
            case .main:
                return collectionView.dequeueConfiguredReusableCell(
                    using: folderRegistration,
                    for: indexPath,
                    item: item as? FolderData
                )
            }
        }
        
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }
    
    private func setupNavigationBar() {
        // Only show menu for nest owners
        guard entryRepository is NestService else { return }
        
        let pinnedCategoriesAction = UIAction(
            title: "Pinned Folders",
            image: UIImage(systemName: "rectangle.grid.2x2.fill")
        ) { [weak self] _ in
            self?.presentPinnedCategories()
        }
        
        var menuChildren: [UIMenuElement] = [pinnedCategoriesAction]
        
        // Only show "Add Folder" if we haven't reached max depth
        let currentDepth = currentFolderPath.isEmpty ? 0 : currentFolderPath.components(separatedBy: "/").count
        if currentDepth < 3 {
            let addFolderAction = UIAction(
                title: "Add Folder",
                image: UIImage(systemName: "folder.badge.plus")
            ) { [weak self] _ in
                self?.presentAddFolder()
            }
            menuChildren.append(addFolderAction)
        }
        
        let menu = UIMenu(title: "", children: menuChildren)
        
        let menuButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            style: .plain,
            target: nil,
            action: nil
        )
        menuButton.menu = menu
        
        navigationItem.rightBarButtonItem = menuButton
    }
    
    private func presentPinnedCategories() {
        let pinnedCategoriesVC = PinnedCategoriesViewController(entryRepository: entryRepository)
        present(UINavigationController(rootViewController: pinnedCategoriesVC), animated: true)
    }
    
    private func presentAddFolder() {
        Task {
            // Check if user has unlimited categories feature (Pro subscription)
            let hasUnlimitedCategories = await SubscriptionService.shared.isFeatureAvailable(.customCategories)
            if !hasUnlimitedCategories {
                await MainActor.run {
                    self.showCategoryLimitUpgradePrompt()
                }
                return
            }
            
            await MainActor.run {
                let categoryVC = CategoryDetailViewController()
                categoryVC.categoryDelegate = self
                self.present(categoryVC, animated: true)
            }
        }
    }
    
    @objc private func addButtonTapped() {
        Task {
            // Check if user has unlimited categories feature (Pro subscription)
            let hasUnlimitedCategories = await SubscriptionService.shared.isFeatureAvailable(.customCategories)
            if !hasUnlimitedCategories {
                await MainActor.run {
                    self.showCategoryLimitUpgradePrompt()
                }
                return
            }
            
            await MainActor.run {
                let buttonFrame = self.newCategoryButton!.convert(self.newCategoryButton!.bounds, to: nil)
                let categoryVC = CategoryDetailViewController(sourceFrame: buttonFrame)
                categoryVC.categoryDelegate = self
                self.present(categoryVC, animated: true)
            }
        }
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, AnyHashable>()
        snapshot.appendSections([.address, .main])
        
        // Get address from the appropriate service
        var address: String?
        if let nestService = entryRepository as? NestService {
            address = nestService.currentNest?.address
        } else if let sitterService = entryRepository as? SitterViewService {
            address = sitterService.currentNestAddress
        }
        
        if let address = address {
            snapshot.appendItems([address], toSection: .address)
        }
        
        snapshot.appendItems(folders, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
        
        // Update UI elements based on current folder depth
        setupNavigationBar()
        setupNewCategoryButton()
    }
    
    private func setupNewCategoryButton() {
        // Only show new category button for nest owners
        guard entryRepository is NestService else { return }
        
        // Check if we've reached max folder depth
        let currentDepth = currentFolderPath.isEmpty ? 0 : currentFolderPath.components(separatedBy: "/").count
        guard currentDepth < 3 else { 
            // Remove existing button if we're at max depth
            newCategoryButton?.removeFromSuperview()
            newCategoryButton = nil
            collectionView.contentInset.bottom = 0
            collectionView.verticalScrollIndicatorInsets.bottom = 0
            return 
        }
    }
    
    private func loadEntries() async {
        loadingIndicator.startAnimating()
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        do {
            Logger.log(level: .info, category: .general, message: "Starting to load entries, categories, and places")
            
            // Fetch categories first
            let categories = try await entryRepository.fetchCategories()
            self.categories = categories
            
            // For NestService, use efficient combined fetch
            if let nestService = entryRepository as? NestService {
                do {
                    let (groupedEntries, places) = try await nestService.fetchEntriesAndPlaces()
                    Logger.log(level: .info, category: .general, message: "Efficient fetch complete - \(groupedEntries.count) entry groups, \(places.count) places")
                    self.entries = groupedEntries
                    self.places = places
                } catch {
                    Logger.log(level: .error, category: .general, message: "Failed to fetch entries and places: \(error)")
                    // Fallback to separate fetches
                    let groupedEntries = try await entryRepository.fetchEntries()
                    self.entries = groupedEntries
                    self.places = []
                }
            } else {
                // For other repository types, fetch entries only
                let groupedEntries = try await entryRepository.fetchEntries()
                Logger.log(level: .info, category: .general, message: "Fetched \(groupedEntries.count) entry groups")
                self.entries = groupedEntries
                self.places = []
            }
            
            await MainActor.run {
                self.newCategoryButton?.isEnabled = true
                self.hasLoadedInitialData = true
                self.handleLoadedEntries(self.entries ?? [:])
                self.loadingIndicator.stopAnimating()
                navigationItem.rightBarButtonItem?.isEnabled = true
            }
        } catch {
            Logger.log(level: .error, category: .general, message: "Failed to load entries and categories: \(error)")
            await MainActor.run {
                self.newCategoryButton?.isEnabled = false
                self.loadingIndicator.stopAnimating()
                self.showError(error.localizedDescription)
            }
        }
    }
}

extension NestViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        // Skip navigation for address section
        if indexPath.section == Section.address.rawValue { return }
        
        let section = Section(rawValue: indexPath.section)!
        
        if section == .main {
            // Handle folder navigation
            guard let folderData = item as? FolderData else { return }
            
            let sessionVisibilityLevel = (entryRepository as? SitterViewService)?.currentSessionVisibilityLevel
            let nestCategoryViewController = NestCategoryViewController(
                category: folderData.fullPath,
                places: places,
                entryRepository: entryRepository,
                sessionVisibilityLevel: sessionVisibilityLevel
            )
            navigationController?.pushViewController(nestCategoryViewController, animated: true)
        }
    }
}

extension NestViewController: CategoryDetailViewControllerDelegate {
    func categoryDetailViewController(_ controller: CategoryDetailViewController, didSaveCategory category: String?, withIcon icon: String?) {
        guard let categoryName = category,
              let iconName = icon,
              let nestService = entryRepository as? NestService else {
            // Only NestService can create categories
            showError("Categories can only be created by nest owners")
            return
        }
        
        Task {
            do {
                // Create full folder path considering current folder location
                let fullFolderPath = currentFolderPath.isEmpty ? categoryName : "\(currentFolderPath)/\(categoryName)"
                
                // Create and save the new category with full path and selected icon
                let newCategory = NestCategory(name: fullFolderPath, symbolName: iconName)
                try await nestService.createCategory(newCategory)
                
                // Refresh the categories, entries, and places
                async let categoriesTask = nestService.fetchCategories()
                async let entriesTask = entryRepository.refreshEntries()
                
                let (newCategories, groupedEntries) = try await (categoriesTask, entriesTask)
                
                // Refresh places too
                let refreshedPlaces = try await nestService.fetchPlacesWithFilter(includeTemporary: false)
                
                await MainActor.run {
                    self.categories = newCategories
                    self.entries = groupedEntries
                    self.places = refreshedPlaces
                    self.applyInitialSnapshots()
                    self.showToast(text: "Category Created")
                }
            } catch {
                Logger.log(level: .error, category: .general, message: "Failed to create category: \(error)")
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Category Limit Handling
    
    private func showCategoryLimitUpgradePrompt() {
        showUpgradePrompt(for: proFeature)
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
    
    func showTips() {
        // Only show tips when in read-only mode (sitter view)
        guard !(entryRepository is NestService) else { return }
        
        trackScreenVisit()
        
        // Find the address cell in the first section
        let addressIndexPath = IndexPath(item: 0, section: Section.address.rawValue)
        if let addressCell = collectionView.cellForItem(at: addressIndexPath),
           NNTipManager.shared.shouldShowTip(NestViewTips.getDirectionsTip) {
            NNTipManager.shared.showTip(
                NestViewTips.getDirectionsTip,
                sourceView: addressCell,
                in: self,
                pinToEdge: .bottom,
                offset: CGPoint(x: 0, y: 8)
            )
        }
    }
}

