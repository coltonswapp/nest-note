//
//  NestCategoryViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 10/6/24.
//

import UIKit
import RevenueCat
import RevenueCatUI
import TipKit

class NestCategoryViewController: NNViewController, NestLoadable, CollectionViewLoadable, PaywallPresentable, PaywallViewControllerDelegate, NNTippable {
    // MARK: - Properties
    private let entryRepository: EntryRepository
    private let category: String
    private let sessionVisibilityLevel: VisibilityLevel
    
    // MARK: - PaywallPresentable
    var proFeature: ProFeature {
        return .unlimitedEntries
    }
    
    // Required by NestLoadable
    var loadingIndicator: UIActivityIndicatorView!
    var hasLoadedInitialData: Bool = false
    var refreshControl: UIRefreshControl!
    
    var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, AnyHashable>!
    private var addEntryButton: NNPrimaryLabeledButton!
    private var emptyStateView: NNEmptyStateView!
    
    enum Section: Int, CaseIterable {
        case folders, codes, other
    }
    
    var entries: [BaseEntry] = [] {
        didSet {
            applySnapshot()
        }
    }
    
    private var folders: [FolderData] = [] {
        didSet {
            applySnapshot()
        }
    }
    
    // Track the order of sections in the current snapshot
    private var sectionOrder: [Section] = []
    
    // Store the index path for context menu preview
    private var contextMenuIndexPath: IndexPath?
    
    // Edit mode properties
    private var isEditingMode: Bool = false {
        didSet {
            updateEditModeUI()
        }
    }
    private var selectedEntries: Set<BaseEntry> = []
    
    // Select entries mode properties
    private var isEditOnlyMode: Bool = false
    weak var selectEntriesDelegate: NestCategoryViewControllerSelectEntriesDelegate?
    
    init(category: String, entries: [BaseEntry] = [], entryRepository: EntryRepository, sessionVisibilityLevel: VisibilityLevel? = nil, isEditOnlyMode: Bool = false) {
        self.category = category
        self.entries = entries
        self.entryRepository = entryRepository
        self.isEditOnlyMode = isEditOnlyMode
        // For nest owners, access level doesn't matter since they bypass all checks. For sitters, use provided level or default to standard
        self.sessionVisibilityLevel = entryRepository is NestService ? .extended : (sessionVisibilityLevel ?? .halfDay)
        super.init(nibName: nil, bundle: nil)
        
        // Extract the folder name from the full path for the title
        // e.g. "Pets/Donna" becomes "Donna"
        title = category.components(separatedBy: "/").last ?? category
    }
    
    // Convenience initializer for select entries flow
    convenience init(entryRepository: EntryRepository, initialCategory: String, isEditOnlyMode: Bool) {
        self.init(category: initialCategory, entries: [], entryRepository: entryRepository, sessionVisibilityLevel: nil, isEditOnlyMode: isEditOnlyMode)
    }
    
