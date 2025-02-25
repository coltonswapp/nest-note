//
//  NestCategoryViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 10/6/24.
//

import UIKit

class NestCategoryViewController: UIViewController, NestLoadable {
    func handleLoadedData() {
        return
    }
    
    // Required by NestLoadable
    var loadingIndicator: UIActivityIndicatorView!
    var hasLoadedInitialData: Bool = false
    var refreshControl: UIRefreshControl!
    
    var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, BaseEntry>!
    private var suggestionButton: NNPrimaryLabeledButton!
    
    enum Section: Int, CaseIterable {
        case codes, other
    }
    
    var entries: [BaseEntry] = [] {
        didSet {
            applySnapshot()
        }
    }
    
    private let category: String
    
    init(category: String, entries: [BaseEntry] = []) {
        self.category = category
        self.entries = entries
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
        setupSuggestionButton()
        configureDataSource()
        
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
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
        
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
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
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
                    cell.configure(key: entry.title, value: entry.content)
                    return cell
                case .other:
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                    cell.configure(key: entry.title, value: entry.content)
                    return cell
                }
            } else {
                // Use full-width cells for all items in other categories
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                cell.configure(key: entry.title, value: entry.content)
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
        let addEntryButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonTapped))
        navigationItem.rightBarButtonItems = [addEntryButton]
    }
    
    @objc private func addButtonTapped() {
        let newEntryVC = EntryDetailViewController(category: category)
        newEntryVC.entryDelegate = self
        present(newEntryVC, animated: true)
    }
    
    private func setupSuggestionButton() {
        suggestionButton = NNPrimaryLabeledButton(title: "Looking for suggestions?", image: UIImage(systemName: "sparkles"))
        suggestionButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        suggestionButton.addTarget(self, action: #selector(suggestionButtonTapped), for: .touchUpInside)
    }
    
    @objc private func suggestionButtonTapped() {
        // Handle the suggestion button tap here
        print("Suggestion button tapped")
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
}

extension NestCategoryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let selectedEntry = dataSource.itemIdentifier(for: indexPath),
              let cell = collectionView.cellForItem(at: indexPath) else { return }
        
        Logger.log(level: .info, category: .nestService, message: "Selected entry for editing: \(selectedEntry.title)")
        
        let cellFrame = collectionView.convert(cell.frame, to: nil)
        
        let editEntryVC = EntryDetailViewController(
            category: category,
            entry: selectedEntry,
            sourceFrame: cellFrame
        )
        editEntryVC.entryDelegate = self
        present(editEntryVC, animated: true)
    }
}

// Add delegate conformance
extension NestCategoryViewController: EntryDetailViewControllerDelegate {
    func entryDetailViewController(_ controller: EntryDetailViewController, didSaveEntry entry: BaseEntry?) {
        if let entry = entry {
            // Handle save/update
            Logger.log(level: .info, category: .nestService, message: "Delegate received saved entry: \(entry.title)")
            
            if entries.contains(where: { $0.id == entry.id }) {
                updateLocalEntry(entry)
            } else {
                addLocalEntry(entry)
            }
        } else {
            // Handle deletion
            Logger.log(level: .info, category: .nestService, message: "Delegate received deletion")
            
            if let editingEntry = controller.entry,
               let index = entries.firstIndex(where: { $0.id == editingEntry.id }) {
                entries.remove(at: index)
                
                DispatchQueue.main.async {
                    guard let dataSource = self.dataSource else { return }
                    var snapshot = dataSource.snapshot()
                    snapshot.deleteItems([editingEntry])
                    dataSource.apply(snapshot, animatingDifferences: true)
                }
                
                showToast(text: "Entry Deleted")
            }
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

