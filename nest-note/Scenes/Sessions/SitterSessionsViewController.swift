import UIKit

class SitterSessionsViewController: NNViewController {
    struct MonthSection: Hashable {
        let date: Date
        let bucket: SessionService.SessionBucket
        
        var title: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: date)
        }
    }
    
    enum Section: Int, CaseIterable {
        case inProgress
        case upcoming
        
        var title: String {
            switch self {
            case .inProgress: return "IN PROGRESS"
            case .upcoming: return "UPCOMING"
            }
        }
    }
    
    enum Item: Hashable {
        case session(SessionItem)
        case empty(Section)
    }
    
    private var filterView: SessionFilterView!
    internal var loadingIndicator: UIActivityIndicatorView!
    internal var refreshControl: UIRefreshControl!
    
    internal var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<MonthSection, Item>!
    
    private let sessionService = SessionService.shared
    private var allSessions: [SessionItem] = [] {
        didSet {
            updateDisplayedSessions()
        }
    }
    private var currentBucket: SessionService.SessionBucket = .upcoming
    
    private var filteredSessions: [SessionItem] {
        let now = Date()
        
        switch currentBucket {
        case .upcoming:
            return allSessions
                .filter { $0.startDate > now }
                .sorted { $0.startDate < $1.startDate }
        case .inProgress:
            return allSessions
                .filter { $0.startDate <= now && $0.endDate > now }
                .sorted { $0.endDate < $1.endDate }
        case .past:
            return []
        }
    }
    
    private var ctaButton: NNPrimaryLabeledButton!
    
    private lazy var emptyStateView: NNEmptyStateView = {
        let view = NNEmptyStateView(
            icon: UIImage(systemName: "calendar"),
            title: "No sessions",
            subtitle: "Your sessions will appear here."
        )
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadSessions()
    }
    
    override func setup() {
        title = "My Sessions"
        setupFilterView()
        setupCollectionView()
        setupEmptyStateView()
        setupJoinSessionButton()
        configureDataSource()
    }
    
    private func setupFilterView() {
        filterView = SessionFilterView(
            filters: [.upcoming, .inProgress],
            initialFilter: .upcoming
        )
        filterView.delegate = self
        filterView.frame.size.height = 40
        addNavigationBarPalette(filterView)
    }
    
    private func setupCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        
        collectionView.register(SitterSessionCell.self, forCellWithReuseIdentifier: SitterSessionCell.reuseIdentifier)
        
        view.addSubview(collectionView)
        
        let insets = UIEdgeInsets(
            top: 16,
            left: 0,
            bottom: 88, // Account for button height + padding
            right: 0
        )
        
        collectionView.contentInset = insets
        collectionView.scrollIndicatorInsets = insets
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<MonthSection, Item>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: SitterSessionCell.reuseIdentifier,
                for: indexPath
            ) as! SitterSessionCell
            
            switch item {
            case .session(let session):
                // Configure with default nest name first
                cell.configure(with: session, nestName: "Loading...")
                
                // Then fetch the actual nest name
                Task {
                    if let sitterSession = try? await self?.sessionService.getSitterSession(sessionID: session.id) {
                        await MainActor.run {
                            cell.configure(with: session, nestName: sitterSession.nestName)
                        }
                    }
                }
            case .empty(let section):
                cell.configureEmptyState(for: section)
            }
            
            return cell
        }
        
        let headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] headerView, elementKind, indexPath in
            guard let section = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            headerView.configure(title: section.title)
        }
        
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            return collectionView.dequeueConfiguredReusableSupplementary(
                using: headerRegistration,
                for: indexPath
            )
        }
    }
    
    private func updateDisplayedSessions() {
        let now = Date()
        var snapshot = NSDiffableDataSourceSnapshot<MonthSection, Item>()
        
        // Group sessions by month for the current filter
        let calendar = Calendar.current
        let groupedSessions = Dictionary(grouping: filteredSessions) { session in
            calendar.startOfMonth(for: session.startDate)
        }
        
        // Sort months and create sections
        let sortedMonths = groupedSessions.keys.sorted { date1, date2 in
            // For past sessions, reverse the order (most recent first)
            if currentBucket == .past {
                return date1 > date2
            }
            // For upcoming and in-progress, keep chronological order
            return date1 < date2
        }
        
        for month in sortedMonths {
            let section = MonthSection(date: month, bucket: currentBucket)
            snapshot.appendSections([section])
            
            if let monthSessions = groupedSessions[month] {
                snapshot.appendItems(monthSessions.map { .session($0) }, toSection: section)
            }
        }
        
        dataSource.apply(snapshot, animatingDifferences: true)
        updateEmptyState()
    }
    
    private func loadSessions() {
        fetchSitterSessions()
    }
    
    private func fetchSitterSessions() {
        Task {
            do {
                guard let userID = UserService.shared.currentUser?.id else { return }
                
                // TODO: Implement fetchSitterSessions in SessionService
                let collection = try await sessionService.fetchSitterSessions(userID: userID)
                
                await MainActor.run {
                    self.allSessions = collection.upcoming + collection.inProgress + collection.past
                    updateEmptyState()
                }
            } catch {
                print("Error loading sitter sessions: \(error)")
            }
        }
    }
    
    private func setupJoinSessionButton() {
        ctaButton = NNPrimaryLabeledButton(title: "Join a Session")
        view.addSubview(ctaButton)
        
        ctaButton.addTarget(self, action: #selector(joinSessionTapped), for: .touchUpInside)
        
        ctaButton.pinToBottom(
            of: view,
            addBlurEffect: true, 
            blurMaskImage: UIImage(named: "testBG3")!
        )
    }
    
    @objc private func joinSessionTapped() {
        let vc = JoinSessionViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func setupEmptyStateView() {
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -44),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    private func updateEmptyState() {
        let hasItems = !filteredSessions.isEmpty
        emptyStateView.isHidden = hasItems
        
        if !hasItems {
            let (title, subtitle, icon) = emptyStateConfig(for: currentBucket)
            emptyStateView.configure(icon: icon, title: title, subtitle: subtitle)
        }
    }
    
    private func emptyStateConfig(for bucket: SessionService.SessionBucket) -> (title: String, subtitle: String, icon: UIImage?) {
        switch bucket {
        case .upcoming:
            return (
                "No upcoming sessions",
                "Join a session to get started.",
                UIImage(systemName: "calendar.badge.plus")
            )
        case .inProgress:
            return (
                "No active sessions",
                "Sessions in progress will appear here.",
                UIImage(systemName: "calendar.badge.clock")
            )
        case .past:
            // This case should never be reached in the sitter view
            return (
                "", "", nil
            )
        }
    }
}

extension SitterSessionsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard case .session(let session) = dataSource.itemIdentifier(for: indexPath) else {
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        }
        
        // Get the nest name from the sitter session
        Task {
            if let sitterSession = try? await sessionService.getSitterSession(sessionID: session.id) {
                await MainActor.run {
                    // Present the detail view modally
                    let detailVC = SitterSessionDetailViewController(session: session, nestName: sitterSession.nestName)
                    detailVC.modalPresentationStyle = .pageSheet
                    present(detailVC, animated: true)
                }
            }
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
}

extension SitterSessionsViewController: SessionFilterViewDelegate {
    func sessionFilterView(_ filterView: SessionFilterView, didSelectFilter filter: SessionService.SessionBucket) {
        currentBucket = filter
        updateDisplayedSessions()
    }
}

extension SitterSessionsViewController: CollectionViewLoadable {
    func handleLoadedData() {
        updateDisplayedSessions()
    }
    
    func loadData(showLoadingIndicator: Bool) async {
        do {
            if showLoadingIndicator {
                await MainActor.run {
                    loadingIndicator.startAnimating()
                }
            }
            
            guard let userID = UserService.shared.currentUser?.id else { return }
            let collection = try await sessionService.fetchSitterSessions(userID: userID)
            
            await MainActor.run {
                self.allSessions = collection.upcoming + collection.inProgress + collection.past
                loadingIndicator.stopAnimating()
            }
            
        } catch {
            await MainActor.run {
                loadingIndicator.stopAnimating()
                Logger.log(level: .error, category: .sessionService, message: "Error loading sitter sessions: \(error.localizedDescription)")
            }
        }
    }
} 
