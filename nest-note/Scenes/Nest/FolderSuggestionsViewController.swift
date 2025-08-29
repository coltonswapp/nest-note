//
//  FolderSuggestionsViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 8/29/25.
//

import UIKit

protocol FolderSuggestionsViewControllerDelegate: AnyObject {
    func folderSuggestionsViewController(_ controller: FolderSuggestionsViewController, didSelectFolder name: String, withIcon icon: String)
}

class FolderSuggestionsViewController: UIViewController {
    
    // MARK: - Properties
    weak var delegate: FolderSuggestionsViewControllerDelegate?
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, FolderSuggestion>!
    
    private enum Section {
        case main
    }
    
    private struct FolderSuggestion: Hashable {
        let name: String
        let icon: String
        
        var folderData: FolderData {
            return FolderData(
                title: name,
                image: UIImage(systemName: icon) ?? UIImage(systemName: "folder")!,
                itemCount: 0,
                fullPath: name,
                category: nil
            )
        }
    }
    
    // MARK: - Folder Suggestions Data
    private let folderSuggestions: [FolderSuggestion] = [
        FolderSuggestion(name: "Emergency", icon: "exclamationmark.triangle"),
        FolderSuggestion(name: "Pets", icon: "pawprint.fill"),
        FolderSuggestion(name: "Rules", icon: "list.bullet"),
        FolderSuggestion(name: "School", icon: "studentdesk"),
        FolderSuggestion(name: "Medical", icon: "pills.fill"),
        FolderSuggestion(name: "Activities", icon: "american.football.fill"),
        FolderSuggestion(name: "Meals", icon: "heart.fill")
    ]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        configureDataSource()
        applySnapshot()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Folder Suggestions"
        
        // Add close button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
    }
    
    private func setupCollectionView() {
        // Create layout similar to NestViewController's main section
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(144) // Same height as folder cells
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 20,
            leading: 10,
            bottom: 20,
            trailing: 10
        )
        
        let layout = UICollectionViewCompositionalLayout(section: section)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        
        view.addSubview(collectionView)
        
        // Register the FolderCollectionViewCell
        collectionView.register(FolderCollectionViewCell.self, forCellWithReuseIdentifier: FolderCollectionViewCell.reuseIdentifier)
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, FolderSuggestion>(collectionView: collectionView) { collectionView, indexPath, folderSuggestion in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FolderCollectionViewCell.reuseIdentifier, for: indexPath) as! FolderCollectionViewCell
            cell.configure(with: folderSuggestion.folderData)
            return cell
        }
    }
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, FolderSuggestion>()
        snapshot.appendSections([.main])
        snapshot.appendItems(folderSuggestions, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDelegate
extension FolderSuggestionsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let folderSuggestion = dataSource.itemIdentifier(for: indexPath) else { return }
        
        // Dismiss this view controller and notify delegate
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.folderSuggestionsViewController(self, didSelectFolder: folderSuggestion.name, withIcon: folderSuggestion.icon)
        }
    }
}