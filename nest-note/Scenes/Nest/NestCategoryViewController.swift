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

class NestCategoryViewController: NNViewController, NestLoadable, CollectionViewLoadable, PaywallPresentable, PaywallViewControllerDelegate, PlaceListViewControllerDelegate {
    enum ItemDisplayLayout {
        case standard
        case waterfallGrid
    }

    // MARK: - Properties
    internal let nestItemRepository: NestItemRepository
    private let category: String
    private let itemDisplayLayout: ItemDisplayLayout
    private var waterfallLayout: WaterfallCollectionLayout?
    private var waterfallHeightCache: [IndexPath: CGFloat] = [:]
    private lazy var waterfallSizingCell = WaterfallGridCell(frame: .zero)

    // Toolbar support
    private var isUsingToolbar: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }

    // Glass container support
    private var isUsingGlassContainer: Bool {
        if #available(iOS 18.0, *) {
            return !isUsingToolbar // Use glass container for iOS 18-25
        }
        return false
    }
    // Expose current category path to selection flow controller for scoping
    func getCurrentCategoryPath() -> String { category }
    private var selectAllBarButtonItem: UIBarButtonItem?
    private var allItemIdsInScope: Set<String> = []
    private var hasPreparedSelectableItemsInScope = false
    private var inScopeEntries: [NoteItem] = []
    private var inScopePlaces: [PlaceItem] = []
    private var inScopeRoutines: [RoutineItem] = []
    private var inScopeContacts: [ContactItem] = []
    private var inScopeUnknownItems: [UnknownItem] = []
    
    // MARK: - PaywallPresentable
    var proFeature: ProFeature {
        return .unlimitedNotes
    }
    
    // Required by NestLoadable
    var loadingIndicator: UIActivityIndicatorView!
    var hasLoadedInitialData: Bool = false
    var refreshControl: UIRefreshControl!
    
    var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, AnyHashable>!
    private var addEntryButton: UIButton!
    private var addEntryButtonWidthConstraint: NSLayoutConstraint?
    private var addEntryButtonBlurView: UIVisualEffectView?
    private var emptyStateView: NNEmptyStateView!

    // Glass container for edit mode buttons (iOS 18+)
    @available(iOS 18.0, *)
    private var glassContainerView: UIVisualEffectView?
    @available(iOS 18.0, *)
    private var glassMoveButton: UIButton?
    @available(iOS 18.0, *)
    private var glassDeleteButton: UIButton?
    
    /// Raw values define default snapshot order (ascending): folders, contacts, notes, routines, places, …
    enum Section: Int, CaseIterable {
        case folders, contacts, codes, other, routines, places, unknownItems
    }
    
    var notes: [NoteItem] = [] {
        didSet {
            if shouldApplySnapshotAutomatically {
                applySnapshot(animated: true)
            }
        }
    }
    
    private var folders: [FolderData] = [] {
        didSet {
            if shouldApplySnapshotAutomatically {
                applySnapshot(animated: true)
            }
        }
    }
    
    private var filterView: NNCategoryFilterView?
    private var enabledSections: Set<Section> = Set(Section.allCases) {
        didSet {
            if shouldApplySnapshotAutomatically {
                applySnapshot(animated: true)
            }
        }
    }
    
    var places: [PlaceItem] = [] {
        didSet {
            if shouldApplySnapshotAutomatically {
                applySnapshot(animated: true)
            }
        }
    }
    
    var routines: [RoutineItem] = [] {
        didSet {
            if shouldApplySnapshotAutomatically {
                applySnapshot(animated: true)
            }
        }
    }
    
    private var contacts: [ContactItem] = [] {
        didSet {
            if shouldApplySnapshotAutomatically {
                applySnapshot(animated: true)
            }
        }
    }
    
    private var unknownItems: [UnknownItem] = [] {
        didSet {
            if shouldApplySnapshotAutomatically {
                applySnapshot(animated: true)
            }
        }
    }
    
    private var allPlaces: [PlaceItem] = [] // All places (for passing to subfolders)
    
    // Track the order of sections in the current snapshot
    private var sectionOrder: [Section] = []
    private var previousSectionOrder: [Section] = []
    
    // Prevent concurrent snapshot applications
    private var isApplyingSnapshot = false
    /// When a snapshot is already applying, remember the latest requested animation preference.
    private var pendingSnapshotAnimation: Bool?
    private var pendingSnapshotCompletion: (() -> Void)?
    
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
    private var selectedNotes: Set<NoteItem> = []
    private var selectedPlaces: Set<PlaceItem> = []
    private var selectedRoutines: Set<RoutineItem> = []
    private var selectedContacts: Set<ContactItem> = []
    private var selectedUnknownItems: Set<UnknownItem> = []
    
    // Select entries mode properties
    private var isEditOnlyMode: Bool = false
    weak var selectNestItemsDelegate: NestCategoryViewControllerSelectNestItemsDelegate?
    
    // Selection limit properties
    private var selectionLimit: Int? = nil
    /// When true, limit alert offers Pro upgrade (session free-tier). When false, shows a hard-cap message (attachments).
    private var selectionLimitOffersUpgrade: Bool = true
    /// Item IDs hidden/unselectable in edit-only selection mode (e.g. attachment host).
    private var excludedItemIds: Set<String> = []
    /// When true, omits Select All in edit-only selection mode (attachment picker).
    private var hidesSelectAllButton = false
    
    // Dynamic logging category based on repository type
    private var logCategory: Logger.Category {
        return nestItemRepository is NestService ? .nestService : .sitterViewService
    }

    private var allowsNestEdits: Bool {
        nestItemRepository.allowsNestEdits
    }

    private var showsOwnerChrome: Bool {
        nestItemRepository.showsOwnerChrome
    }
    
    init(
        category: String,
        notes: [NoteItem] = [],
        places: [PlaceItem] = [],
        nestItemRepository: NestItemRepository,
        isEditOnlyMode: Bool = false,
        itemDisplayLayout: ItemDisplayLayout = .waterfallGrid
    ) {
        self.category = category
        self.notes = notes
        self.nestItemRepository = nestItemRepository
        self.isEditOnlyMode = isEditOnlyMode
        self.itemDisplayLayout = itemDisplayLayout
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
    convenience init(nestItemRepository: NestItemRepository, initialCategory: String, isEditOnlyMode: Bool, places: [PlaceItem] = []) {
        self.init(category: initialCategory, notes: [], places: places, nestItemRepository: nestItemRepository, isEditOnlyMode: isEditOnlyMode)
    }
    
    // Method to restore selected entries for persistent selection
    func restoreSelectedNotes(_ notes: Set<NoteItem>) {
        selectedNotes = notes
        
        // If we're already loaded, update the UI immediately
        if isViewLoaded {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
                self.restoreCollectionViewSelection()
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
            }
        }
    }
    
    func restoreSelectedItems(_ items: SelectedNestItems) {
        selectedNotes = items.notes
        selectedPlaces = items.places
        selectedRoutines = items.routines
        selectedContacts = items.contacts
        selectedUnknownItems = items.unknownItems
        if isViewLoaded {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
                self.restoreCollectionViewSelection()
            }
        }
    }
    
    private func currentSelectedNestItems() -> SelectedNestItems {
        SelectedNestItems(
            notes: selectedNotes,
            places: selectedPlaces,
            routines: selectedRoutines,
            contacts: selectedContacts,
            unknownItems: selectedUnknownItems
        )
    }
    
    private func notifySelectNestItemsDelegate() {
        guard isEditOnlyMode else { return }
        selectNestItemsDelegate?.nestCategoryViewController(self, didUpdateSelectedItems: currentSelectedNestItems())
    }
    
    // Helper method to restore collection view selection state
    private func restoreCollectionViewSelection() {
        guard isEditingMode, let dataSource = self.dataSource else { return }
        
        let snapshot = dataSource.snapshot()
        
        // Iterate through all sections and items to find matching notes
        for sectionIdentifier in snapshot.sectionIdentifiers {
            let items = snapshot.itemIdentifiers(inSection: sectionIdentifier)
            
            for (itemIndex, item) in items.enumerated() {
                // Check if this item is a NoteItem and if it's selected
                if let entry = item as? NoteItem, selectedNotes.contains(entry) {
                    // Find the section index
                    if let sectionIndex = snapshot.sectionIdentifiers.firstIndex(of: sectionIdentifier) {
                        let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                    }
                }
                else if let place = item as? PlaceItem, selectedPlaces.contains(place) {
                    if let sectionIndex = snapshot.sectionIdentifiers.firstIndex(of: sectionIdentifier) {
                        let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                    }
                } else if let routine = item as? RoutineItem, selectedRoutines.contains(routine) {
                    if let sectionIndex = snapshot.sectionIdentifiers.firstIndex(of: sectionIdentifier) {
                        let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                    }
                } else if let contact = item as? ContactItem, selectedContacts.contains(contact) {
                    if let sectionIndex = snapshot.sectionIdentifiers.firstIndex(of: sectionIdentifier) {
                        let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                    }
                } else if let unknown = item as? UnknownItem, selectedUnknownItems.contains(unknown) {
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
        let count = selectedNotes.filter { entry in
            entry.category.hasPrefix(folderPath)
        }.count
        
        // Debug logging
        if count > 0 {
            print("🔍 Found \(count) selected entries for folder: \(folderPath)")
            selectedNotes.forEach { entry in
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(placeDidSave(_:)),
            name: .placeThumbnailsDidUpdate,
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
        view.backgroundColor = itemDisplayLayout == .waterfallGrid
            ? .systemGroupedBackground
            : .systemBackground
        setupCollectionView()
        setupLoadingIndicator()
        setupRefreshControl()
        setupNavigationBar()
        setupFilterView()
        setupAddEntryButton()
        configureDataSource()
        setupEmptyStateView()
        collectionView.delegate = self

        if isUsingToolbar {
            // Setup toolbar for iOS 26+
            if #available(iOS 26.0, *) {
                setupToolbar()
            }
        }

        // Setup glass container for iOS 18-25
        if isUsingGlassContainer {
            if #available(iOS 26.0, *) {
                setupGlassContainer()
            }
        }

        // Set up notification observers for place updates
        setupNotificationObservers()
        
        // If in edit-only mode, automatically enter edit mode
        if isEditOnlyMode {
            isEditingMode = true
        }
        
        // Prepare Select All button and data for edit-only selection flow
        if isEditOnlyMode {
            setupSelectAllButton()
            Task { await prepareSelectableItemsInScope() }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !hasLoadedInitialData {
            Task {
                await loadNotes()
            }
        }
    }
    
    // Implement NestLoadable requirement - now much simpler!
    func handleLoadedNotes(_ groupedNotes: [String: [NoteItem]]) {
        // For backward compatibility, this method still exists but now just calls loadFolderContents
        Task {
            await loadFolderContents()
        }
    }
    
    private func loadFolderContents() async {
        do {
            let folderContents: FolderUtility.FolderContents
            
            if let nestService = nestItemRepository as? NestService {
                folderContents = try await nestService.fetchFolderContents(for: category)
            } else if let sitterService = nestItemRepository as? SitterViewService {
                folderContents = try await sitterService.fetchFolderContents(for: category)
            } else {
                // Fallback for other repository types
                await loadBasicEntries()
                return
            }
            
            await MainActor.run {
                // Disable automatic snapshots during data loading
                self.shouldApplySnapshotAutomatically = false
                
                // Set all the data from the service
                self.notes = folderContents.notes.filter { !self.excludedItemIds.contains($0.id) }
                self.places = folderContents.places.filter { !self.excludedItemIds.contains($0.id) }
                self.routines = folderContents.routines.filter { !self.excludedItemIds.contains($0.id) }
                self.contacts = folderContents.contacts.filter { !self.excludedItemIds.contains($0.id) }
                self.unknownItems = folderContents.unknownItems.filter { !self.excludedItemIds.contains($0.id) }
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
            let groupedNotes = try await nestItemRepository.fetchNotes()
            let notesForCategory = groupedNotes[category] ?? []
            
            await MainActor.run {
                // Disable automatic snapshots during data loading
                self.shouldApplySnapshotAutomatically = false
                
                // Set the entries data
                self.notes = notesForCategory
                
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
            Logger.log(level: .error, category: logCategory, message: "Failed to load basic notes: \(error)")
            await MainActor.run {
                self.showError("Failed to load notes")
            }
        }
    }
    
    func refreshEmptyState() {
        // Show or hide empty state view based on entries, folders, places, and routines count
        let shouldShowEmptyState = notes.isEmpty && folders.isEmpty && places.isEmpty && routines.isEmpty
            && contacts.isEmpty && unknownItems.isEmpty
        
        if shouldShowEmptyState {
            emptyStateView.animateIn()
            addEntryButton?.isHidden = true
        } else {
            emptyStateView.animateOut()
            addEntryButton?.isHidden = false
        }

        // Keep the Select menu item enabled state in sync with content
        if !isEditingMode {
            setupNavigationBar()
        }
    }
    
    // MARK: - CollectionViewLoadable Implementation
    func handleLoadedData() {
        // This is called when data is loaded
        // We're already handling this in handleLoadedNotes
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
        
        // Minimal top inset — filter chips live in the navigation bar palette above.
        collectionView.contentInset.top = 8
        collectionView.verticalScrollIndicatorInsets.top = 8
        
        // Set content insets based on iOS version and toolbar usage
        if isUsingToolbar {
            // For iOS 26+, account for toolbar
            collectionView.contentInset.bottom = 20
            collectionView.verticalScrollIndicatorInsets.bottom = 20
        } else {
            // For pre-iOS 26, account for floating button
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
        collectionView.register(
            WaterfallGridCell.self,
            forCellWithReuseIdentifier: WaterfallGridCell.reuseIdentifier
        )

        if itemDisplayLayout == .waterfallGrid {
            collectionView.backgroundColor = .systemGroupedBackground
        }
        
        // Register section headers
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SectionHeader")
        
        collectionView.allowsSelection = true
    }
    
    private func createLayout() -> UICollectionViewLayout {
        if itemDisplayLayout == .waterfallGrid {
            let layout = WaterfallCollectionLayout()
            layout.delegate = self
            waterfallLayout = layout
            return layout
        }

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
            case .contacts:
                let hasUnknownSection = self.sectionOrder.contains(.unknownItems)
                return self.createHalfWidthSectionWithHeader(needsBottomPadding: !hasUnknownSection)
            case .unknownItems:
                return self.createFullWidthSectionWithHeader()
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
        
        // Don't add header for inset grouped section when used for .other notes
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

            if self.itemDisplayLayout == .waterfallGrid {
                return self.dequeueWaterfallCell(in: collectionView, for: item, section: section, at: indexPath)
            }
            
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
            
            if section == .contacts, let contact = item as? ContactItem {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HalfWidthCell.reuseIdentifier, for: indexPath) as! HalfWidthCell
                cell.configure(
                    key: contact.title,
                    value: contact.content,
                    isNestOwner: self.allowsNestEdits,
                    isEditMode: self.isEditingMode,
                    isSelected: self.selectedContacts.contains(contact),
                    isModalInPresentation: navigationController?.modalPresentationStyle == .formSheet || navigationController?.modalPresentationStyle == .pageSheet
                )
                return cell
            }
            
            if section == .unknownItems, let unknown = item as? UnknownItem {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                cell.configure(
                    key: unknown.title,
                    value: "Type: \(unknown.originalTypeString)",
                    isNestOwner: self.allowsNestEdits,
                    isEditMode: self.isEditingMode,
                    isSelected: self.selectedUnknownItems.contains(unknown),
                    isModalInPresentation: navigationController?.modalPresentationStyle == .formSheet || navigationController?.modalPresentationStyle == .pageSheet
                )
                return cell
            }
            
            // Handle notes
            guard let entry = item as? NoteItem else {
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
                    isNestOwner: self.allowsNestEdits,
                    isEditMode: self.isEditingMode,
                    isSelected: self.selectedNotes.contains(entry),
                    isModalInPresentation: navigationController?.modalPresentationStyle == .formSheet || navigationController?.modalPresentationStyle == .pageSheet
                )
                
                return cell
            case .other:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                cell.configure(
                    key: entry.title,
                    value: entry.content,
                    isNestOwner: self.allowsNestEdits,
                    isEditMode: self.isEditingMode,
                    isSelected: self.selectedNotes.contains(entry),
                    isModalInPresentation: navigationController?.modalPresentationStyle == .formSheet || navigationController?.modalPresentationStyle == .pageSheet
                )
                
                return cell
            case .folders:
                // This should not happen with proper snapshot creation - debug and handle gracefully
                Logger.log(level: .error, category: logCategory, message: "DEBUGGING: NoteItem '\(entry.title)' found in folders section at indexPath \(indexPath). Entry category: '\(entry.category)'. Current category: '\(self.category)'")
                
                // Use fallback cell to prevent crash
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                cell.configure(
                    key: entry.title,
                    value: entry.content,
                    isNestOwner: self.allowsNestEdits,
                    isEditMode: self.isEditingMode,
                    isSelected: self.selectedNotes.contains(entry),
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
                title = "NOTES"
            case .other:
                title = "NOTES"
            case .places:
                title = "PLACES"
            case .routines:
                title = "ROUTINES"
            case .contacts:
                title = "CONTACTS"
            case .unknownItems:
                title = "UNSUPPORTED"
            }
            
            // Create and configure header label
            header.subviews.forEach { $0.removeFromSuperview() }
            
            let label = UILabel()
            label.text = title
            label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            label.textColor = UIColor.secondaryLabel
            label.translatesAutoresizingMaskIntoConstraints = false

            let leadingInset = self.itemDisplayLayout == .waterfallGrid
                ? Self.waterfallSectionHeaderLeadingInset
                : 16
            let bottomInset = self.itemDisplayLayout == .waterfallGrid
                ? Self.sectionHeaderLabelBottomInset
                : 8
            
            header.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: leadingInset),
                label.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -bottomInset)
            ])
            
            return header
        }
    }
    
    private func createSnapshot() -> NSDiffableDataSourceSnapshot<Section, AnyHashable> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, AnyHashable>()
        
        // Debug logging
        Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Creating snapshot for category '\(category)'. Folders: \(folders.count), Entries: \(notes.count), Places: \(places.count)")
        
        // Filter entries based on cell type (title + content < 15 characters)
        let codesNotes = notes.filter { $0.shouldUseHalfWidthCell }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        let otherNotes = notes.filter { !$0.shouldUseHalfWidthCell }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        
        Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Category '\(category)' - Codes: \(codesNotes.count), Other: \(otherNotes.count)")
        
        // Build sections map similar to the Medium article approach
        var sectionsData: [Section: [AnyHashable]] = [:]
        
        // Add folders section if we have folders and it's enabled
        if !folders.isEmpty && enabledSections.contains(.folders) {
            let sortedFolders = folders.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            sectionsData[.folders] = sortedFolders
            Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Adding .folders section with \(folders.count) folders")
        }
        
        // Add entries section(s)
        if itemDisplayLayout == .waterfallGrid {
            let sortedEntries = notes.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            if !sortedEntries.isEmpty && enabledSections.contains(.codes) {
                sectionsData[.codes] = sortedEntries
                Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Adding waterfall .codes section")
            }
        } else {
            if !codesNotes.isEmpty && enabledSections.contains(.codes) {
                sectionsData[.codes] = codesNotes
                Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Adding .codes section")
            }

            if !otherNotes.isEmpty && enabledSections.contains(.codes) {
                sectionsData[.other] = otherNotes
                Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Adding .other section")
            }
        }
        
        // Add places section if we have places and it's enabled
        if !places.isEmpty && enabledSections.contains(.places) {
            let sortedPlaces = places.sorted { $0.alias?.localizedCaseInsensitiveCompare($1.alias ?? "") == .orderedAscending }
            sectionsData[.places] = sortedPlaces
            Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Adding .places section with \(places.count) places")
        }
        
        // Add routines section if we have routines and it's enabled
        if !routines.isEmpty && enabledSections.contains(.routines) {
            let sortedRoutines = routines.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            sectionsData[.routines] = sortedRoutines
            Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Adding .routines section with \(routines.count) routines")
        }
        
        if !contacts.isEmpty && enabledSections.contains(.contacts) {
            let sorted = contacts.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            sectionsData[.contacts] = sorted
            Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Adding .contacts section")
        }
        
        if !unknownItems.isEmpty && enabledSections.contains(.unknownItems) {
            let sorted = unknownItems.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            sectionsData[.unknownItems] = sorted
            Logger.log(level: .info, category: logCategory, message: "DEBUGGING: Adding .unknownItems section")
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
    
    private func applySnapshot(animated: Bool = false, completion: (() -> Void)? = nil) {
        guard let dataSource = self.dataSource else { 
            Logger.log(level: .error, category: logCategory, message: "❌ CRASH DEBUG: DataSource is nil!")
            return 
        }
        
        // Coalesce concurrent requests so rapid add/remove still lands on the latest data.
        guard !isApplyingSnapshot else {
            pendingSnapshotAnimation = (pendingSnapshotAnimation ?? false) || animated
            if let completion {
                let previous = pendingSnapshotCompletion
                pendingSnapshotCompletion = {
                    previous?()
                    completion()
                }
            }
            Logger.log(level: .info, category: logCategory, message: "Snapshot application already in progress, queuing follow-up")
            return
        }
        
        Logger.log(level: .info, category: logCategory, message: "🔄 CRASH DEBUG: Starting snapshot application...")
        isApplyingSnapshot = true
        waterfallHeightCache.removeAll()
        
        Task { @MainActor in
            do {
                let snapshot = createSnapshot()
                
                // Log section information for debugging
                Logger.log(level: .info, category: logCategory, message: "🔄 CRASH DEBUG: Created snapshot with sections: \(sectionOrder.map { $0.rawValue })")
                Logger.log(level: .info, category: logCategory, message: "🔄 CRASH DEBUG: Snapshot has \(snapshot.numberOfSections) sections, \(snapshot.numberOfItems) total items")
                
                // Validate snapshot before applying
                if snapshot.numberOfSections == 0 && (notes.isEmpty && folders.isEmpty && places.isEmpty && routines.isEmpty
                    && contacts.isEmpty && unknownItems.isEmpty) {
                    Logger.log(level: .info, category: logCategory, message: "🔄 CRASH DEBUG: Empty snapshot - showing empty state")
                    let pendingAnimation = self.pendingSnapshotAnimation
                    let pendingCompletion = self.pendingSnapshotCompletion
                    self.pendingSnapshotAnimation = nil
                    self.pendingSnapshotCompletion = nil
                    self.isApplyingSnapshot = false
                    refreshEmptyState()
                    completion?()
                    if let pendingAnimation {
                        self.applySnapshot(animated: pendingAnimation, completion: pendingCompletion)
                    } else {
                        pendingCompletion?()
                    }
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
                        
                        let pendingAnimation = self.pendingSnapshotAnimation
                        let pendingCompletion = self.pendingSnapshotCompletion
                        self.pendingSnapshotAnimation = nil
                        self.pendingSnapshotCompletion = nil
                        self.isApplyingSnapshot = false
                        if self.itemDisplayLayout == .waterfallGrid {
                            self.waterfallLayout?.invalidateLayout()
                        }
                        Logger.log(level: .info, category: logCategory, message: "✅ CRASH DEBUG: Snapshot applied successfully")
                        completion?()
                        if let pendingAnimation {
                            self.applySnapshot(animated: pendingAnimation, completion: pendingCompletion)
                        } else {
                            pendingCompletion?()
                        }
                    }
                }
            } catch {
                Logger.log(level: .error, category: logCategory, message: "❌ CRASH DEBUG: Snapshot application failed: \(error)")
                let pendingAnimation = self.pendingSnapshotAnimation
                let pendingCompletion = self.pendingSnapshotCompletion
                self.pendingSnapshotAnimation = nil
                self.pendingSnapshotCompletion = nil
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

                completion?()
                if let pendingAnimation {
                    applySnapshot(animated: pendingAnimation, completion: pendingCompletion)
                } else {
                    pendingCompletion?()
                }
            }
        }
    }
    
    private var allNotes: [NoteItem] {
        return notes
    }
    
    private func setupNavigationBar() {
        // Only show menu button for nest owners
        if allowsNestEdits {
            if isEditingMode {
                // In edit-only mode, don't show any navigation buttons as the flow controller handles navigation
                if isEditOnlyMode {
                    if hidesSelectAllButton {
                        selectAllBarButtonItem = nil
                        navigationItem.rightBarButtonItems = []
                    } else {
                        // Show Select All when selecting items in edit-only mode
                        if selectAllBarButtonItem == nil {
                            setupSelectAllButton()
                        }
                        navigationItem.rightBarButtonItems = selectAllBarButtonItem != nil ? [selectAllBarButtonItem!] : []
                    }
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
                
                // Create Edit action (separate section); disable when there is nothing to select
                let hasSelectableItems = !notes.isEmpty || !places.isEmpty || !routines.isEmpty
                    || !contacts.isEmpty || !unknownItems.isEmpty
                let editAction = UIAction(
                    title: "Select",
                    image: UIImage(systemName: "checkmark.circle"),
                    attributes: hasSelectableItems ? [] : .disabled
                ) { _ in
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

    // MARK: - Select All Support (Edit-only mode)
    private func setupSelectAllButton() {
        let button = UIBarButtonItem(title: "Select All", style: .plain, target: self, action: #selector(didTapSelectAll))
        selectAllBarButtonItem = button
        navigationItem.rightBarButtonItem = button
        updateSelectAllButtonTitle()
    }
    
    // Compute all items in current category INCLUDING descendants
    private func isInScope(_ itemCategory: String) -> Bool {
        return itemCategory == category || itemCategory.hasPrefix(category + "/")
    }
    
    private func updateSelectAllButtonTitle() {
        guard isEditOnlyMode, !hidesSelectAllButton else { return }
        let total = allItemIdsInScope.count
        let selectedInScopeCount = selectedItemIdsInScope().count
        let isAllSelected = total > 0 && selectedInScopeCount >= total
        selectAllBarButtonItem?.title = isAllSelected ? "Clear All" : "Select All"
        selectAllBarButtonItem?.isEnabled = total > 0
    }
    
    private func updateSelectAllButtonAfterSelectionChange() {
        if isEditOnlyMode { updateSelectAllButtonTitle() }
    }
    
    /// Selected IDs that belong to the current folder (and descendants), ignoring selections restored from other folders.
    private func selectedItemIdsInScope() -> Set<String> {
        let allSelectedIds = Set(
            selectedNotes.map(\.id)
            + selectedPlaces.map(\.id)
            + selectedRoutines.map(\.id)
            + selectedContacts.map(\.id)
            + selectedUnknownItems.map(\.id)
        )
        return allSelectedIds.intersection(allItemIdsInScope)
    }
    
    private func prepareSelectableItemsInScope() async {
        do {
            let allItems: [BaseItem]
            if let nestService = nestItemRepository as? NestService {
                allItems = try await nestService.fetchAllItems()
            } else if let sitterService = nestItemRepository as? SitterViewService {
                allItems = try await sitterService.fetchAllItems()
            } else {
                let groupedNotes = try await nestItemRepository.fetchNotes()
                let allPlaces = try await nestItemRepository.fetchPlaces()
                allItems = groupedNotes.values.flatMap { $0 } + allPlaces
            }
            let scoped = allItems.filter { isInScope($0.category) }
            let notes = scoped.compactMap { $0 as? NoteItem }
            let places = scoped.compactMap { $0 as? PlaceItem }
            let routines = scoped.compactMap { $0 as? RoutineItem }
            let contactItems = scoped.compactMap { $0 as? ContactItem }
            let unknowns = scoped.compactMap { $0 as? UnknownItem }
            let ids = Set(scoped.map { $0.id })
            await MainActor.run {
                self.inScopeEntries = notes
                self.inScopePlaces = places
                self.inScopeRoutines = routines
                self.inScopeContacts = contactItems
                self.inScopeUnknownItems = unknowns
                self.allItemIdsInScope = ids
                self.hasPreparedSelectableItemsInScope = true
                self.updateSelectAllButtonTitle()
            }
        } catch {
            await MainActor.run {
                self.inScopeEntries = []
                self.inScopePlaces = []
                self.inScopeRoutines = []
                self.inScopeContacts = []
                self.inScopeUnknownItems = []
                self.allItemIdsInScope = []
                self.hasPreparedSelectableItemsInScope = true
                self.updateSelectAllButtonTitle()
            }
        }
    }
    
    @objc private func didTapSelectAll() {
        guard isEditOnlyMode else { return }
        
        // Wait until in-scope items are prepared; otherwise the first tap can no-op.
        guard hasPreparedSelectableItemsInScope else {
            Task {
                await prepareSelectableItemsInScope()
                await MainActor.run { self.didTapSelectAll() }
            }
            return
        }
        
        guard !allItemIdsInScope.isEmpty else { return }
        
        let total = allItemIdsInScope.count
        let selectedInScopeCount = selectedItemIdsInScope().count
        let isAllSelected = total > 0 && selectedInScopeCount >= total
        
        if isAllSelected {
            // Clear only this folder's selections; keep items from other folders.
            let inScope = allItemIdsInScope
            selectedNotes = selectedNotes.filter { !inScope.contains($0.id) }
            selectedPlaces = selectedPlaces.filter { !inScope.contains($0.id) }
            selectedRoutines = selectedRoutines.filter { !inScope.contains($0.id) }
            selectedContacts = selectedContacts.filter { !inScope.contains($0.id) }
            selectedUnknownItems = selectedUnknownItems.filter { !inScope.contains($0.id) }
        } else {
            // Select items, respecting the limit
            if let limit = selectionLimit {
                // Calculate how many more items we can select
                let globalSelectedCount = getCurrentTotalSelections()
                let availableSlots = limit - globalSelectedCount
                
                if availableSlots <= 0 {
                    // Already at limit, show alert
                    showSelectionLimitAlert()
                    return
                }
                
                // Select up to the available slots
                var itemsSelected = 0
                
                // Add entries first (up to limit)
                for entry in inScopeEntries {
                    if itemsSelected >= availableSlots { break }
                    if selectedNotes.insert(entry).inserted {
                        itemsSelected += 1
                    }
                }
                
                // Add places next (up to remaining limit)
                for place in inScopePlaces {
                    if itemsSelected >= availableSlots { break }
                    if selectedPlaces.insert(place).inserted {
                        itemsSelected += 1
                    }
                }
                
                // Add routines last (up to remaining limit)
                for routine in inScopeRoutines {
                    if itemsSelected >= availableSlots { break }
                    if selectedRoutines.insert(routine).inserted {
                        itemsSelected += 1
                    }
                }
                for contact in inScopeContacts {
                    if itemsSelected >= availableSlots { break }
                    if selectedContacts.insert(contact).inserted {
                        itemsSelected += 1
                    }
                }
                for unknown in inScopeUnknownItems {
                    if itemsSelected >= availableSlots { break }
                    if selectedUnknownItems.insert(unknown).inserted {
                        itemsSelected += 1
                    }
                }
                
                // Show alert if we couldn't select all items due to limit
                if (total - selectedInScopeCount) > availableSlots {
                    showSelectionLimitAlert()
                }
            } else {
                // No limit (pro user): union in-scope items so other-folder selections stay intact.
                selectedNotes.formUnion(inScopeEntries)
                selectedPlaces.formUnion(inScopePlaces)
                selectedRoutines.formUnion(inScopeRoutines)
                selectedContacts.formUnion(inScopeContacts)
                selectedUnknownItems.formUnion(inScopeUnknownItems)
            }
        }
        notifySelectNestItemsDelegate()
        
        // Update UI
        collectionView.reloadData()
        refreshFolderSelectionCounts()
        updateSelectAllButtonTitle()
    }
    
    private func updateEditModeUI() {
        setupNavigationBar() // Refresh navigation bar to update menu
        collectionView.allowsMultipleSelection = isEditingMode

        // Drop browse-mode contextual highlight when entering multi-select.
        if isEditingMode {
            collectionView.indexPathsForSelectedItems?.forEach {
                collectionView.deselectItem(at: $0, animated: false)
            }
        }

        if !isEditingMode {
            selectedNotes.removeAll()
            selectedPlaces.removeAll()
            selectedRoutines.removeAll()
            selectedContacts.removeAll()
            selectedUnknownItems.removeAll()

            // Notify delegate when clearing selections in edit-only mode
            if isEditOnlyMode {
                notifySelectNestItemsDelegate()
            }
        }

        // Update the add entry button for edit mode (floating button)
        if !isUsingToolbar && !isUsingGlassContainer {
            updateAddEntryButtonForEditMode()
        }

        // Update toolbar for iOS 26+
        if isUsingToolbar {
            // Setup toolbar for iOS 26+
            if #available(iOS 26.0, *) {
                setupToolbar()
            }
        }

        // Update glass container for iOS 18-25
        if isUsingGlassContainer {
            if #available(iOS 18.0, *) {
                if isEditingMode {
                    showGlassContainer()
                } else {
                    hideGlassContainer()
                }
            }
        }

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
        addEntryButton?.alpha = 1.0
    }
    
    private func updateCellSelection(for entry: NoteItem) {
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

    private func updateContactCellSelection(for contact: ContactItem) {
        guard let dataSource = self.dataSource else { return }
        var snapshot = dataSource.snapshot()
        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems([contact])
        } else {
            snapshot.reloadItems([contact])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
        updateMoveButtonState()
    }

    private func updateUnknownCellSelection(for unknown: UnknownItem) {
        guard let dataSource = self.dataSource else { return }
        var snapshot = dataSource.snapshot()
        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems([unknown])
        } else {
            snapshot.reloadItems([unknown])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
        updateMoveButtonState()
    }
    
    private func showItemSuggestions() {
        // Present CommonItemsViewController as a sheet with medium and large detents
        let commonItemsVC = CommonItemsViewController(category: category, nestItemRepository: nestItemRepository)
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
        let categoryVC = CategoryDetailViewController()
        categoryVC.categoryDelegate = self
        present(categoryVC, animated: true)
    }
    
    @objc private func addButtonTapped() {
        // Show the create sheet for nest owners, including demo (saves are blocked).
        guard showsOwnerChrome else { return }
        
        let newEntryVC = NoteDetailViewController(category: self.category)
        newEntryVC.noteDelegate = self
        self.present(newEntryVC, animated: true)
    }
    
    @objc private func moveButtonTapped() {
        // Handle move action for selected entries and places

        let selectedNotesArray = Array(selectedNotes)
        let selectedPlacesArray = Array(selectedPlaces)

        // Handle moving both entries and places between categories
        if !selectedNotesArray.isEmpty || !selectedPlacesArray.isEmpty {
            let selectFolderVC = SelectFolderViewController(
                nestItemRepository: nestItemRepository,
                currentCategory: category,
                selectedNotes: selectedNotesArray,
                selectedPlaces: selectedPlacesArray
            )
            selectFolderVC.delegate = self

            let navController = UINavigationController(rootViewController: selectFolderVC)
            present(navController, animated: true)
        }
    }

    @objc private func deleteButtonTapped() {
        // Only allow deletion for nest owners
        guard allowsNestEdits else { return }

        let selectedNotesArray = Array(selectedNotes)
        let selectedPlacesArray = Array(selectedPlaces)
        let selectedRoutinesArray = Array(selectedRoutines)
        let selectedContactArray = Array(selectedContacts)
        let selectedUnknownArray = Array(selectedUnknownItems)

        let totalItems = selectedNotesArray.count + selectedPlacesArray.count + selectedRoutinesArray.count
            + selectedContactArray.count + selectedUnknownArray.count
        guard totalItems > 0 else { return }

        // Show confirmation alert
        let itemText = totalItems == 1 ? "item" : "items"
        let alert = UIAlertController(
            title: "Delete \(totalItems) \(itemText)?",
            message: "This action cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performBulkDelete(
                notes: selectedNotesArray,
                places: selectedPlacesArray,
                routines: selectedRoutinesArray,
                contacts: selectedContactArray,
                unknownItems: selectedUnknownArray
            )
        })

        present(alert, animated: true)
    }

    private func performBulkDelete(
        notes: [NoteItem],
        places: [PlaceItem],
        routines: [RoutineItem],
        contacts: [ContactItem],
        unknownItems: [UnknownItem]
    ) {
        guard let nestService = nestItemRepository as? NestService else { return }

        Task {
            do {
                // Delete notes
                for entry in notes {
                    try await nestService.deleteNote(entry)
                }

                // Delete places
                for place in places {
                    try await nestService.deletePlace(place)
                }

                // Delete routines
                for routine in routines {
                    try await nestService.deleteRoutine(routine)
                }
                
                for contact in contacts {
                    try await nestService.deleteItem(id: contact.id)
                }
                for unknown in unknownItems {
                    try await nestService.deleteItem(id: unknown.id)
                }

                // Invalidate cache after bulk operations
                nestService.invalidateItemsCache()

                await MainActor.run {
                    // Batch local removals so we apply one animated snapshot.
                    self.shouldApplySnapshotAutomatically = false

                    let deletedNoteIds = Set(notes.map(\.id))
                    let deletedPlaceIds = Set(places.map(\.id))
                    let deletedRoutineIds = Set(routines.map(\.id))
                    let deletedContactIds = Set(contacts.map(\.id))
                    let deletedUnknownIds = Set(unknownItems.map(\.id))

                    self.notes.removeAll { deletedNoteIds.contains($0.id) }
                    self.places.removeAll { deletedPlaceIds.contains($0.id) }
                    self.routines.removeAll { deletedRoutineIds.contains($0.id) }
                    self.contacts.removeAll { deletedContactIds.contains($0.id) }
                    self.unknownItems.removeAll { deletedUnknownIds.contains($0.id) }

                    self.shouldApplySnapshotAutomatically = true
                    self.applySnapshot(animated: true)

                    // Exit edit mode
                    self.isEditingMode = false

                    // Show success message
                    let totalDeleted = notes.count + places.count + routines.count + contacts.count + unknownItems.count
                    let itemText = totalDeleted == 1 ? "item" : "items"
                    self.showToast(text: "\(totalDeleted) \(itemText) deleted")

                    // Refresh empty state
                    self.refreshEmptyState()
                }
            } catch {
                await MainActor.run {
                    Logger.log(level: .error, category: self.logCategory, message: "Failed to delete items: \(error)")
                    self.showToast(text: "Failed to delete items")
                }
            }
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

        if !contacts.isEmpty {
            sections.append(.contacts)
        }
        
        let codesNotes = notes.filter { $0.shouldUseHalfWidthCell }
        let otherNotes = notes.filter { !$0.shouldUseHalfWidthCell }
        
        if !codesNotes.isEmpty || !otherNotes.isEmpty {
            sections.append(.codes)
        }

        if !routines.isEmpty {
            sections.append(.routines)
        }
        
        if !places.isEmpty {
            sections.append(.places)
        }
        
        if !unknownItems.isEmpty {
            sections.append(.unknownItems)
        }
        
        return sections
    }

    private func setupAddEntryButton() {
        // Only show floating button for pre-iOS 18, nest owners, and not in edit-only mode
        guard !isUsingToolbar && !isUsingGlassContainer && showsOwnerChrome && !isEditOnlyMode else { return }

        addEntryButton = UIButton(type: .system)
        addEntryButton.translatesAutoresizingMaskIntoConstraints = false

        // Configure button appearance with glass effect
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "plus")
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .systemBackground.withAlphaComponent(0.8)
        config.baseForegroundColor = .label

        addEntryButton.configuration = config

        // Add glass effect
        addEntryButton.layer.shadowColor = UIColor.black.cgColor
        addEntryButton.layer.shadowOpacity = 0.1
        addEntryButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        addEntryButton.layer.shadowRadius = 4

        // Add blur effect
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 22
        blurView.layer.masksToBounds = true
        blurView.isUserInteractionEnabled = false

        // Store reference for later updates
        addEntryButtonBlurView = blurView

        addEntryButton.insertSubview(blurView, at: 0)
        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: addEntryButton.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: addEntryButton.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: addEntryButton.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: addEntryButton.bottomAnchor)
        ])

        view.addSubview(addEntryButton)

        // Store the width constraint for later manipulation
        addEntryButtonWidthConstraint = addEntryButton.widthAnchor.constraint(equalToConstant: 44)

        NSLayoutConstraint.activate([
            addEntryButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            addEntryButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            addEntryButton.heightAnchor.constraint(equalToConstant: 44),
            addEntryButtonWidthConstraint!
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
            // Change to "Actions" button with ellipsis icon and show menu
            var config = addEntryButton.configuration ?? UIButton.Configuration.filled()
            config.title = "Actions"
            config.image = UIImage(systemName: "ellipsis")
            config.imagePlacement = .leading
            config.imagePadding = 8
            addEntryButton.configuration = config

            // Create menu with Move and Delete options
            addEntryButton.menu = createEditActionsMenu()
            addEntryButton.showsMenuAsPrimaryAction = true

            // Remove any previous target actions
            addEntryButton.removeTarget(self, action: #selector(moveButtonTapped), for: .touchUpInside)

            // Update width constraint to accommodate text
            addEntryButtonWidthConstraint?.isActive = false
            addEntryButtonWidthConstraint = addEntryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
            addEntryButtonWidthConstraint?.isActive = true

            // Update glass effect corner radius for rectangular button (height is 44, so radius should be 22)
            addEntryButtonBlurView?.layer.cornerRadius = 22

            // Update button state based on selection
            updateMoveButtonState()
        } else {
            // Change back to add button with plus icon and restore menu
            var config = addEntryButton.configuration ?? UIButton.Configuration.filled()
            config.title = ""
            config.image = UIImage(systemName: "plus")
            config.imagePlacement = .leading
            config.imagePadding = 0
            addEntryButton.configuration = config

            addEntryButton.removeTarget(self, action: #selector(moveButtonTapped), for: .touchUpInside)
            setupAddButtonMenu() // Restore the menu
            addEntryButton.isEnabled = true // Ensure it's enabled when not in edit mode

            // Update width constraint back to square button
            addEntryButtonWidthConstraint?.isActive = false
            addEntryButtonWidthConstraint = addEntryButton.widthAnchor.constraint(equalToConstant: 44)
            addEntryButtonWidthConstraint?.isActive = true

            // Update glass effect corner radius for square button
            addEntryButtonBlurView?.layer.cornerRadius = 22
        }
    }

    private func createEditActionsMenu() -> UIMenu {
        let hasSelection = !selectedNotes.isEmpty || !selectedPlaces.isEmpty || !selectedRoutines.isEmpty
            || !selectedContacts.isEmpty || !selectedUnknownItems.isEmpty

        let moveAction = UIAction(
            title: "Move",
            image: UIImage(systemName: "arrow.right"),
            attributes: hasSelection ? [] : .disabled
        ) { _ in
            self.moveButtonTapped()
        }

        let deleteAction = UIAction(
            title: "Delete",
            image: UIImage(systemName: "trash"),
            attributes: hasSelection ? .destructive : [.disabled, .destructive]
        ) { _ in
            self.deleteButtonTapped()
        }

        return UIMenu(title: "Actions", children: [moveAction, deleteAction])
    }
    
    private func updateMoveButtonState() {
        let hasSelection = !selectedNotes.isEmpty || !selectedPlaces.isEmpty || !selectedRoutines.isEmpty
            || !selectedContacts.isEmpty || !selectedUnknownItems.isEmpty

        if isUsingToolbar {
            // Update toolbar buttons (both move and delete)
            if let toolbarItems = self.toolbarItems {
                for item in toolbarItems {
                    if item.action == #selector(moveButtonTapped) {
                        item.isEnabled = hasSelection && allowsNestEdits
                    } else if item.action == #selector(deleteButtonTapped) {
                        item.isEnabled = hasSelection && allowsNestEdits
                    }
                }
            }
        } else if isUsingGlassContainer {
            // Update glass container buttons
            if #available(iOS 18.0, *) {
                updateGlassButtonStates()
            }
        } else {
            // Update floating button
            guard let addEntryButton = addEntryButton, isEditingMode else { return }
            addEntryButton.isEnabled = true // Always enabled, but menu items may be disabled
            addEntryButton.alpha = 1.0

            // Refresh the menu to update enabled/disabled states
            addEntryButton.menu = createEditActionsMenu()
        }
    }
    

    
    private func flashCell(for entry: NoteItem) {
        guard let indexPath = dataSource?.indexPath(for: entry),
              let cell = collectionView.cellForItem(at: indexPath) else { return }
        
        if let waterfallCell = cell as? WaterfallGridCell {
            waterfallCell.flash()
        } else if let halfWidthCell = cell as? HalfWidthCell {
            halfWidthCell.flash()
        } else if let fullWidthCell = cell as? FullWidthCell {
            fullWidthCell.flash()
        }
    }
    
    private func updateLocalEntry(_ entry: NoteItem) {
        guard let index = notes.firstIndex(where: { $0.id == entry.id }) else {
            Logger.log(level: .error, category: logCategory, message: "Entry not found for update: \(entry.id)")
            return
        }

        shouldApplySnapshotAutomatically = false
        notes[index] = entry
        shouldApplySnapshotAutomatically = true

        DispatchQueue.main.async {
            self.refreshGridItem(
                matching: { ($0 as? NoteItem)?.id == entry.id },
                updatedItem: entry,
                orderIds: {
                    self.notes
                        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                        .map(\.id)
                },
                idFromItem: { ($0 as? NoteItem)?.id },
                flash: { self.flashCell(for: entry) }
            )
        }
    }
    
    private func addLocalEntry(_ entry: NoteItem) {
        shouldApplySnapshotAutomatically = false
        notes.append(entry)
        shouldApplySnapshotAutomatically = true
        applySnapshot(animated: true) { [weak self] in
            self?.flashCell(for: entry)
        }
    }
    
    private func updateLocalPlace(_ place: PlaceItem) {
        DispatchQueue.main.async {
            self.shouldApplySnapshotAutomatically = false
            if let index = self.places.firstIndex(where: { $0.id == place.id }) {
                self.places[index] = place
            }
            self.shouldApplySnapshotAutomatically = true

            // PlaceItem is a struct with id-only equality — replace the snapshot
            // identifier so Diffable hands the cell provider fresh values.
            self.refreshGridItem(
                matching: { ($0 as? PlaceItem)?.id == place.id },
                updatedItem: place,
                replacesStoredIdentifier: true,
                orderIds: {
                    self.places
                        .sorted { ($0.alias ?? "").localizedCaseInsensitiveCompare($1.alias ?? "") == .orderedAscending }
                        .map(\.id)
                },
                idFromItem: { ($0 as? PlaceItem)?.id },
                flash: { self.flashPlaceCell(for: place) }
            )
        }
    }
    
    private func addLocalPlace(_ place: PlaceItem) {
        shouldApplySnapshotAutomatically = false
        places.append(place)
        shouldApplySnapshotAutomatically = true
        applySnapshot(animated: true) { [weak self] in
            self?.flashPlaceCell(for: place)
        }
    }
    
    private func flashPlaceCell(for place: PlaceItem) {
        guard let indexPath = dataSource?.indexPath(for: place),
              let cell = collectionView.cellForItem(at: indexPath) else { return }

        if let waterfallCell = cell as? WaterfallGridCell {
            waterfallCell.flash()
        } else if let placeCell = cell as? PlaceCell {
            placeCell.flash()
        }
    }
    
    private func updateLocalRoutine(_ routine: RoutineItem) {
        DispatchQueue.main.async {
            self.shouldApplySnapshotAutomatically = false
            if let index = self.routines.firstIndex(where: { $0.id == routine.id }) {
                self.routines[index] = routine
            }
            self.shouldApplySnapshotAutomatically = true

            self.refreshGridItem(
                matching: { ($0 as? RoutineItem)?.id == routine.id },
                updatedItem: routine,
                orderIds: {
                    self.routines
                        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                        .map(\.id)
                },
                idFromItem: { ($0 as? RoutineItem)?.id },
                flash: { self.flashRoutineCell(for: routine) }
            )
        }
    }
    
    private func addLocalRoutine(_ routine: RoutineItem) {
        shouldApplySnapshotAutomatically = false
        routines.append(routine)
        shouldApplySnapshotAutomatically = true
        applySnapshot(animated: true) { [weak self] in
            self?.flashRoutineCell(for: routine)
        }
    }
    
    private func flashRoutineCell(for routine: RoutineItem) {
        guard let indexPath = dataSource?.indexPath(for: routine),
              let cell = collectionView.cellForItem(at: indexPath) else { return }

        if let waterfallCell = cell as? WaterfallGridCell {
            waterfallCell.flash()
        } else if let routineCell = cell as? RoutineCell {
            routineCell.flash()
        }
    }

    private func updateLocalContact(_ contact: ContactItem) {
        DispatchQueue.main.async {
            self.shouldApplySnapshotAutomatically = false
            if let index = self.contacts.firstIndex(where: { $0.id == contact.id }) {
                self.contacts[index] = contact
            }
            self.shouldApplySnapshotAutomatically = true

            self.refreshGridItem(
                matching: { ($0 as? ContactItem)?.id == contact.id },
                updatedItem: contact,
                replacesStoredIdentifier: true,
                orderIds: {
                    self.contacts
                        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                        .map(\.id)
                },
                idFromItem: { ($0 as? ContactItem)?.id },
                flash: {
                    if let indexPath = self.dataSource?.indexPath(for: contact),
                       let cell = self.collectionView.cellForItem(at: indexPath) as? WaterfallGridCell {
                        cell.flash()
                    }
                }
            )
        }
    }

    /// Reloads one item from the *live* Diffable snapshot so the cell provider
    /// runs again. A freshly built snapshot + `reconfigureItems` is often a no-op
    /// when identity is id-only (equal items → no cell refresh).
    private func refreshGridItem<Item: Hashable>(
        matching: @escaping (AnyHashable) -> Bool,
        updatedItem: Item,
        replacesStoredIdentifier: Bool = false,
        orderIds: () -> [String],
        idFromItem: (AnyHashable) -> String?,
        flash: @escaping () -> Void
    ) {
        guard let dataSource else {
            applySnapshot(animated: false, completion: flash)
            return
        }

        let currentSnapshot = dataSource.snapshot()
        guard let existing = currentSnapshot.itemIdentifiers.first(where: matching),
              let section = currentSnapshot.sectionIdentifier(containingItem: existing) else {
            waterfallHeightCache.removeAll()
            applySnapshot(animated: false) { [weak self] in
                self?.invalidateWaterfallLayoutAfterContentChange()
                flash()
            }
            return
        }

        let currentOrder = currentSnapshot.itemIdentifiers(inSection: section).compactMap(idFromItem)
        let desiredOrder = orderIds().filter { currentOrder.contains($0) }
        let orderChanged = currentOrder != desiredOrder

        var snapshot = currentSnapshot
        if replacesStoredIdentifier {
            // Structs hashed by id keep stale values across apply; swap identifiers.
            let sectionItems = snapshot.itemIdentifiers(inSection: section)
            snapshot.deleteItems(sectionItems)
            if orderChanged {
                let fresh = createSnapshot()
                if fresh.sectionIdentifiers.contains(section) {
                    snapshot.appendItems(fresh.itemIdentifiers(inSection: section), toSection: section)
                } else {
                    waterfallHeightCache.removeAll()
                    applySnapshot(animated: false) { [weak self] in
                        self?.invalidateWaterfallLayoutAfterContentChange()
                        flash()
                    }
                    return
                }
            } else if let index = sectionItems.firstIndex(of: existing) {
                var replaced = sectionItems
                replaced[index] = updatedItem
                snapshot.appendItems(replaced, toSection: section)
            } else {
                snapshot.appendItems([updatedItem], toSection: section)
            }
        } else if orderChanged {
            // Reference-type items were mutated in place; rebuild to re-sort,
            // then reload so moved cells pick up the new title/content.
            waterfallHeightCache.removeAll()
            applySnapshot(animated: false) { [weak self] in
                guard let self, let dataSource = self.dataSource else {
                    flash()
                    return
                }
                var snapshot = dataSource.snapshot()
                if let item = snapshot.itemIdentifiers.first(where: matching) {
                    snapshot.reloadItems([item])
                    dataSource.apply(snapshot, animatingDifferences: false) {
                        self.invalidateWaterfallLayoutAfterContentChange()
                        flash()
                    }
                } else {
                    self.invalidateWaterfallLayoutAfterContentChange()
                    flash()
                }
            }
            return
        } else {
            // Classes mutated in place: force the existing cell to reconfigure.
            snapshot.reloadItems([existing])
        }

        waterfallHeightCache.removeAll()
        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            guard let self else { return }
            self.invalidateWaterfallLayoutAfterContentChange()
            flash()
        }
    }
    
    // Update loadNotes to use the new streamlined approach
    private func loadNotes() async {
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
            if let nestService = nestItemRepository as? NestService {
                nestService.invalidateItemsCache()
            } else if let sitterService = nestItemRepository as? SitterViewService {
                sitterService.clearNotesCache()
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
                title: "No notes to select",
                subtitle: "There are no notes in this folder yet.",
                actionButtonTitle: nil
            )
        } else {
            // Normal mode: standard empty state with action button for nest owners
            emptyStateView = NNEmptyStateView(
                icon: UIImage(systemName: "moon.zzz.fill"),
                title: "It's a little quiet in here",
                subtitle: nestItemRepository is NestService ? "Items for this folder will appear here. Add an item by tapping below or explore suggestions." :
                    "This folder either has no items in it or none of the items were shared with you.",
                actionButtonTitle: showsOwnerChrome ? "Add Item" : nil,
                actionButtonMenu: showsOwnerChrome ? createAddItemMenu() : nil
            )
            
            if showsOwnerChrome {
                emptyStateView.addAction(title: "Item Suggestions", backgroundColor: .systemBlue.withAlphaComponent(0.15), foregroundColor: .systemBlue, tag: 1)
            }
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
    
    // MARK: - Item Deletion
    
    private func deleteFolderWithConfirmation(_ folderData: FolderData) {
        presentDeleteConfirmation(
            title: "Delete Folder",
            message: "Are you sure you want to delete the folder '\(folderData.title)'? This will also delete all items within this folder. This action cannot be undone."
        ) { [weak self] in
            self?.deleteFolder(folderData)
        }
    }

    private func deleteEntryWithConfirmation(_ entry: NoteItem) {
        presentDeleteConfirmation(
            title: "Delete Note",
            message: "Are you sure you want to delete '\(entry.title)'? This action cannot be undone."
        ) { [weak self] in
            self?.performBulkDelete(notes: [entry], places: [], routines: [], contacts: [], unknownItems: [])
        }
    }

    private func deletePlaceWithConfirmation(_ place: PlaceItem) {
        let displayName = place.alias ?? place.title
        presentDeleteConfirmation(
            title: "Delete Place",
            message: "Are you sure you want to delete '\(displayName)'? This action cannot be undone."
        ) { [weak self] in
            self?.performBulkDelete(notes: [], places: [place], routines: [], contacts: [], unknownItems: [])
        }
    }

    private func deleteRoutineWithConfirmation(_ routine: RoutineItem) {
        presentDeleteConfirmation(
            title: "Delete Routine",
            message: "Are you sure you want to delete '\(routine.title)'? This action cannot be undone."
        ) { [weak self] in
            self?.performBulkDelete(notes: [], places: [], routines: [routine], contacts: [], unknownItems: [])
        }
    }

    private func deleteContactWithConfirmation(_ contact: ContactItem) {
        presentDeleteConfirmation(
            title: "Delete Contact",
            message: "Are you sure you want to delete '\(contact.title)'? This action cannot be undone."
        ) { [weak self] in
            self?.performBulkDelete(notes: [], places: [], routines: [], contacts: [contact], unknownItems: [])
        }
    }

    private func deleteUnknownItemWithConfirmation(_ unknown: UnknownItem) {
        presentDeleteConfirmation(
            title: "Delete Item",
            message: "Are you sure you want to delete '\(unknown.title)'? This action cannot be undone."
        ) { [weak self] in
            self?.performBulkDelete(notes: [], places: [], routines: [], contacts: [], unknownItems: [unknown])
        }
    }

    private func presentDeleteConfirmation(title: String, message: String, onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            onConfirm()
        })
        present(alert, animated: true)
    }
    
    private func deleteFolder(_ folderData: FolderData) {
        guard let nestService = nestItemRepository as? NestService else {
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
        let selectPlaceVC = SelectPlaceViewController()
        selectPlaceVC.category = self.category
        let navController = UINavigationController(rootViewController: selectPlaceVC)
        present(navController, animated: true)
    }
    
    func addRoutineTapped() {
        // Navigate to RoutineDetailViewController for creating a new routine
        let newRoutineVC = RoutineDetailViewController(category: self.category)
        newRoutineVC.routineDelegate = self
        present(newRoutineVC, animated: true)
    }
    
    func addContactTapped() {
        guard showsOwnerChrome else { return }
        let vc = ContactDetailViewController(category: category)
        vc.contactDelegate = self
        // Defer until the add menu finishes dismissing (avoids presentation timing issues on Simulator).
        DispatchQueue.main.async {
            self.present(vc, animated: true)
        }
    }

    @available(iOS 26.0, *)
    private func setupToolbar() {
        if isEditingMode {
            // Move and Delete buttons in edit mode
            let hasSelection = !selectedNotes.isEmpty || !selectedPlaces.isEmpty || !selectedRoutines.isEmpty
            || !selectedContacts.isEmpty || !selectedUnknownItems.isEmpty

            let deleteBarButtonItem = UIBarButtonItem(
                title: "Delete",
                style: .plain,
                target: self,
                action: #selector(deleteButtonTapped)
            )
            deleteBarButtonItem.image = UIImage(systemName: "trash")
            deleteBarButtonItem.tintColor = .systemRed
            deleteBarButtonItem.isEnabled = hasSelection && allowsNestEdits // Only nest owners can delete

            let moveBarButtonItem = UIBarButtonItem(
                title: "Move",
                style: .plain,
                target: self,
                action: #selector(moveButtonTapped)
            )
            moveBarButtonItem.image = UIImage(systemName: "arrow.right")
            moveBarButtonItem.isEnabled = hasSelection && allowsNestEdits // Only nest owners can move

            if allowsNestEdits && !isEditOnlyMode {
                // Full functionality for nest owners
                toolbarItems = [deleteBarButtonItem, .flexibleSpace(), moveBarButtonItem]
            } else if isEditOnlyMode {
                // Edit-only mode: no delete or move, just selection
                toolbarItems = []
            } else {
                // Sitters: no actions available
                toolbarItems = []
            }
        } else {
            // Add menu in normal mode (nest owners and demo; saves are blocked in demo)
            if showsOwnerChrome && !isEditOnlyMode {
                let addBarButtonItem = UIBarButtonItem(systemItem: .add)
                addBarButtonItem.menu = createAddItemMenu()

                toolbarItems = [.flexibleSpace(), addBarButtonItem]
            } else {
                // No toolbar items for sitters or edit-only mode
                toolbarItems = []
            }
        }

        navigationController?.setToolbarHidden(toolbarItems?.isEmpty ?? true, animated: true)
    }

    func createAddItemMenu() -> UIMenu {

        let addFolderAction = UIAction(
            title: "Add Folder",
            image: UIImage(systemName: "folder.badge.plus")
        ) { _ in
            self.presentAddFolder()
        }

        let addEntryAction = UIAction(
            title: "Add Note",
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
        
        let addContactAction = UIAction(
            title: "Add Contact",
            image: UIImage(systemName: "person.crop.circle")
        ) { _ in
            self.addContactTapped()
        }

        // Mirror the depth restriction used in the top-right nav menu
        let currentDepth = category.components(separatedBy: "/").count
        var children: [UIMenuElement] = [addEntryAction, addPlaceAction, addRoutineAction, addContactAction]
        if currentDepth < 3 {
            // Prefer showing Add Folder first
            children.insert(addFolderAction, at: 0)
        }

        return UIMenu(title: "Add Item", children: children)
    }

    @available(iOS 26.0, *)
    private func setupGlassContainer() {
        // Only setup for nest owners and not in edit-only mode
        guard showsOwnerChrome && !isEditOnlyMode else { return }

        // Create the glass container effect
        let glassContainerEffect = UIGlassContainerEffect()
        glassContainerEffect.spacing = 20

        glassContainerView = UIVisualEffectView(effect: glassContainerEffect)
        glassContainerView?.translatesAutoresizingMaskIntoConstraints = false
        glassContainerView?.isHidden = true // Start hidden

        view.addSubview(glassContainerView!)

        // Setup initial position (same as add button would be)
        NSLayoutConstraint.activate([
            glassContainerView!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            glassContainerView!.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            glassContainerView!.heightAnchor.constraint(equalToConstant: 44)
        ])

        setupGlassButtons()
    }

    @available(iOS 26.0, *)
    private func setupGlassButtons() {
        guard let containerView = glassContainerView else { return }

        // Create glass effect for individual buttons
        let glassEffect = UIGlassEffect()

        // Delete button
        let deleteButtonView = UIVisualEffectView(effect: glassEffect)
        deleteButtonView.translatesAutoresizingMaskIntoConstraints = false

        glassDeleteButton = UIButton(type: .system)
        glassDeleteButton?.translatesAutoresizingMaskIntoConstraints = false
        glassDeleteButton?.setImage(UIImage(systemName: "trash"), for: .normal)
        glassDeleteButton?.tintColor = .systemRed
        glassDeleteButton?.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)

        deleteButtonView.contentView.addSubview(glassDeleteButton!)
        containerView.contentView.addSubview(deleteButtonView)

        // Move button
        let moveButtonView = UIVisualEffectView(effect: glassEffect)
        moveButtonView.translatesAutoresizingMaskIntoConstraints = false

        glassMoveButton = UIButton(type: .system)
        glassMoveButton?.translatesAutoresizingMaskIntoConstraints = false
        glassMoveButton?.setImage(UIImage(systemName: "arrow.right"), for: .normal)
        glassMoveButton?.tintColor = .label
        glassMoveButton?.addTarget(self, action: #selector(moveButtonTapped), for: .touchUpInside)

        moveButtonView.contentView.addSubview(glassMoveButton!)
        containerView.contentView.addSubview(moveButtonView)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Delete button
            deleteButtonView.leadingAnchor.constraint(equalTo: containerView.contentView.leadingAnchor),
            deleteButtonView.topAnchor.constraint(equalTo: containerView.contentView.topAnchor),
            deleteButtonView.bottomAnchor.constraint(equalTo: containerView.contentView.bottomAnchor),
            deleteButtonView.widthAnchor.constraint(equalToConstant: 44),

            glassDeleteButton!.leadingAnchor.constraint(equalTo: deleteButtonView.contentView.leadingAnchor),
            glassDeleteButton!.trailingAnchor.constraint(equalTo: deleteButtonView.contentView.trailingAnchor),
            glassDeleteButton!.topAnchor.constraint(equalTo: deleteButtonView.contentView.topAnchor),
            glassDeleteButton!.bottomAnchor.constraint(equalTo: deleteButtonView.contentView.bottomAnchor),

            // Move button
            moveButtonView.trailingAnchor.constraint(equalTo: containerView.contentView.trailingAnchor),
            moveButtonView.topAnchor.constraint(equalTo: containerView.contentView.topAnchor),
            moveButtonView.bottomAnchor.constraint(equalTo: containerView.contentView.bottomAnchor),
            moveButtonView.widthAnchor.constraint(equalToConstant: 44),

            glassMoveButton!.leadingAnchor.constraint(equalTo: moveButtonView.contentView.leadingAnchor),
            glassMoveButton!.trailingAnchor.constraint(equalTo: moveButtonView.contentView.trailingAnchor),
            glassMoveButton!.topAnchor.constraint(equalTo: moveButtonView.contentView.topAnchor),
            glassMoveButton!.bottomAnchor.constraint(equalTo: moveButtonView.contentView.bottomAnchor),

            // Container layout
            containerView.contentView.widthAnchor.constraint(equalToConstant: 108) // 44 + 20 + 44
        ])

        updateGlassButtonStates()
    }

    @available(iOS 18.0, *)
    private func updateGlassButtonStates() {
        let hasSelection = !selectedNotes.isEmpty || !selectedPlaces.isEmpty || !selectedRoutines.isEmpty
            || !selectedContacts.isEmpty || !selectedUnknownItems.isEmpty

        glassMoveButton?.isEnabled = hasSelection
        glassDeleteButton?.isEnabled = hasSelection

        glassMoveButton?.alpha = hasSelection ? 1.0 : 0.6
        glassDeleteButton?.alpha = hasSelection ? 1.0 : 0.6
    }

    @available(iOS 18.0, *)
    private func showGlassContainer(animated: Bool = true) {
        guard let containerView = glassContainerView else { return }

        containerView.isHidden = false

        if animated {
            // Start from collapsed state
            containerView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            containerView.alpha = 0

            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0.3,
                options: [.curveEaseOut],
                animations: {
                    containerView.transform = .identity
                    containerView.alpha = 1.0
                }
            )
        }
    }

    @available(iOS 18.0, *)
    private func hideGlassContainer(animated: Bool = true) {
        guard let containerView = glassContainerView else { return }

        if animated {
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [.curveEaseIn],
                animations: {
                    containerView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                    containerView.alpha = 0
                },
                completion: { _ in
                    containerView.isHidden = true
                    containerView.transform = .identity
                }
            )
        } else {
            containerView.isHidden = true
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
                Logger.log(level: .info, category: logCategory, message: "Selected folder for entry selection: \(folderData.title)")
                
                let subfolderVC = NestCategoryViewController(
                    nestItemRepository: nestItemRepository,
                    initialCategory: folderData.fullPath,
                    isEditOnlyMode: true,
                    places: allPlaces
                )
                subfolderVC.selectNestItemsDelegate = selectNestItemsDelegate
                subfolderVC.setSelectionLimit(selectionLimit, offersUpgrade: selectionLimitOffersUpgrade)
                subfolderVC.setExcludedItemIds(excludedItemIds)
                subfolderVC.setHidesSelectAllButton(hidesSelectAllButton)
                
                // Restore selection from flow controller to ensure persistence across navigation
                Task { @MainActor in
                    if let items = await self.selectNestItemsDelegate?.getCurrentSelectedItems() {
                        subfolderVC.restoreSelectedItems(items)
                    } else {
                        subfolderVC.restoreSelectedItems(self.currentSelectedNestItems())
                    }
                }
                
                navigationController?.pushViewController(subfolderVC, animated: true)
            } else if !isEditingMode {
                // Normal folder navigation (not in edit mode)
                Logger.log(level: .info, category: logCategory, message: "Selected folder: \(folderData.title)")
                
                let subfolderVC = NestCategoryViewController(
                    category: folderData.fullPath,
                    notes: [],
                    places: allPlaces,
                    nestItemRepository: nestItemRepository
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
                    // Check selection limit before adding
                    if !canAddMoreSelections() {
                        showSelectionLimitAlert()
                        collectionView.deselectItem(at: indexPath, animated: true)
                        return
                    }
                    selectedPlaces.insert(selectedPlace)
                }
                
                // Update the cell appearance
                updatePlaceCellSelection(for: selectedPlace)
                
                // Notify delegate in edit-only mode
                if isEditOnlyMode {
                    notifySelectNestItemsDelegate()
                    updateSelectAllButtonAfterSelectionChange()
                }
                return
            }
            
            // Normal place selection (not in edit mode) — keep highlight until sheet dismisses.
            Logger.log(level: .info, category: logCategory, message: "Selected place for viewing: \(selectedPlace.alias ?? "Unnamed")")
            presentItemDetail(for: selectedPlace, from: cell)
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
                    // Check selection limit before adding
                    if !canAddMoreSelections() {
                        showSelectionLimitAlert()
                        collectionView.deselectItem(at: indexPath, animated: true)
                        return
                    }
                    selectedRoutines.insert(selectedRoutine)
                }
                
                // Notify delegate in edit-only mode
                if isEditOnlyMode {
                    notifySelectNestItemsDelegate()
                    updateSelectAllButtonAfterSelectionChange()
                }
                
                // Update the cell appearance
                updateRoutineCellSelection(for: selectedRoutine)
                return
            }
            
            // Normal routine selection (not in edit mode) — keep highlight until sheet dismisses.
            Logger.log(level: .info, category: logCategory, message: "Selected routine for viewing: \(selectedRoutine.title)")
            presentItemDetail(for: selectedRoutine, from: cell)
            return
        }
        
        if let contactItem = selectedItem as? ContactItem {
            if isEditingMode {
                HapticsHelper.superLightHaptic()
                if selectedContacts.contains(contactItem) {
                    selectedContacts.remove(contactItem)
                    collectionView.deselectItem(at: indexPath, animated: true)
                } else {
                    if !canAddMoreSelections() {
                        showSelectionLimitAlert()
                        collectionView.deselectItem(at: indexPath, animated: true)
                        return
                    }
                    selectedContacts.insert(contactItem)
                }
                if isEditOnlyMode {
                    notifySelectNestItemsDelegate()
                    updateSelectAllButtonAfterSelectionChange()
                }
                updateContactCellSelection(for: contactItem)
                return
            }
            presentItemDetail(for: contactItem, from: cell)
            return
        }
        
        if let unknown = selectedItem as? UnknownItem {
            if isEditingMode {
                HapticsHelper.superLightHaptic()
                if selectedUnknownItems.contains(unknown) {
                    selectedUnknownItems.remove(unknown)
                    collectionView.deselectItem(at: indexPath, animated: true)
                } else {
                    if !canAddMoreSelections() {
                        showSelectionLimitAlert()
                        collectionView.deselectItem(at: indexPath, animated: true)
                        return
                    }
                    selectedUnknownItems.insert(unknown)
                }
                if isEditOnlyMode {
                    notifySelectNestItemsDelegate()
                    updateSelectAllButtonAfterSelectionChange()
                }
                updateUnknownCellSelection(for: unknown)
                return
            }
            presentItemDetail(for: unknown, from: cell)
            return
        }
        
        // Handle entry selection
        guard let selectedNote = selectedItem as? NoteItem else { return }
        
        // If in edit mode, toggle selection
        if isEditingMode {
            // Add haptic feedback for selection
            HapticsHelper.superLightHaptic()
            
            if selectedNotes.contains(selectedNote) {
                selectedNotes.remove(selectedNote)
                collectionView.deselectItem(at: indexPath, animated: true)
            } else {
                // Check selection limit before adding
                if !canAddMoreSelections() {
                    showSelectionLimitAlert()
                    collectionView.deselectItem(at: indexPath, animated: true)
                    return
                }
                selectedNotes.insert(selectedNote)
            }
            
            // Notify delegate in edit-only mode
            if isEditOnlyMode {
                notifySelectNestItemsDelegate()
                refreshFolderSelectionCounts()
                updateSelectAllButtonAfterSelectionChange()
            }
            
            // Update the cell appearance using diffable data source
            updateCellSelection(for: selectedNote)
            return
        }
        
        // Normal entry selection (not in edit mode) — keep highlight until sheet dismisses.
        Logger.log(level: .info, category: logCategory, message: "Selected entry for editing: \(selectedNote.title)")
        presentItemDetail(for: selectedNote, from: cell)
    }

    /// Presents item detail while leaving the tapped cell selected for context;
    /// clears that highlight when the sheet finishes dismissing.
    private func presentItemDetail(for item: any BaseItem, from cell: UICollectionViewCell) {
        let cellFrame = collectionView.convert(cell.frame, to: nil)
        let itemId = item.id
        NestItemDetailRouter.presentDetail(
            for: item,
            from: self,
            nestItemRepository: nestItemRepository,
            category: category,
            sourceFrame: cellFrame,
            placeListDelegate: self,
            noteDelegate: self,
            routineDelegate: self,
            contactDelegate: self,
            onDismiss: { [weak self] in
                self?.clearContextualItemHighlight(forItemId: itemId)
            }
        )
    }

    private func clearContextualItemHighlight(forItemId itemId: String) {
        guard !isEditingMode else { return }
        let selectedIndexPaths = collectionView.indexPathsForSelectedItems ?? []
        for indexPath in selectedIndexPaths {
            guard let selected = dataSource.itemIdentifier(for: indexPath) else { continue }
            let selectedId: String?
            switch selected {
            case let note as NoteItem: selectedId = note.id
            case let place as PlaceItem: selectedId = place.id
            case let routine as RoutineItem: selectedId = routine.id
            case let contact as ContactItem: selectedId = contact.id
            case let unknown as UnknownItem: selectedId = unknown.id
            default: selectedId = nil
            }
            if selectedId == itemId {
                collectionView.deselectItem(at: indexPath, animated: true)
                return
            }
        }
        // Snapshot refresh after save can reshuffle identity lookup; clear any leftover browse selection.
        for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
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
                    notifySelectNestItemsDelegate()
                    updateSelectAllButtonAfterSelectionChange()
                }
                return
            }
            
            // Handle routine deselection
            if let selectedRoutine = selectedItem as? RoutineItem {
                selectedRoutines.remove(selectedRoutine)
                
                // Notify delegate in edit-only mode
                if isEditOnlyMode {
                    notifySelectNestItemsDelegate()
                }
                
                updateRoutineCellSelection(for: selectedRoutine)
                updateSelectAllButtonAfterSelectionChange()
                return
            }
            
            if let contactItem = selectedItem as? ContactItem {
                selectedContacts.remove(contactItem)
                if isEditOnlyMode { notifySelectNestItemsDelegate() }
                updateSelectAllButtonAfterSelectionChange()
                updateContactCellSelection(for: contactItem)
                return
            }
            
            if let unknown = selectedItem as? UnknownItem {
                selectedUnknownItems.remove(unknown)
                if isEditOnlyMode { notifySelectNestItemsDelegate() }
                updateSelectAllButtonAfterSelectionChange()
                updateUnknownCellSelection(for: unknown)
                return
            }
            
            // Handle entry deselection
            if let selectedNote = selectedItem as? NoteItem {
                selectedNotes.remove(selectedNote)
                
                // Notify delegate in edit-only mode
                if isEditOnlyMode {
                    notifySelectNestItemsDelegate()
                    refreshFolderSelectionCounts()
                    updateSelectAllButtonAfterSelectionChange()
                }
                
                // Update the cell appearance using diffable data source
                updateCellSelection(for: selectedNote)
            }
        }
    }
    
    // MARK: - Context Menu Support
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        // Disable during selection flows; only nest owners can delete
        guard !isEditOnlyMode, !isEditingMode, allowsNestEdits,
              let item = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }

        let menuTitle: String
        let deleteAction: UIAction

        if let folderData = item as? FolderData {
            menuTitle = folderData.title
            deleteAction = UIAction(
                title: "Delete Folder",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.deleteFolderWithConfirmation(folderData)
            }
        } else if let entry = item as? NoteItem {
            menuTitle = entry.title
            deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.deleteEntryWithConfirmation(entry)
            }
        } else if let place = item as? PlaceItem {
            menuTitle = place.alias ?? place.title
            deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.deletePlaceWithConfirmation(place)
            }
        } else if let routine = item as? RoutineItem {
            menuTitle = routine.title
            deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.deleteRoutineWithConfirmation(routine)
            }
        } else if let contact = item as? ContactItem {
            menuTitle = contact.title
            deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.deleteContactWithConfirmation(contact)
            }
        } else if let unknown = item as? UnknownItem {
            menuTitle = unknown.title
            deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.deleteUnknownItemWithConfirmation(unknown)
            }
        } else {
            return nil
        }

        contextMenuIndexPath = indexPath

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(title: menuTitle, children: [deleteAction])
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        contextMenuTargetedPreview(in: collectionView)
    }

    func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        contextMenuTargetedPreview(in: collectionView)
    }

    private func contextMenuTargetedPreview(in collectionView: UICollectionView) -> UITargetedPreview? {
        guard let indexPath = contextMenuIndexPath,
              let cell = collectionView.cellForItem(at: indexPath) else {
            return nil
        }

        if let folderCell = cell as? FolderCollectionViewCell {
            let parameters = UIPreviewParameters()
            let customPath = FolderShape.backFolderPath(in: folderCell.bounds)
            parameters.visiblePath = UIBezierPath(cgPath: customPath)
            parameters.backgroundColor = .clear
            return UITargetedPreview(view: folderCell, parameters: parameters)
        }

        if let waterfallCell = cell as? WaterfallGridCell {
            return waterfallCell.contextMenuTargetedPreview()
        }

        return nil
    }
    
    func collectionView(_ collectionView: UICollectionView, willEndContextMenuInteraction configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        contextMenuIndexPath = nil
    }
}

