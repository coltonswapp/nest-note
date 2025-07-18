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
    
    func setFCMToken()
}

// MARK: - Shared Types
enum HomeSection: Int {
    case nest
    case quickAccess
    case currentSession
    case upcomingSessions
    case events
    case setupProgress
}

enum HomeItem: Hashable {
    case nest(name: String, address: String)
    case quickAccess(HomeQuickAccessType)
    case pinnedCategory(name: String, icon: String)
    case currentSession(SessionItem)
    case upcomingSession(SessionItem)
    case events
    case sessionEvent(SessionEvent)
    case moreEvents(Int)
    case setupProgress(current: Int, total: Int)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .nest(let name, let address):
            hasher.combine(0)
            hasher.combine(name)
            hasher.combine(address)
        case .quickAccess(let type):
            hasher.combine(1)
            hasher.combine(type)
        case .pinnedCategory(let name, let icon):
            hasher.combine(2)
            hasher.combine(name)
            hasher.combine(icon)
        case .currentSession(let session):
            hasher.combine(3)
            hasher.combine(session)
        case .upcomingSession(let session):
            hasher.combine(4)
            hasher.combine(session)
        case .events:
            hasher.combine(5)
        case .sessionEvent(let event):
            hasher.combine(6)
            hasher.combine(event)
        case .moreEvents(let count):
            hasher.combine(7)
            hasher.combine(count)
        case .setupProgress(let current, let total):
            hasher.combine(8)
            hasher.combine(current)
            hasher.combine(total)
        }
    }
    
    static func == (lhs: HomeItem, rhs: HomeItem) -> Bool {
        switch (lhs, rhs) {
        case let (.nest(n1, a1), .nest(n2, a2)):
            return n1 == n2 && a1 == a2
        case let (.quickAccess(t1), .quickAccess(t2)):
            return t1 == t2
        case let (.pinnedCategory(n1, i1), .pinnedCategory(n2, i2)):
            return n1 == n2 && i1 == i2
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
        case let (.setupProgress(c1, t1), .setupProgress(c2, t2)):
            return c1 == c2 && t1 == t2
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
                
            case .setupProgress:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(60))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(60))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 18, bottom: 20, trailing: 18)
                // No header for setup progress section
                return section
                
            case .nest:
                // Full width item with fixed height of 220
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: verticalSpacing + 4, leading: 18, bottom: 20, trailing: 18)
                section.boundarySupplementaryItems = [header]
                return section
                
            case .quickAccess:
                // Two column grid with fixed height of 180
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(100))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(100))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
                group.interItemSpacing = .fixed(8)
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 8
                section.contentInsets = NSDirectionalEdgeInsets(top: verticalSpacing + 4, leading: 18, bottom: 20, trailing: 18)
                section.boundarySupplementaryItems = [header]
                return section
                
            case .upcomingSessions, .events:
                // Use list configuration for these sections
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.showsSeparators = false
                config.headerMode = .supplementary
                
                let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
                section.contentInsets = NSDirectionalEdgeInsets(top: verticalSpacing, leading: 18, bottom: verticalSpacing, trailing: 16)
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

import FirebaseMessaging
extension HomeViewControllerType {
    
    func setFCMToken() {
        Logger.log(level: .info, category: .general, message: "Setting FCM token...")
        
        Task {
            do {
                let fcmToken = try await Messaging.messaging().token()
                try await UserService.shared.updateFCMToken(fcmToken)
                Logger.log(level: .info, category: .general, message: "Successfully updated FCM token.")
            } catch {
                Logger.log(level: .error, category: .general, message: "Failed to update FCM token: \(error.localizedDescription)")
            }
        }
    }
    
}
