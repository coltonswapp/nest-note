//
//  HomeViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//

import UIKit
import SwiftUI

class HomeViewController: NNViewController, UICollectionViewDelegate {
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func loadView() {
        super.loadView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        applyInitialSnapshots()
        collectionView.delegate = self
    }
    
    override func setup() {
        navigationItem.title = "NestNote"
        navigationItem.weeTitle = "Welcome to"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    override func setupNavigationBarButtons() {
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(settingsButtonTapped))
        let buttons = [settingsButton]
        buttons.forEach { $0.tintColor = .label }
        navigationItem.rightBarButtonItems = buttons
    }
    
    override func addSubviews() {
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
        ])
    }
    
    enum Section: Int, Hashable, CaseIterable {
        case nest
        case quickAccess
        case upcomingEvents
        
        init?(rawValue: Int) {
            switch rawValue {
            case 0: self = .nest
            case 1: self = .quickAccess
            case 2: self = .upcomingEvents
            default: return nil
            }
        }
    }
    
    enum Item: Hashable {
        case nest(String)
        case quickAccess(String)
        case event(String, String, String)
    }
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    private func configureCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            switch self.dataSource.snapshot().sectionIdentifiers[sectionIndex] {
            case .nest:
                // Full width item with fixed height of 220
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 2, trailing: 18)
                
                return section
                
            case .quickAccess:
                // Two column grid with fixed height of 180
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(160))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 13, bottom: 12, trailing: 13)
                
                return section
                
            case .upcomingEvents:
                var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
                configuration.showsSeparators = true
                configuration.separatorConfiguration.color = .separator
                
                // Customize insets if needed
                configuration.leadingSwipeActionsConfigurationProvider = nil
                configuration.trailingSwipeActionsConfigurationProvider = nil
                
                let section = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: layoutEnvironment)
                
                // Add header for "Upcoming Events" title
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.9), heightDimension: .estimated(50))
                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
                section.boundarySupplementaryItems = [header]
                
                // Adjust content insets if needed
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
                
                return section
            }
        }
        
        return layout
    }
    
    private func configureDataSource() {
        // Cell registrations
        let nestCellRegistration = UICollectionView.CellRegistration<NestCell, Item> { cell, indexPath, item in
            if case let .nest(title) = item {
                let image = UIImage(systemName: "house.lodge.fill")
                cell.configure(with: title, subtitle: "In progress, thru Oct 16", image: image)
                cell.imageView.tintColor = .label
            }
            
            cell.backgroundColor = .systemGray6
            cell.layer.cornerRadius = 12
            cell.layer.masksToBounds = true
        }
        
        let quickAccessCellRegistration = UICollectionView.CellRegistration<QuickAccessCell, Item> { cell, indexPath, item in
            if case let .quickAccess(title) = item {
                let image: UIImage?
                if indexPath.row == 0 {
                    image = UIImage(systemName: "house")
                } else {
                    image = UIImage(systemName: "light.beacon.max")
                }
                cell.configure(with: title, image: image)
                cell.imageView.tintColor = .label
            }
            
            cell.backgroundColor = .systemGray6
            cell.layer.cornerRadius = 12
            cell.layer.masksToBounds = true
        }
        
        let eventCellRegistration = UICollectionView.CellRegistration<EventCell, Item> { cell, indexPath, item in
            if case let .event(title, time, status) = item {
                cell.configure(title: title, time: time, status: status)
            }
            
            cell.layer.cornerRadius = 12
            cell.layer.masksToBounds = true
        }
        
        // DataSource
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch self.dataSource.snapshot().sectionIdentifiers[indexPath.section] {
            case .nest:
                return collectionView.dequeueConfiguredReusableCell(using: nestCellRegistration, for: indexPath, item: item)
            case .quickAccess:
                return collectionView.dequeueConfiguredReusableCell(using: quickAccessCellRegistration, for: indexPath, item: item)
            case .upcomingEvents:
                return collectionView.dequeueConfiguredReusableCell(using: eventCellRegistration, for: indexPath, item: item)
            }
        }
        
        // Update the header registration
        let headerRegistration = UICollectionView.SupplementaryRegistration<UpcomingEventsHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { (supplementaryView, string, indexPath) in
            supplementaryView.fullScheduleButton.addTarget(self, action: #selector(self.fullScheduleButtonTapped), for: .touchUpInside)
        }
        
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        
        snapshot.appendSections([.nest, .quickAccess, .upcomingEvents])
        
        snapshot.appendItems([.nest("Smith Nest")], toSection: .nest)
        snapshot.appendItems([.quickAccess("Household"), .quickAccess("Emergency")], toSection: .quickAccess)
        snapshot.appendItems([
            .event("Dinner", "6:00pm", "In 2 hrs"),
            .event("Cheer pickup", "7:15pm", "In 3 hrs"),
            .event("Wake up routines", "7:45am", "Tomorrow")
        ], toSection: .upcomingEvents)
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    // MARK: - Bar Button Actions
    @objc func settingsButtonTapped() {
        present(UINavigationController(rootViewController: SettingsViewController()), animated: true)
    }
    
    @objc func fullScheduleButtonTapped() {
        print("Full Schedule button tapped")
        // Add your logic here to show the full schedule
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        switch item {
        case .nest(let name):
            print("Selected Nest: \(name)")
        case .quickAccess(let type):
            print("Selected Quick Access: \(type)")
        case .event(let title, let time, let status):
            print("Selected Event: \(title) at \(time), Status: \(status)")
        }
        
        // Optionally, deselect the item
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}