    // Method to restore selected entries for persistent selection
    func restoreSelectedEntries(_ entries: Set<BaseEntry>) {
        selectedEntries = entries
        
        // If we're already loaded, update the UI immediately
        if isViewLoaded {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
                self.restoreCollectionViewSelection()
                self.selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedEntries: self.selectedEntries)
            }
        }
    }
    
    // Helper method to restore collection view selection state
    private func restoreCollectionViewSelection() {
        guard isEditingMode, let dataSource = self.dataSource else { return }
        
        let snapshot = dataSource.snapshot()
        
        // Iterate through all sections and items to find matching entries
        for sectionIdentifier in snapshot.sectionIdentifiers {
            let items = snapshot.itemIdentifiers(inSection: sectionIdentifier)
            
            for (itemIndex, item) in items.enumerated() {
                // Check if this item is a BaseEntry and if it's selected
                if let entry = item as? BaseEntry, selectedEntries.contains(entry) {
                    // Find the section index
                    if let sectionIndex = snapshot.sectionIdentifiers.firstIndex(of: sectionIdentifier) {
                        let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                    }
                }
            }
        }
    }
    
    // Helper method to count selected entries in a specific folder
    private func countSelectedEntriesInFolder(_ folderPath: String) -> Int {
        let count = selectedEntries.filter { entry in
            entry.category.hasPrefix(folderPath)
        }.count
        
        // Debug logging
        if count > 0 {
            print("🔍 Found \(count) selected entries for folder: \(folderPath)")
            selectedEntries.forEach { entry in
                if entry.category.hasPrefix(folderPath) {
                    print("   - Entry: \(entry.title) in category: \(entry.category)")
                }
            }
        }
        
        return count
    }
    
    // Helper method to refresh folder selection counts
    private func refreshFolderSelectionCounts() {
        guard isEditOnlyMode else { return }
        
        print("🔄 Refreshing folder selection counts...")
        
        // Update folder data with new selection counts
        let updatedFolders = folders.map { folder in
            let selectionCount = countSelectedEntriesInFolder(folder.fullPath)
            print("📁 Folder '\(folder.title)' (\(folder.fullPath)): \(selectionCount) selected")
            
            return FolderData(
                title: folder.title,
                image: folder.image,
                itemCount: folder.itemCount,
                fullPath: folder.fullPath,
                category: folder.category,
                selectedCount: selectionCount
            )
        }
        
        self.folders = updatedFolders
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupCollectionView()
        setupLoadingIndicator()
        setupRefreshControl()
        setupNavigationBar()
        setupAddEntryButton()
        configureDataSource()
        setupEmptyStateView()
        collectionView.delegate = self
        
        // If in edit-only mode, automatically enter edit mode
        if isEditOnlyMode {
            isEditingMode = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !hasLoadedInitialData {
            Task {
                await loadEntries()
            }
        }
    }
    
    // Implement NestLoadable requirement
    func handleLoadedEntries(_ groupedEntries: [String: [BaseEntry]]) {
        // If category contains "/", it's a folder path - filter entries that match this exact path
        if category.contains("/") {
            var matchingEntries: [BaseEntry] = []
            for (_, categoryEntries) in groupedEntries {
                for entry in categoryEntries {
                    if entry.category == category {
                        matchingEntries.append(entry)
                    }
                }
            }
            self.entries = matchingEntries
        } else {
            // For root categories, use the original logic
            self.entries = groupedEntries[category] ?? []
        }
        
        // Also fetch and update folders for this category
        fetchFoldersForCategory(groupedEntries)
        
        refreshEmptyState()
        
        // Restore selection state if in edit-only mode
        if isEditOnlyMode && isEditingMode {
            DispatchQueue.main.async {
                self.restoreCollectionViewSelection()
            }
        }
    }
    
    private func fetchFoldersForCategory(_ groupedEntries: [String: [BaseEntry]]) {
        // Only fetch folders for NestService (nest owners) as they have access to categories
        guard let nestService = entryRepository as? NestService else {
            self.folders = []
            return
        }
        
        Task {
            do {
                // Fetch categories to detect empty folders
                let categories = try await nestService.fetchCategories()
                
                await MainActor.run {
                    var folderItems: [FolderData] = []
                    var folderCounts: [String: Int] = [:]
                    
                    // Get all unique folder paths that are subfolders of the current category
                    var currentLevelFolders: Set<String> = []
                    
                    // First, count entries in subfolders
                    for (categoryName, categoryEntries) in groupedEntries {
                        for entry in categoryEntries {
                            let folderPath = entry.category
                            
                            // Check if this entry belongs to a subfolder of the current category
                            if folderPath.hasPrefix(self.category + "/") {
                                let remainingPath = String(folderPath.dropFirst(self.category.count + 1))
                                
                                if !remainingPath.isEmpty {
                                    // This entry is in a subfolder
                                    let nextFolderComponent = remainingPath.components(separatedBy: "/").first!
                                    let nextFolderPath = "\(self.category)/\(nextFolderComponent)"
                                    currentLevelFolders.insert(nextFolderPath)
                                    folderCounts[nextFolderPath, default: 0] += 1
                                }
                            }
                        }
                    }
                    
                    // Then, add empty folders from categories that don't have entries yet
                    for nestCategory in categories {
                        let folderPath = nestCategory.name
                        
                        // Check if this category is a direct subfolder of the current category
                        if folderPath.hasPrefix(self.category + "/") {
                            let remainingPath = String(folderPath.dropFirst(self.category.count + 1))
                            
                            // Make sure it's a direct child (no more slashes)
                            if !remainingPath.isEmpty && !remainingPath.contains("/") {
                                currentLevelFolders.insert(folderPath)
                                // Don't override the count if we already have entries
                                if folderCounts[folderPath] == nil {
                                    folderCounts[folderPath] = 0
                                }
                            }
                        }
                    }
                    
                    // Create FolderData objects for each subfolder
                    for folderPath in currentLevelFolders.sorted() {
                        let folderName = folderPath.components(separatedBy: "/").last ?? folderPath
                        
                        // Find the matching category to get the correct icon
                        let matchingCategory = categories.first { $0.name == folderPath }
                        let iconName = matchingCategory?.symbolName ?? "folder"
                        let image = UIImage(systemName: iconName)
                        
                        let folderData = FolderData(
                            title: folderName,
                            image: image,
                            itemCount: folderCounts[folderPath] ?? 0,
                            fullPath: folderPath,
                            category: matchingCategory,
                            selectedCount: isEditOnlyMode ? countSelectedEntriesInFolder(folderPath) : 0
                        )
                        folderItems.append(folderData)
                    }
                    
                    self.folders = folderItems
                }
            } catch {
                Logger.log(level: .error, category: .nestService, message: "Failed to fetch categories for folder detection: \(error.localizedDescription)")
                await MainActor.run {
                    self.folders = []
                }
            }
        }
    }
    
    func refreshEmptyState() {
        // Show or hide empty state view based on entries and folders count
        if entries.isEmpty && folders.isEmpty {
            emptyStateView.isHidden = false
            view.bringSubviewToFront(emptyStateView)
            addEntryButton?.isHidden = true
        } else {
            emptyStateView.isHidden = true
            addEntryButton?.isHidden = false
        }
    }
    
    // MARK: - CollectionViewLoadable Implementation
    func handleLoadedData() {
        // This is called when data is loaded
        // We're already handling this in handleLoadedEntries
    }
    
    func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        
        // Adjust content inset to prevent button obstruction (only if not in edit-only mode)
        if !isEditOnlyMode {
            let buttonHeight: CGFloat = 55
            let buttonPadding: CGFloat = 10
            let totalInset = buttonHeight + buttonPadding * 2
            collectionView.contentInset.bottom = totalInset
            collectionView.verticalScrollIndicatorInsets.bottom = totalInset
        }
        
        // Register cells
        collectionView.register(AddressCell.self, forCellWithReuseIdentifier: AddressCell.reuseIdentifier)
        collectionView.register(FullWidthCell.self, forCellWithReuseIdentifier: FullWidthCell.reuseIdentifier)
        collectionView.register(HalfWidthCell.self, forCellWithReuseIdentifier: HalfWidthCell.reuseIdentifier)
        collectionView.register(FolderCollectionViewCell.self, forCellWithReuseIdentifier: FolderCollectionViewCell.reuseIdentifier)
        
        collectionView.allowsSelection = true
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            guard let self = self else { return nil }
            
            // Use the stored section order to get the correct section
            guard sectionIndex < self.sectionOrder.count else { return nil }
            let section = self.sectionOrder[sectionIndex]
            
            switch section {
            case .folders:
                return self.createFoldersSection()
            case .codes:
                // Only use different section layouts for Household category
                if self.category == "Household" {
                    return self.createHalfWidthSection()
                } else {
                    return self.createInsetGroupedSection()
                }
            case .other:
                return self.createInsetGroupedSection()
            }
        }
        return layout
    }
    
    private func createFullWidthSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
        return NSCollectionLayoutSection(group: group)
    }
    
    private func createHalfWidthSection() -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(90))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(90))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 4, bottom: 12, trailing: 4)
        
        return section
    }
    
    private func createMixedWidthSection() -> NSCollectionLayoutSection {
        let fullWidthItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let fullWidthItem = NSCollectionLayoutItem(layoutSize: fullWidthItemSize)
        
        let halfWidthItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .estimated(44))
        let halfWidthItem = NSCollectionLayoutItem(layoutSize: halfWidthItemSize)
        
        let halfWidthGroupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let halfWidthGroup = NSCollectionLayoutGroup.horizontal(layoutSize: halfWidthGroupSize, subitems: [halfWidthItem, halfWidthItem])
        
        let mixedGroup = NSCollectionLayoutGroup.vertical(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(88)), subitems: [fullWidthItem, halfWidthGroup])
        
        return NSCollectionLayoutSection(group: mixedGroup)
    }
    
    private func createFoldersSection() -> NSCollectionLayoutSection {
        // 2-item grid layout for folders (exactly matching NestViewController)
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
        
        return section
    }

    private func createInsetGroupedSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        section.interGroupSpacing = 8  // Reduce this value to decrease spacing between items
        
        return section
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, AnyHashable>(collectionView: collectionView) {
            [weak self] (collectionView, indexPath, item) -> UICollectionViewCell? in
            guard let self = self else { return nil }
            
            // Get the actual section from the snapshot, not the raw value
            guard let dataSource = self.dataSource else { return nil }
            let snapshot = dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            
            // Handle folders section
            if section == .folders, let folderData = item as? FolderData {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FolderCollectionViewCell.reuseIdentifier, for: indexPath) as! FolderCollectionViewCell
                cell.configure(with: folderData)
                return cell
            }
            
            // Handle entries
            guard let entry = item as? BaseEntry else {
                // Log unexpected item type for debugging
                Logger.log(level: .error, category: .nestService, message: "Unexpected item type in cell provider: \(type(of: item)) at section \(section) indexPath \(indexPath)")
                return nil
            }
            
            // Use different cell types only for Household category
            if self.category == "Household" {
                switch section {
                case .codes:
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HalfWidthCell.reuseIdentifier, for: indexPath) as! HalfWidthCell
                    cell.configure(
                        key: entry.title,
                        value: entry.content,
                        entryVisibility: entry.visibility,
                        sessionVisibility: self.sessionVisibilityLevel,
                        isNestOwner: self.entryRepository is NestService,
                        isEditMode: self.isEditingMode,
                        isSelected: self.selectedEntries.contains(entry)
                    )
                    
                    return cell
                case .other:
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                    cell.configure(
                        key: entry.title,
                        value: entry.content,
                        entryVisibility: entry.visibility,
                        sessionVisibility: self.sessionVisibilityLevel,
                        isNestOwner: self.entryRepository is NestService,
                        isEditMode: self.isEditingMode,
                        isSelected: self.selectedEntries.contains(entry)
                    )
                    
                    return cell
                case .folders:
                    // This should not happen with proper snapshot creation - debug and handle gracefully
                    Logger.log(level: .error, category: .nestService, message: "DEBUGGING: BaseEntry '\(entry.title)' found in folders section at indexPath \(indexPath). Entry category: '\(entry.category)'. Current category: '\(self.category)'")
                    
                    // Use fallback cell to prevent crash
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                    cell.configure(
                        key: entry.title,
                        value: entry.content,
                        entryVisibility: entry.visibility,
                        sessionVisibility: self.sessionVisibilityLevel,
                        isNestOwner: self.entryRepository is NestService,
                        isEditMode: self.isEditingMode,
                        isSelected: self.selectedEntries.contains(entry)
                    )
                    
                    return cell
                }
            } else {
                // Use full-width cells for all entries in other categories, regardless of section
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                cell.configure(
                    key: entry.title,
                    value: entry.content,
                    entryVisibility: entry.visibility,
                    sessionVisibility: self.sessionVisibilityLevel,
                    isNestOwner: self.entryRepository is NestService,
                    isEditMode: self.isEditingMode,
                    isSelected: self.selectedEntries.contains(entry)
                )
                
                return cell
            }
        }
    }
    
    private func createSnapshot() -> NSDiffableDataSourceSnapshot<Section, AnyHashable> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, AnyHashable>()
        
        // Debug logging
        Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Creating snapshot for category '\(category)'. Folders: \(folders.count), Entries: \(entries.count)")
        
        // Determine which sections we need based on content
        var sectionsToAdd: [Section] = []
        
        // Add folders section if we have folders
        if !folders.isEmpty {
            sectionsToAdd.append(.folders)
            Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Adding .folders section with \(folders.count) folders")
        }
        
        if category == "Household" {
            // Filter entries based on cell type
            let codesEntries = entries.filter { $0.shouldUseHalfWidthCell }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            let otherEntries = entries.filter { !$0.shouldUseHalfWidthCell }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            
            Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Household category - Codes: \(codesEntries.count), Other: \(otherEntries.count)")
            
            // Only add sections that have content
            if !codesEntries.isEmpty {
                sectionsToAdd.append(.codes)
                Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Adding .codes section")
            }
            if !otherEntries.isEmpty {
                sectionsToAdd.append(.other)
                Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Adding .other section")
            }
            
            // Add the sections to snapshot
            snapshot.appendSections(sectionsToAdd)
            Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Final sections in snapshot: \(sectionsToAdd.map { $0.rawValue })")
            
            // Add content to sections
            if !folders.isEmpty {
                let sortedFolders = folders.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Adding \(sortedFolders.count) folders to .folders section: \(sortedFolders.map { $0.title })")
                snapshot.appendItems(sortedFolders, toSection: .folders)
            }
            if !codesEntries.isEmpty {
                Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Adding \(codesEntries.count) entries to .codes section: \(codesEntries.map { $0.title })")
                snapshot.appendItems(codesEntries, toSection: .codes)
            }
            if !otherEntries.isEmpty {
                Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Adding \(otherEntries.count) entries to .other section: \(otherEntries.map { $0.title })")
                snapshot.appendItems(otherEntries, toSection: .other)
            }
        } else {
            // For non-Household categories, all entries go in .other section
            let sortedEntries = entries.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            
            Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Non-Household category - Entries: \(sortedEntries.count)")
            
            // Only add .other section if we have entries
            if !sortedEntries.isEmpty {
                sectionsToAdd.append(.other)
                Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Adding .other section")
            }
            
            // Add the sections to snapshot
            snapshot.appendSections(sectionsToAdd)
            Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Final sections in snapshot: \(sectionsToAdd.map { $0.rawValue })")
            
            // Add content to sections
            if !folders.isEmpty {
                let sortedFolders = folders.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Adding \(sortedFolders.count) folders to .folders section: \(sortedFolders.map { $0.title })")
                snapshot.appendItems(sortedFolders, toSection: .folders)
            }
            if !sortedEntries.isEmpty {
                Logger.log(level: .info, category: .nestService, message: "DEBUGGING: Adding \(sortedEntries.count) entries to .other section: \(sortedEntries.map { $0.title })")
                snapshot.appendItems(sortedEntries, toSection: .other)
            }
        }
        
        // Store the section order for layout creation
        self.sectionOrder = sectionsToAdd
        
        return snapshot
    }
    
    private func applySnapshot() {
        guard let dataSource = self.dataSource else { return }
        
        let snapshot = createSnapshot()
        
        // Update the collection view layout since section order may have changed
        collectionView.setCollectionViewLayout(createLayout(), animated: false)
        
        dataSource.apply(snapshot, animatingDifferences: false)
        collectionView.layoutIfNeeded()
    }
    
    private var allEntries: [BaseEntry] {
        return entries
    }
    
    private func setupNavigationBar() {
        // Only show menu button for nest owners
        if entryRepository is NestService {
            if isEditingMode {
                // In edit-only mode, don't show any navigation buttons as the flow controller handles navigation
                if isEditOnlyMode {
                    navigationItem.rightBarButtonItems = []
                } else {
                    // When in edit mode, show a simple "Done" button
                    let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonTapped))
                    navigationItem.rightBarButtonItems = [doneButton]
                }
            } else {
                // Create top section actions (suggestions and add folder)
                var topActions: [UIAction] = [
                    UIAction(title: "Entry Suggestions", image: UIImage(systemName: "sparkles")) { _ in
                        self.showEntrySuggestions()
                    }
                ]
                
                // Only show "Add Folder" if we haven't reached max depth
                let currentDepth = category.components(separatedBy: "/").count
                if currentDepth < 3 {
                    topActions.append(
                        UIAction(title: "Add Folder", image: UIImage(systemName: "folder.badge.plus")) { _ in
                            self.presentAddFolder()
                        }
                    )
                }
                
                // Create divider section with top actions
                let topSection = UIMenu(title: "", options: .displayInline, children: topActions)
                
                // Create Edit action (separate section)
                let editAction = UIAction(title: "Select", image: UIImage(systemName: "checkmark.circle")) { _ in
                    self.toggleEditMode()
                }
                
                // Combine sections with divider
                let menu = UIMenu(title: "", children: [topSection, editAction])
                let menuButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)
                navigationItem.rightBarButtonItems = [menuButton]
            }
            navigationController?.navigationBar.tintColor = .label
        }
    }
    
    private func updateEditModeUI() {
        setupNavigationBar() // Refresh navigation bar to update menu
        collectionView.allowsMultipleSelection = isEditingMode
        
        if !isEditingMode {
            selectedEntries.removeAll()
        }
        
        // Update the add entry button for edit mode
        updateAddEntryButtonForEditMode()
        
        // Reload visible cells to update their appearance
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
    
    private func toggleEditMode() {
        isEditingMode.toggle()
    }
    
    @objc private func doneButtonTapped() {
        isEditingMode = false
        addEntryButton.alpha = 1.0
    }
    
    private func updateCellSelection(for entry: BaseEntry) {
        guard let dataSource = self.dataSource else { return }
        var snapshot = dataSource.snapshot()
        
        // Use reconfigureItems instead of reloadItems for better performance
        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems([entry])
        } else {
            snapshot.reloadItems([entry])
        }
        
        dataSource.apply(snapshot, animatingDifferences: false)
        
        // Update move button state when selection changes
        updateMoveButtonState()
    }
    
    
    
    private func showEntrySuggestions() {
        // Dismiss the suggestion tip when user opens suggestions
        NNTipManager.shared.dismissTip(NestCategoryTips.entrySuggestionTip)
        
        // Present CommonEntriesViewController as a sheet with medium and large detents
        let commonEntriesVC = CommonEntriesViewController(category: category, entryRepository: entryRepository, sessionVisibilityLevel: sessionVisibilityLevel)
        let navController = UINavigationController(rootViewController: commonEntriesVC)
        
        // Set this view controller as the delegate
        commonEntriesVC.delegate = self
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.prefersEdgeAttachedInCompactHeight = true
        }
        
        present(navController, animated: true)
    }
    
    private func presentAddFolder() {
        Task {
            // Check if user has unlimited categories feature (Pro subscription)
            let hasUnlimitedCategories = await SubscriptionService.shared.isFeatureAvailable(.customCategories)
            if !hasUnlimitedCategories {
                await MainActor.run {
                    // You may need to implement showCategoryLimitUpgradePrompt for this VC
                    // For now, we'll use a simple alert
                    let alert = UIAlertController(
                        title: "Pro Feature",
                        message: "Creating custom folders requires a Pro subscription.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
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
        // Only allow adding entries for nest owners
        guard entryRepository is NestService else { return }
        
        Task {
            // Check entry limit for free tier users
            let hasUnlimitedEntries = await SubscriptionService.shared.isFeatureAvailable(.unlimitedEntries)
            if !hasUnlimitedEntries {
                do {
                    let currentCount = try await (entryRepository as! NestService).getCurrentEntryCount()
                    if currentCount >= 10 {
                        await MainActor.run {
                            self.showEntryLimitUpgradePrompt()
                        }
                        return
                    }
                } catch {
                    Logger.log(level: .error, category: .nestService, message: "Failed to check entry count: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                let newEntryVC = EntryDetailViewController(category: self.category)
                newEntryVC.entryDelegate = self
                self.present(newEntryVC, animated: true)
            }
        }
    }
    
    @objc private func moveButtonTapped() {
        // Handle move action for selected entries
        // No need to check if entries are selected since button is disabled when none are selected
        
        let selectedEntriesArray = Array(selectedEntries)
        let selectFolderVC = SelectFolderViewController(
            entryRepository: entryRepository,
            currentCategory: category,
            selectedEntries: selectedEntriesArray
        )
        selectFolderVC.delegate = self
        
        let navController = UINavigationController(rootViewController: selectFolderVC)
        present(navController, animated: true)
    }
    
    // MARK: - Entry Limit Handling
    
    internal func showEntryLimitUpgradePrompt() {
        showUpgradePrompt(for: proFeature)
    }
    
    private func setupAddEntryButton() {
        // Only show add entry button for nest owners and not in edit-only mode
        guard entryRepository is NestService && !isEditOnlyMode else { return }
        
        addEntryButton = NNPrimaryLabeledButton(title: "New Entry", image: UIImage(systemName: "plus"))
        addEntryButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        addEntryButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
    }
    
    private func updateAddEntryButtonForEditMode() {
        guard let addEntryButton = addEntryButton else { return }
        
        if isEditingMode {
            // Change to "Move" button with arrow.right icon
            addEntryButton.setTitle("Move")
            addEntryButton.setImage(UIImage(systemName: "arrow.right"))
            addEntryButton.removeTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
            addEntryButton.addTarget(self, action: #selector(moveButtonTapped), for: .touchUpInside)
            
            // Update button state based on selection
            updateMoveButtonState()
        } else {
            // Change back to "New Entry" button with plus icon
            addEntryButton.setTitle("New Entry")
            addEntryButton.setImage(UIImage(systemName: "plus"))
            addEntryButton.removeTarget(self, action: #selector(moveButtonTapped), for: .touchUpInside)
            addEntryButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
            addEntryButton.isEnabled = true // Ensure it's enabled when not in edit mode
        }
    }
    
    private func updateMoveButtonState() {
        guard let addEntryButton = addEntryButton, isEditingMode else { return }
        
        let hasSelection = !selectedEntries.isEmpty
        addEntryButton.isEnabled = hasSelection
        
        // Update visual appearance based on enabled state
        addEntryButton.alpha = hasSelection ? 1.0 : 0.6
    }
    
    func showTips() {
        // Only show tips for nest owners
        guard entryRepository is NestService else { return }
        
        trackScreenVisit()
        
        // Show "Entries Live Here" tip first, pointing to the title
        if NNTipManager.shared.shouldShowTip(NestCategoryTips.entriesLiveHereTip) {
            // Use the navigation bar title as the source view
            if let titleView = navigationController?.navigationBar {
                NNTipManager.shared.showTip(
                    NestCategoryTips.entriesLiveHereTip,
                    sourceView: titleView,
                    in: self,
                    pinToEdge: .bottom,
                    offset: CGPoint(x: 0, y: 8)
                )
                return
            }
        }
        
        // Show suggestion tip for nest owners and if the menu button exists
        if let menuButton = navigationItem.rightBarButtonItems?.first,
           NNTipManager.shared.shouldShowTip(NestCategoryTips.entrySuggestionTip),
           !NNTipManager.shared.shouldShowTip(NestCategoryTips.entriesLiveHereTip) {
            
            // Show the tooltip anchored to the navigation bar menu button
            // Using .bottom edge to show tooltip below the navigation bar
            guard !(navigationController?.navigationBar.prefersLargeTitles ?? false) else { return }
            
            if let buttonView = menuButton.value(forKey: "view") as? UIView {
                NNTipManager.shared.showTip(
                    NestCategoryTips.entrySuggestionTip,
                    sourceView: buttonView,
                    in: self,
                    pinToEdge: .bottom,
                    offset: CGPoint(x: -8, y: 0)
                )
            }
        }
    }
    
    
    private func flashCell(for entry: BaseEntry) {
        guard let indexPath = dataSource?.indexPath(for: entry),
              let cell = collectionView.cellForItem(at: indexPath) else { return }
        
        if let halfWidthCell = cell as? HalfWidthCell {
            halfWidthCell.flash()
        } else if let fullWidthCell = cell as? FullWidthCell {
            fullWidthCell.flash()
        }
    }
    
    private func updateLocalEntry(_ entry: BaseEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            
            DispatchQueue.main.async {
                guard let dataSource = self.dataSource else { return }
                var snapshot = dataSource.snapshot()
                
                let section: Section
                if self.category == "Household" {
                    if entry.shouldUseHalfWidthCell {
                        section = .codes
                    } else {
                        section = .other
                    }
                } else {
                    section = .other
                }
                
                let items = snapshot.itemIdentifiers(inSection: section)
                let entryItems = items.compactMap { $0 as? BaseEntry }
                if !entryItems.isEmpty && entryItems.contains(where: { $0.id == entry.id }) {
                    snapshot.reloadItems([entry])
                    dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
                        self?.flashCell(for: entry)
                    }
                }
            }
        } else {
            Logger.log(level: .error, category: .nestService, message: "Entry not found for update: \(entry.id)")
        }
    }
    
    private func addLocalEntry(_ entry: BaseEntry) {
        entries.append(entry)
        
        DispatchQueue.main.async {
            guard let dataSource = self.dataSource else { return }
            var snapshot = dataSource.snapshot()
            
            let section: Section
            if self.category == "Household" {
                if entry.shouldUseHalfWidthCell {
                    section = .codes
                } else {
                    section = .other
                }
            } else {
                section = .other
            }
            
            snapshot.appendItems([entry], toSection: section)
            dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
                self?.flashCell(for: entry)
            }
        }
    }
    
    // Update loadEntries to use the repository
    private func loadEntries() async {
        do {
            let groupedEntries = try await entryRepository.fetchEntries()
            await MainActor.run {
                self.hasLoadedInitialData = true
                self.handleLoadedEntries(groupedEntries)
            }
        } catch {
            Logger.log(level: .error, category: .nestService, message: "Failed to load entries: \(error)")
            // Handle error appropriately
        }
    }
    
    // Update refresh to use the repository
    @objc private func refresh() {
        Task {
            do {
                let groupedEntries = try await entryRepository.refreshEntries()
                await MainActor.run {
                    self.refreshControl.endRefreshing()
                    self.handleLoadedEntries(groupedEntries)
                }
            } catch {
                Logger.log(level: .error, category: .nestService, message: "Failed to refresh entries: \(error)")
                await MainActor.run {
                    self.refreshControl.endRefreshing()
                }
                // Handle error appropriately
            }
        }
    }
    
    private func setupEmptyStateView() {
        if isEditOnlyMode {
            // Edit-only mode: simplified empty state with no action button
            emptyStateView = NNEmptyStateView(
                icon: UIImage(systemName: "moon.zzz.fill"),
                title: "No entries to select",
                subtitle: "There are no entries in this folder yet.",
                actionButtonTitle: nil
            )
        } else {
            // Normal mode: standard empty state with action button for nest owners
            emptyStateView = NNEmptyStateView(
                icon: UIImage(systemName: "moon.zzz.fill"),
                title: "It's a little quiet in here",
                subtitle: "Entries for this category will appear here. Suggestions can be found in the upper-right corner.",
                actionButtonTitle: entryRepository is NestService ? "Add an Entry" : nil
            )
        }
        
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        emptyStateView.isUserInteractionEnabled = !isEditOnlyMode // Disable interaction in edit-only mode
        emptyStateView.delegate = self
        
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    // MARK: - Folder Management
    
    private func deleteFolderWithConfirmation(_ folderData: FolderData) {
        let alert = UIAlertController(
            title: "Delete Folder",
            message: "Are you sure you want to delete the folder '\(folderData.title)'? This will also delete all entries within this folder. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteFolder(folderData)
        })
        
        present(alert, animated: true)
    }
    
    private func deleteFolder(_ folderData: FolderData) {
        guard let nestService = entryRepository as? NestService else {
            Logger.log(level: .error, category: .nestService, message: "Only nest owners can delete folders")
            return
        }
        
        Task {
            do {
                // Delete the category/folder from the backend
                try await nestService.deleteCategory(folderData.fullPath)
                
                await MainActor.run {
                    Logger.log(level: .info, category: .nestService, message: "Folder deleted: \(folderData.fullPath)")
                    self.showToast(text: "Folder Deleted")
                    
                    // Simply remove the deleted folder from the local folders array
                    self.folders.removeAll { $0.fullPath == folderData.fullPath }
                }
            } catch {
                await MainActor.run {
                    Logger.log(level: .error, category: .nestService, message: "Failed to delete folder: \(error.localizedDescription)")
                    self.showToast(text: "Failed to delete folder")
                }
            }
        }
    }
}

extension NestCategoryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let selectedItem = dataSource.itemIdentifier(for: indexPath),
              let cell = collectionView.cellForItem(at: indexPath) else { return }
        
        // Handle folder selection
        if let folderData = selectedItem as? FolderData {
            collectionView.deselectItem(at: indexPath, animated: true)
            
            if isEditOnlyMode {
                // In edit-only mode, navigate to subfolder for entry selection
                Logger.log(level: .info, category: .nestService, message: "Selected folder for entry selection: \(folderData.title)")
                
                let subfolderVC = NestCategoryViewController(
                    entryRepository: entryRepository,
                    initialCategory: folderData.fullPath,
                    isEditOnlyMode: true
                )
                subfolderVC.selectEntriesDelegate = selectEntriesDelegate
                subfolderVC.restoreSelectedEntries(selectedEntries)
                
                navigationController?.pushViewController(subfolderVC, animated: true)
            } else if !isEditingMode {
                // Normal folder navigation (not in edit mode)
                Logger.log(level: .info, category: .nestService, message: "Selected folder: \(folderData.title)")
                
                let subfolderVC = NestCategoryViewController(
                    category: folderData.fullPath,
                    entries: [],
                    entryRepository: entryRepository,
                    sessionVisibilityLevel: sessionVisibilityLevel
                )
                navigationController?.pushViewController(subfolderVC, animated: true)
            }
            return
        }
        
        // Handle entry selection
        guard let selectedEntry = selectedItem as? BaseEntry else { return }
        
        // If in edit mode, toggle selection
        if isEditingMode {
            // Add haptic feedback for selection
            HapticsHelper.superLightHaptic()
            
            if selectedEntries.contains(selectedEntry) {
                selectedEntries.remove(selectedEntry)
                collectionView.deselectItem(at: indexPath, animated: true)
            } else {
                selectedEntries.insert(selectedEntry)
            }
            
            // Notify delegate in edit-only mode
            if isEditOnlyMode {
                selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedEntries: selectedEntries)
                refreshFolderSelectionCounts()
            }
            
            // Update the cell appearance using diffable data source
            updateCellSelection(for: selectedEntry)
            return
        }
        
        // Normal entry selection (not in edit mode)
        collectionView.deselectItem(at: indexPath, animated: true)
        
        // Check if user has access to this entry (skip check for nest owners)
        if !(entryRepository is NestService) && !sessionVisibilityLevel.hasAccess(to: selectedEntry.visibility) {
            let alert = UIAlertController(
                title: "Access Required",
                message: "This entry requires \(selectedEntry.visibility.title) access level. The current access level for this session is \(sessionVisibilityLevel.title).",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        Logger.log(level: .info, category: .nestService, message: "Selected entry for editing: \(selectedEntry.title)")
        
        let cellFrame = collectionView.convert(cell.frame, to: nil)
        let isReadOnly = !(entryRepository is NestService)
        
        let editEntryVC = EntryDetailViewController(
            category: category,
            entry: selectedEntry,
            sourceFrame: cellFrame,
            isReadOnly: isReadOnly
        )
        editEntryVC.entryDelegate = self
        present(editEntryVC, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        // Handle deselection in edit mode
        if isEditingMode,
           let selectedItem = dataSource.itemIdentifier(for: indexPath),
           let selectedEntry = selectedItem as? BaseEntry {
            selectedEntries.remove(selectedEntry)
            
            // Notify delegate in edit-only mode
            if isEditOnlyMode {
                selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedEntries: selectedEntries)
                refreshFolderSelectionCounts()
            }
            
            // Update the cell appearance using diffable data source
            updateCellSelection(for: selectedEntry)
        }
    }
    
    // MARK: - Context Menu Support
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        // Disable context menu in edit-only mode
        guard !isEditOnlyMode else { return nil }
        
        guard let item = dataSource.itemIdentifier(for: indexPath),
              let folderData = item as? FolderData,
              entryRepository is NestService else {
            // Only show context menu for folders and only for nest owners
            return nil
        }
        
        // Store the index path for the preview method
        contextMenuIndexPath = indexPath
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let deleteAction = UIAction(
                title: "Delete Folder",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.deleteFolderWithConfirmation(folderData)
            }
            
            return UIMenu(title: folderData.title, children: [deleteAction])
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        // Use the stored index path from the context menu configuration
        guard let indexPath = contextMenuIndexPath,
              let cell = collectionView.cellForItem(at: indexPath) as? FolderCollectionViewCell else {
            return nil
        }
        
        // Create a custom preview using the folder's custom shape
        let parameters = UIPreviewParameters()
        
        // Create a custom path that matches the folder shape
        let cellBounds = cell.bounds
        let customPath = createFolderShapePath(in: cellBounds)
        parameters.visiblePath = UIBezierPath(cgPath: customPath)
        
        // Set background color to clear to show the custom shape
        parameters.backgroundColor = UIColor.clear
        
        // Create the targeted preview with the custom parameters
        return UITargetedPreview(view: cell, parameters: parameters)
    }
    
    private func createFolderShapePath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let width = rect.width
        let height = rect.height
        
        // Scale the SVG path to fit the cell (SVG is 170x151)
        let scaleX = width / 170.0
        let scaleY = height / 151.0
        
        // Start point from SVG: M0 18.4316
        path.move(to: CGPoint(x: 0, y: 18.4316 * scaleY))
        
        // Curve: C0 8.49052 8.05888 0.431641 18 0.431641
        path.addCurve(to: CGPoint(x: 18 * scaleX, y: 0.431641 * scaleY),
                      control1: CGPoint(x: 0, y: 8.49052 * scaleY),
                      control2: CGPoint(x: 8.05888 * scaleX, y: 0.431641 * scaleY))
        
        // Line: H50.8316
        path.addLine(to: CGPoint(x: 50.8316 * scaleX, y: 0.431641 * scaleY))
        
        // Curve for tab: C53.6933 0.431641 56.5138 1.11397 59.0591 2.42202
        path.addCurve(to: CGPoint(x: 59.0591 * scaleX, y: 2.42202 * scaleY),
                      control1: CGPoint(x: 53.6933 * scaleX, y: 0.431641 * scaleY),
                      control2: CGPoint(x: 56.5138 * scaleX, y: 1.11397 * scaleY))
        
        // Line: L79.3719 12.861
        path.addLine(to: CGPoint(x: 79.3719 * scaleX, y: 12.861 * scaleY)) // Folder Tab Angled Line
        
        // Curve: C81.9172 14.1691 84.7377 14.8514 87.5995 14.8514
        path.addCurve(to: CGPoint(x: 87.5995 * scaleX, y: 14.8514 * scaleY),
                      control1: CGPoint(x: 81.9172 * scaleX, y: 14.1691 * scaleY),
                      control2: CGPoint(x: 84.7377 * scaleX, y: 14.8514 * scaleY))
        
        // Line: H152
        path.addLine(to: CGPoint(x: 152 * scaleX, y: 14.8514 * scaleY))
        
        // Curve: C161.941 14.8514 170 22.9103 170 32.8514
        path.addCurve(to: CGPoint(x: 170 * scaleX, y: 32.8514 * scaleY),
                      control1: CGPoint(x: 161.941 * scaleX, y: 14.8514 * scaleY),
                      control2: CGPoint(x: 170 * scaleX, y: 22.9103 * scaleY))
        
        // Line: V132.431
        path.addLine(to: CGPoint(x: 170 * scaleX, y: 132.431 * scaleY))
        
        // Curve: C170 142.372 161.941 150.431 152 150.431
        path.addCurve(to: CGPoint(x: 152 * scaleX, y: 150.431 * scaleY),
                      control1: CGPoint(x: 170 * scaleX, y: 142.372 * scaleY),
                      control2: CGPoint(x: 161.941 * scaleX, y: 150.431 * scaleY))
        
        // Line: H18
        path.addLine(to: CGPoint(x: 18 * scaleX, y: 150.431 * scaleY))
        
        // Curve: C8.05887 150.431 0 142.372 0 132.431
        path.addCurve(to: CGPoint(x: 0, y: 132.431 * scaleY),
                      control1: CGPoint(x: 8.05887 * scaleX, y: 150.431 * scaleY),
                      control2: CGPoint(x: 0, y: 142.372 * scaleY))
        
        // Close path: Z
        path.closeSubpath()
        
        return path
    }
    
    func collectionView(_ collectionView: UICollectionView, willEndContextMenuInteraction configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        // Clean up the stored index path when context menu ends
        contextMenuIndexPath = nil
    }
}

// Add delegate conformance
extension NestCategoryViewController: EntryDetailViewControllerDelegate {
    func entryDetailViewController(didSaveEntry entry: BaseEntry?) {
        if let entry = entry {
            // Handle save/update
            Logger.log(level: .info, category: .nestService, message: "Delegate received saved entry: \(entry.title)")
            
            if entries.contains(where: { $0.id == entry.id }) {
                updateLocalEntry(entry)
            } else {
                addLocalEntry(entry)
                refreshEmptyState()
            }
        }
    }
    
    func entryDetailViewController(didDeleteEntry entry: BaseEntry) {
        Logger.log(level: .info, category: .nestService, message: "Delegate received deletion")
        
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries.remove(at: index)
            
            DispatchQueue.main.async {
                guard let dataSource = self.dataSource else { return }
                var snapshot = dataSource.snapshot()
                snapshot.deleteItems([entry])
                dataSource.apply(snapshot, animatingDifferences: true)
            }
            
            showToast(text: "Entry Deleted")
            
            refreshEmptyState()
        }
    }
}

