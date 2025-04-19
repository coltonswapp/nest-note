import UIKit

class NestSessionsViewController: NNViewController {
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
        case past
        case inProgress
        case upcoming
        
        var title: String {
            switch self {
            case .inProgress: return "IN PROGRESS"
            case .upcoming: return "UPCOMING"
            case .past: return "PAST"
            }
        }
    }
    
    enum Item: Hashable {
        case session(any SessionDisplayable)
        case empty(Section)
        
        // Implement Equatable manually since we're using an existential type
        static func == (lhs: Item, rhs: Item) -> Bool {
            switch (lhs, rhs) {
            case (.empty(let lhsSection), .empty(let rhsSection)):
                return lhsSection == rhsSection
            case (.session(let lhsSession), .session(let rhsSession)):
                return lhsSession.id == rhsSession.id
            default:
                return false
            }
        }
        
        // Implement hash(into:) manually since we're using an existential type
        func hash(into hasher: inout Hasher) {
            switch self {
            case .empty(let section):
                hasher.combine(0) // Different value for empty case
                hasher.combine(section)
            case .session(let session):
                hasher.combine(1) // Different value for session case
                hasher.combine(session.id)
            }
        }
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
    private var archivedSessions: [ArchivedSession] = [] {
        didSet {
            updateDisplayedSessions()
        }
    }
    private var currentBucket: SessionService.SessionBucket = .inProgress
    
    private var filteredSessions: [any SessionDisplayable] {
        switch currentBucket {
        case .past:
            // Combine completed sessions and archived sessions
            let completedSessions = allSessions
                .filter { $0.status == .completed }
                .sorted { $0.endDate > $1.endDate }
                .map { $0 as (any SessionDisplayable) }
            
            let sortedArchivedSessions = archivedSessions
                .sorted { $0.endDate > $1.endDate }
                .map { $0 as (any SessionDisplayable) }
            
            return completedSessions + sortedArchivedSessions
            
        case .inProgress:
            return allSessions
                .filter { $0.status == .inProgress || $0.status == .extended }
                .sorted { $0.endDate < $1.endDate }
                .map { $0 as (any SessionDisplayable) }
                
        case .upcoming:
            return allSessions
                .filter { $0.status == .upcoming }
                .sorted { $0.startDate < $1.startDate }
                .map { $0 as (any SessionDisplayable) }
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
    
    private lazy var loadingSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadSessions()
        
        // Set initial filter to inProgress
        currentBucket = .inProgress
        filterView.selectBucket(.inProgress)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    override func setup() {
        title = "Nest Sessions"
        setupFilterView()
        setupCollectionView()
        setupEmptyStateView()
        setupNewSessionButton()
        configureDataSource()
        
        // Add loading spinner
        view.addSubview(loadingSpinner)
        NSLayoutConstraint.activate([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupFilterView() {
        filterView = SessionFilterView()
        filterView.delegate = self
        filterView.frame.size.height = 40
        addNavigationBarPalette(filterView)
    }
    
    private func setupCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self = self,
                  case .session(let session) = self.dataSource.itemIdentifier(for: indexPath),
                  let sessionItem = session as? SessionItem else {
                return nil
            }
            
            // Don't allow swipe actions for archived sessions
//            if session is ArchivedSession {
//                return nil
//            }
            
            let deleteAction = UIContextualAction(
                style: .destructive,
                title: "Delete"
            ) { [weak self] _, _, completion in
                guard let self = self else {
                    completion(false)
                    return
                }
                
                let alert = UIAlertController(
                    title: "Delete Session",
                    message: "Are you sure you want to delete this session? This action cannot be undone.",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(
                    title: "Cancel",
                    style: .cancel
                ) { _ in
                    completion(false)
                })
                
                alert.addAction(UIAlertAction(
                    title: "Delete",
                    style: .destructive
                ) { _ in
                    // We'll implement the delete functionality later
                    print("Delete session: \(sessionItem.id)")
                    completion(true)
                })
                
                self.present(alert, animated: true)
            }
            
            #if DEBUG
            let archiveAction = UIContextualAction(
                style: .normal,
                title: "Archive"
            ) { [weak self] _, _, completion in
                guard let self = self else {
                    completion(false)
                    return
                }
                
                let alert = UIAlertController(
                    title: "Archive Session",
                    message: "Are you sure you want to archive this session?",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(
                    title: "Cancel",
                    style: .cancel
                ) { _ in
                    completion(false)
                })
                
                alert.addAction(UIAlertAction(
                    title: "Archive",
                    style: .default
                ) { _ in
                    self.archiveSession(sessionItem)
                    completion(true)
                })
                
                self.present(alert, animated: true)
            }
            archiveAction.backgroundColor = .systemOrange
            
            return UISwipeActionsConfiguration(actions: [deleteAction, archiveAction])
            #else
            return UISwipeActionsConfiguration(actions: [deleteAction])
            #endif
        }
        
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        
        collectionView.register(SessionCell.self, forCellWithReuseIdentifier: SessionCell.reuseIdentifier)
        
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
        ) { collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: SessionCell.reuseIdentifier,
                for: indexPath
            ) as! SessionCell
            
            switch item {
            case .session(let session):
                if let sessionItem = session as? SessionItem {
                    cell.configure(with: sessionItem)
                } else if let archivedSession = session as? ArchivedSession {
                    // Configure cell for archived session
                    cell.configure(with: archivedSession)
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
            calendar.startOfMonth(for: session.endDate)
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
        fetchNestSessions()
    }
    
    private func fetchNestSessions() {
        Task {
            do {
                filterView.isEnabled = false
                emptyStateView.isHidden = true
                loadingSpinner.startAnimating()
                guard let nestID = NestService.shared.currentNest?.id else {
                    // Show error state for no current nest
                    await MainActor.run {
                        self.allSessions = []
                        self.archivedSessions = []
                        self.emptyStateView.configure(
                            icon: UIImage(systemName: "house.slash"),
                            title: "No Current Nest",
                            subtitle: "Please select a nest to view its sessions."
                        )
                        self.updateEmptyState()
                        self.loadingSpinner.stopAnimating()
                    }
                    return
                }
                
                // Fetch all sessions and archived sessions in parallel
                async let sessionsCollection = sessionService.fetchSessions(nestID: nestID)
                async let archivedSessions = sessionService.fetchArchivedSessions(nestID: nestID)
                
                let (collection, archived) = try await (sessionsCollection, archivedSessions)
                
                await MainActor.run {
                    // Store all sessions
                    filterView.isEnabled = true
                    self.allSessions = collection.upcoming + collection.inProgress + collection.past
                    self.archivedSessions = archived
                    updateEmptyState()
                    self.loadingSpinner.stopAnimating()
                }
            } catch {
                // Handle error
                filterView.isEnabled = false
                print("Error loading sessions: \(error)")
                await MainActor.run {
                    self.loadingSpinner.stopAnimating()
                }
            }
        }
    }
    
    // Add method to refresh data when needed (e.g., after creating a new session)
    func refreshSessions() {
        loadSessions()
    }
    
    private func setupNewSessionButton() {
        ctaButton = NNPrimaryLabeledButton(title: "New Session")
        view.addSubview(ctaButton)
        
        ctaButton.addTarget(self, action: #selector(ctaTapped), for: .touchUpInside)
        
        ctaButton.pinToBottom(
            of: view,
            addBlurEffect: true, 
            blurMaskImage: UIImage(named: "testBG3")!
        )
    }
    
    private func setupEmptyStateView() {
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -44), // Offset for button
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
        return SessionEmptyStateDataSource.nestEmptyState(for: bucket)
    }
    
    @objc private func ctaTapped() {
        let vc = EditSessionViewController()
        vc.delegate = self
        vc.modalPresentationStyle = .pageSheet
        present(vc, animated: true)
    }
}

extension NestSessionsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard case .session(let session) = dataSource.itemIdentifier(for: indexPath) else {
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        }
        
        // Handle both SessionItem and ArchivedSession
        if let sessionItem = session as? SessionItem {
            let editVC = EditSessionViewController(sessionItem: sessionItem)
            editVC.delegate = self
            editVC.modalPresentationStyle = .pageSheet
            present(editVC, animated: true)
        } else if let archivedSession = session as? ArchivedSession {
            // Use the new initializer for ArchivedSession
            let editVC = EditSessionViewController(archivedSession: archivedSession)
            editVC.delegate = self
            editVC.modalPresentationStyle = .pageSheet
            present(editVC, animated: true)
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    
    // Helper method to archive a session
    private func archiveSession(_ session: SessionItem) {
        Task {
            do {
                // Call the service to archive the session
                try await sessionService.archiveSession(session)
                
                // Refresh the sessions list
                await MainActor.run {
                    loadSessions()
                }
            } catch {
                print("Error archiving session: \(error)")
            }
        }
    }
}

extension NestSessionsViewController: SessionFilterViewDelegate {
    func sessionFilterView(_ filterView: SessionFilterView, didSelectFilter filter: SessionService.SessionBucket) {
        currentBucket = filter
        updateDisplayedSessions()
    }
}

// Helper extension
extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

// MARK: - EditSessionViewControllerDelegate
extension NestSessionsViewController: EditSessionViewControllerDelegate {
    func editSessionViewController(_ controller: EditSessionViewController, didCreateSession session: SessionItem) {
        // Refresh sessions to include the new one
        loadSessions()
        
        // Optionally, ensure we're showing the appropriate bucket
        if currentBucket != .upcoming {
            filterView.selectBucket(.upcoming)
        }
    }
    
    func editSessionViewController(_ controller: EditSessionViewController, didUpdateSession session: SessionItem) {
        // Refresh sessions to get the updated data
        loadSessions()
        
        // Determine which bucket the updated session belongs in
        let now = Date()
        let updatedBucket: SessionService.SessionBucket
        
        if session.startDate > now {
            updatedBucket = .upcoming
        } else if session.endDate <= now {
            updatedBucket = .past
        } else {
            updatedBucket = .inProgress
        }
        
        // If the session's bucket is different from current view, switch to it
        if currentBucket != updatedBucket {
            filterView.selectBucket(updatedBucket)
        }
    }
}

extension NestSessionsViewController: CollectionViewLoadable {
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
            
            guard let nestID = NestService.shared.currentNest?.id else { return }
            let collection = try await sessionService.fetchSessions(nestID: nestID)
            
            await MainActor.run {
                self.allSessions = collection.upcoming + collection.inProgress + collection.past
                loadingIndicator.stopAnimating()
            }
            
        } catch {
            await MainActor.run {
                loadingIndicator.stopAnimating()
                Logger.log(level: .error, category: .sessionService, message: "Error loading sessions: \(error.localizedDescription)")
            }
        }
    }
} 
