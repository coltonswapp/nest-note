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

class NestCategoryViewController: NNViewController, NestLoadable, CollectionViewLoadable, PaywallPresentable, PaywallViewControllerDelegate {
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
    private var dataSource: UICollectionViewDiffableDataSource<Section, BaseEntry>!
    private var addEntryButton: NNPrimaryLabeledButton!
    private var emptyStateView: NNEmptyStateView!
    
    enum Section: Int, CaseIterable {
        case codes, other
    }
    
    var entries: [BaseEntry] = [] {
        didSet {
            applySnapshot()
        }
    }
    
    init(category: String, entries: [BaseEntry] = [], entryRepository: EntryRepository, sessionVisibilityLevel: VisibilityLevel? = nil) {
        self.category = category
        self.entries = entries
        self.entryRepository = entryRepository
        // If it's a NestService (owner), they get comprehensive access. Otherwise use provided level or default to standard
        self.sessionVisibilityLevel = entryRepository is NestService ? .comprehensive : (sessionVisibilityLevel ?? .standard)
        super.init(nibName: nil, bundle: nil)
        title = category
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
        self.entries = groupedEntries[category] ?? []
        
        refreshEmptyState()
    }
    
    func refreshEmptyState() {
        // Show or hide empty state view based on entries count
        if entries.isEmpty {
            emptyStateView.isHidden = false
            view.bringSubviewToFront(emptyStateView)
        } else {
            emptyStateView.isHidden = true
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
        
        // Adjust content inset to prevent button obstruction
        let buttonHeight: CGFloat = 55
        let buttonPadding: CGFloat = 10
        let totalInset = buttonHeight + buttonPadding * 2
        collectionView.contentInset.bottom = totalInset
        collectionView.verticalScrollIndicatorInsets.bottom = totalInset
        
        // Register cells
        collectionView.register(AddressCell.self, forCellWithReuseIdentifier: AddressCell.reuseIdentifier)
        collectionView.register(FullWidthCell.self, forCellWithReuseIdentifier: FullWidthCell.reuseIdentifier)
        collectionView.register(HalfWidthCell.self, forCellWithReuseIdentifier: HalfWidthCell.reuseIdentifier)
        
        collectionView.allowsSelection = true
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            guard let self = self else { return nil }
            let section = Section(rawValue: sectionIndex)!
            
            // Only use different section layouts for Household category
            if self.category == "Household" {
                switch section {
                case .codes:
                    return self.createHalfWidthSection()
                case .other:
                    return self.createInsetGroupedSection()
                }
            } else {
                // Use full-width section for all items in other categories
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
        dataSource = UICollectionViewDiffableDataSource<Section, BaseEntry>(collectionView: collectionView) {
            [weak self] (collectionView, indexPath, entry) -> UICollectionViewCell? in
            guard let self = self else { return nil }
            
            let section = Section(rawValue: indexPath.section)!
            
            // Use different cell types only for Household category
            if self.category == "Household" {
                switch section {
                case .codes:
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HalfWidthCell.reuseIdentifier, for: indexPath) as! HalfWidthCell
                    cell.configure(
                        key: entry.title,
                        value: entry.content,
                        entryVisibility: entry.visibility,
                        sessionVisibility: self.sessionVisibilityLevel
                    )
                    return cell
                case .other:
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                    cell.configure(
                        key: entry.title,
                        value: entry.content,
                        entryVisibility: entry.visibility,
                        sessionVisibility: self.sessionVisibilityLevel
                    )
                    return cell
                }
            } else {
                // Use full-width cells for all items in other categories
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                cell.configure(
                    key: entry.title,
                    value: entry.content,
                    entryVisibility: entry.visibility,
                    sessionVisibility: self.sessionVisibilityLevel
                )
                return cell
            }
        }
    }
    
    private func createSnapshot() -> NSDiffableDataSourceSnapshot<Section, BaseEntry> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, BaseEntry>()
        snapshot.appendSections([.codes, .other])
        
        if category == "Household" {
            // Filter and sort entries based on cell type
            let codesEntries = entries.filter { $0.shouldUseHalfWidthCell }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            let otherEntries = entries.filter { !$0.shouldUseHalfWidthCell }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            
            snapshot.appendItems(codesEntries, toSection: .codes)
            snapshot.appendItems(otherEntries, toSection: .other)
        } else {
            // For non-Household categories, all entries go in .other section
            let sortedEntries = entries.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            snapshot.appendItems(sortedEntries, toSection: .other)
        }
        
        return snapshot
    }
    
    private func applySnapshot() {
        guard let dataSource = self.dataSource else { return }
        
        let snapshot = createSnapshot()
        
        dataSource.apply(snapshot, animatingDifferences: false)
        collectionView.layoutIfNeeded()
    }
    
    private var allEntries: [BaseEntry] {
        return entries
    }
    
    private func setupNavigationBar() {
        // Only show menu button for nest owners
        if entryRepository is NestService {
            let menu = UIMenu(title: "", children: [
                UIAction(title: "Entry Suggestions", image: UIImage(systemName: "sparkles")) { _ in
                    self.showEntrySuggestions()
                }
            ])
            
            let menuButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)
            navigationItem.rightBarButtonItems = [menuButton]
            navigationController?.navigationBar.tintColor = .label
        }
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
    
    // MARK: - Entry Limit Handling
    
    internal func showEntryLimitUpgradePrompt() {
        showUpgradePrompt(for: proFeature)
    }
    
    private func setupAddEntryButton() {
        // Only show add entry button for nest owners
        guard entryRepository is NestService else { return }
        
        addEntryButton = NNPrimaryLabeledButton(title: "New Entry", image: UIImage(systemName: "plus"))
        addEntryButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        addEntryButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
    }
    
    override func showTips() {
        // Only show suggestion tip for nest owners and if the menu button exists
        guard entryRepository is NestService, 
              let menuButton = navigationItem.rightBarButtonItems?.first,
              NNTipManager.shared.shouldShowTip(NestCategoryTips.entrySuggestionTip) else { return }
        
        // Show the tooltip anchored to the navigation bar menu button
        // Using .bottom edge to show tooltip below the navigation bar
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
                if !items.isEmpty && items.contains(where: { $0.id == entry.id }) {
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
        emptyStateView = NNEmptyStateView(
            icon: UIImage(systemName: "moon.zzz.fill"),
            title: "It's a little quiet in here",
            subtitle: "Entries for this category will appear here.",
            actionButtonTitle: entryRepository is NestService ? "Add an Entry" : nil
        )
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        emptyStateView.isUserInteractionEnabled = true
        emptyStateView.delegate = self
        
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

extension NestCategoryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let selectedEntry = dataSource.itemIdentifier(for: indexPath),
              let cell = collectionView.cellForItem(at: indexPath) else { return }
        
        // Check if user has access to this entry
        if !sessionVisibilityLevel.hasAccess(to: selectedEntry.visibility) {
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
    func categoryDetailViewController(_ controller: CategoryDetailViewController, didSaveCategory category: String?) {
        if let categoryName = category {
            // Here you would typically save the category to your data store
            Logger.log(level: .info, category: .nestService, message: "New category created: \(categoryName)")
            showToast(text: "Category Created: \(categoryName)")
        }
    }
}

// Add delegate conformance for empty state view
extension NestCategoryViewController: NNEmptyStateViewDelegate {
    func emptyStateViewDidTapActionButton(_ emptyStateView: NNEmptyStateView) {
        
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


