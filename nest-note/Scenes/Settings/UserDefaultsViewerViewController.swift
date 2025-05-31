//
//  UserDefaultsViewerViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 5/24/25.
//

import UIKit

class UserDefaultsViewerViewController: NNViewController {
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, UserDefaultsItem>!
    private var userDefaultsItems: [UserDefaultsItem] = []
    private var allUserDefaultsItems: [UserDefaultsItem] = []
    private var showOnlyAppKeys = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        configureDataSource()
        loadUserDefaults()
        applySnapshot()
    }
    
    override func setup() {
        navigationItem.title = "UserDefaults Viewer"
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    override func setupNavigationBarButtons() {
        let filterButton = UIBarButtonItem(
            image: UIImage(systemName: showOnlyAppKeys ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"),
            style: .plain,
            target: self,
            action: #selector(filterTapped)
        )
        
        let refreshButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshTapped)
        )
        
        [filterButton, refreshButton].forEach { $0.tintColor = .label }
        navigationItem.rightBarButtonItems = [refreshButton, filterButton]
    }
    
    private func setupCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        return UICollectionViewCompositionalLayout.list(using: config)
    }
    
    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, UserDefaultsItem> { cell, indexPath, item in
            var content = cell.defaultContentConfiguration()
            content.text = item.key
            content.secondaryText = item.formattedValue
            content.textProperties.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
            content.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            content.secondaryTextProperties.color = .secondaryLabel
            content.secondaryTextProperties.numberOfLines = 0
            
            // Add visual indicator for different value types
            let typeColor: UIColor
            switch item.type {
            case .string:
                typeColor = .systemBlue
            case .bool:
                typeColor = .systemGreen
            case .integer:
                typeColor = .systemOrange
            case .array:
                typeColor = .systemPurple
            case .data:
                typeColor = .systemRed
            case .unknown:
                typeColor = .systemGray
            }
            
            let typeIndicator = UIView()
            typeIndicator.backgroundColor = typeColor
            typeIndicator.layer.cornerRadius = 4
            typeIndicator.translatesAutoresizingMaskIntoConstraints = true
            typeIndicator.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
            
            cell.accessories = [.customView(configuration: .init(customView: typeIndicator, placement: .trailing()))]
            cell.contentConfiguration = content
        }
        
        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { headerView, elementKind, indexPath in
            var content = headerView.defaultContentConfiguration()
            let filterText = self.showOnlyAppKeys ? "App Keys" : "All Keys"
            content.text = "\(filterText) (\(self.userDefaultsItems.count))"
            content.textProperties.font = .preferredFont(forTextStyle: .headline)
            headerView.contentConfiguration = content
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, UserDefaultsItem>(collectionView: collectionView) { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            if kind == UICollectionView.elementKindSectionHeader {
                return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            }
            return nil
        }
    }
    
    private func loadUserDefaults() {
        let defaults = UserDefaults.standard
        let allKeys = Array(defaults.dictionaryRepresentation().keys).sorted()
        
        allUserDefaultsItems = allKeys.compactMap { key in
            let value = defaults.object(forKey: key)
            return UserDefaultsItem(key: key, value: value)
        }
        
        filterUserDefaults()
    }
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, UserDefaultsItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(userDefaultsItems, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    @objc private func refreshTapped() {
        loadUserDefaults()
        applySnapshot()
        
        // Show a brief feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    @objc private func filterTapped() {
        showOnlyAppKeys.toggle()
        setupNavigationBarButtons() // Update the filter button icon
        filterUserDefaults()
        applySnapshot()
    }
    
    private func filterUserDefaults() {
        if showOnlyAppKeys {
            userDefaultsItems = allUserDefaultsItems.filter { item in
                guard let firstChar = item.key.first else { return false }
                return firstChar.isLowercase && firstChar.isLetter
            }
        } else {
            userDefaultsItems = allUserDefaultsItems
        }
    }
}

// MARK: - Supporting Types
extension UserDefaultsViewerViewController {
    enum Section: CaseIterable {
        case main
    }
}

struct UserDefaultsItem: Hashable {
    let key: String
    let value: Any?
    let type: ValueType
    
    init(key: String, value: Any?) {
        self.key = key
        self.value = value
        self.type = ValueType.from(value: value)
    }
    
    var formattedValue: String {
        guard let value = value else { return "nil" }
        
        switch type {
        case .string:
            return "\"\(value)\""
        case .bool:
            return value as? Bool == true ? "true" : "false"
        case .integer:
            return "\(value)"
        case .array:
            if let array = value as? [Any] {
                return "[\(array.count) items] \(array)"
            }
            return "\(value)"
        case .data:
            if let data = value as? Data {
                return "Data (\(data.count) bytes)"
            }
            return "\(value)"
        case .unknown:
            return "\(value)"
        }
    }
    
    enum ValueType {
        case string
        case bool
        case integer
        case array
        case data
        case unknown
        
        static func from(value: Any?) -> ValueType {
            guard let value = value else { return .unknown }
            
            switch value {
            case is String:
                return .string
            case is Bool:
                return .bool
            case is Int, is Int32, is Int64, is Float, is Double:
                return .integer
            case is Array<Any>:
                return .array
            case is Data:
                return .data
            default:
                return .unknown
            }
        }
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(type)
        // Note: We can't hash the value directly since Any? isn't Hashable
        // Using the formatted value as a proxy
        hasher.combine(formattedValue)
    }
    
    static func == (lhs: UserDefaultsItem, rhs: UserDefaultsItem) -> Bool {
        return lhs.key == rhs.key && 
               lhs.type == rhs.type && 
               lhs.formattedValue == rhs.formattedValue
    }
} 