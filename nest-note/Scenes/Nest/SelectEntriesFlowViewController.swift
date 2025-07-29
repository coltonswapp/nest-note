//
//  SelectEntriesFlowViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 1/29/25
//

import UIKit

protocol SelectEntriesFlowDelegate: AnyObject {
    func selectEntriesFlow(_ controller: SelectEntriesFlowViewController, didFinishWithEntries entries: [BaseEntry])
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
        
        setupContentNavigationController()
        setupSelectionCounterView()
        setupConstraints()
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
        let count = selectedEntries.count
        let entryText = count == 1 ? "item" : "items"
        countLabel.text = "\(count) \(entryText) selected"
        
        finishButton.isEnabled = count > 0
        finishButton.alpha = count > 0 ? 1.0 : 0.6
    }
    
    @objc private func cancelButtonTapped() {
        delegate?.selectEntriesFlowDidCancel(self)
    }
    
    @objc private func finishButtonTapped() {
        let entriesArray = Array(selectedEntries)
        delegate?.selectEntriesFlow(self, didFinishWithEntries: entriesArray)
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
        
        // Pass the currently selected entries to maintain selection state
        categoryVC.restoreSelectedEntries(selectedEntries)
        
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
    
    enum Section: Int, CaseIterable {
        case folders
    }
    
    struct FolderItem: Hashable {
        let name: String
        let fullPath: String
        let symbolName: String
        let id: String
        let selectedCount: Int
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(fullPath)
        }
        
        static func == (lhs: FolderItem, rhs: FolderItem) -> Bool {
            return lhs.name == rhs.name && rhs.id == lhs.id && rhs.fullPath == lhs.fullPath && lhs.selectedCount == rhs.selectedCount
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
        applySnapshot()
    }
    
    // Helper method to count selected entries in a specific folder
    private func countSelectedEntriesInFolder(_ folderPath: String) -> Int {
        return selectedEntries.filter { entry in
            entry.category.hasPrefix(folderPath)
        }.count
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        
        collectionView.allowsSelection = true
    }
    
    private func createLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.trailingSwipeActionsConfigurationProvider = nil
        
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        return layout
    }
    
    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, FolderItem> { cell, indexPath, item in
            var content = cell.defaultContentConfiguration()
            content.text = item.name
            
            // Show selection count if any entries are selected
            if item.selectedCount > 0 {
                let entryText = item.selectedCount == 1 ? "selected" : "selected"
                content.secondaryText = "\(item.selectedCount) \(entryText)"
                content.secondaryTextProperties.color = NNColors.primary
            } else {
                content.secondaryText = "0 selected"
                content.secondaryTextProperties.color = .secondaryLabel
            }
            
            let symbolConfiguration = UIImage.SymbolConfiguration(weight: .bold)
            let image = UIImage(systemName: item.symbolName, withConfiguration: symbolConfiguration)?
                .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
            content.image = image
            
            content.imageProperties.tintColor = NNColors.primary
            content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
            content.imageToTextPadding = 16
            
            content.directionalLayoutMargins.top = 16
            content.directionalLayoutMargins.bottom = 16
            
            cell.contentConfiguration = content
            
            // Add disclosure indicator
            cell.accessories = [.disclosureIndicator()]
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, FolderItem>(collectionView: collectionView) { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration,
                for: indexPath,
                item: item
            )
        }
    }
    
    private func loadCategories() {
        Task {
            do {
                let fetchedCategories = try await entryRepository.fetchCategories()
                
                await MainActor.run {
                    self.categories = fetchedCategories
                    self.applySnapshot()
                }
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func applySnapshot() {
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
                selectedCount: countSelectedEntriesInFolder(category.name)
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
}
