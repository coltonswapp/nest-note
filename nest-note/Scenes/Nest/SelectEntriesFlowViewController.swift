//
//  SelectEntriesFlowViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 1/29/25
//

import UIKit

protocol SelectEntriesFlowDelegate: AnyObject {
    func selectEntriesFlow(_ controller: SelectEntriesFlowViewController, didFinishWithEntries entries: [BaseEntry], places: [PlaceItem], routines: [RoutineItem])
    func selectEntriesFlowDidCancel(_ controller: SelectEntriesFlowViewController)
}

class SelectEntriesFlowViewController: UIViewController {
    // MARK: - Properties
    private let entryRepository: EntryRepository
    weak var delegate: SelectEntriesFlowDelegate?
    
    private var contentNavigationController: UINavigationController!
    private var selectionCounterView: SelectEntriesCountView!
    
    private var selectedEntries: Set<BaseEntry> = []
    private var selectedPlaces: Set<PlaceItem> = []
    private var selectedRoutines: Set<RoutineItem> = []
    
    init(entryRepository: EntryRepository) {
        self.entryRepository = entryRepository
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Method to set initial selected entries
    func setInitialSelectedEntries(_ entries: [BaseEntry]) {
        selectedEntries = Set(entries)
        // Update UI if view is already loaded
        if isViewLoaded {
            updateSelectionCounter()
            rootFolderViewController?.updateSelectedEntries(selectedEntries)
        }
    }
    
    // Method to set initial selected places
    func setInitialSelectedPlaces(_ places: [PlaceItem]) {
        selectedPlaces = Set(places)
        // Update UI if view is already loaded
        if isViewLoaded {
            updateSelectionCounter()
            rootFolderViewController?.updateSelectedPlaces(selectedPlaces)
        }
    }
    
    // Method to set initial selected routines
    func setInitialSelectedRoutines(_ routines: [RoutineItem]) {
        selectedRoutines = Set(routines)
        // Update UI if view is already loaded
        if isViewLoaded {
            updateSelectionCounter()
            // Note: Root folder view controller doesn't need routine-specific updates
            // as it already counts all selected items generically
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupContentNavigationController()
        setupSelectionCounterView()
        setupConstraints()
        
        // Update UI with any pre-selected entries, places, or routines
        if !selectedEntries.isEmpty || !selectedPlaces.isEmpty || !selectedRoutines.isEmpty {
            updateSelectionCounter()
            rootFolderViewController?.updateSelectedEntries(selectedEntries)
            rootFolderViewController?.updateSelectedPlaces(selectedPlaces)
        }
    }
    
    private func setupContentNavigationController() {
        // Create the initial folder selection view controller
        let folderVC = ModifiedSelectFolderViewController(entryRepository: entryRepository)
        folderVC.delegate = self
        folderVC.title = "Select Items"
        
        // Add cancel button to the root view controller
        folderVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        // Create navigation controller with folder selection as root
        contentNavigationController = UINavigationController(rootViewController: folderVC)
        contentNavigationController.navigationBar.prefersLargeTitles = false
        contentNavigationController.navigationBar.tintColor = NNColors.primary
        
        // Add as child view controller
        addChild(contentNavigationController)
        view.addSubview(contentNavigationController.view)
        contentNavigationController.didMove(toParent: self)
        
        contentNavigationController.view.translatesAutoresizingMaskIntoConstraints = false
    }
    
    // Helper method to get the root folder view controller
    private var rootFolderViewController: ModifiedSelectFolderViewController? {
        return contentNavigationController.viewControllers.first as? ModifiedSelectFolderViewController
    }
    
    private func setupSelectionCounterView() {
        selectionCounterView = SelectEntriesCountView()
        selectionCounterView.onContinueTapped = { [weak self] in
            self?.finishButtonTapped()
        }
        
        view.addSubview(selectionCounterView)
        updateSelectionCounter()
        
        view.backgroundColor = .clear
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Content navigation controller takes up space above the counter with padding for floating effect
            contentNavigationController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentNavigationController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentNavigationController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentNavigationController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Selection counter view centered and floating
            selectionCounterView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            selectionCounterView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }
    
    private func updateSelectionCounter() {
        let totalCount = selectedEntries.count + selectedPlaces.count + selectedRoutines.count
        selectionCounterView.count = totalCount
    }
    
    @objc private func cancelButtonTapped() {
        delegate?.selectEntriesFlowDidCancel(self)
    }
    
    private func finishButtonTapped() {
        let totalCount = selectedEntries.count + selectedPlaces.count + selectedRoutines.count
        let itemText = totalCount == 1 ? "item" : "items"
        
        let alert = UIAlertController(
            title: "Confirm Selection",
            message: "Add \(totalCount) \(itemText) to the session? These items will be visible to sitters throughout the duration of the session.",
            preferredStyle: .alert
        )
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let confirmAction = UIAlertAction(title: "Continue", style: .default) { _ in
            let entriesArray = Array(self.selectedEntries)
            let placesArray = Array(self.selectedPlaces)
            let routinesArray = Array(self.selectedRoutines)
            self.delegate?.selectEntriesFlow(self, didFinishWithEntries: entriesArray, places: placesArray, routines: routinesArray)
        }
        
        alert.addAction(cancelAction)
        alert.addAction(confirmAction)
        
        present(alert, animated: true)
    }
}

// MARK: - ModifiedSelectFolderViewControllerDelegate
extension SelectEntriesFlowViewController: ModifiedSelectFolderViewControllerDelegate {
    func modifiedSelectFolderViewController(_ controller: ModifiedSelectFolderViewController, didSelectFolder folderPath: String) {
        // Create and push the category view controller to the content navigation controller
        let categoryVC = NestCategoryViewController(
            entryRepository: entryRepository,
            initialCategory: folderPath,
            isEditOnlyMode: true
        )
        categoryVC.selectEntriesDelegate = self
        categoryVC.title = folderPath.components(separatedBy: "/").last ?? folderPath
        
        // Pass the currently selected entries, places, and routines to maintain selection state
        categoryVC.restoreSelectedEntries(selectedEntries)
        categoryVC.restoreSelectedPlaces(selectedPlaces)
        categoryVC.restoreSelectedRoutines(selectedRoutines)
        
        contentNavigationController.pushViewController(categoryVC, animated: true)
    }
}

// MARK: - NestCategoryViewControllerSelectEntriesDelegate
extension SelectEntriesFlowViewController: NestCategoryViewControllerSelectEntriesDelegate {
    func nestCategoryViewController(_ controller: NestCategoryViewController, didUpdateSelectedEntries entries: Set<BaseEntry>) {
        selectedEntries = entries
        updateSelectionCounter()
        
        // Update the root folder view controller to show selection counts
        rootFolderViewController?.updateSelectedEntries(entries)
    }
    
    func nestCategoryViewController(_ controller: NestCategoryViewController, didUpdateSelectedPlaces places: Set<PlaceItem>) {
        selectedPlaces = places
        updateSelectionCounter()
        
        // Update the root folder view controller to show place selection counts
        rootFolderViewController?.updateSelectedPlaces(places)
    }
    
    func nestCategoryViewController(_ controller: NestCategoryViewController, didUpdateSelectedRoutines routines: Set<RoutineItem>) {
        selectedRoutines = routines
        updateSelectionCounter()
        
        // Note: Root folder view controller doesn't need routine-specific updates
        // as it already counts all selected items generically
    }
}

// MARK: - ModifiedSelectFolderViewController
class ModifiedSelectFolderViewController: UIViewController {
    // MARK: - Properties
    private let entryRepository: EntryRepository
    weak var delegate: ModifiedSelectFolderViewControllerDelegate?
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, FolderItem>!
    
    private var categories: [NestCategory] = []
    private var selectedEntries: Set<BaseEntry> = []
    private var selectedPlaces: Set<PlaceItem> = []
    private var pendingUpdateNeeded = false
    private var folderItemCounts: [String: Int] = [:]
    
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
        
        collectionView.delegate = self
        loadCategories()
    }
    
    // Method to update selected entries and refresh the display
    func updateSelectedEntries(_ entries: Set<BaseEntry>) {
        selectedEntries = entries
        // Only apply snapshot if view is loaded and configured
        if isViewLoaded && dataSource != nil {
            applySnapshot()
            pendingUpdateNeeded = false
        } else {
            // Mark that we need to update when the view is ready
            pendingUpdateNeeded = true
        }
    }
    
    // Method to update selected places and refresh the display
    func updateSelectedPlaces(_ places: Set<PlaceItem>) {
        selectedPlaces = places
        // Only apply snapshot if view is loaded and configured
        if isViewLoaded && dataSource != nil {
            applySnapshot()
            pendingUpdateNeeded = false
        } else {
            // Mark that we need to update when the view is ready
            pendingUpdateNeeded = true
        }
    }
    
    // Helper method to count selected entries in a specific folder
    private func countSelectedEntriesInFolder(_ folderPath: String) -> Int {
        return selectedEntries.filter { entry in
            entry.category.hasPrefix(folderPath)
        }.count
    }
    
    // Helper method to count selected places in a specific folder
    private func countSelectedPlacesInFolder(_ folderPath: String) -> Int {
        return selectedPlaces.filter { place in
            place.category.hasPrefix(folderPath)
        }.count
    }
    
    // Helper method to count all selected items (entries + places) in a specific folder
    private func countSelectedItemsInFolder(_ folderPath: String) -> Int {
        return countSelectedEntriesInFolder(folderPath) + countSelectedPlacesInFolder(folderPath)
    }
    
    // Helper method to get cached total items count for a specific folder
    private func getTotalItemsInFolder(_ folderPath: String) -> Int {
        return folderItemCounts[folderPath] ?? 0
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
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        
        view.addSubview(collectionView)
        
        // Set up Auto Layout constraints
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Use automatic content inset adjustment for proper navigation bar handling
        collectionView.contentInsetAdjustmentBehavior = .automatic
        
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
