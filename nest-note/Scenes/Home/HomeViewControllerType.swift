import UIKit

/// Protocol defining shared functionality between owner and sitter home view controllers
protocol HomeViewControllerType: NNViewController {
    // MARK: - Properties
    var collectionView: UICollectionView! { get }
    var dataSource: UICollectionViewDiffableDataSource<HomeSection, HomeItem>! { get }
    
    // MARK: - Data Management
    func refreshData()
    func handleError(_ error: Error)
    
    // MARK: - Collection View Setup
    func configureCollectionView()
    func createLayout() -> UICollectionViewLayout
    func configureDataSource()
    func applySnapshot(animatingDifferences: Bool)
    
    
    // MARK: - Navigation
    func presentHouseholdView()
    func presentCategoryView(category: String)
}

// MARK: - Shared Types
enum HomeSection: Int {
    case nest
    case quickAccess
    case currentSession
    case upcomingSessions
    case events
}

enum HomeItem: Hashable {
    case nest(name: String, address: String)
    case quickAccess(HomeQuickAccessType)
    case currentSession(SessionItem)
    case upcomingSession(SessionItem)
    case events
    case sessionEvent(SessionEvent)
    case moreEvents(Int)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .nest(let name, let address):
            hasher.combine(0)
            hasher.combine(name)
            hasher.combine(address)
        case .quickAccess(let type):
            hasher.combine(1)
            hasher.combine(type)
        case .currentSession(let session):
            hasher.combine(2)
            hasher.combine(session)
        case .upcomingSession(let session):
            hasher.combine(3)
            hasher.combine(session)
        case .events:
            hasher.combine(4)
        case .sessionEvent(let event):
            hasher.combine(5)
            hasher.combine(event)
        case .moreEvents(let count):
            hasher.combine(6)
            hasher.combine(count)
        }
    }
    
    static func == (lhs: HomeItem, rhs: HomeItem) -> Bool {
        switch (lhs, rhs) {
        case let (.nest(n1, a1), .nest(n2, a2)):
            return n1 == n2 && a1 == a2
        case let (.quickAccess(t1), .quickAccess(t2)):
            return t1 == t2
        case let (.currentSession(s1), .currentSession(s2)):
            return s1 == s2
        case let (.upcomingSession(s1), .upcomingSession(s2)):
            return s1 == s2
        case (.events, .events):
            return true
        case let (.sessionEvent(e1), .sessionEvent(e2)):
            return e1 == e2
        case let (.moreEvents(c1), .moreEvents(c2)):
            return c1 == c2
        default:
            return false
        }
    }
}

// MARK: - Default Implementation
extension HomeViewControllerType {
    func createLayout() -> UICollectionViewLayout {
        
        let verticalSpacing: CGFloat = 4
        
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnvironment in
            guard let self = self else { return nil }
            
            // Configure header size for all sections
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(16)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            
            switch self.dataSource.snapshot().sectionIdentifiers[sectionIndex] {
            case .currentSession:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(60))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(60))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 18, bottom: 20, trailing: 18)
                section.boundarySupplementaryItems = [header]
                return section
                
            case .nest:
                // Full width item with fixed height of 220
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: verticalSpacing + 4, leading: 18, bottom: verticalSpacing, trailing: 18)
                section.boundarySupplementaryItems = [header]
                return section
                
            case .quickAccess:
                // Two column grid with fixed height of 180
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(160))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: verticalSpacing, leading: 13, bottom: 20, trailing: 13)
//                section.boundarySupplementaryItems = [header]
                return section
                
            case .upcomingSessions, .events:
                // Use list configuration for these sections
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.showsSeparators = false
                config.headerMode = .supplementary
                
                let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
                section.contentInsets = NSDirectionalEdgeInsets(top: verticalSpacing, leading: 16, bottom: verticalSpacing, trailing: 16)
                section.boundarySupplementaryItems = [header]
                return section
            }
        }
        return layout
    }
    
    func handleError(_ error: Error) {
        // Default error handling implementation
        Logger.log(level: .error, category: .general, message: error.localizedDescription)
        
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Error",
                message: "Something went wrong. Please try again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
} 