// Add delegate conformance
extension NestCategoryViewController: NoteDetailViewControllerDelegate {
    func noteDetailViewController(didSaveNote entry: NoteItem?) {
        if let entry = entry {
            // Handle save/update
            Logger.log(level: .info, category: logCategory, message: "Delegate received saved entry: \(entry.title)")
            
            // Invalidate cache so parent views will refresh
            if let nestService = nestItemRepository as? NestService {
                nestService.invalidateItemsCache()
            }
            
            if notes.contains(where: { $0.id == entry.id }) {
                updateLocalEntry(entry)
            } else {
                addLocalEntry(entry)
                refreshEmptyState()
                updateFilterView()
            }
        }
    }
    
    func noteDetailViewController(didDeleteNote entry: NoteItem) {
        Logger.log(level: .info, category: logCategory, message: "Delegate received deletion")
        
        if let index = notes.firstIndex(where: { $0.id == entry.id }) {
            // Remove from local array (this will trigger didSet and applySnapshot)
            notes.remove(at: index)
            
            // No need to manually apply snapshot here since entries.didSet will handle it
            // The didSet will create a proper snapshot with correct sections
            
            showToast(text: "Note Deleted")
            refreshEmptyState()
        }
    }
}

extension NestCategoryViewController: ContactDetailViewControllerDelegate {
    func contactDetailViewController(_ controller: ContactDetailViewController, didSave contact: ContactItem) {
        if let nestService = nestItemRepository as? NestService {
            nestService.invalidateItemsCache()
        }

        if contacts.contains(where: { $0.id == contact.id }) {
            updateLocalContact(contact)
        } else {
            shouldApplySnapshotAutomatically = false
            contacts.append(contact)
            shouldApplySnapshotAutomatically = true
            applySnapshot(animated: true)
            refreshEmptyState()
            updateFilterView()
        }
        showToast(text: "Contact saved")
    }

