//
//  NestCategoryViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 10/6/24.
//

import UIKit
import RevenueCat
import RevenueCatUI
import CoreLocation

class NestCategoryViewController: NNViewController, NestLoadable, CollectionViewLoadable, PaywallPresentable, PaywallViewControllerDelegate, NNTippable, PlaceListViewControllerDelegate {
    // MARK: - Properties
    internal let entryRepository: EntryRepository
    private let category: String
    
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
    private var addEntryButton: NNSmallPrimaryButton!
    private var emptyStateView: NNEmptyStateView!
    
    enum Section: Int, CaseIterable {
        case folders, codes, other, places, routines
    }
    
    var entries: [BaseEntry] = [] {
        didSet {
            if shouldApplySnapshotAutomatically {
                applySnapshot()
            }
        }
    }
    
    private var folders: [FolderData] = [] {
        didSet {
            if shouldApplySnapshotAutomatically {
                applySnapshot()
            }
        }
    }
    
    private var filterView: NNCategoryFilterView?
    private var enabledSections: Set<Section> = Set(Section.allCases) {
        didSet {
            if shouldApplySnapshotAutomatically {
                applySnapshot()
            }
        }
    }
    
    var places: [PlaceItem] = [] {
        didSet {
            if shouldApplySnapshotAutomatically {
                applySnapshot()
            }
        }
    }
    
    var routines: [RoutineItem] = [] {
        didSet {
            if shouldApplySnapshotAutomatically {
                applySnapshot()
            }
        }
    }
    
    private var allPlaces: [PlaceItem] = [] // All places (for passing to subfolders)
    
    // Track the order of sections in the current snapshot
    private var sectionOrder: [Section] = []
    private var previousSectionOrder: [Section] = []
    
    // Prevent concurrent snapshot applications
    private var isApplyingSnapshot = false
    
    // Flag to temporarily disable automatic snapshots during bulk operations
    private var shouldApplySnapshotAutomatically = true
    
    // Store the index path for context menu preview
    private var contextMenuIndexPath: IndexPath?
    
    // Edit mode properties
    private var isEditingMode: Bool = false {
        didSet {
            updateEditModeUI()
        }
    }
    private var selectedEntries: Set<BaseEntry> = []
    private var selectedPlaces: Set<PlaceItem> = []
    private var selectedRoutines: Set<RoutineItem> = []
    
    // Select entries mode properties
    private var isEditOnlyMode: Bool = false
    weak var selectEntriesDelegate: NestCategoryViewControllerSelectEntriesDelegate?
    
    // Dynamic logging category based on repository type
    private var logCategory: Logger.Category {
        return entryRepository is NestService ? .nestService : .sitterViewService
    }
    
    init(category: String, entries: [BaseEntry] = [], places: [PlaceItem] = [], entryRepository: EntryRepository, isEditOnlyMode: Bool = false) {
        self.category = category
        self.entries = entries
        self.entryRepository = entryRepository
        self.isEditOnlyMode = isEditOnlyMode
        // For nest owners, access level doesn't matter since they bypass all checks. For sitters, use provided level or default to standard
        super.init(nibName: nil, bundle: nil)
        
        // Store all places for passing to subfolders
        self.allPlaces = places
        
        self.places = places.filter { $0.category == category }
        
        // Extract the folder name from the full path for the title
        // e.g. "Pets/Donna" becomes "Donna"
        title = category.components(separatedBy: "/").last ?? category
    }
    
