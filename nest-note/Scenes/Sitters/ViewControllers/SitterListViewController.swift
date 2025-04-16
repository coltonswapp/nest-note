import UIKit

// Import NestService to access SavedSitter
import Foundation

protocol SitterListViewControllerDelegate: AnyObject {
    func sitterListViewController(didSelectSitter sitter: SitterItem)
    func didDeleteSitterInvite()
}

// Define the display mode enum
enum SitterListDisplayMode {
    case `default`    // Just show the list of sitters
    case selectSitter // Allow selecting a sitter (like InviteSitterViewController)
}

// Convert between SitterItem and SavedSitter
extension SitterItem {
    init(from savedSitter: NestService.SavedSitter) {
        self.id = savedSitter.id
        self.name = savedSitter.name
        // Decode the percent-encoded email
        self.email = savedSitter.email.removingPercentEncoding ?? savedSitter.email
    }
    
    func toSavedSitter() -> NestService.SavedSitter {
        return NestService.SavedSitter(
            id: id,
            name: name,
            // Encode the email for storage
            email: email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
        )
    }
}

class SitterListViewController: NNViewController, CollectionViewLoadable {
    // MARK: - Properties
    private var currentSession: SessionItem?
    private var selectedSitter: SitterItem?
    private var dataSource: UICollectionViewDiffableDataSource<Section, AnyHashable>!
    private var sitters: [SitterItem] = []
    
    // MARK: - CollectionViewLoadable Properties
    var loadingIndicator: UIActivityIndicatorView!
    var refreshControl: UIRefreshControl!
    
    // MARK: - UI Elements
    var collectionView: UICollectionView!
    
    private let searchBarView: NNSearchBarView = {
        let view = NNSearchBarView(placeholder: "Search for a sitter")
        view.frame.size.height = 60
        return view
    }()
    
    private var inviteButton: NNPrimaryLabeledButton!
    private let initialSelectedSitter: SitterItem?
    private let displayMode: SitterListDisplayMode
    
    // Add empty state view
    private lazy var emptyStateView: NNEmptyStateView = {
        // Configure based on display mode
        let icon = UIImage(systemName: "person.2.slash")
        let title = displayMode == .default ? "No Sitters Yet" : "No Sitters Found"
        let subtitle = displayMode == .default ? 
            "Add your first sitter by tapping the button below" : 
            "Try adjusting your search or add a new sitter"
        
        let emptyView = NNEmptyStateView(
            icon: icon,
            title: title,
            subtitle: subtitle
        )
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.isHidden = true
        emptyView.alpha = 0 // Start with alpha 0 for fade-in animation
        
        return emptyView
    }()
    
    enum Section: Hashable {
        case inviteStatus
        case sitters
    }

    private var allSitters: [SitterItem] = []
    private var filteredSitters: [SitterItem] = []
    
    // used to determine whether can or cannot send invite
    private var isEditingSession: Bool
    
    weak var delegate: SitterListViewControllerDelegate?
    
    // MARK: - Initialization
    init(displayMode: SitterListDisplayMode = .default, selectedSitter: SitterItem? = nil, session: SessionItem? = nil, isEditingSession: Bool = true) {
        self.displayMode = displayMode
        self.initialSelectedSitter = selectedSitter
        self.currentSession = session
        self.isEditingSession = isEditingSession
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set initial selection first
        if let sitter = initialSelectedSitter {
            selectedSitter = sitter
            updateInviteButtonState()
        } else if let session = currentSession,
                  let assignedSitter = session.assignedSitter {
            // If no initial sitter but we have an assigned sitter, use that
            selectedSitter = SitterItem(
                id: assignedSitter.id,
                name: assignedSitter.name,
                email: assignedSitter.email
            )
            updateInviteButtonState()
        }
        
        // Setup loading indicator and refresh control
        setupLoadingIndicator()
        setupRefreshControl()
        
        // Then load sitters and apply snapshot
        Task {
            await loadData()
        }
    }
    
    override func setup() {
        // Set title based on mode
        title = displayMode == .default ? "Sitters" : "Select a Sitter"
        
        // Setup search bar if in selectSitter mode
        if displayMode == .selectSitter {
            searchBarView.searchBar.delegate = self
        }
    }
    