// Add this extension to help determine cell size
extension BaseEntry {
    var shouldUseHalfWidthCell: Bool {
        return title.count <= 15 && content.count <= 15
    }
}

// Add this delegate conformance:
extension NestCategoryViewController: CategoryDetailViewControllerDelegate {
    func categoryDetailViewController(_ controller: CategoryDetailViewController, didSaveCategory category: String?, withIcon icon: String?) {
        guard let categoryName = category,
              let iconName = icon,
              let nestService = entryRepository as? NestService else {
            // Only NestService can create categories
            return
        }
        
        Task {
            do {
                // Create full folder path considering current category location
                let fullFolderPath = "\(self.category)/\(categoryName)"
                
                // Create and save the new category with full path and selected icon
                let newCategory = NestCategory(name: fullFolderPath, symbolName: iconName)
                try await nestService.createCategory(newCategory)
                
                await MainActor.run {
                    Logger.log(level: .info, category: .nestService, message: "New folder created: \(fullFolderPath) with icon: \(iconName)")
                    self.showToast(text: "Folder Created")
                    
                    // Force refresh the data to show the new folder immediately
                    Task {
                        await self.loadEntries()
                    }
                }
            } catch {
                await MainActor.run {
                    Logger.log(level: .error, category: .nestService, message: "Failed to create folder: \(error.localizedDescription)")
                    self.showToast(text: "Failed to create folder")
                }
            }
        }
    }
}