    // Convenience initializer for select entries flow
    convenience init(entryRepository: EntryRepository, initialCategory: String, isEditOnlyMode: Bool, places: [PlaceItem] = []) {
        self.init(category: initialCategory, entries: [], places: places, entryRepository: entryRepository, isEditOnlyMode: isEditOnlyMode)
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
    
    // Method to restore selected places for persistent selection
    func restoreSelectedPlaces(_ places: Set<PlaceItem>) {
        selectedPlaces = places
        
        // If we're already loaded, update the UI immediately
        if isViewLoaded {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
                self.restoreCollectionViewSelection()
                self.selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedPlaces: self.selectedPlaces)
            }
        }
    }
    
    // Method to restore selected routines for persistent selection
    func restoreSelectedRoutines(_ routines: Set<RoutineItem>) {
        selectedRoutines = routines
        
        // If we're already loaded, update the UI immediately
        if isViewLoaded {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
                self.restoreCollectionViewSelection()
                self.selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedRoutines: self.selectedRoutines)
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
                // Check if this item is a PlaceItem and if it's selected
                else if let place = item as? PlaceItem, selectedPlaces.contains(place) {
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
                    print("   - Entry: \(entry.title) in category: \(entry.category ?? "nil")")
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotificationObservers() {
        // Listen for place creation/update notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(placeDidSave(_:)),
            name: .placeDidSave,
            object: nil
        )
    }
    
    @objc private func placeDidSave(_ notification: Notification) {
        // Refresh folder contents when a place is saved to show the new place
        Task {
            await loadFolderContents()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupCollectionView()
        setupLoadingIndicator()
        setupRefreshControl()
        setupNavigationBar()
        setupFilterView()
        setupAddEntryButton()
        configureDataSource()
        setupEmptyStateView()
        collectionView.delegate = self
        
        // Set up notification observers for place updates
        setupNotificationObservers()
        
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
    
    // Implement NestLoadable requirement - now much simpler!
    func handleLoadedEntries(_ groupedEntries: [String: [BaseEntry]]) {
        // For backward compatibility, this method still exists but now just calls loadFolderContents
        Task {
            await loadFolderContents()
        }
    }
    
    private func loadFolderContents() async {
        do {
            let folderContents: (entries: [BaseEntry], places: [PlaceItem], routines: [RoutineItem], subfolders: [FolderData], allPlaces: [PlaceItem])
            
            if let nestService = entryRepository as? NestService {
                let contents = try await nestService.fetchFolderContents(for: category)
                folderContents = (contents.entries, contents.places, contents.routines, contents.subfolders, contents.allPlaces)
            } else if let sitterService = entryRepository as? SitterViewService {
                let contents = try await sitterService.fetchFolderContents(for: category)
                folderContents = (contents.entries, contents.places, contents.routines, contents.subfolders, contents.allPlaces) // SitterViewService now supports routines
            } else {
                // Fallback for other repository types
                await loadBasicEntries()
                return
            }
            
            await MainActor.run {
                // Disable automatic snapshots during data loading
                self.shouldApplySnapshotAutomatically = false
                
                // Set all the data from the service
                self.entries = folderContents.entries
                self.places = folderContents.places
                self.routines = folderContents.routines
                self.folders = folderContents.subfolders
                self.allPlaces = folderContents.allPlaces
                
                // Re-enable automatic snapshots and apply
                self.shouldApplySnapshotAutomatically = true
                self.applySnapshot()
                
                // Update UI state
                self.refreshEmptyState()
                
                // Update filter view after a brief delay to ensure data is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateFilterView()
                }
                
                // Restore selection state if in edit-only mode
                if self.isEditOnlyMode && self.isEditingMode {
                    self.restoreCollectionViewSelection()
                }
            }
        } catch {
            Logger.log(level: .error, category: logCategory, message: "Failed to load folder contents: \(error)")
            await MainActor.run {
                self.showError("Failed to load folder contents")
            }
        }
    }
    
    private func loadBasicEntries() async {
        do {
            let groupedEntries = try await entryRepository.fetchEntries()
            let entriesForCategory = groupedEntries[category] ?? []
            
            await MainActor.run {
                // Disable automatic snapshots during data loading
                self.shouldApplySnapshotAutomatically = false
                
                // Set the entries data
                self.entries = entriesForCategory
                
                // For sitter view, we don't have folders or places management
                // These should be empty as folders are not navigable for sitters
                self.folders = []
                
                // Places could be loaded here if needed, but for now keep them as initialized
                // self.places remains as passed in the initializer
                
                // Re-enable automatic snapshots and apply
                self.shouldApplySnapshotAutomatically = true
                self.applySnapshot()
                
                // Update UI state
                self.refreshEmptyState()
                
                // Update filter view after a brief delay to ensure data is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateFilterView()
                }
                
                // Restore selection state if in edit-only mode
                if self.isEditOnlyMode && self.isEditingMode {
                    self.restoreCollectionViewSelection()
                }
            }
        } catch {
            Logger.log(level: .error, category: logCategory, message: "Failed to load basic entries: \(error)")
            await MainActor.run {
                self.showError("Failed to load entries")
            }
        }
    }
    
    func refreshEmptyState() {
        // Show or hide empty state view based on entries, folders, places, and routines count
        if entries.isEmpty && folders.isEmpty && places.isEmpty && routines.isEmpty {
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
        
        // Add top content inset for better spacing
        collectionView.contentInset.top = 30
        collectionView.verticalScrollIndicatorInsets.top = 30
        
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
        collectionView.register(PlaceCell.self, forCellWithReuseIdentifier: PlaceCell.reuseIdentifier)
        collectionView.register(RoutineCell.self, forCellWithReuseIdentifier: RoutineCell.reuseIdentifier)
        
        // Register section headers
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SectionHeader")
        
        collectionView.allowsSelection = true
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            guard let self = self else { return nil }
            
            // Use the stored section order to get the correct section
            guard sectionIndex < self.sectionOrder.count else { 
                Logger.log(level: .error, category: logCategory, message: "❌ LAYOUT ERROR: sectionIndex \(sectionIndex) >= sectionOrder.count \(self.sectionOrder.count). SectionOrder: \(self.sectionOrder.map { $0.rawValue })")
                return self.createFullWidthSection() // Fallback section
            }
            let section = self.sectionOrder[sectionIndex]
            
            switch section {
            case .folders:
                return self.createFoldersSection()
            case .codes:
                // Always show header for .codes section (first entries section)
                // Check if .other section is present - if not, codes section needs bottom padding
                let hasOtherSection = self.sectionOrder.contains(.other)
                return self.createHalfWidthSectionWithHeader(needsBottomPadding: !hasOtherSection)
            case .other:
                // Show header only if .codes section is not present (FullWidth-only scenario)
                let hasCodesSection = self.sectionOrder.contains(.codes)
                return hasCodesSection ? self.createFullWidthSection() : self.createFullWidthSectionWithHeader()
            case .places:
                return self.createPlacesSection()
            case .routines:
                return self.createRoutinesSection()
            }
        }
        return layout
    }
    
    private func createFullWidthSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 40, trailing: 12)
        section.interGroupSpacing = 8
        return section
    }
    
    private func createFullWidthSectionWithHeader() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 40, trailing: 12)
        section.interGroupSpacing = 8
        
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NestCategoryViewController.headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    private func createHalfWidthSection() -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(90))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(90))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4)
        return section
    }
    
    private func createHalfWidthSectionWithHeader(needsBottomPadding: Bool = false) -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(90))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(90))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
        let section = NSCollectionLayoutSection(group: group)
        
        // Use 30 points bottom padding when there's no .other section (to match .other section padding)
        let bottomPadding: CGFloat = needsBottomPadding ? 40 : 4
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: bottomPadding, trailing: 4)
        
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NestCategoryViewController.headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        
        return section
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
            top: 0,
            leading: 10,
            bottom: 40,
            trailing: 10
        )
        
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NestCategoryViewController.headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    private func createPlacesSection() -> NSCollectionLayoutSection {
        // Use the same grid layout as PlaceListViewController
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .fractionalWidth(0.6) // Fixed aspect ratio relative to width
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(0.6) // Match item height
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item, item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 40, trailing: 8)
        
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NestCategoryViewController.headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    private func createRoutinesSection() -> NSCollectionLayoutSection {
        // Use the same 2-item grid layout as places
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .absolute(140) // Fixed aspect ratio relative to width
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(140) // Match item height
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item, item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 40, trailing: 8)
        
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NestCategoryViewController.headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        
        return section
    }

    private func createInsetGroupedSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 40, trailing: 12)
        section.interGroupSpacing = 8  // Reduce this value to decrease spacing between items
        
        // Don't add header for inset grouped section when used for .other entries
        // The header is only shown on the .codes section
        
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
            
            // Handle places section
            if section == .places, let placeItem = item as? PlaceItem {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PlaceCell.reuseIdentifier, for: indexPath) as! PlaceCell
                cell.configure(
                    with: placeItem, 
                    isGridLayout: true, 
                    isEditMode: self.isEditingMode, 
                    isSelected: self.selectedPlaces.contains(placeItem)
                )
                return cell
            }
            
            // Handle routines section
            if section == .routines, let routineItem = item as? RoutineItem {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RoutineCell.reuseIdentifier, for: indexPath) as! RoutineCell
                cell.configure(
                    with: routineItem,
                    isEditMode: self.isEditingMode,
                    isSelected: self.selectedRoutines.contains(routineItem)
                )
                return cell
            }
            
            // Handle entries
            guard let entry = item as? BaseEntry else {
                // Log unexpected item type for debugging
                Logger.log(level: .error, category: logCategory, message: "Unexpected item type in cell provider: \(type(of: item)) at section \(section) indexPath \(indexPath)")
                return nil
            }
            
            // Use different cell types based on section
            switch section {
            case .codes:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HalfWidthCell.reuseIdentifier, for: indexPath) as! HalfWidthCell
                cell.configure(
                    key: entry.title,
                    value: entry.content,
                    isNestOwner: self.entryRepository is NestService,
                    isEditMode: self.isEditingMode,
                    isSelected: self.selectedEntries.contains(entry),
                    isModalInPresentation: navigationController?.modalPresentationStyle == .formSheet || navigationController?.modalPresentationStyle == .pageSheet
                )
                
                return cell
            case .other:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                cell.configure(
                    key: entry.title,
                    value: entry.content,
                    isNestOwner: self.entryRepository is NestService,
                    isEditMode: self.isEditingMode,
                    isSelected: self.selectedEntries.contains(entry),
                    isModalInPresentation: navigationController?.modalPresentationStyle == .formSheet || navigationController?.modalPresentationStyle == .pageSheet
                )
                
                return cell
            case .folders:
                // This should not happen with proper snapshot creation - debug and handle gracefully
                Logger.log(level: .error, category: logCategory, message: "DEBUGGING: BaseEntry '\(entry.title)' found in folders section at indexPath \(indexPath). Entry category: '\(entry.category)'. Current category: '\(self.category)'")
                
                // Use fallback cell to prevent crash
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                cell.configure(
                    key: entry.title,
                    value: entry.content,
                    isNestOwner: self.entryRepository is NestService,
                    isEditMode: self.isEditingMode,
                    isSelected: self.selectedEntries.contains(entry),
                    isModalInPresentation: navigationController?.modalPresentationStyle == .formSheet
                )
                
                return cell
            default:
                return nil
            }
        }
        
        // Configure supplementary view provider for section headers
        dataSource.supplementaryViewProvider = { [weak self] (collectionView, kind, indexPath) -> UICollectionReusableView? in
            guard let self = self,
                  kind == UICollectionView.elementKindSectionHeader else { return nil }
            
            // Configure header based on section
            let section = self.sectionOrder[indexPath.section]
            
            // Apply the same logic as in the layout creation
            let shouldShowHeader: Bool
            switch section {
            case .codes:
                // Always show header for .codes section (first entries section)
                shouldShowHeader = true
            case .other:
                // Show header only if .codes section is not present (FullWidth-only scenario)
                shouldShowHeader = !self.sectionOrder.contains(.codes)
            default:
                // All other sections always show headers
                shouldShowHeader = true
            }
            
            if !shouldShowHeader {
                return nil
            }
            
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: "SectionHeader",
                for: indexPath
            )
            
            let title: String
            switch section {
            case .folders:
                title = "FOLDERS"
            case .codes:
                title = "ENTRIES"
            case .other:
                title = "ENTRIES"
            case .places:
                title = "PLACES"
            case .routines:
                title = "ROUTINES"
            }
            
            // Create and configure header label
            header.subviews.forEach { $0.removeFromSuperview() }
            
            let label = UILabel()
            label.text = title
            label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            label.textColor = UIColor.secondaryLabel
            label.translatesAutoresizingMaskIntoConstraints = false
            
            header.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
                label.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8)
            ])
            
            return header
        }
    }
    
    private func createSnapshot() -> NSDiffableDataSourceSnapshot<Section, AnyHashable> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, AnyHashable>()
        
        // Debug logging
        Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Creating snapshot for category '\(category)'. Folders: \(folders.count), Entries: \(entries.count), Places: \(places.count)")
        
        // Filter entries based on cell type (title + content < 15 characters)
        let codesEntries = entries.filter { $0.shouldUseHalfWidthCell }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        let otherEntries = entries.filter { !$0.shouldUseHalfWidthCell }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        
        Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Category '\(category)' - Codes: \(codesEntries.count), Other: \(otherEntries.count)")
        
        // Build sections map similar to the Medium article approach
        var sectionsData: [Section: [AnyHashable]] = [:]
        
        // Add folders section if we have folders and it's enabled
        if !folders.isEmpty && enabledSections.contains(.folders) {
            let sortedFolders = folders.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            sectionsData[.folders] = sortedFolders
            Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Adding .folders section with \(folders.count) folders")
        }
        
        // Add codes entries section if we have them and it's enabled
        if !codesEntries.isEmpty && enabledSections.contains(.codes) {
            sectionsData[.codes] = codesEntries
            Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Adding .codes section")
        }
        
        // Add other entries section if we have them and it's enabled
        if !otherEntries.isEmpty && enabledSections.contains(.codes) {
            sectionsData[.other] = otherEntries
            Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Adding .other section")
        }
        
        // Add places section if we have places and it's enabled
        if !places.isEmpty && enabledSections.contains(.places) {
            let sortedPlaces = places.sorted { $0.alias?.localizedCaseInsensitiveCompare($1.alias ?? "") == .orderedAscending }
            sectionsData[.places] = sortedPlaces
            Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Adding .places section with \(places.count) places")
        }
        
        // Add routines section LAST if we have routines and it's enabled
        if !routines.isEmpty && enabledSections.contains(.routines) {
            let sortedRoutines = routines.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            sectionsData[.routines] = sortedRoutines
            Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Adding .routines section with \(routines.count) routines")
        }
        
        // Sort sections by their defined order
        let sectionKeys = sectionsData.keys.sorted { section0, section1 in
            return section0.rawValue < section1.rawValue
        }
        
        // Apply sections and items following the Medium article pattern
        for sectionKey in sectionKeys {
            if let items = sectionsData[sectionKey], !items.isEmpty {
                snapshot.appendSections([sectionKey])
                snapshot.appendItems(items, toSection: sectionKey)
                Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Added section \(sectionKey) with \(items.count) items")
            }
        }
        
        // Store the section order for layout creation
        self.sectionOrder = sectionKeys
        
        Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Final sections in snapshot: \(sectionKeys.map { $0.rawValue })")
        
        return snapshot
    }
    
    private func applySnapshot(animated: Bool = false) {
        guard let dataSource = self.dataSource else { 
            Logger.log(level: .error, category: logCategory, message: "❌ CRASH DEBUG: DataSource is nil!")
            return 
        }
        
        // Prevent concurrent snapshot applications
        guard !isApplyingSnapshot else {
            Logger.log(level: .info, category: logCategory, message: "Snapshot application already in progress, skipping")
            return
        }
        
        Logger.log(level: .info, category: logCategory, message: "🔄 CRASH DEBUG: Starting snapshot application...")
        isApplyingSnapshot = true
        
        Task { @MainActor in
            do {
                let snapshot = createSnapshot()
                
                // Log section information for debugging
                Logger.log(level: .info, category: logCategory, message: "🔄 CRASH DEBUG: Created snapshot with sections: \(sectionOrder.map { $0.rawValue })")
                Logger.log(level: .info, category: logCategory, message: "🔄 CRASH DEBUG: Snapshot has \(snapshot.numberOfSections) sections, \(snapshot.numberOfItems) total items")
                
                // Validate snapshot before applying
                if snapshot.numberOfSections == 0 && (entries.isEmpty && folders.isEmpty && places.isEmpty && routines.isEmpty) {
                    Logger.log(level: .info, category: logCategory, message: "🔄 CRASH DEBUG: Empty snapshot - showing empty state")
                    isApplyingSnapshot = false
                    refreshEmptyState()
                    return
                }
                
                // Always animate when requested for filtering operations
                let shouldAnimate = animated
                
                // Apply snapshot following the Medium article pattern
                Logger.log(level: .info, category: logCategory, message: "🎬 Applying snapshot with animation: \(shouldAnimate)")
                dataSource.apply(snapshot, animatingDifferences: shouldAnimate) { [weak self] in
                    print("Apply snapshot completed!")
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        
                        self.isApplyingSnapshot = false
                        Logger.log(level: .info, category: logCategory, message: "✅ CRASH DEBUG: Snapshot applied successfully")
                    }
                }
            } catch {
                Logger.log(level: .error, category: logCategory, message: "❌ CRASH DEBUG: Snapshot application failed: \(error)")
                isApplyingSnapshot = false
                
                // For filtering operations, try to apply without animation as fallback
                if animated {
                    Logger.log(level: .info, category: logCategory, message: "Retrying snapshot without animation")
                    let snapshot = createSnapshot()
                    dataSource.apply(snapshot, animatingDifferences: false)
                } else {
                    // Only use reloadData as last resort
                    collectionView.reloadData()
                }
                
                // Restore alpha if we were animating
                if animated {
                    collectionView.alpha = 1.0
                }
            }
        }
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
                    UIAction(title: "Item Suggestions", image: UIImage(systemName: "sparkles")) { _ in
                        self.showItemSuggestions()
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
            selectedPlaces.removeAll()
            selectedRoutines.removeAll()
            
            // Notify delegate when clearing selections in edit-only mode
            if isEditOnlyMode {
                selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedEntries: selectedEntries)
                selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedPlaces: selectedPlaces)
                selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedRoutines: selectedRoutines)
            }
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
    
    private func updatePlaceCellSelection(for place: PlaceItem) {
        guard let dataSource = self.dataSource else { return }
        var snapshot = dataSource.snapshot()
        
        // Use reconfigureItems instead of reloadItems for better performance
        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems([place])
        } else {
            snapshot.reloadItems([place])
        }
        
        dataSource.apply(snapshot, animatingDifferences: false)
        
        // Update move button state when selection changes
        updateMoveButtonState()
    }
    
    private func updateRoutineCellSelection(for routine: RoutineItem) {
        guard let dataSource = self.dataSource else { return }
        var snapshot = dataSource.snapshot()
        
        // Use reconfigureItems instead of reloadItems for better performance
        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems([routine])
        } else {
            snapshot.reloadItems([routine])
        }
        
        dataSource.apply(snapshot, animatingDifferences: false)
        
        // Update move button state when selection changes
        updateMoveButtonState()
    }
    
    private func showItemSuggestions() {
        // Dismiss the suggestion tip when user opens suggestions
        NNTipManager.shared.dismissTip(NestCategoryTips.entrySuggestionTip)

        // Present CommonItemsViewController as a sheet with medium and large detents
        let commonItemsVC = CommonItemsViewController(category: category, entryRepository: entryRepository)
        commonItemsVC.delegate = self
        let navController = UINavigationController(rootViewController: commonItemsVC)

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
                    Logger.log(level: .error, category: logCategory, message: "Failed to check entry count: \(error.localizedDescription)")
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
        // Handle move action for selected entries and places
        
        let selectedEntriesArray = Array(selectedEntries)
        let selectedPlacesArray = Array(selectedPlaces)
        
        // Handle moving both entries and places between categories
        if !selectedEntriesArray.isEmpty || !selectedPlacesArray.isEmpty {
            let selectFolderVC = SelectFolderViewController(
                entryRepository: entryRepository,
                currentCategory: category,
                selectedEntries: selectedEntriesArray,
                selectedPlaces: selectedPlacesArray
            )
            selectFolderVC.delegate = self
            
            let navController = UINavigationController(rootViewController: selectFolderVC)
            present(navController, animated: true)
        }
    }
    
    // MARK: - Entry Limit Handling
    
    internal func showEntryLimitUpgradePrompt() {
        showUpgradePrompt(for: proFeature)
    }
    
    private func setupFilterView() {
        // Don't show filter view in edit-only mode
        guard !isEditOnlyMode else { return }
        
        // Always create the filterView in viewDidLoad to avoid late addition issues
        filterView = NNCategoryFilterView()
        filterView?.delegate = self
        filterView?.frame.size.height = 55
        filterView?.isHidden = true // Start hidden, will be shown when data loads if needed
        
        if let filterView = filterView {
            addNavigationBarPalette(filterView)
        }
    }
    
    private func updateFilterView() {
        guard let filterView = filterView, !isEditOnlyMode else { return }
        
        let availableSections = getAvailableSections()
        
        // Hide filter view only if there are no items at all
        if availableSections.isEmpty {
            filterView.isHidden = true
            return
        }
        
        print("🔄 Updating filter view with sections: \(availableSections.map { $0.displayTitle })")
        filterView.isHidden = false
        filterView.configure(
            with: availableSections,
            allowsMultipleSelection: true,
            showsAllOption: true
        )
    }
    
    private func getAvailableSections() -> [Section] {
        var sections: [Section] = []
        
        if !folders.isEmpty {
            sections.append(.folders)
        }
        
        let codesEntries = entries.filter { $0.shouldUseHalfWidthCell }
        let otherEntries = entries.filter { !$0.shouldUseHalfWidthCell }
        
        if !codesEntries.isEmpty || !otherEntries.isEmpty {
            sections.append(.codes)
        }
        
        if !places.isEmpty {
            sections.append(.places)
        }
        
        if !routines.isEmpty {
            sections.append(.routines)
        }
        
        return sections
    }

    private func setupAddEntryButton() {
        // Only show add entry button for nest owners and not in edit-only mode
        guard entryRepository is NestService && !isEditOnlyMode else { return }
        
        addEntryButton = NNSmallPrimaryButton(title: "", image: UIImage(systemName: "plus"))
        addEntryButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(addEntryButton)
        
        NSLayoutConstraint.activate([
            addEntryButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            addEntryButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            addEntryButton.heightAnchor.constraint(equalToConstant: 44),
            addEntryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        
        // Setup UIMenu for Entry/Place/Routine creation
        setupAddButtonMenu()
    }
    
    private func setupAddButtonMenu() {
        addEntryButton.menu = createAddItemMenu()
        addEntryButton.showsMenuAsPrimaryAction = true
    }
    
    private func updateAddEntryButtonForEditMode() {
        guard let addEntryButton = addEntryButton else { return }
        
        if isEditingMode {
            // Change to "Move" button with arrow.right icon and disable menu
            addEntryButton.setTitle("Move", for: .normal)
            addEntryButton.setImage(UIImage(systemName: "arrow.right"), for: .normal)
            addEntryButton.menu = nil
            addEntryButton.showsMenuAsPrimaryAction = false
            addEntryButton.addTarget(self, action: #selector(moveButtonTapped), for: .touchUpInside)
            
            // Update button state based on selection
            updateMoveButtonState()
        } else {
            // Change back to add button with plus icon and restore menu
            addEntryButton.setTitle("", for: .normal)
            addEntryButton.setImage(UIImage(systemName: "plus"), for: .normal)
            addEntryButton.removeTarget(self, action: #selector(moveButtonTapped), for: .touchUpInside)
            setupAddButtonMenu() // Restore the menu
            addEntryButton.isEnabled = true // Ensure it's enabled when not in edit mode
        }
    }
    
    private func updateMoveButtonState() {
        guard let addEntryButton = addEntryButton, isEditingMode else { return }
        
        let hasSelection = !selectedEntries.isEmpty || !selectedPlaces.isEmpty || !selectedRoutines.isEmpty
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
                if entry.shouldUseHalfWidthCell {
                    section = .codes
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
            Logger.log(level: .error, category: logCategory, message: "Entry not found for update: \(entry.id)")
        }
    }
    
    private func addLocalEntry(_ entry: BaseEntry) {
        entries.append(entry)
        
        DispatchQueue.main.async {
            guard let dataSource = self.dataSource else { return }
            var snapshot = dataSource.snapshot()
            
            let section: Section
            if entry.shouldUseHalfWidthCell {
                section = .codes
            } else {
                section = .other
            }
            
            snapshot.appendItems([entry], toSection: section)
            dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
                self?.flashCell(for: entry)
            }
        }
    }
    
    private func updateLocalPlace(_ place: PlaceItem) {
        DispatchQueue.main.async {
            guard let dataSource = self.dataSource else { return }
            var snapshot = dataSource.snapshot()
            
            // Use reconfigureItems instead of reloadItems for better performance
            if #available(iOS 15.0, *) {
                snapshot.reconfigureItems([place])
            } else {
                snapshot.reloadItems([place])
            }
            
            dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
                self?.flashPlaceCell(for: place)
            }
        }
    }
    
    private func addLocalPlace(_ place: PlaceItem) {
        places.append(place)
        
        DispatchQueue.main.async {
            guard let dataSource = self.dataSource else { return }
            var snapshot = dataSource.snapshot()
            
            // Add place to places section if it exists, otherwise create the section
            if snapshot.sectionIdentifiers.contains(.places) {
                snapshot.appendItems([place], toSection: .places)
            } else {
                // If places section doesn't exist, recreate the entire snapshot
                snapshot = self.createSnapshot()
            }
            
            dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
                self?.flashPlaceCell(for: place)
            }
        }
    }
    
    private func flashPlaceCell(for place: PlaceItem) {
        guard let indexPath = dataSource?.indexPath(for: place),
              let cell = collectionView.cellForItem(at: indexPath) as? PlaceCell else { return }
        
        cell.flash()
    }
    
    private func updateLocalRoutine(_ routine: RoutineItem) {
        DispatchQueue.main.async {
            guard let dataSource = self.dataSource else { return }
            var snapshot = dataSource.snapshot()
            
            // Use reconfigureItems instead of reloadItems for better performance
            if #available(iOS 15.0, *) {
                snapshot.reconfigureItems([routine])
            } else {
                snapshot.reloadItems([routine])
            }
            
            dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
                self?.flashRoutineCell(for: routine)
            }
        }
    }
    
    private func addLocalRoutine(_ routine: RoutineItem) {
        routines.append(routine)
        
        DispatchQueue.main.async {
            guard let dataSource = self.dataSource else { return }
            var snapshot = dataSource.snapshot()
            
            // Add routine to routines section if it exists, otherwise create the section
            if snapshot.sectionIdentifiers.contains(.routines) {
                snapshot.appendItems([routine], toSection: .routines)
            } else {
                // If routines section doesn't exist, recreate the entire snapshot
                snapshot = self.createSnapshot()
            }
            
            dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
                self?.flashRoutineCell(for: routine)
            }
        }
    }
    
    private func flashRoutineCell(for routine: RoutineItem) {
        guard let indexPath = dataSource?.indexPath(for: routine),
              let cell = collectionView.cellForItem(at: indexPath) as? RoutineCell else { return }
        
        cell.flash()
    }
    
    // Update loadEntries to use the new streamlined approach
    private func loadEntries() async {
        await MainActor.run {
            self.hasLoadedInitialData = true
        }
        
        // Use the new streamlined folder contents loading
        await loadFolderContents()
    }
    
    // Update refresh to use the new streamlined approach
    @objc private func refresh() {
        Task {
            // Invalidate cache to ensure fresh data
            if let nestService = entryRepository as? NestService {
                nestService.invalidateItemsCache()
            } else if let sitterService = entryRepository as? SitterViewService {
                sitterService.clearEntriesCache()
                sitterService.clearPlacesCache()
            }
            
            // Use the new streamlined folder contents loading
            await loadFolderContents()
            
            await MainActor.run {
                self.refreshControl.endRefreshing()
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
                subtitle: entryRepository is NestService ? "Items for this folder will appear here. Suggestions can be found in the upper-right corner." :
                    "This folder either has no items in it or none of the items were shared with you.",
                actionButtonTitle: entryRepository is NestService ? "Add Item" : nil,
                actionButtonMenu: entryRepository is NestService ? createAddItemMenu() : nil
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
            Logger.log(level: .error, category: logCategory, message: "Only nest owners can delete folders")
            return
        }
        
        Task {
            do {
                // Delete the category/folder from the backend
                try await nestService.deleteCategory(folderData.fullPath)
                
                await MainActor.run {
                    Logger.log(level: .info, category: logCategory, message: "Folder deleted: \(folderData.fullPath)")
                    self.showToast(text: "Folder Deleted")
                    
                    // Simply remove the deleted folder from the local folders array
                    self.folders.removeAll { $0.fullPath == folderData.fullPath }
                }
            } catch {
                await MainActor.run {
                    Logger.log(level: .error, category: logCategory, message: "Failed to delete folder: \(error.localizedDescription)")
                    self.showToast(text: "Failed to delete folder")
                }
            }
        }
    }
    
    // MARK: - Add Items
    
    func addEntryTapped() {
        // Use the existing addButtonTapped logic
        addButtonTapped()
    }
    
    func addPlaceTapped() {
        // Navigate to PlaceDetailViewController for creating a new place
        Task {
            // Check place limit for free tier users
            let hasUnlimitedPlaces = await SubscriptionService.shared.isFeatureAvailable(.unlimitedPlaces)
            if !hasUnlimitedPlaces {
                // Get current place count from NestService
                if let nestService = entryRepository as? NestService {
                    do {
                        let currentPlaces = try await nestService.fetchPlacesWithFilter(includeTemporary: false)
                        let nonTemporaryPlaces = currentPlaces.filter { !$0.isTemporary }
                        if nonTemporaryPlaces.count >= 3 {
                            await MainActor.run {
                                self.showPlaceLimitAlert()
                            }
                            return
                        }
                    } catch {
                        Logger.log(level: .error, category: logCategory, message: "Failed to check place count: \(error.localizedDescription)")
                    }
                }
            }
            
            await MainActor.run {
                let selectPlaceVC = SelectPlaceViewController()
                selectPlaceVC.category = self.category
                let navController = UINavigationController(rootViewController: selectPlaceVC)
                self.present(navController, animated: true)
            }
        }
    }
    
    func addRoutineTapped() {
        // Navigate to RoutineDetailViewController for creating a new routine
        let newRoutineVC = RoutineDetailViewController(category: self.category)
        newRoutineVC.routineDelegate = self
        present(newRoutineVC, animated: true)
    }
    
    func createAddItemMenu() -> UIMenu {
        
        let addEntryAction = UIAction(
            title: "Add Entry",
            image: UIImage(systemName: "doc.text")
        ) { _ in
            self.addEntryTapped()
        }
        
        let addPlaceAction = UIAction(
            title: "Add Place",
            image: UIImage(systemName: "mappin.and.ellipse")
        ) { _ in
            self.addPlaceTapped()
        }
        
        let addRoutineAction = UIAction(
            title: "Add Routine",
            image: UIImage(systemName: "checklist")
        ) { _ in
            self.addRoutineTapped()
        }
        
        return UIMenu(title: "Add Item", children: [addEntryAction, addPlaceAction, addRoutineAction])
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
                Logger.log(level: .info, category: logCategory, message: "Selected folder for entry selection: \(folderData.title)")
                
                let subfolderVC = NestCategoryViewController(
                    entryRepository: entryRepository,
                    initialCategory: folderData.fullPath,
                    isEditOnlyMode: true,
                    places: allPlaces
                )
                subfolderVC.selectEntriesDelegate = selectEntriesDelegate
                subfolderVC.restoreSelectedEntries(selectedEntries)
                
                navigationController?.pushViewController(subfolderVC, animated: true)
            } else if !isEditingMode {
                // Normal folder navigation (not in edit mode)
                Logger.log(level: .info, category: logCategory, message: "Selected folder: \(folderData.title)")
                
                let subfolderVC = NestCategoryViewController(
                    category: folderData.fullPath,
                    entries: [],
                    places: allPlaces,
                    entryRepository: entryRepository
                )
                navigationController?.pushViewController(subfolderVC, animated: true)
            }
            return
        }
        
        // Handle place selection
        if let selectedPlace = selectedItem as? PlaceItem {
            // If in edit mode, toggle selection
            if isEditingMode {
                // Add haptic feedback for selection
                HapticsHelper.superLightHaptic()
                
                if selectedPlaces.contains(selectedPlace) {
                    selectedPlaces.remove(selectedPlace)
                    collectionView.deselectItem(at: indexPath, animated: true)
                } else {
                    selectedPlaces.insert(selectedPlace)
                }
                
                // Update the cell appearance
                updatePlaceCellSelection(for: selectedPlace)
                
                // Notify delegate in edit-only mode
                if isEditOnlyMode {
                    selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedPlaces: selectedPlaces)
                }
                return
            }
            
            // Normal place selection (not in edit mode)
            collectionView.deselectItem(at: indexPath, animated: true)
            
            // Normal place selection (not in edit mode) - navigate to PlaceDetailViewController
            Logger.log(level: .info, category: logCategory, message: "Selected place for viewing: \(selectedPlace.alias ?? "Unnamed")")
            
            let cellFrame = collectionView.convert(cell.frame, to: nil)
            let isReadOnly = !(entryRepository is NestService)
            
            let placeDetailVC = PlaceDetailViewController(
                place: selectedPlace,
                thumbnail: nil, // TODO: Get thumbnail from cell if needed
                isReadOnly: isReadOnly
            )
            placeDetailVC.placeListDelegate = self
            present(placeDetailVC, animated: true)
            return
        }
        
        // Handle routine selection
        if let selectedRoutine = selectedItem as? RoutineItem {
            // If in edit mode, toggle selection
            if isEditingMode {
                // Add haptic feedback for selection
                HapticsHelper.superLightHaptic()
                
                if selectedRoutines.contains(selectedRoutine) {
                    selectedRoutines.remove(selectedRoutine)
                    collectionView.deselectItem(at: indexPath, animated: true)
                } else {
                    selectedRoutines.insert(selectedRoutine)
                }
                
                // Notify delegate in edit-only mode
                if isEditOnlyMode {
                    selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedRoutines: selectedRoutines)
                }
                
                // Update the cell appearance
                updateRoutineCellSelection(for: selectedRoutine)
                return
            }
            
            // Normal routine selection (not in edit mode)
            collectionView.deselectItem(at: indexPath, animated: true)
            
            // Navigate to RoutineDetailViewController
            Logger.log(level: .info, category: logCategory, message: "Selected routine for viewing: \(selectedRoutine.title)")
            
            let cellFrame = collectionView.convert(cell.frame, to: nil)
            let isReadOnly = !(entryRepository is NestService)
            
            let routineDetailVC = RoutineDetailViewController(
                category: category,
                routine: selectedRoutine,
                sourceFrame: cellFrame,
                isReadOnly: isReadOnly
            )
            routineDetailVC.routineDelegate = self
            present(routineDetailVC, animated: true)
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
        
        
        Logger.log(level: .info, category: logCategory, message: "Selected entry for editing: \(selectedEntry.title)")
        
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
           let selectedItem = dataSource.itemIdentifier(for: indexPath) {
            
            // Handle place deselection
            if let selectedPlace = selectedItem as? PlaceItem {
                selectedPlaces.remove(selectedPlace)
                updatePlaceCellSelection(for: selectedPlace)
                
                // Notify delegate in edit-only mode
                if isEditOnlyMode {
                    selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedPlaces: selectedPlaces)
                }
                return
            }
            
            // Handle routine deselection
            if let selectedRoutine = selectedItem as? RoutineItem {
                selectedRoutines.remove(selectedRoutine)
                
                // Notify delegate in edit-only mode
                if isEditOnlyMode {
                    selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedRoutines: selectedRoutines)
                }
                
                updateRoutineCellSelection(for: selectedRoutine)
                return
            }
            
            // Handle entry deselection
            if let selectedEntry = selectedItem as? BaseEntry {
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
            Logger.log(level: .info, category: logCategory, message: "Delegate received saved entry: \(entry.title)")
            
            // Invalidate cache so parent views will refresh
            if let nestService = entryRepository as? NestService {
                nestService.invalidateItemsCache()
            }
            
            if entries.contains(where: { $0.id == entry.id }) {
                updateLocalEntry(entry)
            } else {
                addLocalEntry(entry)
                refreshEmptyState()
                updateFilterView()
            }
        }
    }
    
    func entryDetailViewController(didDeleteEntry entry: BaseEntry) {
        Logger.log(level: .info, category: logCategory, message: "Delegate received deletion")
        
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            // Remove from local array (this will trigger didSet and applySnapshot)
            entries.remove(at: index)
            
            // No need to manually apply snapshot here since entries.didSet will handle it
            // The didSet will create a proper snapshot with correct sections
            
            showToast(text: "Entry Deleted")
            refreshEmptyState()
        }
    }
}

