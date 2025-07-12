//
//  PinnedCategoriesViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 1/21/25
//

import UIKit

class PinnedCategoriesViewController: UIViewController {
    // MARK: - Properties
    private let entryRepository: EntryRepository
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, CategoryItem>!
    private var instructionLabel: BlurBackgroundLabel!
    private var saveButton: NNLoadingButton!
    
    private var categories: [NestCategory] = []
    private var pinnedCategoryNames: Set<String> = []
    private var originalPinnedCategoryNames: Set<String> = []
    
    enum Section: Int, CaseIterable {
        case categories
    }
    
    struct CategoryItem: Hashable {
        let name: String
        let symbolName: String
        let isPinned: Bool
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
        }
        
        static func == (lhs: CategoryItem, rhs: CategoryItem) -> Bool {
            return lhs.name == rhs.name && lhs.isPinned == rhs.isPinned
        }
    }
    
    init(entryRepository: EntryRepository) {
        self.entryRepository = entryRepository
        super.init(nibName: nil, bundle: nil)
        self.title = "Pinned Categories"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupCollectionView()
        configureDataSource()
        setupSaveButton()
        setupInstructionLabel()
        
        collectionView.delegate = self
        
        navigationItem.weeTitle = "Manage Pinned"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.tintColor = NNColors.primary
        
        loadCategories()
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        
        // Account for both the save button and the instruction label
        let buttonHeight: CGFloat = 55
        let labelHeight: CGFloat = 60 // Estimated height for blur label
        let padding: CGFloat = 20
        let totalInset = buttonHeight + labelHeight + padding
        collectionView.contentInset.bottom = totalInset
        collectionView.verticalScrollIndicatorInsets.bottom = totalInset
        
        collectionView.allowsSelection = true
    }
    
    private func createLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.trailingSwipeActionsConfigurationProvider = nil
        
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        return layout
    }
    
    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, CategoryItem> { cell, indexPath, item in
            var content = cell.defaultContentConfiguration()
            content.text = item.name
            
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
            
            // Add pin/unpin indicator on the right
            let pinImageName = item.isPinned ? "checkmark.circle.fill" : "circle"
            let pinImage = UIImage(systemName: pinImageName)?
                .withTintColor(item.isPinned ? NNColors.primary : .tertiaryLabel, renderingMode: .alwaysOriginal)
            
            let pinImageView = UIImageView(image: pinImage)
            pinImageView.contentMode = .scaleAspectFit
            pinImageView.translatesAutoresizingMaskIntoConstraints = true
            
            let customAccessory = UICellAccessory.customView(configuration: .init(
                customView: pinImageView,
                placement: .trailing()
            ))
            
            cell.accessories = [customAccessory]
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, CategoryItem>(collectionView: collectionView) { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration,
                for: indexPath,
                item: item
            )
        }
    }
    
    private func setupInstructionLabel() {
        instructionLabel = BlurBackgroundLabel(with: .systemThickMaterial)
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.text = "Pinned categories will be visible to sitters. Limit: 4 categories."
        instructionLabel.font = .bodyL
        instructionLabel.textColor = .secondaryLabel
        
        view.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -12),
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)
        ])
    }
    
    private func setupSaveButton() {
        saveButton = NNLoadingButton(title: "Save Changes", titleColor: .white, fillStyle: .fill(NNColors.primary))
        saveButton.isEnabled = false
        saveButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
    }
    
    private func loadCategories() {
        Task {
            do {
                // Fetch both categories and pinned categories
                async let categoriesTask = entryRepository.fetchCategories()
                async let pinnedCategoriesTask = (entryRepository as? NestService)?.fetchPinnedCategories() ?? []
                
                let (fetchedCategories, pinnedCategoryNames) = try await (categoriesTask, pinnedCategoriesTask)
                
                await MainActor.run {
                    self.categories = fetchedCategories
                    self.pinnedCategoryNames = Set(pinnedCategoryNames)
                    self.originalPinnedCategoryNames = Set(pinnedCategoryNames)
                    self.applySnapshot()
                    self.updateSaveButtonState()
                }
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, CategoryItem>()
        snapshot.appendSections([.categories])
        
        // Create category items from fetched categories
        var categoryItems = categories.map { category in
            CategoryItem(
                name: category.name,
                symbolName: category.symbolName,
                isPinned: pinnedCategoryNames.contains(category.name)
            )
        }
        
        // Always add "Places" as an option
        let placesItem = CategoryItem(
            name: "Places",
            symbolName: "map.fill",
            isPinned: pinnedCategoryNames.contains("Places")
        )
        categoryItems.append(placesItem)
        
        // Sort all items alphabetically
        categoryItems.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        snapshot.appendItems(categoryItems, toSection: .categories)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func togglePin(for categoryName: String) {
        if pinnedCategoryNames.contains(categoryName) {
            pinnedCategoryNames.remove(categoryName)
        } else {
            // Check if we're at the limit
            if pinnedCategoryNames.count >= 4 {
                return
            }
            pinnedCategoryNames.insert(categoryName)
        }
        
        applySnapshot()
        updateSaveButtonState()
    }
    
    private func updateSaveButtonState() {
        let hasChanges = pinnedCategoryNames != originalPinnedCategoryNames
        saveButton.isEnabled = hasChanges
    }
    
    @objc private func saveButtonTapped() {
        Task {
            await MainActor.run {
                saveButton.startLoading()
            }
            
            do {
                // Convert Set to Array for saving
                let categoryNamesArray = Array(pinnedCategoryNames)
                
                // Save using NestService
                if let nestService = entryRepository as? NestService {
                    try await nestService.savePinnedCategories(categoryNamesArray)
                }
                
                await MainActor.run {
                    self.originalPinnedCategoryNames = self.pinnedCategoryNames
                    self.showToast(text: "Pinned categories saved")
                    self.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.saveButton.stopLoading()
                    self.showError("Failed to save pinned categories: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - UICollectionViewDelegate
extension PinnedCategoriesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        togglePin(for: item.name)
    }
}