// Add delegate conformance for empty state view
extension NestCategoryViewController: NNEmptyStateViewDelegate {
    func emptyStateViewDidTapActionButton(_ emptyStateView: NNEmptyStateView) {
        // Don't handle action button tap in edit-only mode
        guard !isEditOnlyMode else { return }
        
        print("Empty state tapped:")
        // Only allow adding entries for nest owners
        guard entryRepository is NestService else { return }
        
        // Use the same action as the add button
        addButtonTapped()
    }
}

// Add extension to implement the CommonEntriesViewControllerDelegate
extension NestCategoryViewController: CommonEntriesViewControllerDelegate {
    func commonEntriesViewController(_ controller: CommonEntriesViewController, didSelectEntry entry: BaseEntry) {
        // Show the entry detail with this controller as the delegate
        let cellFrame = view.frame  // We don't have a cell frame since we're coming from a different view
        let isReadOnly = !(entryRepository is NestService)
        
        let editEntryVC = EntryDetailViewController(
            category: entry.category,
            entry: entry,
            sourceFrame: cellFrame,
            isReadOnly: isReadOnly
        )
        editEntryVC.entryDelegate = self
        present(editEntryVC, animated: true)
    }
    
    func showUpgradePrompt() {
        showEntryLimitUpgradePrompt()
    }
}