// Add this extension to help determine cell size
extension BaseEntry {
    var shouldUseHalfWidthCell: Bool {
        return title.count < 15 && content.count < 15
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
                    Logger.log(level: .info, category: logCategory, message: "New folder created: \(fullFolderPath) with icon: \(iconName)")
                    self.showToast(text: "Folder Created")
                }
                
                // Use the new streamlined approach to refresh all data
                await self.loadFolderContents()
            } catch {
                await MainActor.run {
                    Logger.log(level: .error, category: logCategory, message: "Failed to create folder: \(error.localizedDescription)")
                    self.showToast(text: "Failed to create folder")
                }
            }
        }
    }
    
    // Method to get all selected item IDs across all types
    func getAllSelectedItemIds() -> [String] {
        let entryIds = selectedEntries.map { $0.id }
        let placeIds = selectedPlaces.map { $0.id }
        let routineIds = selectedRoutines.map { $0.id }
        return entryIds + placeIds + routineIds
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
    func commonEntriesViewController(didSelectEntry entry: BaseEntry) {
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

// MARK: - CommonItemsViewControllerDelegate
extension NestCategoryViewController: CommonItemsViewControllerDelegate {
    func commonItemsViewController(_ controller: CommonItemsViewController, didSelectEntry entry: CommonEntry) {
        // Only allow creating entries for nest owners
        guard entryRepository is NestService else { return }
        Logger.log(level: .info, category: logCategory, message: "Selected common entry: \(entry.title)")

        // Check entry limit for free tier users, then present EntryDetailViewController
        Task {
            let hasUnlimitedEntries = await SubscriptionService.shared.isFeatureAvailable(.unlimitedEntries)
            if !hasUnlimitedEntries {
                do {
                    let currentCount = try await (entryRepository as! NestService).getCurrentEntryCount()
                    if currentCount >= 10 {
                        await MainActor.run {
                            self.dismiss(animated: true) {
                                self.showEntryLimitUpgradePrompt()
                            }
                        }
                        return
                    }
                } catch {
                    Logger.log(level: .error, category: logCategory, message: "Failed to check entry count: \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                let editEntryVC = EntryDetailViewController(
                    category: self.category,
                    title: entry.title,
                    content: entry.content
                )
                editEntryVC.entryDelegate = self
                self.dismiss(animated: true) {
                    self.present(editEntryVC, animated: true)
                }
            }
        }
    }

    func commonItemsViewController(_ controller: CommonItemsViewController, didSelectPlace place: CommonPlace) {
        // Only allow creating places for nest owners
        guard entryRepository is NestService else { return }

        // Present SelectPlaceViewController to choose location, prefilled with suggested name
        let selectPlaceVC = SelectPlaceViewController()
        selectPlaceVC.suggestedPlaceName = place.name
        selectPlaceVC.category = self.category
        let navController = UINavigationController(rootViewController: selectPlaceVC)
        self.dismiss(animated: true) {
            self.present(navController, animated: true)
        }
    }

    func commonItemsViewController(_ controller: CommonItemsViewController, didSelectRoutine routine: CommonRoutine) {
        // Only allow creating routines for nest owners
        guard entryRepository is NestService else { return }

        let routineDetailVC = RoutineDetailViewController(
            category: self.category,
            routineName: routine.name
        )
        routineDetailVC.routineDelegate = self
        self.dismiss(animated: true) {
            self.present(routineDetailVC, animated: true)
        }
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
                        self.showToast(text: "Only nest owners can move items")
                    }
                    return
                }
                
                let selectedEntriesArray = Array(selectedEntries)
                let selectedPlacesArray = Array(selectedPlaces)
                
                // Move each selected entry to the new folder
                for entry in selectedEntriesArray {
                    var updatedEntry = entry
                    updatedEntry.category = folder
                    try await nestService.updateEntry(updatedEntry)
                }
                
                // Move each selected place to the new folder
                for place in selectedPlacesArray {
                    var updatedPlace = place
                    updatedPlace.category = folder
                    try await nestService.updatePlace(updatedPlace)
                }
                
                // Invalidate cache after move operation to ensure data consistency across all views
                nestService.invalidateItemsCache()
                
                await MainActor.run {
                    controller.dismiss(animated: true)
                    
                    // Exit edit mode first
                    self.isEditingMode = false
                    self.selectedEntries.removeAll()
                    self.selectedPlaces.removeAll()
                    
                    // Notify delegate when clearing selections after move operation
                    if self.isEditOnlyMode {
                        self.selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedEntries: self.selectedEntries)
                        self.selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedPlaces: self.selectedPlaces)
                    }
                    
                    let totalCount = selectedEntriesArray.count + selectedPlacesArray.count
                    let itemText: String
                    
                    if selectedEntriesArray.count > 0 && selectedPlacesArray.count > 0 {
                        itemText = totalCount == 1 ? "item" : "items"
                    } else if selectedEntriesArray.count > 0 {
                        itemText = selectedEntriesArray.count == 1 ? "entry" : "entries"
                    } else {
                        itemText = selectedPlacesArray.count == 1 ? "place" : "places"
                    }
                    
                    let folderDisplayName = folder.components(separatedBy: "/").last ?? folder
                    self.showToast(text: "Moved \(totalCount) \(itemText) to \(folderDisplayName)")
                }
                
                // Use the new streamlined approach to refresh all data
                await self.loadFolderContents()
            } catch {
                await MainActor.run {
                    controller.dismiss(animated: true)
                    Logger.log(level: .error, category: logCategory, message: "Failed to move items: \(error.localizedDescription)")
                    self.showToast(text: "Failed to move items")
                }
            }
        }
    }
    
    func selectFolderViewControllerDidCancel(_ controller: SelectFolderViewController) {
        controller.dismiss(animated: true)
    }
}

