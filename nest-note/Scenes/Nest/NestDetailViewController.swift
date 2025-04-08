import UIKit

class NestDetailViewController: NNViewController, UICollectionViewDelegate {
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<NNSectionHeaderView>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        applyInitialSnapshots()
        collectionView.delegate = self
        
        // Add observer for user information updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserInformationUpdate),
            name: .userInformationUpdated,
            object: nil
        )
    }
    
    override func setup() {
        navigationItem.title = "Nest Details"
    }
    
    private func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        
        return UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
            
            // Standardize header size
            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(32))
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]
            
            return section
        }
    }
    
    private func configureDataSource() {
        headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] (headerView, string, indexPath) in
            guard let section = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            headerView.configure(title: section.title)
        }
        
        let infoCellRegistration = UICollectionView.CellRegistration<InfoCell, Item> { cell, indexPath, item in
            if case let .info(title, detail) = item {
                cell.configure(title: title, detail: detail)
            }
        }
        
        let actionCellRegistration = UICollectionView.CellRegistration<ActionCell, Item> { cell, indexPath, item in
            if case let .action(title, imageName, destructive) = item {
                cell.configure(title: title, imageName: imageName, destructive: destructive)
            }
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .info:
                return collectionView.dequeueConfiguredReusableCell(using: infoCellRegistration, for: indexPath, item: item)
            case .action:
                return collectionView.dequeueConfiguredReusableCell(using: actionCellRegistration, for: indexPath, item: item)
            }
        }
        
        dataSource.supplementaryViewProvider = { [weak self] (collectionView, kind, indexPath) in
            collectionView.dequeueConfiguredReusableSupplementary(using: self!.headerRegistration, for: indexPath)
        }
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.info, .actions, .danger])
        
        // Info section
        if let nest = NestService.shared.currentNest {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            
            let infoItems: [Item] = [
                .info(title: "Name", detail: nest.name),
                .info(title: "Address", detail: nest.address),
                .info(title: "Nest ID", detail: nest.id),
                .info(title: "Owner ID", detail: nest.ownerId),
            ]
            snapshot.appendItems(infoItems, toSection: .info)
        }
        
        // Actions section
        snapshot.appendItems([
            .action(title: "Add another Residence", imageName: "plus.circle", destructive: false)
        ], toSection: .actions)
        
        // Danger section
        snapshot.appendItems([.action(title: "Delete Nest", imageName: "trash", destructive: true)], toSection: .danger)
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch item {
        case .info(let title, let detail):
            switch title {
            case "Name":
                let editVC = EditUserInfoViewController(type: .nestName)
                let nav = UINavigationController(rootViewController: editVC)
                present(nav, animated: true)
            case "Address":
                let editVC = EditUserInfoViewController(type: .nestAddress)
                let nav = UINavigationController(rootViewController: editVC)
                present(nav, animated: true)
            case "Nest ID", "Owner ID":
                UIPasteboard.general.string = detail
                if let cell = collectionView.cellForItem(at: indexPath) {
                    cell.showCopyFeedback(text: "Copied!")
                }
            default:
                break
            }
        case .action(let title, _, _):
            switch title {
            case "Add another Residence":
                let featureVC = NNFeaturePreviewViewController(feature: .multipleNests)
                let nav = UINavigationController(rootViewController: featureVC)
                present(nav, animated: true)
            case "Delete Nest":
                handleDeleteNest()
            default:
                break
            }
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    
    private func handleDeleteNest() {
        let alert = UIAlertController(
            title: "Delete Nest",
            message: "Are you sure you want to delete this nest? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            // TODO: Implement nest deletion
//            Logger.log(level: .info, category: .nest, message: "User requested nest deletion")
        })
        
        present(alert, animated: true)
    }
    
    @objc private func handleUserInformationUpdate() {
        applyInitialSnapshots()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Types
    
    enum Section: Hashable {
        case info, actions, danger
        
        var title: String {
            switch self {
            case .info: return "Nest Information"
            case .actions: return "Actions"
            case .danger: return "Danger Zone"
            }
        }
    }
    
    enum Item: Hashable {
        case info(title: String, detail: String)
        case action(title: String, imageName: String, destructive: Bool = false)
    }
}

class InfoCell: UICollectionViewListCell {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .left
        return label
    }()
    
    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .label
        label.textAlignment = .left
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        stack.distribution = .equalSpacing
        return stack
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(title: String, detail: String) {
        titleLabel.text = title.uppercased()
        detailLabel.text = detail
    }
}

private class ActionCell: UICollectionViewListCell {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17)
        return label
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGray3
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        return imageView
    }()
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, iconImageView])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(title: String, imageName: String, destructive: Bool = false) {
        titleLabel.text = title
        titleLabel.textColor = destructive ? .systemRed : .label
        
        iconImageView.image = UIImage(systemName: imageName)
        iconImageView.tintColor = destructive ? .systemRed : .systemGray3
    }
} 
