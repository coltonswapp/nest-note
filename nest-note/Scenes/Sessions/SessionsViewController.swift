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
    private var currentBucket: SessionService.SessionBucket = .inProgress
    
    private var filteredSessions: [SessionItem] {
        switch currentBucket {
        case .past:
            return allSessions
                .filter { $0.status == .completed }
                .sorted { $0.endDate > $1.endDate }
        case .inProgress:
            return allSessions
                .filter { $0.status == .inProgress || $0.status == .extended }
                .sorted { $0.endDate < $1.endDate }
        case .upcoming:
            return allSessions
                .filter { $0.status == .upcoming }
                .sorted { $0.startDate < $1.startDate }
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
                cell.configure(with: session)
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
        fetchNestSessions()
    }
    
    private func fetchNestSessions() {
        Task {
            do {
                guard let nestID = NestService.shared.currentNest?.id else {
                    // Show error state for no current nest
                    await MainActor.run {
                        self.allSessions = []
                        self.emptyStateView.configure(
                            icon: UIImage(systemName: "house.slash"),
                            title: "No Current Nest",
                            subtitle: "Please select a nest to view its sessions."
                        )
                        self.updateEmptyState()
                    }
                    return
                }
                
                // Fetch all sessions once
                let collection = try await sessionService.fetchSessions(nestID: nestID)
                await MainActor.run {
                    // Store all sessions
                    self.allSessions = collection.upcoming + collection.inProgress + collection.past
                    updateEmptyState()
                }
            } catch {
                // Handle error
                print("Error loading sessions: \(error)")
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
        
        let editVC = EditSessionViewController(sessionItem: session)
        editVC.delegate = self
        editVC.modalPresentationStyle = .pageSheet
        present(editVC, animated: true)
        
        collectionView.deselectItem(at: indexPath, animated: true)
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
