import UIKit

protocol InviteSitterViewControllerDelegate: AnyObject {
    func inviteSitterViewController(_ controller: InviteSitterViewController, didSelectSitter sitter: SitterItem)
}

class InviteSitterViewController: NNViewController {
    
    private let searchBarView: NNSearchBarView = {
        let view = NNSearchBarView()
        view.frame.size.height = 50
        return view
    }()
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, SitterItem>!
    private var inviteButton: NNPrimaryLabeledButton!
    private var selectedSitter: SitterItem?
    
    enum Section {
        case recent
    }

    private var allSitters: [SitterItem] = []
    private var filteredSitters: [SitterItem] = []
    
    // Replace sampleSitters with this larger dataset
    private let sampleSitters = [
        SitterItem(name: "Sarah Johnson", email: "sarah.j@gmail.com"),
        SitterItem(name: "Mike Peters", email: "mike.peters@yahoo.com"),
        SitterItem(name: "Emma Wilson", email: "emma.w@outlook.com"),
        SitterItem(name: "Alex Thompson", email: "alex.t@gmail.com"),
        SitterItem(name: "Lisa Chen", email: "lisa.chen@outlook.com"),
        SitterItem(name: "David Miller", email: "david.m@gmail.com"),
        SitterItem(name: "Rachel Green", email: "rachel.g@yahoo.com"),
        SitterItem(name: "James Wilson", email: "james.w@gmail.com"),
        SitterItem(name: "Sophie Brown", email: "sophie.b@outlook.com"),
        SitterItem(name: "Oliver Smith", email: "oliver.s@gmail.com"),
        SitterItem(name: "Emily Davis", email: "emily.d@yahoo.com"),
        SitterItem(name: "Michael Chang", email: "michael.c@gmail.com"),
        SitterItem(name: "Isabella Rodriguez", email: "bella.r@outlook.com")
    ]
    
    weak var delegate: InviteSitterViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        filterSitters(with: "")
        updateInviteButtonState()
    }
    
    override func setup() {
        title = "Add a Sitter"
        searchBarView.searchBar.delegate = self
        
        // Initialize sitters
        allSitters = sampleSitters
        filteredSitters = allSitters
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
    
    @objc func closeButtonTapped() {
        self.dismiss(animated: true)
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
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
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
}

// Add UICollectionViewDelegate
extension InviteSitterViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let selectedSitter = dataSource.itemIdentifier(for: indexPath) else { return }
        
        var snapshot = dataSource.snapshot()
        
        // If selecting the same sitter, deselect it
        if self.selectedSitter?.id == selectedSitter.id {
            self.selectedSitter = nil
            snapshot.reloadItems([selectedSitter])
        } else {
            // If selecting a different sitter:
            // 1. Clear previous selection if it exists
            if let previousSitter = self.selectedSitter {
                snapshot.reloadItems([previousSitter])
            }
            
            // 2. Set new selection
            self.selectedSitter = selectedSitter
            snapshot.reloadItems([selectedSitter])
        }
        
        // Apply changes
        dataSource.apply(snapshot, animatingDifferences: true)
        
        // Deselect for visual feedback
        collectionView.deselectItem(at: indexPath, animated: true)
        
        // Update button state
        updateInviteButtonState()
        
        searchBarView.searchBar.resignFirstResponder()
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
