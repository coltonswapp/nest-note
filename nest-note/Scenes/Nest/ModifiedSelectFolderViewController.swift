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
    private let nestItemRepository: NestItemRepository
    weak var delegate: ModifiedSelectFolderViewControllerDelegate?
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, FolderItem>!
    private var selectionCounterView: SelectItemsCountView!
    private var selectAllBarButtonItem: UIBarButtonItem?
    
    // Selected items tab
    private var segmentedControl: UISegmentedControl!
    private var selectedItemsCollectionView: UICollectionView!
    private var selectedItemsDataSource: UICollectionViewDiffableDataSource<SelectedSection, SelectedItemInfo>!
    private var cachedSelectedItems: [SelectedItemInfo] = []
    
    private var categories: [NestCategory] = []
    private var pendingUpdateNeeded = false
    private var folderItemCounts: [String: Int] = [:]
    private var preloadedAllItems: [BaseItem]? = nil
    
    var onContinueTapped: (([String]) -> Void)?
    
    /// When true, the Selected segment is shown on first layout (e.g. opening from "view more" in session editor).
    var showsSelectedTabInitially = false
    
    /// When true, Continue stays available after clearing all items (session edit flow).
    var allowsEmptySelection = false
    
    /// When true, shows an instructional title/subtitle and keeps Continue always visible (session creation step).
    var showsCreationHeader = false

    /// When set, hard-caps selection (e.g. attachments max 3) and overrides the pro/free limit.
    var maxSelectionCount: Int? = nil

    /// Item IDs that cannot be selected (e.g. the host entry/routine when picking attachments).
    var excludedItemIds: Set<String> = []

    /// When true, omits the Select All / Clear All bar button (attachment picker).
    var hidesSelectAllButton = false
    
    private var currentSelectedIds: [String] = []
    private var allSelectableItemIds: [String] = []
    private var initialPeakSelectionCount = 0
    
    private var selectionLimit: Int? = nil
    private var isProUser: Bool = false
    
    private static let creationHeaderElementKind = "SelectEntriesCreationHeader"
    
    // MARK: - PaywallPresentable
    var proFeature: ProFeature {
        return .unlimitedNotes
    }
    
    enum Section: Int, CaseIterable {
        case folders
    }
    
    enum SelectedSection: Int, CaseIterable {
        case contacts
        case notes
        case places
        case routines
        case other
        
        /// Uppercase labels, matching `NestCategoryViewController` section headers.
        var nestStyleHeaderTitle: String {
            switch self {
            case .contacts: return "CONTACTS"
            case .notes:  return "NOTES"
            case .places:   return "PLACES"
            case .routines: return "ROUTINES"
            case .other:    return "OTHER"
            }
        }
        
        init(itemType: ItemType) {
            switch itemType {
            case .contact:         self = .contacts
            case .entry:           self = .notes
            case .place:           self = .places
            case .routine:         self = .routines
            case .unknownDocument: self = .other
            }
        }
    }
    
    struct SelectedItemInfo: Hashable {
        let id: String
        let title: String
        let type: ItemType
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
    
    init(nestItemRepository: NestItemRepository) {
        self.nestItemRepository = nestItemRepository
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupSegmentedControl()
        setupCollectionView()
        setupSelectedItemsCollectionView()
        configureDataSource()
        configureSelectedItemsDataSource()
        setupSelectionCounterView()
        setupNavigationItems()
        
        collectionView.delegate = self
        selectedItemsCollectionView.delegate = self
        
        updateSelectionCounter()
        if showsSelectedTabInitially {
            showsSelectedTabInitially = false
            segmentedControl.selectedSegmentIndex = 1
            segmentChanged(segmentedControl)
        }
        
        Task { 
            await checkProStatusAndSetLimit()
            await initialLoad() 
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isPushedOntoExistingNavigationStack {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if isMovingFromParent || isBeingDismissed {
            removeSelectionCounterView()
        }
        
        guard isPushedOntoExistingNavigationStack, isMovingFromParent else { return }
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    deinit {
        removeSelectionCounterView()
    }
    
    private var isPushedOntoExistingNavigationStack: Bool {
        guard let navigationController else { return false }
        return navigationController.viewControllers.first != self
    }
    
    // MARK: - Continue Loading
    
    func startContinueLoading() {
        selectionCounterView?.startLoading()
    }
    
    func stopContinueLoading(
        withSuccess success: Bool? = nil,
        restoreTitle: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        selectionCounterView?.stopLoading(
            withSuccess: success,
            restoreTitle: restoreTitle,
            completion: completion
        )
    }
    
    func animateContinueOff(completion: (() -> Void)? = nil) {
        guard let selectionCounterView else {
            completion?()
            return
        }
        
        selectionCounterView.animateOff { [weak self] in
            self?.removeSelectionCounterView()
            completion?()
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
        if let maxSelectionCount {
            selectionLimit = maxSelectionCount
            await MainActor.run {
                selectionCounterView?.selectionLimit = selectionLimit
            }
            return
        }

        // Use the same pro status checking as other features for consistency
        isProUser = await SubscriptionService.shared.canUseFullFeatures()
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
        if let maxSelectionCount {
            let alert = UIAlertController(
                title: "Selection Limit Reached",
                message: "You can attach up to \(maxSelectionCount) items.",
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

    // Consolidated initial load to fetch categories and all items once
    private func initialLoad() async {
        do {
            async let categoriesTask = nestItemRepository.fetchCategories()
            // Use preloaded snapshot if available
            let allItems = try await { () -> [BaseItem] in
                if let items = self.preloadedAllItems { return items }
                return try await self.nestItemRepository.fetchAllItems()
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

            let ids = allItems
                .map { $0.id }
                .filter { !self.excludedItemIds.contains($0) }

            await MainActor.run {
                self.categories = fetchedCategories
                self.itemFolderMapping = mapping
                self.folderItemCounts = counts
                self.allSelectableItemIds = ids
                // Drop any excluded IDs that were pre-selected
                self.currentSelectedIds = self.currentSelectedIds.filter { !self.excludedItemIds.contains($0) }
                self.applySnapshot()
                self.updateSelectAllButtonTitle()
                self.updateSelectionCounter()
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
                return try await self.nestItemRepository.fetchAllItems()
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
        currentSelectedIds = ids.filter { !excludedItemIds.contains($0) }
        if let maxSelectionCount {
            currentSelectedIds = Array(currentSelectedIds.prefix(maxSelectionCount))
        }
        initialPeakSelectionCount = currentSelectedIds.count
        updateSelectionCounter()
    }
    
    // Method to update current selections (called by NestCategoryViewController)
    func updateCurrentSelectedIds(_ ids: [String]) {
        let filtered = ids.filter { !excludedItemIds.contains($0) }

        // Check selection limit
        if let limit = selectionLimit {
            if filtered.count > limit {
                // Limit exceeded, show alert and take only the allowed number
                showSelectionLimitAlert()
                currentSelectedIds = Array(filtered.prefix(limit))
            } else {
                currentSelectedIds = filtered
            }
        } else {
            // No limit (pro user)
            currentSelectedIds = filtered
        }
        
        updateSelectionCounter()
    }
    
    /// Current selected items by type (for restoring in `NestCategoryViewController`).
    func getCurrentSelectedItems() async -> SelectedNestItems {
        do {
            let allItems = try await nestItemRepository.fetchAllItems()
            
            var selectedNotes: Set<NoteItem> = []
            var selectedPlaces: Set<PlaceItem> = []
            var selectedRoutines: Set<RoutineItem> = []
            var selectedContacts: Set<ContactItem> = []
            var selectedUnknown: Set<UnknownItem> = []
            
            for item in allItems {
                if currentSelectedIds.contains(item.id) {
                    switch item.type {
                    case .entry:
                        if let entry = item as? NoteItem {
                            selectedNotes.insert(entry)
                        }
                    case .place:
                        if let place = item as? PlaceItem {
                            selectedPlaces.insert(place)
                        }
                    case .routine:
                        if let routine = item as? RoutineItem {
                            selectedRoutines.insert(routine)
                        }
                    case .contact:
                        if let contact = item as? ContactItem {
                            selectedContacts.insert(contact)
                        }
                    case .unknownDocument:
                        if let unknown = item as? UnknownItem {
                            selectedUnknown.insert(unknown)
                        }
                    }
                }
            }
            
            return SelectedNestItems(
                notes: selectedNotes,
                places: selectedPlaces,
                routines: selectedRoutines,
                contacts: selectedContacts,
                unknownItems: selectedUnknown
            )
        } catch {
            print("[ERROR] Failed to fetch items for restoration: \(error)")
            return SelectedNestItems()
        }
    }
    
    private func setupSelectionCounterView() {
        selectionCounterView = SelectItemsCountView()
        selectionCounterView.allowsEmptySelection = allowsEmptySelection
        selectionCounterView.alwaysShowsContinue = showsCreationHeader
        selectionCounterView.peakSelectionCount = initialPeakSelectionCount
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
    
    private func removeSelectionCounterView() {
        selectionCounterView?.removeFromSuperview()
        selectionCounterView = nil
    }
    
    private func setupNavigationItems() {
        if hidesSelectAllButton {
            selectAllBarButtonItem = nil
            // Keep any Cancel (or other) item that was already installed by the presenter.
            return
        }

        // Creation flow already has a Cancel-free back button; keep Select All on the right.
        // Edit sheet may already have a Cancel button — place Select All beside it when present.
        let button = UIBarButtonItem(title: "Select All", style: .plain, target: self, action: #selector(didTapSelectAll))
        selectAllBarButtonItem = button
        
        if let existingRight = navigationItem.rightBarButtonItem {
            navigationItem.rightBarButtonItems = [existingRight, button]
        } else {
            navigationItem.rightBarButtonItem = button
        }
        updateSelectAllButtonTitle()
    }
    
    private func updateSelectionCounter() {
        guard isViewLoaded else { 
            return 
        }
        
        selectionCounterView?.count = currentSelectedIds.count
        selectionCounterView?.peakSelectionCount = max(selectionCounterView?.peakSelectionCount ?? 0, currentSelectedIds.count)
        updateSegmentedControlTitle()
        
        if let navController = navigationController {
            navController.view.bringSubviewToFront(selectionCounterView)
        }
        updateSelectAllButtonTitle()
    }
    
    // Toggle Select All / Clear All button title based on selection state
    private func updateSelectAllButtonTitle() {
        guard !hidesSelectAllButton, selectAllBarButtonItem != nil else { return }
        if let control = segmentedControl, control.selectedSegmentIndex == 1 {
            selectAllBarButtonItem?.title = "Clear All"
            selectAllBarButtonItem?.isEnabled = !currentSelectedIds.isEmpty
            return
        }
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
                    .filter { !self.excludedItemIds.contains($0) }
                self.updateSelectAllButtonTitle()
            }
            return
        }
        // Fallback: fetch once (or reuse preloaded) and populate both mapping and IDs
        do {
            let allItems = try await { () -> [BaseItem] in
                if let items = self.preloadedAllItems { return items }
                return try await self.nestItemRepository.fetchAllItems()
            }()
            var mapping: [String: String] = [:]
            for item in allItems { mapping[item.id] = item.category }
            let ids = allItems
                .map { $0.id }
                .filter { !self.excludedItemIds.contains($0) }
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
        let isOnSelectedTab = segmentedControl.selectedSegmentIndex == 1
        
        if isOnSelectedTab {
            currentSelectedIds = []
            cachedSelectedItems = []
            applySelectedItemsSnapshot()
            updateSelectionCounter()
            selectAllBarButtonItem?.isEnabled = false
            return
        }
        
        let total = allSelectableItemIds.count
        let isAllSelected = total > 0 && currentSelectedIds.count >= total
        
        if isAllSelected {
            currentSelectedIds = []
        } else {
            if let limit = selectionLimit {
                let itemsToSelect = min(limit, total)
                currentSelectedIds = Array(allSelectableItemIds.prefix(itemsToSelect))
                if total > limit {
                    showSelectionLimitAlert()
                }
            } else {
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
    
    private func setupSegmentedControl() {
        segmentedControl = UISegmentedControl(items: ["Folders", "Selected (0)"])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        if showsCreationHeader {
            navigationItem.title = nil
            navigationItem.titleView = nil
        } else {
            navigationItem.titleView = segmentedControl
        }
    }
    
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        let showingSelected = sender.selectedSegmentIndex == 1
        collectionView.isHidden = showingSelected
        selectedItemsCollectionView.isHidden = !showingSelected
        
        if showingSelected {
            selectAllBarButtonItem?.title = "Clear All"
            selectAllBarButtonItem?.isEnabled = !currentSelectedIds.isEmpty
            loadSelectedItems()
        } else {
            updateSelectAllButtonTitle()
            applySnapshot()
        }
        
        reattachSegmentedControlToVisibleCollection()
    }
    
    private func reattachSegmentedControlToVisibleCollection() {
        guard showsCreationHeader else { return }
        
        let visibleCollection = segmentedControl.selectedSegmentIndex == 1
            ? selectedItemsCollectionView
            : collectionView
        
        visibleCollection?.layoutIfNeeded()
        
        if let header = visibleCollection?
            .visibleSupplementaryViews(ofKind: Self.creationHeaderElementKind)
            .first as? SelectNestItemsCreationHeaderView {
            configureCreationHeaderView(header)
        } else {
            // Header may not be visible yet; reload so the provider embeds the control.
            visibleCollection?.reloadData()
        }
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createFoldersLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
        collectionView.verticalScrollIndicatorInsets = collectionView.contentInset
        
        collectionView.register(FolderCollectionViewCell.self, forCellWithReuseIdentifier: FolderCollectionViewCell.reuseIdentifier)
        collectionView.register(
            SelectNestItemsCreationHeaderView.self,
            forSupplementaryViewOfKind: Self.creationHeaderElementKind,
            withReuseIdentifier: SelectNestItemsCreationHeaderView.reuseIdentifier
        )
        
        collectionView.allowsSelection = true
    }
    
    private func setupSelectedItemsCollectionView() {
        var listConfig = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        listConfig.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self,
                  let item = self.selectedItemsDataSource?.itemIdentifier(for: indexPath) else {
                return nil
            }
            let deleteAction = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, completion in
                self?.deselectItem(item)
                completion(true)
            }
            deleteAction.image = UIImage(systemName: "minus.circle.fill")
            return UISwipeActionsConfiguration(actions: [deleteAction])
        }
        listConfig.headerMode = .supplementary
        
        let layout = UICollectionViewCompositionalLayout.list(using: listConfig)
        
        if showsCreationHeader {
            var configuration = layout.configuration
            configuration.boundarySupplementaryItems = [makeCreationHeaderBoundaryItem()]
            layout.configuration = configuration
        }
        
        selectedItemsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        selectedItemsCollectionView.translatesAutoresizingMaskIntoConstraints = false
        selectedItemsCollectionView.backgroundColor = .systemGroupedBackground
        selectedItemsCollectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
        selectedItemsCollectionView.isHidden = true
        view.addSubview(selectedItemsCollectionView)
        
        NSLayoutConstraint.activate([
            selectedItemsCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
            selectedItemsCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            selectedItemsCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            selectedItemsCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        selectedItemsCollectionView.register(
            SelectNestItemsCreationHeaderView.self,
            forSupplementaryViewOfKind: Self.creationHeaderElementKind,
            withReuseIdentifier: SelectNestItemsCreationHeaderView.reuseIdentifier
        )
    }
    
    private func makeCreationHeaderBoundaryItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(140)
        )
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: Self.creationHeaderElementKind,
            alignment: .top
        )
    }
    
    private func createFoldersLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(144)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 8,
            leading: 10,
            bottom: 16,
            trailing: 10
        )
        
        let layout = UICollectionViewCompositionalLayout(section: section)
        
        if showsCreationHeader {
            var configuration = layout.configuration
            configuration.boundarySupplementaryItems = [makeCreationHeaderBoundaryItem()]
            layout.configuration = configuration
        }
        
        return layout
    }
    
    private func configureCreationHeaderView(_ headerView: SelectNestItemsCreationHeaderView) {
        headerView.configure(
            title: "Share with your sitter",
            subtitle: "Choose which nest items sitters can see during this session."
        )
        headerView.embedSegmentedControl(segmentedControl)
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
            self.configureSelectNestItemsCell(cell, with: folderData, selectedCount: item.selectedCount, totalCount: item.totalItemCount)
            return cell
        }
        
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self, kind == Self.creationHeaderElementKind else { return nil }
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: SelectNestItemsCreationHeaderView.reuseIdentifier,
                for: indexPath
            ) as! SelectNestItemsCreationHeaderView
            self.configureCreationHeaderView(header)
            return header
        }
    }
    
    private func configureSelectedItemsDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, SelectedItemInfo> { cell, indexPath, item in
            var content = cell.defaultContentConfiguration()
            content.text = item.title
            
            let iconName: String
            switch item.type {
            case .entry:           iconName = "doc.text"
            case .place:           iconName = "map"
            case .routine:         iconName = "arrow.triangle.2.circlepath"
            case .contact:         iconName = "person.crop.circle"
            case .unknownDocument: iconName = "doc.questionmark"
            }
            content.image = UIImage(systemName: iconName)
            content.imageProperties.tintColor = NNColors.primary
            
            cell.contentConfiguration = content
        }
        
        selectedItemsDataSource = UICollectionViewDiffableDataSource<SelectedSection, SelectedItemInfo>(
            collectionView: selectedItemsCollectionView
        ) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        
        let sectionHeaderRegistration = UICollectionView.SupplementaryRegistration<UICollectionReusableView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] headerView, elementKind, indexPath in
            guard let self,
                  let section = self.selectedItemsDataSource.sectionIdentifier(for: indexPath.section) else { return }
            
            headerView.subviews.forEach { $0.removeFromSuperview() }
            
            let itemCount = self.selectedItemsDataSource.snapshot().numberOfItems(inSection: section)
            guard itemCount > 0 else { return }
            
            let label = UILabel()
            label.text = section.nestStyleHeaderTitle
            label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            label.textColor = UIColor.secondaryLabel
            label.translatesAutoresizingMaskIntoConstraints = false
            
            headerView.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -16),
                label.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
                label.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8)
            ])
        }
        
        selectedItemsDataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self else { return nil }
            
            if kind == Self.creationHeaderElementKind {
                let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: SelectNestItemsCreationHeaderView.reuseIdentifier,
                    for: indexPath
                ) as! SelectNestItemsCreationHeaderView
                self.configureCreationHeaderView(header)
                return header
            }
            
            return collectionView.dequeueConfiguredReusableSupplementary(
                using: sectionHeaderRegistration,
                for: indexPath
            )
        }
    }
    
    private func loadSelectedItems() {
        Task {
            do {
                let allItems = try await nestItemRepository.fetchAllItems()
                let idSet = Set(currentSelectedIds)
                let infos: [SelectedItemInfo] = allItems
                    .filter { idSet.contains($0.id) }
                    .map { SelectedItemInfo(id: $0.id, title: $0.title, type: $0.type) }
                
                await MainActor.run {
                    self.cachedSelectedItems = infos
                    self.applySelectedItemsSnapshot()
                }
            } catch {
                Logger.log(level: .error, category: .general, message: "Failed to load selected items: \(error.localizedDescription)")
            }
        }
    }
    
    private func applySelectedItemsSnapshot() {
        guard selectedItemsDataSource != nil else { return }
        
        var snapshot = NSDiffableDataSourceSnapshot<SelectedSection, SelectedItemInfo>()
        
        let grouped = Dictionary(grouping: cachedSelectedItems) { SelectedSection(itemType: $0.type) }
        
        for section in SelectedSection.allCases {
            guard let items = grouped[section], !items.isEmpty else { continue }
            snapshot.appendSections([section])
            let sorted = items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            snapshot.appendItems(sorted, toSection: section)
        }
        
        // Keep at least one section so the scrolling creation header can layout when empty.
        if snapshot.sectionIdentifiers.isEmpty && showsCreationHeader {
            snapshot.appendSections([.notes])
        }
        
        selectedItemsDataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func deselectItem(_ item: SelectedItemInfo) {
        currentSelectedIds.removeAll { $0 == item.id }
        cachedSelectedItems.removeAll { $0.id == item.id }
        applySelectedItemsSnapshot()
        updateSelectionCounter()
        updateSegmentedControlTitle()
        applySnapshot()
    }
    
    private func updateSegmentedControlTitle() {
        let count = currentSelectedIds.count
        segmentedControl?.setTitle("Selected (\(count))", forSegmentAt: 1)
    }
    
    private func configureSelectNestItemsCell(_ cell: FolderCollectionViewCell, with data: FolderData, selectedCount: Int, totalCount: Int) {
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
                let fetchedCategories = try await nestItemRepository.fetchCategories()
                
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
        
        if collectionView === self.collectionView {
            guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
            delegate?.modifiedSelectFolderViewController(self, didSelectFolder: item.fullPath)
        }
    }
}

