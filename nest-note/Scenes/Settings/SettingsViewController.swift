//
//  SettingsViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 10/6/24.
//

import UIKit

class SettingsViewController: NNViewController, UICollectionViewDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupRegistrations()
        configureCollectionView()
        configureDataSource()
        applyInitialSnapshots()
        collectionView.delegate = self
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        switch item {
        case .account(let email, let name):
            print("Selected Account: \(name) (\(email))")
        case .myNestItem(let title, _):
            print("Selected My Nest item: \(title)")
        case .generalItem(let title, _):
            print("Selected General item: \(title)")
        }
        
        // Optionally, deselect the item
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func loadView() {
        super.loadView()
    }
    
    private func setupRegistrations() {
        headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] (supplementaryView, string, indexPath) in
            guard let self = self else { return }
            var content = supplementaryView.defaultContentConfiguration()
            content.text = self.dataSource.snapshot().sectionIdentifiers[indexPath.section] == .myNest ? "My Nest" : "General"
            content.textProperties.font = UIFont.boldSystemFont(ofSize: 16.0)
            content.textProperties.color = .secondaryLabel
            supplementaryView.contentConfiguration = content
        }

        footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionFooter) { (supplementaryView, string, indexPath) in
            var content = supplementaryView.defaultContentConfiguration()
            content.text = "❤️ \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")"
            content.textProperties.alignment = .center
            content.textProperties.font = UIFont.preferredFont(forTextStyle: .footnote)
            content.textProperties.color = .secondaryLabel
            supplementaryView.contentConfiguration = content
        }
    }
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!
    private var footerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!

    override func setup() {
        navigationItem.title = "Settings"
//        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    override func setupNavigationBarButtons() {
        let closeButton = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeButtonTapped))
        let buttons = [closeButton]
        buttons.forEach { $0.tintColor = .label }
        navigationItem.rightBarButtonItems = buttons
    }
    
    override func addSubviews() {
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
        ])
    }
    
    @objc func closeButtonTapped() {
        self.dismiss(animated: true)
    }
    
    private func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)
    }

    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            let section = self.dataSource.snapshot().sectionIdentifiers[sectionIndex]
            switch section {
            case .account:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(80))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 18, bottom: 20, trailing: 18)
                return section
            case .myNest, .general:
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.headerMode = .supplementary // This is key for showing headers
                let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
                
                // Explicitly add header to the section
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
                section.boundarySupplementaryItems = [header]
                
                return section
            }
        }
        
        // Create a footer for the entire collection view
        let footerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let footer = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: footerSize,
            elementKind: UICollectionView.elementKindSectionFooter,
            alignment: .bottom
        )
        
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.boundarySupplementaryItems = [footer]
        layout.configuration = config
        
        return layout
    }

    private func configureDataSource() {
        let accountCellRegistration = UICollectionView.CellRegistration<AccountCell, Item> { cell, indexPath, item in
            if case let .account(email, name) = item {
                cell.configure(email: email, name: name)
            }
        }
        
        let listCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, indexPath, item in
            var content = cell.defaultContentConfiguration()
            
            switch item {
            case .myNestItem(let title, let symbolName), .generalItem(let title, let symbolName):
                content.text = title
                
                // Create a symbol configuration with semibold weight
                let symbolConfiguration = UIImage.SymbolConfiguration(weight: .bold)
                
                // Create the SF Symbol image with the primary color tint and semibold weight
                let image = UIImage(systemName: symbolName, withConfiguration: symbolConfiguration)?
                    .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
                content.image = image
                
                // Adjust image properties if needed
                content.imageProperties.tintColor = NNColors.primary
                content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
                content.imageToTextPadding = 16

                content.directionalLayoutMargins.top = 16
                content.directionalLayoutMargins.bottom = 16
            default:
                break
            }
            
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch self.dataSource.snapshot().sectionIdentifiers[indexPath.section] {
            case .account:
                return collectionView.dequeueConfiguredReusableCell(using: accountCellRegistration, for: indexPath, item: item)
            case .myNest, .general:
                return collectionView.dequeueConfiguredReusableCell(using: listCellRegistration, for: indexPath, item: item)
            }
        }
        
        dataSource.supplementaryViewProvider = { [weak self] (collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView? in
            guard let self = self else { return nil }
            if kind == UICollectionView.elementKindSectionFooter {
                return collectionView.dequeueConfiguredReusableSupplementary(using: self.footerRegistration, for: indexPath)
            } else if kind == UICollectionView.elementKindSectionHeader {
                return collectionView.dequeueConfiguredReusableSupplementary(using: self.headerRegistration, for: indexPath)
            } else {
                return nil
            }
        }
    }

    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.account, .myNest, .general])
        
        snapshot.appendItems([.account(email: "user@example.com", name: "John Doe")], toSection: .account)
        
        let myNestItems = [
            ("Nest Members", "person.2.fill"),
            ("Saved Sitters", "heart"),
            ("Upcoming Sessions", "calendar"),
            ("Session History", "clock"),
            ("Subscription", "creditcard")
        ].map { Item.myNestItem(title: $0.0, symbolName: $0.1) }
        snapshot.appendItems(myNestItems, toSection: .myNest)
        
        let generalItems = [
            ("Notifications", "bell"),
            ("App Icon", "app"),
            ("Terms & Privacy", "doc.text"),
            ("Support", "questionmark.circle")
        ].map { Item.generalItem(title: $0.0, symbolName: $0.1) }
        snapshot.appendItems(generalItems, toSection: .general)
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    enum Section: Hashable {
        case account
        case myNest
        case general
    }

    enum Item: Hashable {
        case account(email: String, name: String)
        case myNestItem(title: String, symbolName: String)
        case generalItem(title: String, symbolName: String)
    }
}

class AccountCell: UICollectionViewCell {
    private let emailLabel = UILabel()
    private let nameLabel = UILabel()
    private let imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        
        backgroundColor = .white
        layer.cornerRadius = 12
        layer.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Set up the image view
        imageView.backgroundColor = .systemGray6
        imageView.layer.cornerRadius = 25 // Adjust this value as needed
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        
        // Set up constraints for the image view
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 50),
            imageView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Set up the vertical stack view for labels
        let labelStackView = UIStackView(arrangedSubviews: [nameLabel, emailLabel])
        labelStackView.axis = .vertical
        labelStackView.spacing = 4
        
        // Set up the horizontal stack view
        let horizontalStackView = UIStackView(arrangedSubviews: [imageView, labelStackView])
        horizontalStackView.axis = .horizontal
        horizontalStackView.spacing = 16
        horizontalStackView.alignment = .center
        
        contentView.addSubview(horizontalStackView)
        horizontalStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            horizontalStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            horizontalStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            horizontalStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            horizontalStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
        
        emailLabel.font = UIFont.preferredFont(forTextStyle: .body)
        emailLabel.textColor = .secondaryLabel
        nameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
    }
    
    func configure(email: String, name: String) {
        emailLabel.text = email
        nameLabel.text = name
    }
}