    override func addSubviews() {
        // Add search bar if in selectSitter mode
        if displayMode == .selectSitter {
            setupPaletteSearch()
        }
        
        setupCollectionView()
        setupInviteButton()
        
        // Add empty state view
        setupEmptyStateView()
    }
    
    func setupPaletteSearch() {
        addNavigationBarPalette(searchBarView)
    }
    
    override func setupNavigationBarButtons() {
        let closeButton = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeButtonTapped))
        let buttons = [closeButton]
        buttons.forEach { $0.tintColor = .label }
        navigationItem.rightBarButtonItems = buttons
        navigationController?.navigationBar.tintColor = NNColors.primary
    }
    
    private func setupCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        
        // Enable swipe actions for deleting sitters
        if displayMode == .default {
            config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                guard let self = self else { return nil }
                
                // Get the section
                let sectionIdentifiers = self.dataSource.snapshot().sectionIdentifiers
                guard indexPath.section < sectionIdentifiers.count else { return nil }
                
                let section = sectionIdentifiers[indexPath.section]
                
                // Only allow deletion in the sitters section
                guard section == .sitters else { return nil }
                
                // Get the appropriate sitters array based on mode
                let sittersArray = self.displayMode == .selectSitter ? self.filteredSitters : self.allSitters
                guard indexPath.row < sittersArray.count else { return nil }
                
                let sitter = sittersArray[indexPath.row]
                
                // Create delete action
                let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
                    guard let self = self else {
                        completion(false)
                        return
                    }
                    
                    // Show confirmation alert
                    let alert = UIAlertController(
                        title: "Delete Sitter",
                        message: "Are you sure you want to delete \(sitter.name)?",
                        preferredStyle: .alert
                    )
                    
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        completion(false)
                    })
                    
                    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                        // Delete the sitter
                        self.deleteSitter(sitter)
                        completion(true)
                    })
                    
                    self.present(alert, animated: true)
                }
                
                return UISwipeActionsConfiguration(actions: [deleteAction])
            }
        }
        
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.allowsSelection = displayMode == .selectSitter
        view.addSubview(collectionView)
        
        // Add content insets
        let buttonHeight: CGFloat = 55
        let buttonPadding: CGFloat = 16
        collectionView.contentInset = UIEdgeInsets(
            top: 20,
            left: 0,
            bottom: buttonHeight + (buttonPadding * 2),
            right: 0
        )
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.register(InviteStatusCell.self, forCellWithReuseIdentifier: InviteStatusCell.reuseIdentifier)
        collectionView.register(InviteSitterCell.self, forCellWithReuseIdentifier: InviteSitterCell.reuseIdentifier)
        collectionView.register(
            NNSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "SectionHeader"
        )
        collectionView.delegate = self
        
        // Configure datasource and apply initial data
        configureDataSource()
        applySnapshot(animatingDifferences: false)
    }
    
    private func configureDataSource() {
        // Create header registration
        let headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] (headerView, string, indexPath) in
            guard let section = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            let title = section == .inviteStatus ? "Selected Sitter" : "Available Sitters"
            headerView.configure(title: title)
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, AnyHashable>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            if let selectedSitter = item as? SelectedSitterItem {
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: InviteStatusCell.reuseIdentifier,
                    for: indexPath
                ) as? InviteStatusCell else {
                    fatalError("Could not create new cell")
                }
                
                cell.delegate = self
                
                // Get invite status and code for the current session
                if let session = self?.currentSession,
                   let assignedSitter = session.assignedSitter {
                    // If we have an invite ID, include the code
                    if let inviteID = assignedSitter.inviteID,
                       let code = inviteID.split(separator: "-").last {
                        cell.configure(
                            with: selectedSitter.sitter,
                            inviteStatus: assignedSitter.inviteStatus,
                            inviteCode: String(code),
                            isEditingSession: self?.isEditingSession ?? true
                        )
                    } else {
                        // No invite yet, but we still have the assigned sitter status
                        cell.configure(
                            with: selectedSitter.sitter,
                            inviteStatus: assignedSitter.inviteStatus,
                            isEditingSession: self?.isEditingSession ?? true
                        )
                    }
                } else {
                    // No assigned sitter yet
                    cell.configure(
                        with: selectedSitter.sitter,
                        inviteStatus: .none,
                        isEditingSession: self?.isEditingSession ?? true
                    )
                }
                
                return cell
            } else if let sitter = item as? SitterItem {
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: InviteSitterCell.reuseIdentifier,
                    for: indexPath
                ) as? InviteSitterCell else {
                    fatalError("Could not create new cell")
                }
                
                cell.configure(
                    name: sitter.name,
                    email: sitter.email,
                    isSelected: sitter.id == self?.selectedSitter?.id
                )
                
                return cell
            }
            
            fatalError("Unknown item type")
        }
        
        // Set supplementary view provider
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            return collectionView.dequeueConfiguredReusableSupplementary(
                using: headerRegistration,
                for: indexPath
            )
        }
    }
    
    private func applySnapshot(animatingDifferences: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, AnyHashable>()
        
        // Add invite status section if we have a selected sitter
        if let selectedSitter = selectedSitter {
            snapshot.appendSections([.inviteStatus])
            snapshot.appendItems([SelectedSitterItem(sitter: selectedSitter)], toSection: .inviteStatus)
        }
        
        // Add sitters section if we have sitters
        if !sitters.isEmpty {
            snapshot.appendSections([.sitters])
            snapshot.appendItems(sitters, toSection: .sitters)
        }
        
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
        
        // Update empty state visibility
        updateEmptyStateVisibility()
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
    
    private func updateEmptyStateVisibility() {
        // Only show empty state when there are no sitters
        let sittersToCheck = displayMode == .selectSitter ? filteredSitters : allSitters
        let shouldShowEmptyState = sittersToCheck.isEmpty
        
        // Update empty state message based on search context in selectSitter mode
        if displayMode == .selectSitter && shouldShowEmptyState && searchBarView.searchBar.text?.isEmpty == false {
            // If we're searching and found nothing
            emptyStateView.configure(
                icon: UIImage(systemName: "magnifyingglass"),
                title: "No Results",
                subtitle: "No sitters match your search criteria"
            )
        } else {
            // Default empty state
            let title = displayMode == .default ? "No Sitters Yet" : "No Sitters Found"
            let subtitle = displayMode == .default ? 
                "Add your first sitter by tapping the button below" : 
                "Try adjusting your search or add a new sitter"
            
            emptyStateView.configure(
                icon: UIImage(systemName: "person.2.slash"),
                title: title,
                subtitle: subtitle
            )
        }
        
        // Update visibility based on data state
        UIView.animate(withDuration: 0.3) {
            self.emptyStateView.alpha = shouldShowEmptyState ? 1.0 : 0.0
            self.collectionView.alpha = shouldShowEmptyState ? 0.0 : 1.0
        }
        
        // Update hidden state after animation
        emptyStateView.isHidden = !shouldShowEmptyState
        collectionView.isHidden = shouldShowEmptyState
    }
    
    private func setupInviteButton() {
        // Set button title based on mode
        let buttonTitle = displayMode == .default ? "Add a New Sitter" : "Select Sitter"
        inviteButton = NNPrimaryLabeledButton(title: buttonTitle)
        inviteButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        inviteButton.addTarget(self, action: #selector(inviteButtonTapped), for: .touchUpInside)
        
        // In default mode, the button is always enabled
        // In selectSitter mode, the button is only enabled when a sitter is selected
        if displayMode == .default {
            inviteButton.isEnabled = true
        } else {
            updateInviteButtonState()
        }
    }
    
    @objc private func inviteButtonTapped() {
        if displayMode == .default {
            // In default mode, we want to add a new sitter
            let addVC = AddSitterViewController()
            addVC.delegate = self
            let navController = UINavigationController(rootViewController: addVC)
            present(navController, animated: true)
        } else {
            // In selectSitter mode, we want to select the chosen sitter
            guard let selectedSitter = selectedSitter else { return }
            delegate?.sitterListViewController(didSelectSitter: selectedSitter)
            dismiss(animated: true)
        }
    }
    
    @objc override func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    private func updateInviteButtonState() {
        // Only update button state in selectSitter mode
        if displayMode == .selectSitter {
            inviteButton.isEnabled = selectedSitter != nil
        }
    }
    
    // MARK: - CollectionViewLoadable Implementation
    func handleLoadedData() {
        // Initialize filteredSitters if in selectSitter mode
        if displayMode == .selectSitter {
            filteredSitters = allSitters
            sitters = filteredSitters
        } else {
            sitters = allSitters
        }
        
        // Update UI based on data
        if sitters.isEmpty {
            emptyStateView.isHidden = false
            collectionView.isHidden = true
        } else {
            emptyStateView.isHidden = true
            collectionView.isHidden = false
            applySnapshot()
        }
    }
    
    func loadData(showLoadingIndicator: Bool = true) async {
        do {
            if showLoadingIndicator {
                await MainActor.run {
                    loadingIndicator.startAnimating()
                    collectionView.isHidden = true
                    emptyStateView.isHidden = true
                }
            }
            
            // Fetch saved sitters from NestService
            let savedSitters = try await NestService.shared.fetchSavedSitters()
            
            await MainActor.run {
                self.allSitters = savedSitters.map { SitterItem(from: $0) }
                self.handleLoadedData()
                self.loadingIndicator.stopAnimating()
            }
        } catch {
            await MainActor.run {
                self.loadingIndicator.stopAnimating()
                self.emptyStateView.isHidden = false
                self.collectionView.isHidden = true
                Logger.log(level: .error, category: .general, message: "Error loading sitters: \(error.localizedDescription)")
            }
        }
    }
    
    private func filterSitters(with searchText: String) {
        if searchText.isEmpty {
            filteredSitters = allSitters
        } else {
            filteredSitters = allSitters.filter { sitter in
                sitter.name.localizedCaseInsensitiveContains(searchText) ||
                sitter.email.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Update the main sitters array based on display mode
        if displayMode == .selectSitter {
            sitters = filteredSitters
        } else {
            sitters = allSitters
        }
        
        applySnapshot()
        
        // Update empty state after filtering
        updateEmptyStateVisibility()
    }
    
    // Add method to save a sitter to Firestore
    private func saveSitter(_ sitter: SitterItem) {
        Task {
            do {
                // Convert SitterItem to SavedSitter and save it
                let savedSitter = sitter.toSavedSitter()
                try await NestService.shared.addSavedSitter(savedSitter)
                
                // Reload sitters to update the UI
                await loadData()
            } catch {
                print("Failed to save sitter: \(error.localizedDescription)")
                
                // Show error alert
                await MainActor.run {
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to save sitter: \(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
    
    // Add method to delete a sitter from Firestore
    private func deleteSitter(_ sitter: SitterItem) {
        Task {
            do {
                // Convert SitterItem to SavedSitter and delete it
                let savedSitter = sitter.toSavedSitter()
                try await NestService.shared.deleteSavedSitter(savedSitter)
                
                // Reload sitters to update the UI
                await loadData()
            } catch {
                print("Failed to delete sitter: \(error.localizedDescription)")
                
                // Show error alert
                await MainActor.run {
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to delete sitter: \(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
}

// Helper class to represent a selected sitter in the invite status section
class SelectedSitterItem: Hashable {
    let id = UUID()
    let sitter: SitterItem
    
    init(sitter: SitterItem) {
        self.sitter = sitter
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SelectedSitterItem, rhs: SelectedSitterItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// Add UICollectionViewDelegate
extension SitterListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Get the section
        let sectionIdentifiers = dataSource.snapshot().sectionIdentifiers
        guard indexPath.section < sectionIdentifiers.count else { return }
        
        let section = sectionIdentifiers[indexPath.section]
        
        // Only handle selection in the recent section
        guard section == .sitters else {
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        }
        
        // Get the appropriate sitters array based on mode
        let sittersArray = displayMode == .selectSitter ? filteredSitters : allSitters
        guard indexPath.row < sittersArray.count else { return }
        
        let tappedSitter = sittersArray[indexPath.row]
        
        // Check if we have an active invite
        if let session = currentSession, 
           let sitter = session.assignedSitter,
           sitter.inviteStatus != .none && 
           sitter.inviteStatus != .declined && 
           sitter.inviteStatus != .cancelled {
            // Show confirmation alert
            let alert = UIAlertController(
                title: "Change Sitter?",
                message: "This session already has an active invite. Changing the sitter will cancel the current invite. Are you sure you want to proceed?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                collectionView.deselectItem(at: indexPath, animated: true)
            })
            
            alert.addAction(UIAlertAction(title: "Change Sitter", style: .destructive) { [weak self] _ in
                self?.updateSitterSelection(tappedSitter, in: collectionView, at: indexPath)
            })
            
            present(alert, animated: true)
            return
        }
        
        // If no active invite or user confirmed, update the selection
        updateSitterSelection(tappedSitter, in: collectionView, at: indexPath)
    }
    
    private func updateSitterSelection(_ tappedSitter: SitterItem, in collectionView: UICollectionView, at indexPath: IndexPath) {
        // Store previous selection before updating
        let previousSitter = selectedSitter
        
        // Toggle selection
        if selectedSitter?.id == tappedSitter.id {
            selectedSitter = nil
        } else {
            selectedSitter = tappedSitter
        }
        
        updateInviteButtonState()
        
        // If the session has an invite, delete it, so we can
        // generate a new invite for the newly selected sitter
        deleteSessionInvite()
        currentSession?.assignedSitter = nil
        
        // First update the cells in the current snapshot
        var currentSnapshot = dataSource.snapshot()
        
        // Reconfigure all sitters to ensure consistent selection state
        let sittersToReconfigure = currentSnapshot.itemIdentifiers(inSection: .sitters)
        currentSnapshot.reconfigureItems(sittersToReconfigure)
        
        
        // Apply the current snapshot to update cell configurations
        dataSource.apply(currentSnapshot, animatingDifferences: true) {
            // After cell configurations are updated, then update sections if needed
            if self.displayMode == .selectSitter {
                self.applySnapshot()
            }
        }
        
        // Always deselect the cell to remove the persistent highlight
        collectionView.deselectItem(at: indexPath, animated: true)
        
        
        
        // If in selectSitter mode, dismiss the search keyboard
        if displayMode == .selectSitter {
            searchBarView.searchBar.resignFirstResponder()
        }
    }
    
    func deleteSessionInvite() {
        if currentSession?.assignedSitter != nil {
            guard let sessionId = currentSession?.id,
                  let inviteId = currentSession?.assignedSitter?.inviteID else { return }
            
            Task {
                try await SessionService.shared.deleteInvite(inviteID: inviteId, sessionID: sessionId)
            }
        }
    }
    
    func shouldHighlightItem(at indexPath: IndexPath, in collectionView: UICollectionView) -> Bool {
        return true
    }
}

// Add UISearchBarDelegate only for selectSitter mode
extension SitterListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterSitters(with: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        searchBar.showsCancelButton = true
        filterSitters(with: "")
    }
}

class InviteStatusCell: UICollectionViewListCell {
    static let reuseIdentifier = "InviteStatusCell"
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var sendInviteButton: NNSmallPrimaryButton!
    
    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    weak var delegate: InviteStatusCellDelegate?
    private var inviteCode: String?
    private var isEditingSession: Bool = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Initialize the button with default state
        sendInviteButton = NNSmallPrimaryButton(
            title: "SEND INVITE",
            image: UIImage(systemName: "envelope.fill"),
            backgroundColor: NNColors.primary.withAlphaComponent(0.15),
            foregroundColor: NNColors.primary
        )
        sendInviteButton.translatesAutoresizingMaskIntoConstraints = false
        sendInviteButton.addTarget(self, action: #selector(sendInviteButtonTapped), for: .touchUpInside)
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(containerView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(sendInviteButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            nameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            sendInviteButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            sendInviteButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            sendInviteButton.heightAnchor.constraint(equalToConstant: 46),
            sendInviteButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8)
        ])
    }
    
    @objc private func sendInviteButtonTapped() {
        if let code = inviteCode {
            delegate?.inviteStatusCell(self, didTapViewInviteWithCode: code)
        } else {
            delegate?.inviteStatusCellDidTapSendInvite(self)
        }
    }
    
    func configure(with sitter: SitterItem, inviteStatus: SessionInviteStatus = .none, inviteCode: String? = nil, isEditingSession: Bool = true) {
        nameLabel.text = sitter.name
        self.inviteCode = inviteCode
        self.isEditingSession = isEditingSession
        
        // Hide the invite button if we're not editing an existing session
        sendInviteButton.isHidden = !isEditingSession
        sendInviteButton.isEnabled = true
        
        // Configure button based on invite status
        switch inviteStatus {
        case .none:
            sendInviteButton.configureButton(
                title: "SEND INVITE",
                image: UIImage(systemName: "arrow.up.circle.fill"),
                imagePlacement: .right,
                foregroundColor: NNColors.primary
            )
            sendInviteButton.backgroundColor = NNColors.primary.withAlphaComponent(0.15)
            
        case .invited:
            sendInviteButton.configureButton(
                title: "INVITE SENT",
                image: UIImage(systemName: inviteStatus.icon),
                imagePlacement: .right,
                foregroundColor: UIColor.secondaryLabel
            )
            sendInviteButton.backgroundColor = UIColor.tertiarySystemGroupedBackground
            
        case .accepted:
            sendInviteButton.configureButton(
                title: "ACCEPTED",
                image: UIImage(systemName: inviteStatus.icon),
                imagePlacement: .right,
                foregroundColor: UIColor.secondaryLabel
            )
            sendInviteButton.backgroundColor = UIColor.tertiarySystemGroupedBackground
            
        case .declined:
            sendInviteButton.configureButton(
                title: "DECLINED",
                image: UIImage(systemName: inviteStatus.icon),
                imagePlacement: .right,
                foregroundColor: UIColor.secondaryLabel
            )
            sendInviteButton.backgroundColor = UIColor.tertiarySystemGroupedBackground
            sendInviteButton.isEnabled = false
            
        case .cancelled:
            sendInviteButton.configureButton(
                title: "CANCELLED",
                image: UIImage(systemName: inviteStatus.icon),
                imagePlacement: .right,
                foregroundColor: UIColor.secondaryLabel
            )
            sendInviteButton.backgroundColor = UIColor.tertiarySystemGroupedBackground
        }
    }
}

// MARK: - InviteSitterViewControllerDelegate
extension SitterListViewController: InviteSitterViewControllerDelegate {
    func inviteDetailViewControllerDidDeleteInvite() {
        delegate?.didDeleteSitterInvite()
    }
    
    func inviteSitterViewControllerDidSendInvite(to sitter: SitterItem) {
        delegate?.sitterListViewController(didSelectSitter: sitter)
    }
    
    func inviteSitterViewControllerDidCancel(_ controller: InviteSitterViewController) {
        // Just pop back to the sitter list
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - AddSitterViewControllerDelegate
extension SitterListViewController: AddSitterViewControllerDelegate {
    func addSitterViewController(_ controller: AddSitterViewController, didAddSitter sitter: SitterItem) {
        // Dismiss the add sitter view controller
        controller.dismiss(animated: true)
        
        // Show success toast
        showToast(text: "Sitter added successfully")
        
        // Refresh the list to show the new sitter
        Task {
            await loadData()
        }
    }
    
    func addSitterViewControllerDidCancel(_ controller: AddSitterViewController) {
        controller.dismiss(animated: true)
    }
}

// MARK: - InviteStatusCellDelegate
extension SitterListViewController: InviteStatusCellDelegate {
    func inviteStatusCellDidTapSendInvite(_ cell: InviteStatusCell) {
        guard let selectedSitter = selectedSitter, let session = currentSession else { return }
        
        // Create and configure the InviteSitterViewController
        let inviteSitterVC = InviteSitterViewController(sitter: selectedSitter, session: session)
        inviteSitterVC.delegate = self
        
        // Push it onto the navigation stack
        navigationController?.pushViewController(inviteSitterVC, animated: true)
    }
    
    func inviteStatusCell(_ cell: InviteStatusCell, didTapViewInviteWithCode code: String) {
        let inviteDetailVC = InviteDetailViewController()
        inviteDetailVC.delegate = self
        inviteDetailVC.configure(with: code, sessionID: currentSession!.id)
        navigationController?.pushViewController(inviteDetailVC, animated: true)
    }
    
    func inviteStatusCellDidTapDeleteInvite(_ cell: InviteStatusCell) {
        // Implementation needed
    }
} 