// MARK: - SelectPlaceLocationDelegate
extension NestCategoryViewController: SelectPlaceLocationDelegate {
    func didUpdatePlaceLocation(
        _ place: PlaceItem,
        newAddress: String,
        newCoordinate: CLLocationCoordinate2D,
        newThumbnail: UIImage
    ) {
        // This is called when a place location is updated in SelectPlaceViewController
        // The actual place will be created/updated through the PlaceDetailViewController delegate
        print("Place location updated: \(newAddress)")
    }
}

// MARK: - RoutineDetailViewControllerDelegate
extension NestCategoryViewController: RoutineDetailViewControllerDelegate {
    func routineDetailViewController(didSaveRoutine routine: RoutineItem?) {
        if let routine = routine {
            // Handle save/update - exact same pattern as entries
            Logger.log(level: .info, category: logCategory, message: "Delegate received saved routine: \(routine.title)")
            
            // Invalidate cache so parent views will refresh
            if let nestService = entryRepository as? NestService {
                nestService.invalidateItemsCache()
            }
            
            if routines.contains(where: { $0.id == routine.id }) {
                updateLocalRoutine(routine)
            } else {
                addLocalRoutine(routine)
                refreshEmptyState()
                updateFilterView()
            }
        }
    }
    
    func routineDetailViewController(didDeleteRoutine routine: RoutineItem) {
        Logger.log(level: .info, category: logCategory, message: "Delegate received routine deletion: \(routine.title)")
        
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            // Remove from selected routines if it was selected
            selectedRoutines.remove(routine)
            
            // Remove from local array (this will trigger didSet and applySnapshot)
            routines.remove(at: index)
            
            showToast(text: "Routine Deleted")
            refreshEmptyState()
        }
    }
}

