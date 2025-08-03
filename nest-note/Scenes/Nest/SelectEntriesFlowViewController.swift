//
//  SelectEntriesFlowViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 1/29/25
//

import UIKit

protocol SelectEntriesFlowDelegate: AnyObject {
    func selectEntriesFlow(_ controller: SelectEntriesFlowViewController, didFinishWithEntries entries: [BaseEntry], places: [PlaceItem])
    func selectEntriesFlowDidCancel(_ controller: SelectEntriesFlowViewController)
}

class SelectEntriesFlowViewController: UIViewController {
    // MARK: - Properties
    private let entryRepository: EntryRepository
    weak var delegate: SelectEntriesFlowDelegate?
    
    private var contentNavigationController: UINavigationController!
    private var selectionCounterView: UIView!
    private var countLabel: UILabel!
    private var finishButton: NNPrimaryLabeledButton!
    private var stackView: UIStackView!
    
    private var selectedEntries: Set<BaseEntry> = []
    private var selectedPlaces: Set<PlaceItem> = []
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupContentNavigationController()
        setupSelectionCounterView()
        setupConstraints()
        
        // Update UI with any pre-selected entries or places
        if !selectedEntries.isEmpty || !selectedPlaces.isEmpty {
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
        selectionCounterView = UIView()
        selectionCounterView.backgroundColor = .systemBackground
        selectionCounterView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add shadow and border
        selectionCounterView.layer.shadowColor = UIColor.black.cgColor
        selectionCounterView.layer.shadowOffset = CGSize(width: 0, height: -2)
        selectionCounterView.layer.shadowOpacity = 0.1
        selectionCounterView.layer.shadowRadius = 4
        
        // Add top border
        let topBorder = UIView()
        topBorder.backgroundColor = .separator
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        selectionCounterView.addSubview(topBorder)
        
        // Create stack view for vertical layout
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create count label
        countLabel = UILabel()
        countLabel.font = .h4
        countLabel.textColor = .secondaryLabel
        countLabel.textAlignment = .center
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create finish button - using "Done" to match the image
        finishButton = NNPrimaryLabeledButton(title: "Done")
        finishButton.addTarget(self, action: #selector(finishButtonTapped), for: .touchUpInside)
        finishButton.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.addArrangedSubview(countLabel)
        stackView.addArrangedSubview(finishButton)
        
        selectionCounterView.addSubview(stackView)
        view.addSubview(selectionCounterView)
        
        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: selectionCounterView.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: selectionCounterView.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: selectionCounterView.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 0.5),
            
            stackView.topAnchor.constraint(equalTo: selectionCounterView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: selectionCounterView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: selectionCounterView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            
            finishButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        updateSelectionCounter()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Content navigation controller takes up space above the counter
            contentNavigationController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentNavigationController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentNavigationController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentNavigationController.view.bottomAnchor.constraint(equalTo: selectionCounterView.topAnchor),
            
            // Selection counter view is fixed at the bottom
            selectionCounterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            selectionCounterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            selectionCounterView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func updateSelectionCounter() {
        let totalCount = selectedEntries.count + selectedPlaces.count
        let itemText = totalCount == 1 ? "item" : "items"
        countLabel.text = "\(totalCount) \(itemText) selected"
        
        finishButton.isEnabled = totalCount > 0
        finishButton.alpha = totalCount > 0 ? 1.0 : 0.6
    }
    
    @objc private func cancelButtonTapped() {
        delegate?.selectEntriesFlowDidCancel(self)
    }
    
    @objc private func finishButtonTapped() {
        let entriesArray = Array(selectedEntries)
        let placesArray = Array(selectedPlaces)
        delegate?.selectEntriesFlow(self, didFinishWithEntries: entriesArray, places: placesArray)
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
        
        // Pass the currently selected entries and places to maintain selection state
        categoryVC.restoreSelectedEntries(selectedEntries)
        categoryVC.restoreSelectedPlaces(selectedPlaces)
        
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
    
    // Helper method to count total items in a specific folder (simulated for now)
    private func countTotalItemsInFolder(_ folderPath: String) -> Int {
        // For now, we'll simulate the total count based on the category name
        // In a real implementation, this would come from the backend
        // This is a placeholder that shows different counts for different folders
        switch folderPath {
        case "Pets":
            return 5
        case "Home":
            return 8
        case "Work":
            return 3
        default:
            return 4
        }
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        
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
                totalItemCount: countTotalItemsInFolder(category.name)
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
}
