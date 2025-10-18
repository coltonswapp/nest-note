//
//  SelectEntriesFlowViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 1/29/25
//

import UIKit
import RevenueCat
import RevenueCatUI

class ModifiedSelectFolderViewController: UIViewController, PaywallPresentable, PaywallViewControllerDelegate {
    // MARK: - Properties
    private let entryRepository: EntryRepository
    weak var delegate: ModifiedSelectFolderViewControllerDelegate?
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, FolderItem>!
    private var selectionCounterView: SelectItemsCountView!
    private var selectAllBarButtonItem: UIBarButtonItem?
    
    private var categories: [NestCategory] = []
    private var pendingUpdateNeeded = false
    private var folderItemCounts: [String: Int] = [:]
    // Optional preloaded items to avoid redundant service calls
    private var preloadedAllItems: [BaseItem]? = nil
    
    // Callback for continue button - now passes selected IDs
    var onContinueTapped: (([String]) -> Void)?
    
    // Track all selected IDs locally (not committed until continue)
    private var currentSelectedIds: [String] = []
    // Cache of all selectable item IDs (entries + places + routines)
    private var allSelectableItemIds: [String] = []
    
    // Selection limit properties
    private var selectionLimit: Int? = nil
    private var isProUser: Bool = false
    
    // MARK: - PaywallPresentable
    var proFeature: ProFeature {
        return .unlimitedEntries
    }
    
    enum Section: Int, CaseIterable {
        case folders
    }
    
    struct FolderItem: Hashable {
        let name: String
        let fullPath: String
        let symbolName: String
        let id: String
        let selectedCount: Int
        let totalItemCount: Int
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(fullPath)
        }
        
        static func == (lhs: FolderItem, rhs: FolderItem) -> Bool {
            return lhs.name == rhs.name && rhs.id == lhs.id && rhs.fullPath == lhs.fullPath && lhs.selectedCount == rhs.selectedCount && lhs.totalItemCount == rhs.totalItemCount
        }
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
        view.backgroundColor = .systemBackground
        
        setupCollectionView()
        configureDataSource()
        setupSelectionCounterView()
        setupNavigationItems()
        
        collectionView.delegate = self
        
