import UIKit

protocol InviteSitterViewControllerDelegate: AnyObject {
    func inviteSitterViewController(_ controller: InviteSitterViewController, didSelectSitter sitter: SitterItem)
}

class InviteSitterViewController: NNViewController {
    
    private let searchBarView: NNSearchBarView = {
        let view = NNSearchBarView(placeholder: "Search for a sitter")
        view.frame.size.height = 60
        return view
    }()
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, SitterItem>!
    private var inviteButton: NNPrimaryLabeledButton!
    private var selectedSitter: SitterItem?
    private let initialSelectedSitter: SitterItem?
    
    enum Section {
        case recent
    }

    private var allSitters: [SitterItem] = []
    private var filteredSitters: [SitterItem] = []
    
    // Replace sampleSitters with this larger dataset
    private let sampleSitters = [
        SitterItem(id: "1", name: "Sarah Johnson", email: "sarah.j@gmail.com"),
        SitterItem(id: "2", name: "Mike Peters", email: "mike.peters@yahoo.com"),
        SitterItem(id: "3", name: "Emma Wilson", email: "emma.w@outlook.com"),
        SitterItem(id: "4", name: "Alex Thompson", email: "alex.t@gmail.com"),
        SitterItem(id: "5", name: "Lisa Chen", email: "lisa.chen@outlook.com"),
        SitterItem(id: "6", name: "David Miller", email: "david.m@gmail.com"),
        SitterItem(id: "7", name: "Rachel Green", email: "rachel.g@yahoo.com"),
        SitterItem(id: "8", name: "James Wilson", email: "james.w@gmail.com"),
        SitterItem(id: "9", name: "Sophie Brown", email: "sophie.b@outlook.com"),
        SitterItem(id: "10", name: "Oliver Smith", email: "oliver.s@gmail.com"),
        SitterItem(id: "11", name: "Emily Davis", email: "emily.d@yahoo.com"),
        SitterItem(id: "12", name: "Michael Chang", email: "michael.c@gmail.com"),
        SitterItem(id: "13", name: "Isabella Rodriguez", email: "bella.r@outlook.com")
    ]
    
    weak var delegate: InviteSitterViewControllerDelegate?
    
    init(selectedSitter: SitterItem? = nil) {
        self.initialSelectedSitter = selectedSitter
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
        }
        
        // Then load sitters and apply snapshot
        loadSitters()
    }
    
    override func setup() {
        title = "Add a Sitter"
        searchBarView.searchBar.delegate = self
        
        // Initialize sitters
//        allSitters = sampleSitters
//        filteredSitters = allSitters
    }
    
    override func addSubviews() {
        setupPaletteSearch()
        setupCollectionView()
        setupInviteButton()
    }
    
    func setupPaletteSearch() {
        addNavigationBarPalette(searchBarView)
    }
    
    override func setupNavigationBarButtons() {
        let closeButton = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeButtonTapped))
        let buttons = [closeButton]
        buttons.forEach { $0.tintColor = .label }
        navigationItem.rightBarButtonItems = buttons
    }
    
    private func setupCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.addSubview(collectionView)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
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
        collectionView.register(InviteSitterCell.self, forCellWithReuseIdentifier: InviteSitterCell.reuseIdentifier)
        collectionView.delegate = self
        
        // Configure datasource and apply initial data
        configureDataSource()
        applySnapshot(animatingDifferences: false)
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, SitterItem>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: InviteSitterCell.reuseIdentifier,
                for: indexPath
            ) as! InviteSitterCell
            
            cell.configure(
                name: item.name,
                email: item.email,
                isSelected: item.id == self?.selectedSitter?.id
            )
            return cell
        }
        
        let headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] headerView, elementKind, indexPath in
            guard let self = self else { return }
            
            headerView.configure(title: "RECENT")
        }
        
        // Add supplementary view provider
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            return collectionView.dequeueConfiguredReusableSupplementary(
                using: headerRegistration,
                for: indexPath
            )
        }
    }
    
    private func applySnapshot(animatingDifferences: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, SitterItem>()
        snapshot.appendSections([.recent])
        snapshot.appendItems(filteredSitters, toSection: .recent)
        
        // First apply the snapshot
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences) { [weak self] in
            // Then update the UI to reflect selection
            guard let self = self,
                  let selectedSitter = self.selectedSitter,
                  let index = self.filteredSitters.firstIndex(where: { $0.id == selectedSitter.id }) else { return }
            
            DispatchQueue.main.async {
                let indexPath = IndexPath(row: index, section: 0)
                self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)
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
        applySnapshot()
    }
    
    private func setupInviteButton() {
        inviteButton = NNPrimaryLabeledButton(title: "Select Sitter")
        inviteButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        inviteButton.addTarget(self, action: #selector(inviteButtonTapped), for: .touchUpInside)
    }
    
    @objc private func inviteButtonTapped() {
        guard let selectedSitter = selectedSitter else { return }
        delegate?.inviteSitterViewController(self, didSelectSitter: selectedSitter)
        dismiss(animated: true)
    }
    
    private func updateInviteButtonState() {
        inviteButton.isEnabled = selectedSitter != nil
    }
    
    private func loadSitters() {
        Task {
            do {
                allSitters = sampleSitters
                filteredSitters = allSitters
                applySnapshot()
            } catch {
//                Logger.log(level: .error, category: .sitterService, message: "Failed to load sitters: \(error.localizedDescription)")
            }
        }
    }
}

// Add UICollectionViewDelegate
extension InviteSitterViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let tappedSitter = dataSource.itemIdentifier(for: indexPath) else { return }
        
        // Store previous selection before updating
        let previousSitter = selectedSitter
        
        // Toggle selection
        if selectedSitter?.id == tappedSitter.id {
            selectedSitter = nil
        } else {
            selectedSitter = tappedSitter
        }
        
        // Update UI
        var snapshot = dataSource.snapshot()
        
        // Always reconfigure the tapped cell
        snapshot.reconfigureItems([tappedSitter])
        
        // If there was a previous selection, reconfigure that cell too
        if let previous = previousSitter, previous.id != tappedSitter.id {
            snapshot.reconfigureItems([previous])
        }
        
        dataSource.apply(snapshot, animatingDifferences: true)
        
        // Always deselect the cell to remove the persistent highlight
        collectionView.deselectItem(at: indexPath, animated: true)
        
        updateInviteButtonState()
        searchBarView.searchBar.resignFirstResponder()
    }
    
    func shouldHighlightItem(at indexPath: IndexPath, in collectionView: UICollectionView) -> Bool {
        return true
    }
}

// Add UISearchBarDelegate
extension InviteSitterViewController: UISearchBarDelegate {
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