// MARK: - SelectFolderViewControllerDelegate
extension NestCategoryViewController: SelectFolderViewControllerDelegate {
    func selectFolderViewController(_ controller: SelectFolderViewController, didSelectFolder folder: String) {
        Task {
            do {
                guard let nestService = entryRepository as? NestService else {
                    await MainActor.run {
                        controller.dismiss(animated: true)
                        self.showToast(text: "Only nest owners can move entries")
                    }
                    return
                }
                
                let selectedEntriesArray = Array(selectedEntries)
                
                // Move each selected entry to the new folder
                for entry in selectedEntriesArray {
                    var updatedEntry = entry
                    updatedEntry.category = folder
                    try await nestService.updateEntry(updatedEntry)
                }
                
                // Refresh entries from backend to ensure consistency
                let refreshedEntries = try await nestService.refreshEntries()
                
                await MainActor.run {
                    controller.dismiss(animated: true)
                    
                    // Update local entries with refreshed data
                    self.handleLoadedEntries(refreshedEntries)
                    
                    // Exit edit mode and refresh UI
                    self.isEditingMode = false
                    self.selectedEntries.removeAll()
                    self.refreshEmptyState()
                    
                    let entryCount = selectedEntriesArray.count
                    let entryText = entryCount == 1 ? "entry" : "entries"
                    self.showToast(text: "Moved \(entryCount) \(entryText) to \(folder)")
                }
            } catch {
                await MainActor.run {
                    controller.dismiss(animated: true)
                    Logger.log(level: .error, category: .nestService, message: "Failed to move entries: \(error.localizedDescription)")
                    self.showToast(text: "Failed to move entries")
                }
            }
        }
    }
    
    func selectFolderViewControllerDidCancel(_ controller: SelectFolderViewController) {
        controller.dismiss(animated: true)
    }
}