// MARK: - Protocols
protocol ModifiedSelectFolderViewControllerDelegate: AnyObject {
    func modifiedSelectFolderViewController(_ controller: ModifiedSelectFolderViewController, didSelectFolder folderPath: String)
}

protocol NestCategoryViewControllerSelectNestItemsDelegate: AnyObject {
    func nestCategoryViewController(_ controller: NestCategoryViewController, didUpdateSelectedItems items: SelectedNestItems)
    /// Provide current selected items so child folders can restore selection state
    func getCurrentSelectedItems() async -> SelectedNestItems
}

// MARK: - NestCategoryViewControllerSelectNestItemsDelegate
extension ModifiedSelectFolderViewController: NestCategoryViewControllerSelectNestItemsDelegate {
    func nestCategoryViewController(_ controller: NestCategoryViewController, didUpdateSelectedItems items: SelectedNestItems) {
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
        TikTokTracker.shared.trackSubscribe()
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
        TikTokTracker.shared.trackSubscribe()
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

// MARK: - Creation Header

private final class SelectNestItemsCreationHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "SelectNestItemsCreationHeaderView"
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let stackView = UIStackView()
    private var embeddedControl: UIView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        titleLabel.font = .h2
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        subtitleLabel.font = .bodyM
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.setCustomSpacing(16, after: subtitleLabel)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
    
    func embedSegmentedControl(_ control: UISegmentedControl) {
        if embeddedControl === control, control.superview === stackView {
            return
        }
        
        embeddedControl?.removeFromSuperview()
        control.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(control)
        control.heightAnchor.constraint(equalToConstant: 32).isActive = true
        embeddedControl = control
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // Keep the shared segmented control if it's still ours; otherwise clear the slot.
        if let embeddedControl, embeddedControl.superview !== stackView {
            self.embeddedControl = nil
        }
    }
}