        // Single consolidated initial load to avoid duplicate fetches
        Task { 
            await checkProStatusAndSetLimit()
            await initialLoad() 
        }
    }
    
    // Cache for item-to-folder mapping to avoid repeated fetches
    private var itemFolderMapping: [String: String] = [:]
    
    // Helper method to determine if a category is the folder or a descendant
    private func isInFolderOrDescendant(itemCategory: String, folderPath: String) -> Bool {
        return itemCategory == folderPath || itemCategory.hasPrefix(folderPath + "/")
    }
    
    // Check user's pro status and set selection limit
    private func checkProStatusAndSetLimit() async {
        // Use the same pro status checking as other features for consistency
        isProUser = await SubscriptionService.shared.isFeatureAvailable(.unlimitedEntries)
        selectionLimit = isProUser ? nil : FeatureFlagService.shared.getFreeUserSelectionLimit()
        
        await MainActor.run {
            selectionCounterView?.selectionLimit = selectionLimit
        }
    }
    
    // Helper method to check if adding more selections would exceed the limit
    private func canAddMoreSelections(_ count: Int = 1) -> Bool {
        guard let limit = selectionLimit else { return true }
        return currentSelectedIds.count + count <= limit
    }
    
    // Show an alert when selection limit is reached
    private func showSelectionLimitAlert() {
        let limit = FeatureFlagService.shared.getFreeUserSelectionLimit()
        let alert = UIAlertController(
            title: "Selection Limit Reached",
            message: "Free users can select up to \(limit) items to share. Upgrade to Pro for unlimited selections.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        alert.addAction(UIAlertAction(title: "Upgrade to Pro", style: .default) { [weak self] _ in
            self?.showUpgradeFlow()
        })
        
        present(alert, animated: true)
    }

    // Consolidated initial load to fetch categories and all items once
    private func initialLoad() async {
        do {
            async let categoriesTask = entryRepository.fetchCategories()
            // Use preloaded snapshot if available
            let allItems = try await { () -> [BaseItem] in
                if let items = self.preloadedAllItems { return items }
                return try await self.entryRepository.fetchAllItems()
            }()
            let fetchedCategories = try await categoriesTask

            // Build mapping and counts from single items snapshot
            var mapping: [String: String] = [:]
            for item in allItems { mapping[item.id] = item.category }

            var counts: [String: Int] = [:]
            for category in fetchedCategories where !category.name.contains("/") {
                let path = category.name
                let total = allItems.filter { $0.category == path || $0.category.hasPrefix(path + "/") }.count
                counts[path] = total
            }

            let ids = allItems.map { $0.id }

            await MainActor.run {
                self.categories = fetchedCategories
                self.itemFolderMapping = mapping
                self.folderItemCounts = counts
                self.allSelectableItemIds = ids
                self.applySnapshot()
                self.updateSelectAllButtonTitle()
            }
        } catch {
            await MainActor.run {
                self.showError(error.localizedDescription)
            }
        }
    }
    
    // Helper method to count selected items in a specific folder using IDs (including children)
    private func countSelectedItemsInFolder(_ folderPath: String) -> Int {
        return currentSelectedIds.reduce(0) { count, itemId in
            guard let cat = itemFolderMapping[itemId] else { return count }
            return count + (isInFolderOrDescendant(itemCategory: cat, folderPath: folderPath) ? 1 : 0)
        }
    }
    
    // Method to update the item-folder mapping cache
    private func updateItemFolderMapping() async {
        do {
            let allItems = try await { () -> [BaseItem] in
                if let items = self.preloadedAllItems { return items }
                return try await self.entryRepository.fetchAllItems()
            }()
            var mapping: [String: String] = [:]
            for item in allItems { mapping[item.id] = item.category }
            await MainActor.run {
                self.itemFolderMapping = mapping
                self.applySnapshot()
            }
        } catch {
            print("[ERROR] Failed to update item-folder mapping: \(error)")
        }
    }
    
    // Helper method to get cached total items count for a specific folder
    private func getTotalItemsInFolder(_ folderPath: String) -> Int {
        return folderItemCounts[folderPath] ?? 0
    }
    
    // Method to set initial selected IDs (from EditSessionViewController)
    func setInitialSelectedItemIds(_ ids: [String]) {
        currentSelectedIds = ids
        updateSelectionCounter()
    }
    
    // Method to update current selections (called by NestCategoryViewController)
    func updateCurrentSelectedIds(_ ids: [String]) {
        
        // Check selection limit
        if let limit = selectionLimit {
            if ids.count > limit {
                // Limit exceeded, show alert and take only the allowed number
                showSelectionLimitAlert()
                currentSelectedIds = Array(ids.prefix(limit))
            } else {
                currentSelectedIds = ids
            }
        } else {
            // No limit (pro user)
            currentSelectedIds = ids
        }
        
        updateSelectionCounter()
    }
    
    // Method to get current selected items organized by type (for restoring in NestCategoryViewController)
    func getCurrentSelectedItems() async -> (entries: Set<BaseEntry>, places: Set<PlaceItem>, routines: Set<RoutineItem>) {
        do {
            let allItems = try await entryRepository.fetchAllItems()
            
            var selectedEntries: Set<BaseEntry> = []
            var selectedPlaces: Set<PlaceItem> = []
            var selectedRoutines: Set<RoutineItem> = []
            
            for item in allItems {
                if currentSelectedIds.contains(item.id) {
                    switch item.type {
                    case .entry:
                        if let entry = item as? BaseEntry {
                            selectedEntries.insert(entry)
                        }
                    case .place:
                        if let place = item as? PlaceItem {
                            selectedPlaces.insert(place)
                        }
                    case .routine:
                        if let routine = item as? RoutineItem {
                            selectedRoutines.insert(routine)
                        }
                    }
                }
            }
            
            return (entries: selectedEntries, places: selectedPlaces, routines: selectedRoutines)
        } catch {
            print("[ERROR] Failed to fetch items for restoration: \(error)")
            return (entries: [], places: [], routines: [])
        }
    }
    
    private func setupSelectionCounterView() {
        selectionCounterView = SelectItemsCountView()
        selectionCounterView.selectionLimit = selectionLimit
        selectionCounterView.onContinueTapped = { [weak self] in
            guard let self = self else { return }
            self.onContinueTapped?(self.currentSelectedIds)
        }
        
        // Add as overlay to navigation controller's view if available
        if let navController = navigationController {
            navController.view.addSubview(selectionCounterView)
            navController.view.bringSubviewToFront(selectionCounterView)
            
            // Set up constraints
            NSLayoutConstraint.activate([
                selectionCounterView.centerXAnchor.constraint(equalTo: navController.view.centerXAnchor),
                selectionCounterView.bottomAnchor.constraint(equalTo: navController.view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
            ])
        }
        
        updateSelectionCounter()
    }
    
    private func setupNavigationItems() {
        let button = UIBarButtonItem(title: "Select All", style: .plain, target: self, action: #selector(didTapSelectAll))
        selectAllBarButtonItem = button
        navigationItem.rightBarButtonItem = button
        updateSelectAllButtonTitle()
    }
    
    private func updateSelectionCounter() {
        guard isViewLoaded else { 
            return 
        }
        
        selectionCounterView?.count = currentSelectedIds.count
        
        // Ensure counter stays on top
        if let navController = navigationController {
            navController.view.bringSubviewToFront(selectionCounterView)
        }
        updateSelectAllButtonTitle()
    }
    
    // Toggle Select All / Clear All button title based on selection state
    private func updateSelectAllButtonTitle() {
        let total = allSelectableItemIds.count
        let isAllSelected = total > 0 && currentSelectedIds.count >= total
        selectAllBarButtonItem?.title = isAllSelected ? "Clear All" : "Select All"
        selectAllBarButtonItem?.isEnabled = total > 0
    }
    
    // Precompute all selectable item IDs (entries + places + routines)
    private func prepareSelectableItems() async {
        // If we already have the mapping, derive IDs without fetching again
        if !itemFolderMapping.isEmpty {
            await MainActor.run {
                self.allSelectableItemIds = Array(self.itemFolderMapping.keys)
                self.updateSelectAllButtonTitle()
            }
            return
        }
        // Fallback: fetch once (or reuse preloaded) and populate both mapping and IDs
        do {
            let allItems = try await { () -> [BaseItem] in
                if let items = self.preloadedAllItems { return items }
                return try await self.entryRepository.fetchAllItems()
            }()
            var mapping: [String: String] = [:]
            for item in allItems { mapping[item.id] = item.category }
            let ids = allItems.map { $0.id }
            await MainActor.run {
                self.itemFolderMapping = mapping
                self.allSelectableItemIds = ids
                self.updateSelectAllButtonTitle()
                self.applySnapshot()
            }
        } catch {
            await MainActor.run {
                self.allSelectableItemIds = []
                self.updateSelectAllButtonTitle()
            }
        }
    }
    
    @objc private func didTapSelectAll() {
        let total = allSelectableItemIds.count
        let isAllSelected = total > 0 && currentSelectedIds.count >= total
        
        if isAllSelected {
            // Clear all selections
            currentSelectedIds = []
        } else {
            // Select all items, respecting the limit
            if let limit = selectionLimit {
                let itemsToSelect = min(limit, total)
                currentSelectedIds = Array(allSelectableItemIds.prefix(itemsToSelect))
                
                // Show alert if we couldn't select all items due to limit
                if total > limit {
                    showSelectionLimitAlert()
                }
            } else {
                // No limit (pro user)
                currentSelectedIds = allSelectableItemIds
            }
        }
        updateSelectionCounter()
        applySnapshot()
    }
    
    // Async method to load all folder item counts (including child folders)
    private func loadFolderItemCounts() async {
        // Prefer using the existing mapping to avoid extra fetches
        if itemFolderMapping.isEmpty {
            await updateItemFolderMapping()
        }

        var counts: [String: Int] = [:]
        for category in categories {
            // Only top-level folders
            guard !category.name.contains("/") else { continue }
            let folderPath = category.name
            let totalCount = itemFolderMapping.values.filter { cat in
                cat == folderPath || cat.hasPrefix(folderPath + "/")
            }.count
            counts[folderPath] = totalCount
        }

        await MainActor.run {
            self.folderItemCounts = counts
            self.applySnapshot()
        }
    }

    // Allow parent to provide a preloaded items snapshot to eliminate extra fetches
    func setPreloadedItems(_ items: [BaseItem]) {
        preloadedAllItems = items
    }
    
    // Expose selection limit for child view controllers
    func getCurrentSelectionLimit() -> Int? {
        return selectionLimit
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        
        view.addSubview(collectionView)
        
        // Use automatic content inset adjustment for proper navigation bar handling
        let buttonHeight: CGFloat = 50
        let buttonPadding: CGFloat = 24
        let totalInset = buttonHeight + buttonPadding * 2
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
        collectionView.verticalScrollIndicatorInsets = collectionView.contentInset
        
        // Register the FolderCollectionViewCell
        collectionView.register(FolderCollectionViewCell.self, forCellWithReuseIdentifier: FolderCollectionViewCell.reuseIdentifier)
        
        collectionView.allowsSelection = true
    }
    
    private func createLayout() -> UICollectionViewLayout {
        // Use the same 2-item grid layout as NestCategoryViewController's folders section
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
        
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, FolderItem>(collectionView: collectionView) { collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FolderCollectionViewCell.reuseIdentifier, for: indexPath) as! FolderCollectionViewCell
            
            // Create FolderData with the new subtitle format
            let symbolConfiguration = UIImage.SymbolConfiguration(weight: .bold)
            let image = UIImage(systemName: item.symbolName, withConfiguration: symbolConfiguration)?
                .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
            
            let folderData = FolderData(
                title: item.name,
                image: image ?? UIImage(systemName: "folder.fill")!,
                itemCount: item.totalItemCount,
                fullPath: item.fullPath,
                category: nil,
                selectedCount: item.selectedCount
            )
            
            // Configure the cell with custom subtitle format for selection flow
            self.configureSelectEntriesCell(cell, with: folderData, selectedCount: item.selectedCount, totalCount: item.totalItemCount)
            return cell
        }
    }
    
    // Custom configuration method for select entries flow
    private func configureSelectEntriesCell(_ cell: FolderCollectionViewCell, with data: FolderData, selectedCount: Int, totalCount: Int) {
        // Set the basic data
        cell.iconImageView.image = data.image
        cell.titleLabel.text = data.title
        
        // Set custom subtitle with "X / Y selected" format
        cell.subtitleLabel.text = "\(selectedCount) / \(totalCount) selected"
        
        // Add the paper effect
        cell.addPaper(num: data.itemCount)
    }
    
    private func loadCategories() {
        Task {
            do {
                let fetchedCategories = try await entryRepository.fetchCategories()
                
                await MainActor.run {
                    self.categories = fetchedCategories
                    self.applySnapshot()
                    
                    // Apply any pending updates that were called before view was ready
                    if self.pendingUpdateNeeded {
                        self.applySnapshot()
                        self.pendingUpdateNeeded = false
                    }
                }
                
                // Load folder item counts after categories are loaded
                await loadFolderItemCounts()
                
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func applySnapshot() {
        // Guard against calling this before the view is loaded and data source is configured
        guard isViewLoaded, dataSource != nil else {
            return
        }
        
        var snapshot = NSDiffableDataSourceSnapshot<Section, FolderItem>()
        snapshot.appendSections([.folders])
        
        // Create folder items from fetched categories, showing only top-level folders
        let folderItems = categories.compactMap { category -> FolderItem? in
            // Don't show Places as it's reserved
            guard category.name != "Places" else { return nil }
            
            // Only show top-level folders (no "/" in the name)
            guard !category.name.contains("/") else { return nil }
            
            return FolderItem(
                name: category.name,
                fullPath: category.name,
                symbolName: category.symbolName,
                id: category.id,
                selectedCount: countSelectedItemsInFolder(category.name),
                totalItemCount: getTotalItemsInFolder(category.name)
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        snapshot.appendItems(folderItems, toSection: .folders)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

// MARK: - UICollectionViewDelegate
extension ModifiedSelectFolderViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        delegate?.modifiedSelectFolderViewController(self, didSelectFolder: item.fullPath)
    }
}

// MARK: - Protocols
protocol ModifiedSelectFolderViewControllerDelegate: AnyObject {
    func modifiedSelectFolderViewController(_ controller: ModifiedSelectFolderViewController, didSelectFolder folderPath: String)
}

protocol NestCategoryViewControllerSelectEntriesDelegate: AnyObject {
    func nestCategoryViewController(_ controller: NestCategoryViewController, didUpdateSelectedEntries entries: Set<BaseEntry>)
    func nestCategoryViewController(_ controller: NestCategoryViewController, didUpdateSelectedPlaces places: Set<PlaceItem>)
    func nestCategoryViewController(_ controller: NestCategoryViewController, didUpdateSelectedRoutines routines: Set<RoutineItem>)
    // Provide current selected items so child folders can restore selection state
    func getCurrentSelectedItems() async -> (entries: Set<BaseEntry>, places: Set<PlaceItem>, routines: Set<RoutineItem>)
}

// MARK: - NestCategoryViewControllerSelectEntriesDelegate
extension ModifiedSelectFolderViewController: NestCategoryViewControllerSelectEntriesDelegate {
    func nestCategoryViewController(_ controller: NestCategoryViewController, didUpdateSelectedEntries entries: Set<BaseEntry>) {
        updateAllSelectedIds(from: controller)
    }
    
    func nestCategoryViewController(_ controller: NestCategoryViewController, didUpdateSelectedPlaces places: Set<PlaceItem>) {
        updateAllSelectedIds(from: controller)
    }
    
    func nestCategoryViewController(_ controller: NestCategoryViewController, didUpdateSelectedRoutines routines: Set<RoutineItem>) {
        updateAllSelectedIds(from: controller)
    }
    
    // Helper method to get ALL selected IDs from the controller
    private func updateAllSelectedIds(from controller: NestCategoryViewController) {
        let incomingAllIds = Set(controller.getAllSelectedItemIds())
        // Merge: keep selections from other folders, replace selections within the current folder scope
        let scopePath = controller.getCurrentCategoryPath()
        let isInScope: (String) -> Bool = { id in
            guard let cat = self.itemFolderMapping[id] else { return false }
            return cat == scopePath || cat.hasPrefix(scopePath + "/")
        }
        // Use set operations to avoid duplicates
        let existingSet = Set(currentSelectedIds)
        let preserved = existingSet.filter { !isInScope($0) }
        let incomingInScope = incomingAllIds.filter { isInScope($0) }
        let potentialMerged = preserved.union(incomingInScope)
        
        // Check selection limit
        if let limit = selectionLimit {
            if potentialMerged.count > limit {
                // Calculate how many new items we're trying to add
                let previousInScope = existingSet.filter { isInScope($0) }
                let newItemsCount = incomingInScope.count - previousInScope.count
                
                if newItemsCount > 0 && !canAddMoreSelections(newItemsCount) {
                    // Show alert and keep previous selections
                    showSelectionLimitAlert()
                    return
                }
                
                // Respect limit by taking only allowed items
                let availableSlots = limit - preserved.count
                let limitedIncomingInScope = Array(incomingInScope.prefix(availableSlots))
                currentSelectedIds = Array(preserved.union(Set(limitedIncomingInScope)))
            } else {
                currentSelectedIds = Array(potentialMerged)
            }
        } else {
            // No limit (pro user)
            currentSelectedIds = Array(potentialMerged)
        }
        
        
        updateSelectionCounter()
        // Update folder counts when selections change
        applySnapshot()
    }
}

// MARK: - PaywallViewControllerDelegate
extension ModifiedSelectFolderViewController {
    func paywallViewController(_ controller: PaywallViewController, didFinishPurchasingWith customerInfo: CustomerInfo) {
        // Purchase successful - refresh pro status and update UI
        controller.dismiss(animated: true) { [weak self] in
            Task {
                await SubscriptionService.shared.refreshCustomerInfo()
                await self?.checkProStatusAndSetLimit()
                await MainActor.run {
                    self?.showToast(text: self?.proFeature.successMessage ?? "Subscription activated!")
                }
            }
        }
    }
    
    func paywallViewController(_ controller: PaywallViewController, didFailPurchasingWith error: Error) {
        Logger.log(level: .error, category: .purchases, message: "Subscription purchase failed: \(error.localizedDescription)")
    }
    
    func paywallViewController(_ controller: PaywallViewController, didFinishRestoringWith customerInfo: CustomerInfo) {
        controller.dismiss(animated: true) { [weak self] in
            Task {
                await SubscriptionService.shared.refreshCustomerInfo()
                await self?.checkProStatusAndSetLimit()
                await MainActor.run {
                    self?.showToast(text: self?.proFeature.successMessage ?? "Subscription restored!")
                }
            }
        }
    }
    
    func paywallViewController(_ controller: PaywallViewController, didFailRestoringWith error: Error) {
        Logger.log(level: .error, category: .purchases, message: "Subscription restore failed: \(error.localizedDescription)")
    }
}