// MARK: - PlaceListViewControllerDelegate
extension NestCategoryViewController {
    func placeListViewController(didUpdatePlace place: PlaceItem) {
        // Handle save/update - exact same pattern as entries
        Logger.log(level: .info, category: logCategory, message: "Delegate received saved place: \(place.alias ?? "Unnamed")")
        
        // Invalidate cache so parent views will refresh
        if let nestService = entryRepository as? NestService {
            nestService.invalidateItemsCache()
        }
        
        if places.contains(where: { $0.id == place.id }) {
            updateLocalPlace(place)
        } else {
            addLocalPlace(place)
            refreshEmptyState()
            updateFilterView()
        }
    }
    
    func placeListViewController(didDeletePlace place: PlaceItem) {
        // Handle place deletion
        Logger.log(level: .info, category: logCategory, message: "Delegate received place deletion: \(place.alias ?? "Unnamed")")
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            if let index = self.places.firstIndex(where: { $0.id == place.id }) {
                Logger.log(level: .info, category: logCategory, message: "Removing place at index \(index), places count before: \(self.places.count)")
                
                // Remove from selected places if it was selected
                self.selectedPlaces.remove(place)
                
                // Notify delegate if place was selected and we're in edit-only mode
                if self.isEditOnlyMode {
                    self.selectEntriesDelegate?.nestCategoryViewController(self, didUpdateSelectedPlaces: self.selectedPlaces)
                }
                
                // Remove from local array (this will trigger didSet and applySnapshot)
                self.places.remove(at: index)
                
                Logger.log(level: .info, category: logCategory, message: "Place removed, places count after: \(self.places.count)")
                
                // No need to manually apply snapshot here since places.didSet will handle it
                // The didSet will create a proper snapshot with correct sections
                
                self.showToast(text: "Place Deleted")
                self.refreshEmptyState()
            } else {
                Logger.log(level: .info, category: logCategory, message: "Place not found in local array for deletion: \(place.id)")
            }
        }
    }
}

extension NestCategoryViewController: NNCategoryFilterViewDelegate {
    func categoryFilterView(_ filterView: NNCategoryFilterView, didUpdateSelection selection: NNCategoryFilterView.Selection) {
        // Map selection to our concrete enabledSections
        let allAvailable = getAvailableSections()

        let newEnabled: Set<Section>
        switch selection {
        case .all:
            newEnabled = Set(allAvailable)
        case .specific(let ids):
            // ids are AnyHashable of Section (conforming to NNCategoryFilterOption)
            let selected = allAvailable.filter { ids.contains($0) }
            // If user cleared all (should not happen due to All auto-select), fallback to all
            newEnabled = selected.isEmpty ? Set(allAvailable) : Set(selected)
        }

        // Temporarily disable automatic snapshots to prevent double application
        shouldApplySnapshotAutomatically = false
        self.enabledSections = newEnabled
        self.shouldApplySnapshotAutomatically = true

        self.applySnapshot(animated: true)

        DispatchQueue.main.async {
            filterView.updateDisplayedState()
        }
    }
}

extension NestCategoryViewController {
    // Section Header size
    static let headerSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(12)
    )
}
