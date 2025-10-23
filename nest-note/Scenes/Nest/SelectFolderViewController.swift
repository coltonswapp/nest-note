//
//  SelectFolderViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 1/29/25
//

import UIKit

protocol SelectFolderViewControllerDelegate: AnyObject {
    func selectFolderViewController(_ controller: SelectFolderViewController, didSelectFolder folder: String)
    func selectFolderViewControllerDidCancel(_ controller: SelectFolderViewController)
}

class SelectFolderViewController: UIViewController {
    // MARK: - Properties
    private let entryRepository: EntryRepository
    private let currentCategory: String
    private let selectedEntries: [BaseEntry]
    private let selectedPlaces: [PlaceItem]
    weak var delegate: SelectFolderViewControllerDelegate?
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, FolderItem>!
    private var instructionLabel: BlurBackgroundLabel!
    private var moveButton: NNLoadingButton!
    
    private var categories: [NestCategory] = []
    private var selectedFolder: String?
    
    enum Section: Int, CaseIterable {
        case folders
    }
    
    struct FolderItem: Hashable {
        let name: String
        let fullPath: String
        let symbolName: String
        let isSelected: Bool
        let id: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(fullPath)
        }
        
        static func == (lhs: FolderItem, rhs: FolderItem) -> Bool {
            return lhs.name == rhs.name && lhs.isSelected == rhs.isSelected && rhs.id == lhs.id && rhs.fullPath == lhs.fullPath
        }
    }
    
    init(entryRepository: EntryRepository, currentCategory: String, selectedEntries: [BaseEntry], selectedPlaces: [PlaceItem] = []) {
        self.entryRepository = entryRepository
        self.currentCategory = currentCategory
        self.selectedEntries = selectedEntries
        self.selectedPlaces = selectedPlaces
        super.init(nibName: nil, bundle: nil)
        self.title = "Move to Folder"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupNavigationBar()
        setupCollectionView()
        configureDataSource()
        setupMoveButton()
        setupInstructionLabel()
        
        collectionView.delegate = self
        
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = NNColors.primary
        
        loadCategories()
    }
    
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelButtonTapped)
        )
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        
        // Account for both the move button and the instruction label
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
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, FolderItem> { cell, indexPath, item in
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
            
            // Add selection indicator on the right
            let selectionImageName = item.isSelected ? "checkmark.circle.fill" : "circle"
            let selectionImage = UIImage(systemName: selectionImageName)?
                .withTintColor(item.isSelected ? NNColors.primary : .tertiaryLabel, renderingMode: .alwaysOriginal)
            
            let selectionImageView = UIImageView(image: selectionImage)
            selectionImageView.contentMode = .scaleAspectFit
            selectionImageView.translatesAutoresizingMaskIntoConstraints = true
            
            let customAccessory = UICellAccessory.customView(configuration: .init(
                customView: selectionImageView,
                placement: .trailing()
            ))
            
            cell.accessories = [customAccessory]
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, FolderItem>(collectionView: collectionView) { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration,
                for: indexPath,
                item: item
            )
        }
    }
    
    private func setupInstructionLabel() {
        instructionLabel = BlurBackgroundLabel()
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        let totalItems = selectedEntries.count + selectedPlaces.count
        let itemDescriptor: String
        if selectedEntries.count > 0 && selectedPlaces.count > 0 {
            itemDescriptor = "items"
        } else if selectedEntries.count > 0 {
            itemDescriptor = selectedEntries.count == 1 ? "entry" : "entries"
        } else {
            itemDescriptor = selectedPlaces.count == 1 ? "place" : "places"
        }
        instructionLabel.text = "Select a folder to move \(totalItems) \(itemDescriptor) to."
        instructionLabel.font = .bodyL
        instructionLabel.textColor = .secondaryLabel
        
        view.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.bottomAnchor.constraint(equalTo: moveButton.topAnchor, constant: -12),
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)
        ])
    }
    
    private func setupMoveButton() {
        moveButton = NNLoadingButton(title: "Move", titleColor: .white, fillStyle: .fill(NNColors.primary))
        moveButton.isEnabled = false
        moveButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        moveButton.addTarget(self, action: #selector(moveButtonTapped), for: .touchUpInside)
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
        
        // Create folder items from fetched categories, excluding the current category
        let folderItems = categories.compactMap { category -> FolderItem? in
            // Don't show the current category as an option
            guard category.name != currentCategory else { return nil }
            
            return FolderItem(
                name: category.name.components(separatedBy: "/").last ?? category.name,
                fullPath: category.name,
                symbolName: category.symbolName,
                isSelected: selectedFolder == category.name,
                id: category.id
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        snapshot.appendItems(folderItems, toSection: .folders)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func selectFolder(_ folderPath: String) {
        selectedFolder = folderPath
        applySnapshot()
        updateMoveButtonState()
    }
    
    private func updateMoveButtonState() {
        let hasSelection = selectedFolder != nil
        moveButton.isEnabled = hasSelection
    }
    
    @objc private func cancelButtonTapped() {
        delegate?.selectFolderViewControllerDidCancel(self)
    }
    
    @objc private func moveButtonTapped() {
        guard let selectedFolder = selectedFolder else { return }
        
        moveButton.startLoading()
        delegate?.selectFolderViewController(self, didSelectFolder: selectedFolder)
    }
}

// MARK: - UICollectionViewDelegate
extension SelectFolderViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        selectFolder(item.fullPath)
    }
}
