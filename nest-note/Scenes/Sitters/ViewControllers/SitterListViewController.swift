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

class SitterListViewController: NNViewController, CollectionViewLoadable, UISearchResultsUpdating {
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
    
    private var searchController: UISearchController!

    private let searchBarView: NNSearchBarView = {
        let view = NNSearchBarView(placeholder: "Search for a sitter")
        view.frame.size.height = 60
        return view
    }()

    private var isSearchBarAdded: Bool = false

    // Buttons for pre-iOS 26 versions
    private var addSitterButton: NNPrimaryLabeledButton!

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
        } else if let session = currentSession,
                  let assignedSitter = session.assignedSitter {
            // If no initial sitter but we have an assigned sitter, use that
            selectedSitter = SitterItem(
                id: assignedSitter.id,
                name: assignedSitter.name,
                email: assignedSitter.email
            )
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

        // Setup search based on iOS version
        if displayMode == .selectSitter {
            if #available(iOS 26.0, *) {
                setupSearchController()
            } else {
                // Setup search bar delegate for older iOS versions
                searchBarView.searchBar.delegate = self
            }
        }

        // Setup UI based on iOS version
        if #available(iOS 26.0, *) {
            // Setup toolbar with search placement and add button
            setupToolbar()
        }
    }

    private func setupSearchController() {
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search for a sitter"
        searchController.hidesNavigationBarDuringPresentation = false

        // Setup search bar delegate
        searchController.searchBar.delegate = self
    }

    @available(iOS 26.0, *)
    private func setupToolbar() {
        // Create system add button
        let addBarButtonItem = UIBarButtonItem(systemItem: .add)
        addBarButtonItem.target = self
        addBarButtonItem.action = #selector(addSitterButtonTapped)

        // Setup toolbar items based on display mode
        if displayMode == .selectSitter {
            // Use iOS 26 search placement API
            navigationItem.searchController = searchController
            toolbarItems = [navigationItem.searchBarPlacementBarButtonItem, .flexibleSpace(), addBarButtonItem]
        } else {
            // In default mode, just show the add button
            toolbarItems = [.flexibleSpace(), addBarButtonItem]
        }

        // Enable toolbar
        navigationController?.setToolbarHidden(false, animated: false)
    }

    private func setupOriginalButtons() {
        // Create the original NNPrimaryLabeledButton
        addSitterButton = NNPrimaryLabeledButton(title: "Add Sitter", image: UIImage(systemName: "plus"))
        addSitterButton.addTarget(self, action: #selector(addSitterButtonTapped), for: .touchUpInside)
    }
    
    override func addSubviews() {
        setupCollectionView()

        // Add empty state view
        setupEmptyStateView()

        // Add original button for pre-iOS 26 versions
        if !isAvailableIOS26() {
            setupOriginalButtonLayout()
        }
    }

    private func setupOriginalButtonLayout() {
        // Create the button here since addSubviews() is called before setup()
        setupOriginalButtons()

        guard let addSitterButton = addSitterButton else { return }

        view.addSubview(addSitterButton)
        addSitterButton.pinToBottom(
            of: view,
            addBlurEffect: true,
            blurMaskImage: UIImage(named: "testBG3")!
        )
    }

    // MARK: - UISearchResultsUpdating
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        filterSitters(with: searchText)
    }

    func setupPaletteSearch() {
        addNavigationBarPalette(searchBarView)
        isSearchBarAdded = true
    }

    private func updateSearchBarVisibility() {
        // Only show search bar in selectSitter mode when user has saved sitters (pre-iOS 26)
        if displayMode == .selectSitter && !isAvailableIOS26() {
            let shouldShowSearchBar = !allSitters.isEmpty

            // If we should show search bar but it's not added yet, add it
            if shouldShowSearchBar && !isSearchBarAdded {
                setupPaletteSearch()
            }
        }
    }

    private func isAvailableIOS26() -> Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
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
        collectionView.allowsSelection = true
        view.addSubview(collectionView)

        // Add content insets based on iOS version
        if isAvailableIOS26() {
            // For iOS 26+, account for toolbar
            collectionView.contentInset = UIEdgeInsets(
                top: 20,
                left: 0,
                bottom: 20,
                right: 0
            )
        } else {
            // For pre-iOS 26, account for bottom button
            let buttonHeight: CGFloat = 55
            let buttonPadding: CGFloat = 16
            collectionView.contentInset = UIEdgeInsets(
                top: 20,
                left: 0,
                bottom: buttonHeight + (buttonPadding * 2),
                right: 0
            )
        }
        collectionView.backgroundColor = .systemGroupedBackground
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
            let title = "Saved Sitters"
            headerView.configure(title: title)
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, AnyHashable>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            if let sitter = item as? SitterItem {
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: InviteSitterCell.reuseIdentifier,
                    for: indexPath
                ) as? InviteSitterCell else {
                    fatalError("Could not create new cell")
                }
                
                let isSelected = sitter.id == self?.selectedSitter?.id
                print("DEBUG: Configuring cell for \(sitter.name) - isSelected: \(isSelected), selectedSitter: \(String(describing: self?.selectedSitter?.name))")
                
                cell.configure(
                    name: sitter.name,
                    email: sitter.email,
                    isSelected: isSelected
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

        print("DEBUG: updateEmptyStateVisibility - sittersToCheck.count: \(sittersToCheck.count), shouldShowEmptyState: \(shouldShowEmptyState)")

        // Update empty state message based on search context in selectSitter mode
        let searchText = isAvailableIOS26() ? searchController?.searchBar.text : searchBarView.searchBar.text
        if displayMode == .selectSitter && shouldShowEmptyState && searchText?.isEmpty == false {
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

        // Immediately set collection view visibility without animation first
        collectionView.isHidden = shouldShowEmptyState
        collectionView.alpha = shouldShowEmptyState ? 0.0 : 1.0

        print("DEBUG: collectionView.isHidden: \(collectionView.isHidden), collectionView.alpha: \(collectionView.alpha)")

        // Update empty state visibility with crossfade
        emptyStateView.crossFade(shouldShow: shouldShowEmptyState, duration: 0.3)
    }
    
    
    @objc private func selectSitterButtonTapped() {
        guard let selectedSitter = selectedSitter else { return }
        delegate?.sitterListViewController(didSelectSitter: selectedSitter)
        navigationController?.dismiss(animated: true)
    }
    
    @objc private func addSitterButtonTapped() {
        let addVC = EditSitterViewController()
        addVC.delegate = self
        let navController = UINavigationController(rootViewController: addVC)
        present(navController, animated: true)
    }
    
    @objc private func inviteButtonTapped() {
        if displayMode == .default {
            // In default mode, we want to add a new sitter
            let addVC = EditSitterViewController()
            addVC.delegate = self
            let navController = UINavigationController(rootViewController: addVC)
            present(navController, animated: true)
        } else {
            // In selectSitter mode, we want to select the chosen sitter
            guard let selectedSitter = selectedSitter else { return }
            delegate?.sitterListViewController(didSelectSitter: selectedSitter)
            navigationController?.dismiss(animated: true)
        }
    }
    
    @objc override func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    
    private func updateInviteButtonState() {
        // Keep this method for backward compatibility if needed elsewhere
        if displayMode == .selectSitter {
//            inviteButton?.isEnabled = selectedSitter != nil
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

        // Apply snapshot to update the collection view
        applySnapshot()

        // Update search bar visibility for pre-iOS 26 versions
        updateSearchBarVisibility()
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


// Add UICollectionViewDelegate
extension SitterListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("DEBUG: didSelectItemAt called for row \(indexPath.row), displayMode: \(displayMode)")
        
        // Get the appropriate sitters array based on mode
        let sittersArray = displayMode == .selectSitter ? filteredSitters : allSitters
        guard indexPath.row < sittersArray.count else { return }
        
        let tappedSitter = sittersArray[indexPath.row]
        print("DEBUG: Tapped sitter: \(tappedSitter.name)")
        
        // Always deselect the cell immediately
        collectionView.deselectItem(at: indexPath, animated: true)
        
        if displayMode == .default {
            // In default mode, show EditSitterViewController with populated data
            let editVC = EditSitterViewController(sitter: tappedSitter)
            editVC.delegate = self
            let navController = UINavigationController(rootViewController: editVC)
            present(navController, animated: true)
            return
        }
        
        // SelectSitter mode behavior
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
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
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
        print("DEBUG: updateSitterSelection called")
        print("DEBUG: tappedSitter: \(tappedSitter.name)")
        
        // Toggle selection
        if selectedSitter?.id == tappedSitter.id {
            print("DEBUG: Deselecting sitter")
            selectedSitter = nil
        } else {
            print("DEBUG: Selecting new sitter: \(tappedSitter.name)")
            selectedSitter = tappedSitter
        }
        
        print("DEBUG: After selection, selectedSitter: \(String(describing: selectedSitter?.name))")
        
        // If the session has an invite, delete it, so we can
        // generate a new invite for the newly selected sitter
        deleteSessionInvite()
        currentSession?.assignedSitter = nil
        
        // Force reconfigure all cells to update selection display
        var currentSnapshot = dataSource.snapshot()
        if currentSnapshot.sectionIdentifiers.contains(.sitters) {
            let allSitterItems = currentSnapshot.itemIdentifiers(inSection: .sitters)
            currentSnapshot.reconfigureItems(allSitterItems)
            dataSource.apply(currentSnapshot, animatingDifferences: false)
        }
        
        // Always deselect the cell to remove the persistent highlight
        collectionView.deselectItem(at: indexPath, animated: true)
        
        // If in selectSitter mode, dismiss the search keyboard and auto-select after delay
        if displayMode == .selectSitter {
            if isAvailableIOS26() {
                searchController?.searchBar.resignFirstResponder()
            } else {
                searchBarView.searchBar.resignFirstResponder()
            }

            // Auto-dismiss with delay if a sitter was selected (not deselected)
            if selectedSitter != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    guard let self = self, let selectedSitter = self.selectedSitter else { return }
                    self.delegate?.sitterListViewController(didSelectSitter: selectedSitter)
                    self.navigationController?.dismiss(animated: true)
                }
            }
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

// MARK: - AddSitterViewControllerDelegate
extension SitterListViewController: AddSitterViewControllerDelegate {
    func addSitterViewController(_ controller: EditSitterViewController, didAddSitter sitter: SitterItem) {
        // Dismiss the add sitter view controller
        controller.dismiss(animated: true)
        
        // Show success toast
        showToast(text: "Sitter added successfully")
        
        // Refresh the list to show the new sitter
        Task {
            await loadData()
        }
    }
    
    func addSitterViewControllerDidCancel(_ controller: EditSitterViewController) {
        controller.dismiss(animated: true)
    }
}

 
