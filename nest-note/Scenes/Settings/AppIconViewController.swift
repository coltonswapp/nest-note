//
//  AppIconViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 12/6/24.
//

import UIKit

class AppIconViewController: NNViewController {
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, AppIcon>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        applyInitialSnapshot()
    }
    
    override func setup() {
        navigationItem.title = "App Icon"
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    override func setupNavigationBarButtons() {
        let closeButton = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeButtonTapped))
        closeButton.tintColor = .label
        navigationItem.rightBarButtonItem = closeButton
    }
    
    private func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.showsSeparators = false
        config.headerMode = .supplementary
        return UICollectionViewCompositionalLayout.list(using: config)
    }
    
    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, AppIcon> { cell, indexPath, appIcon in
            var content = cell.defaultContentConfiguration()
            content.text = appIcon.displayName
            content.image = UIImage(named: appIcon.previewImageName)
            content.imageProperties.maximumSize = CGSize(width: 60, height: 60)
            content.imageProperties.cornerRadius = 12
            content.imageToTextPadding = 16
            content.imageProperties.strokeWidth = 2
            content.imageProperties.strokeColor = .tertiarySystemFill
            
            cell.contentConfiguration = content
            
            // Add checkmark for selected icon
            if appIcon.isSelected {
                cell.accessories = [.checkmark()]
            } else {
                cell.accessories = []
            }
        }
        
        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { supplementaryView, elementKind, indexPath in
            var content = supplementaryView.defaultContentConfiguration()
            content.text = "Choose your icon"
            content.textProperties.font = UIFont.preferredFont(forTextStyle: .subheadline)
            content.textProperties.color = .secondaryLabel
            supplementaryView.contentConfiguration = content
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, AppIcon>(collectionView: collectionView) { collectionView, indexPath, appIcon in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: appIcon)
        }
        
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            if kind == UICollectionView.elementKindSectionHeader {
                return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            }
            return nil
        }
    }
    
    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, AppIcon>()
        snapshot.appendSections([.main])
        snapshot.appendItems(AppIcon.allCases, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    private func changeAppIcon(to appIcon: AppIcon) {
        Task { @MainActor in
            if UIApplication.shared.supportsAlternateIcons {
                do {
                    print("🔄 Attempting to change icon to: \(appIcon.iconName ?? "nil") (\(appIcon.displayName))")
                    print("🔄 Current icon: \(UIApplication.shared.alternateIconName ?? "nil")")
                    try await UIApplication.shared.setAlternateIconName(appIcon.iconName)
                    print("✅ Successfully changed icon to: \(UIApplication.shared.alternateIconName ?? "nil")")
                    // Refresh the collection view to update selection state
                    configureDataSource()
                    applyInitialSnapshot()
                    showToast(delay: 0.0, text: "App icon changed to \(appIcon.displayName)")
                } catch {
                    print("❌ Failed to change icon: \(error)")
                    showErrorAlert(message: "Failed to change app icon: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    enum Section {
        case main
    }
}

extension AppIconViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let appIcon = dataSource.itemIdentifier(for: indexPath) else { return }
        
        // Don't do anything if the icon is already selected
        if appIcon.isSelected {
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        }
        
        changeAppIcon(to: appIcon)
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}