    func contactDetailViewController(_ controller: ContactDetailViewController, didDelete contact: ContactItem) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            selectedContacts.remove(contact)
            contacts.remove(at: index)
            showToast(text: "Contact deleted")
            refreshEmptyState()
        }
    }
}

// Add this extension to help determine cell size
extension NoteItem {
    var shouldUseHalfWidthCell: Bool {
        return title.count < 15 && content.count < 15
    }
}

// Add this delegate conformance:
extension NestCategoryViewController: CategoryDetailViewControllerDelegate {
    func categoryDetailViewController(_ controller: CategoryDetailViewController, didSaveCategory category: String?, withIcon icon: String?) {
        guard let categoryName = category,
              let iconName = icon,
              let nestService = nestItemRepository as? NestService else {
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
                    self.showToast(text: error.localizedDescription, sentiment: .negative)
                }
            }
        }
    }
    
    // Method to get all selected item IDs across all types
    func getAllSelectedItemIds() -> [String] {
        let entryIds = selectedNotes.map { $0.id }
        let placeIds = selectedPlaces.map { $0.id }
        let routineIds = selectedRoutines.map { $0.id }
        let contactIds = selectedContacts.map { $0.id }
        let unknownIds = selectedUnknownItems.map { $0.id }
        return entryIds + placeIds + routineIds + contactIds + unknownIds
    }
    
    // Set selection limit for this view controller
    func setSelectionLimit(_ limit: Int?, offersUpgrade: Bool = true) {
        selectionLimit = limit
        selectionLimitOffersUpgrade = offersUpgrade
    }

    func setExcludedItemIds(_ ids: Set<String>) {
        excludedItemIds = ids
    }

    func setHidesSelectAllButton(_ hides: Bool) {
        hidesSelectAllButton = hides
    }
    
    // Helper method to get current total selections across all types
    private func getCurrentTotalSelections() -> Int {
        selectedNotes.count + selectedPlaces.count + selectedRoutines.count
            + selectedContacts.count + selectedUnknownItems.count
    }
    
    // Helper method to check if adding more selections would exceed the limit
    private func canAddMoreSelections(_ count: Int = 1) -> Bool {
        guard let limit = selectionLimit else { return true }
        return getCurrentTotalSelections() + count <= limit
    }
    
    // Show an alert when selection limit is reached
    private func showSelectionLimitAlert() {
        if !selectionLimitOffersUpgrade, let limit = selectionLimit {
            let alert = UIAlertController(
                title: "Selection Limit Reached",
                message: "You can attach up to \(limit) items.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

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
}

// Add delegate conformance for empty state view
extension NestCategoryViewController: NNEmptyStateViewDelegate {
    func emptyStateView(_ emptyStateView: NNEmptyStateView, didTapActionWithTag tag: Int) {
        showItemSuggestions()
    }
    
    func emptyStateViewDidTapActionButton(_ emptyStateView: NNEmptyStateView) {
        // Don't handle action button tap in edit-only mode
        guard !isEditOnlyMode else { return }
        
        print("Empty state tapped:")
        // Show the create sheet for nest owners, including demo (saves are blocked).
        guard showsOwnerChrome else { return }
        
        // Use the same action as the add button
        addButtonTapped()
    }
}

// Add extension to implement the CommonNotesViewControllerDelegate
extension NestCategoryViewController: CommonNotesViewControllerDelegate {
    func commonNotesViewController(didSelectNote entry: NoteItem) {
        // Show the entry detail with this controller as the delegate
        let cellFrame = view.frame  // We don't have a cell frame since we're coming from a different view
        let isReadOnly = !(allowsNestEdits)
        
        let editEntryVC = NoteDetailViewController(
            category: entry.category,
            entry: entry,
            sourceFrame: cellFrame,
            isReadOnly: isReadOnly
        )
        editEntryVC.noteDelegate = self
        present(editEntryVC, animated: true)
    }
    
    func showUpgradePrompt() {
        showEntryLimitUpgradePrompt()
    }
}

// MARK: - CommonItemsViewControllerDelegate
extension NestCategoryViewController: CommonItemsViewControllerDelegate {
    func commonItemsViewController(_ controller: CommonItemsViewController, didSelectNote entry: CommonNote) {
        // Only allow creating entries for nest owners
        guard allowsNestEdits else { return }
        Logger.log(level: .info, category: logCategory, message: "Selected common entry: \(entry.title)")

        let editEntryVC = NoteDetailViewController(
            category: self.category,
            title: entry.title,
            content: entry.content
        )
        editEntryVC.noteDelegate = self
        self.dismiss(animated: true) {
            self.present(editEntryVC, animated: true)
        }
    }

    func commonItemsViewController(_ controller: CommonItemsViewController, didSelectPlace place: CommonPlace) {
        // Only allow creating places for nest owners
        guard allowsNestEdits else { return }

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
        guard allowsNestEdits else { return }

        let routineDetailVC = RoutineDetailViewController(
            category: self.category,
            routineName: routine.name,
            suggestedActions: routine.actions
        )
        routineDetailVC.routineDelegate = self
        self.dismiss(animated: true) {
            self.present(routineDetailVC, animated: true)
        }
    }

    func commonItemsViewController(_ controller: CommonItemsViewController, didSelectContact contact: CommonContact) {
        guard allowsNestEdits else { return }

        let contactDetailVC = ContactDetailViewController(
            category: self.category,
            title: contact.title,
            phoneNumber: contact.phoneNumber
        )
        contactDetailVC.contactDelegate = self
        self.dismiss(animated: true) {
            self.present(contactDetailVC, animated: true)
        }
    }
}

// MARK: - SelectFolderViewControllerDelegate
extension NestCategoryViewController: SelectFolderViewControllerDelegate {
    func selectFolderViewController(_ controller: SelectFolderViewController, didSelectFolder folder: String) {
        Task {
            do {
                guard let nestService = nestItemRepository as? NestService else {
                    await MainActor.run {
                        controller.dismiss(animated: true)
                        self.showToast(text: "Only nest owners can move items")
                    }
                    return
                }
                
                let selectedNotesArray = Array(selectedNotes)
                let selectedPlacesArray = Array(selectedPlaces)
                
                // Move each selected entry to the new folder
                for entry in selectedNotesArray {
                    var updatedEntry = entry
                    updatedEntry.category = folder
                    try await nestService.updateNote(updatedEntry)
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
                    self.selectedNotes.removeAll()
                    self.selectedPlaces.removeAll()
                    self.selectedRoutines.removeAll()
                    self.selectedContacts.removeAll()
                    self.selectedUnknownItems.removeAll()
                    
                    if self.isEditOnlyMode {
                        self.notifySelectNestItemsDelegate()
                    }
                    
                    let totalCount = selectedNotesArray.count + selectedPlacesArray.count
                    let itemText: String
                    
                    if selectedNotesArray.count > 0 && selectedPlacesArray.count > 0 {
                        itemText = totalCount == 1 ? "item" : "items"
                    } else if selectedNotesArray.count > 0 {
                        itemText = selectedNotesArray.count == 1 ? "note" : "notes"
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
            // Handle save/update - exact same pattern as notes
            Logger.log(level: .info, category: logCategory, message: "Delegate received saved routine: \(routine.title)")
            
            // Invalidate cache so parent views will refresh
            if let nestService = nestItemRepository as? NestService {
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
        // Handle save/update - exact same pattern as notes
        Logger.log(level: .info, category: logCategory, message: "Delegate received saved place: \(place.alias ?? "Unnamed")")
        
        // Invalidate cache so parent views will refresh
        if let nestService = nestItemRepository as? NestService {
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
                    self.notifySelectNestItemsDelegate()
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

// MARK: - Waterfall Grid Layout

private extension NestCategoryViewController {
    static let waterfallFolderCellHeight: CGFloat = 144

    /// `reconfigureItems` refreshes cell content without resizing; clear cached
    /// heights and invalidate so waterfall cards grow/shrink with edits.
    func invalidateWaterfallLayoutAfterContentChange() {
        guard itemDisplayLayout == .waterfallGrid else { return }
        waterfallHeightCache.removeAll()
        waterfallLayout?.invalidateLayout()
        collectionView.layoutIfNeeded()
    }

    func dequeueWaterfallCell(
        in collectionView: UICollectionView,
        for item: AnyHashable,
        section: Section,
        at indexPath: IndexPath
    ) -> UICollectionViewCell {
        if section == .folders, let folderData = item as? FolderData {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: FolderCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as! FolderCollectionViewCell
            cell.configure(with: folderData)
            return cell
        }

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: WaterfallGridCell.reuseIdentifier,
            for: indexPath
        ) as! WaterfallGridCell

        switch section {
        case .folders:
            break
        case .places:
            if let place = item as? PlaceItem {
                let placeholder = DemoNestSeed.usesMapPlaceholder(for: place)
                    ? DemoNestSeed.placeholderImage(for: place)
                    : nil
                cell.configure(
                    title: place.alias ?? place.title,
                    content: place.address,
                    thumbnail: placeholder,
                    layoutStyle: .place,
                    showsPlaceThumbnail: true,
                    attachmentCount: place.attachmentIds.count,
                    isEditMode: isEditingMode,
                    isSelected: selectedPlaces.contains(place)
                )
                if placeholder == nil {
                    loadPlaceThumbnail(for: place, into: cell)
                }
            }
        case .routines:
            if let routine = item as? RoutineItem {
                cell.configure(
                    title: routine.title,
                    content: Self.routinePreviewLabel(for: routine),
                    attachmentCount: routine.attachmentIds.count,
                    isEditMode: isEditingMode,
                    isSelected: selectedRoutines.contains(routine)
                )
            }
        case .contacts:
            if let contact = item as? ContactItem {
                cell.configure(
                    title: contact.title,
                    content: contact.content,
                    isEditMode: isEditingMode,
                    isSelected: selectedContacts.contains(contact)
                )
            }
        case .unknownItems:
            if let unknown = item as? UnknownItem {
                cell.configure(
                    title: unknown.title,
                    content: "Type: \(unknown.originalTypeString)",
                    isEditMode: isEditingMode,
                    isSelected: selectedUnknownItems.contains(unknown)
                )
            }
        case .codes, .other:
            if let entry = item as? NoteItem {
                cell.configure(
                    title: entry.title,
                    content: entry.content,
                    contentLineLimit: WaterfallGridCell.entryContentLineLimit,
                    attachmentCount: entry.attachmentIds.count,
                    isEditMode: isEditingMode,
                    isSelected: selectedNotes.contains(entry)
                )
            }
        }

        return cell
    }

    func loadPlaceThumbnail(for place: PlaceItem, into cell: WaterfallGridCell) {
        guard place.thumbnailURLs != nil || DemoNestSeed.usesMapPlaceholder(for: place) else { return }

        Task {
            do {
                let image = try await nestItemRepository.loadImages(for: place)
                await MainActor.run {
                    cell.configure(
                        title: place.alias ?? place.title,
                        content: place.address,
                        thumbnail: image,
                        layoutStyle: .place,
                        showsPlaceThumbnail: true,
                        attachmentCount: place.attachmentIds.count,
                        isEditMode: isEditingMode,
                        isSelected: selectedPlaces.contains(place)
                    )
                }
            } catch {
                Logger.log(
                    level: .error,
                    category: logCategory,
                    message: "Failed to load waterfall place thumbnail: \(error.localizedDescription)"
                )
            }
        }
    }

    static func routinePreviewLabel(for routine: RoutineItem) -> String {
        WaterfallGridCell.routinePreviewText(
            for: routine.routineActions,
            emptyFallback: routine.frequency ?? "Routine"
        )
    }

    func configureWaterfallSizingCell(for item: AnyHashable, section: Section, columnWidth: CGFloat) {
        waterfallSizingCell.prepareForReuse()

        switch section {
        case .folders:
            break
        case .places:
            if let place = item as? PlaceItem {
                let showsThumb = place.thumbnailURLs != nil || DemoNestSeed.usesMapPlaceholder(for: place)
                waterfallSizingCell.configure(
                    title: place.alias ?? place.title,
                    content: place.address,
                    thumbnail: showsThumb ? UIImage() : nil,
                    layoutStyle: .place,
                    showsPlaceThumbnail: true,
                    attachmentCount: place.attachmentIds.count
                )
            }
        case .routines:
            if let routine = item as? RoutineItem {
                waterfallSizingCell.configure(
                    title: routine.title,
                    content: Self.routinePreviewLabel(for: routine),
                    attachmentCount: routine.attachmentIds.count
                )
            }
        case .contacts:
            if let contact = item as? ContactItem {
                waterfallSizingCell.configure(
                    title: contact.title,
                    content: contact.content
                )
            }
        case .unknownItems:
            if let unknown = item as? UnknownItem {
                waterfallSizingCell.configure(
                    title: unknown.title,
                    content: "Type: \(unknown.originalTypeString)"
                )
            }
        case .codes, .other:
            if let entry = item as? NoteItem {
                waterfallSizingCell.configure(
                    title: entry.title,
                    content: entry.content,
                    contentLineLimit: WaterfallGridCell.entryContentLineLimit,
                    attachmentCount: entry.attachmentIds.count
                )
            }
        }

        waterfallSizingCell.updateThumbnailHeight(forColumnWidth: columnWidth)
    }

    func measuredWaterfallHeight(for indexPath: IndexPath, columnWidth: CGFloat) -> CGFloat {
        if let cached = waterfallHeightCache[indexPath] {
            return cached
        }

        guard let item = dataSource.itemIdentifier(for: indexPath),
              indexPath.section < sectionOrder.count else {
            return 120
        }

        let section = sectionOrder[indexPath.section]
        if section == .folders {
            waterfallHeightCache[indexPath] = Self.waterfallFolderCellHeight
            return Self.waterfallFolderCellHeight
        }

        configureWaterfallSizingCell(for: item, section: section, columnWidth: columnWidth)

        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.size = CGSize(width: columnWidth, height: 0)
        let fitted = waterfallSizingCell.preferredLayoutAttributesFitting(attributes)
        waterfallHeightCache[indexPath] = fitted.size.height
        return fitted.size.height
    }

    func shouldShowWaterfallHeader(for section: Section) -> Bool {
        switch section {
        case .codes:
            return true
        case .other:
            return !sectionOrder.contains(.codes)
        default:
            return true
        }
    }

    func waterfallHeaderTitle(for section: Section) -> String {
        switch section {
        case .folders: return "FOLDERS"
        case .codes, .other: return "NOTES"
        case .places: return "PLACES"
        case .routines: return "ROUTINES"
        case .contacts: return "CONTACTS"
        case .unknownItems: return "UNSUPPORTED"
        }
    }
}

extension NestCategoryViewController: WaterfallCollectionLayoutDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        layout: WaterfallCollectionLayout,
        heightForItemAt indexPath: IndexPath,
        columnWidth: CGFloat
    ) -> CGFloat {
        measuredWaterfallHeight(for: indexPath, columnWidth: columnWidth)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout: WaterfallCollectionLayout,
        shouldShowHeaderForSection section: Int
    ) -> Bool {
        guard section < sectionOrder.count else { return false }
        return shouldShowWaterfallHeader(for: sectionOrder[section])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout: WaterfallCollectionLayout,
        heightForHeaderInSection section: Int
    ) -> CGFloat {
        Self.waterfallSectionHeaderHeight
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
    static let waterfallSectionHeaderHeight: CGFloat = 36
    static let sectionHeaderLabelBottomInset: CGFloat = 12
    /// Section inset + card content inset so headers align with text inside waterfall cards.
    static let waterfallSectionHeaderLeadingInset: CGFloat = 32

    // Section Header size
    static let headerSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(12)
    )
}
// MARK: - PaywallViewControllerDelegate
extension NestCategoryViewController {
    func paywallViewController(_ controller: PaywallViewController, didFinishPurchasingWith customerInfo: CustomerInfo) {
        TikTokTracker.shared.trackSubscribe()
        // Purchase successful - user is now Pro, update selection limit
        selectionLimit = nil
        
        // Update the selection counter view if we're in edit-only mode
        if isEditOnlyMode {
        }
        
        controller.dismiss(animated: true)
    }
    
    func paywallViewControllerWasDismissed(_ controller: PaywallViewController) {
        // Paywall was dismissed without purchase - no action needed
    }
}
