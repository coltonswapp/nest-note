//
//  SelectEntriesFlowViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 1/29/25
//

import UIKit

class ModifiedSelectFolderViewController: UIViewController {
    // MARK: - Properties
    private let entryRepository: EntryRepository
    weak var delegate: ModifiedSelectFolderViewControllerDelegate?
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, FolderItem>!
    private var selectionCounterView: SelectEntriesCountView!
    
    private var categories: [NestCategory] = []
    private var pendingUpdateNeeded = false
    private var folderItemCounts: [String: Int] = [:]
    
    // Callback for continue button - now passes selected IDs
    var onContinueTapped: (([String]) -> Void)?
    
    // Track all selected IDs locally (not committed until continue)
    private var currentSelectedIds: [String] = []
    
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
        
        collectionView.delegate = self
        loadCategories()
        
        // Load item-folder mapping for selection counting
        Task {
            await updateItemFolderMapping()
        }
    }
    
    // Cache for item-to-folder mapping to avoid repeated fetches
    private var itemFolderMapping: [String: String] = [:]
    
    // Helper method to count selected items in a specific folder using IDs
    private func countSelectedItemsInFolder(_ folderPath: String) -> Int {
        return currentSelectedIds.filter { itemId in
            itemFolderMapping[itemId] == folderPath
        }.count
    }
    
    // Method to update the item-folder mapping cache
    private func updateItemFolderMapping() async {
        do {
            let allItems = try await entryRepository.fetchAllItems()
            
            var mapping: [String: String] = [:]
            
            // Map all items (entries, places, routines) to their categories
            for item in allItems {
                mapping[item.id] = item.category
            }
            
            await MainActor.run {
                self.itemFolderMapping = mapping
                // Refresh snapshot with updated counts
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
        print("[DEBUG] setInitialSelectedItemIds called with \(ids.count) items: \(ids)")
        currentSelectedIds = ids
        updateSelectionCounter()
    }
    
    // Method to update current selections (called by NestCategoryViewController)
    func updateCurrentSelectedIds(_ ids: [String]) {
        print("[DEBUG] updateCurrentSelectedIds called with \(ids.count) items: \(ids)")
        currentSelectedIds = ids
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
        selectionCounterView = SelectEntriesCountView()
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
    
    private func updateSelectionCounter() {
        guard isViewLoaded else { 
            print("[DEBUG] updateSelectionCounter: view not loaded yet")
            return 
        }
        
        print("[DEBUG] updateSelectionCounter: setting count to \(currentSelectedIds.count)")
        selectionCounterView?.count = currentSelectedIds.count
        
        // Ensure counter stays on top
        if let navController = navigationController {
            navController.view.bringSubviewToFront(selectionCounterView)
        }
    }
    
    // Async method to load all folder item counts
    private func loadFolderItemCounts() async {
        do {
            // Fetch all entries and places for counting
            let allEntries = try await entryRepository.fetchEntries()
            let allPlaces = try await entryRepository.fetchPlaces()
            
            var counts: [String: Int] = [:]
            
            // Count items for each top-level category
            for category in categories {
                // Only count top-level folders (no "/" in the name)
                guard !category.name.contains("/") else { continue }
                
                let folderPath = category.name
                
                // Count entries in this exact folder path
                let entriesCount = allEntries.values.flatMap { $0 }.filter { $0.category == folderPath }.count
                
                // Count places in this exact folder path
                let placesCount = allPlaces.filter { $0.category == folderPath }.count
                
                counts[folderPath] = entriesCount + placesCount
            }
            
            await MainActor.run {
                self.folderItemCounts = counts
                // Refresh the snapshot now that we have counts
                self.applySnapshot()
            }
            
        } catch {
            // If there's an error, use empty counts
            await MainActor.run {
                self.folderItemCounts = [:]
                self.applySnapshot()
            }
        }
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
        let allSelectedIds = controller.getAllSelectedItemIds()
        currentSelectedIds = allSelectedIds
        print("[DEBUG] Total selected items: \(currentSelectedIds.count)")
        
        updateSelectionCounter()
        // Update folder counts when selections change
        applySnapshot()
    }
}
