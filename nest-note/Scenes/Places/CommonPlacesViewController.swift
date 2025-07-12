//
//  CommonPlacesViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 7/11/25.
//

import UIKit

protocol CommonPlacesViewControllerDelegate: AnyObject {
    func commonPlacesViewController(_ controller: CommonPlacesViewController, didSelectPlace commonPlace: CommonPlace)
}

struct CommonPlace: Hashable {
    let id = UUID().uuidString
    let name: String
    let icon: String
    
    static let suggestions: [CommonPlace] = [
        CommonPlace(name: "Grandma's House", icon: "house.fill"),
        CommonPlace(name: "School", icon: "graduationcap.fill"),
        CommonPlace(name: "Bus Stop", icon: "bus.fill"),
        CommonPlace(name: "Dance Studio", icon: "figure.dance"),
        CommonPlace(name: "Soccer Practice", icon: "soccerball"),
        CommonPlace(name: "Favorite Park", icon: "tree.fill"),
        CommonPlace(name: "Rec Center", icon: "building.2.fill"),
        CommonPlace(name: "Swimming Pool", icon: "figure.pool.swim")
    ]
}

final class CommonPlacesViewController: UIViewController, CollectionViewLoadable {
    
    // MARK: - Properties
    private let commonPlaces = CommonPlace.suggestions
    
    // Add delegate property
    weak var delegate: CommonPlacesViewControllerDelegate?
    
    // Required by CollectionViewLoadable
    var loadingIndicator: UIActivityIndicatorView!
    var refreshControl: UIRefreshControl!
    
    var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, CommonPlace>!
    
    private var instructionLabel: BlurBackgroundLabel!
    private var emptyStateView: NNEmptyStateView!
    
    // Sections for the collection view
    enum Section: Int, CaseIterable {
        case main
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Place Suggestions"
        view.backgroundColor = .systemBackground
        
        setupCollectionView()
        setupLoadingIndicator()
        configureDataSource()
        setupEmptyStateView()
        setupNavigationBarButtons()
        setupInstructionLabel()
        
        collectionView.delegate = self
        
        navigationItem.weeTitle = "Oh, the places you'll go"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.tintColor = NNColors.primary
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applySnapshot()
    }
    
    // MARK: - CollectionViewLoadable Implementation
    func handleLoadedData() {
        // Not needed with static data
    }
    
    func loadData(showLoadingIndicator: Bool) async {
        // Not needed with static data
    }
    
    private func setupNavigationBarButtons() {
        let dismissButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(dismissTapped)
        )
        
        navigationItem.rightBarButtonItem = dismissButton
    }
    
    @objc private func dismissTapped() {
        dismiss(animated: true)
    }
    
    private func setupInstructionLabel() {
        instructionLabel = BlurBackgroundLabel(with: .systemThickMaterial)
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.text = "Tap a place suggestion to use it\nas a starting point for your new place."
        instructionLabel.font = .bodyL
        instructionLabel.textColor = .secondaryLabel
        
        view.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)
        ])
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        
        let buttonHeight: CGFloat = 50
        let buttonPadding: CGFloat = 10
        let totalInset = buttonHeight + buttonPadding * 2
        collectionView.contentInset.bottom = totalInset
        collectionView.verticalScrollIndicatorInsets.bottom = totalInset
        
        // Register cells
        collectionView.register(CommonPlaceCell.self, forCellWithReuseIdentifier: CommonPlaceCell.reuseIdentifier)
        
        collectionView.allowsSelection = true
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            guard let self = self else { return nil }
            return self.createInsetGroupedSection()
        }
        return layout
    }
    
    private func createInsetGroupedSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(60))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(60))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        section.interGroupSpacing = 8
        
        return section
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, CommonPlace>(collectionView: collectionView) {
            [weak self] (collectionView, indexPath, commonPlace) -> UICollectionViewCell? in
            guard let self = self else { return nil }
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CommonPlaceCell.reuseIdentifier, for: indexPath) as! CommonPlaceCell
            cell.configure(with: commonPlace)
            
            return cell
        }
    }
    
    private func createSnapshot() -> NSDiffableDataSourceSnapshot<Section, CommonPlace> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, CommonPlace>()
        snapshot.appendSections([.main])
        snapshot.appendItems(commonPlaces, toSection: .main)
        return snapshot
    }
    
    private func applySnapshot() {
        let snapshot = createSnapshot()
        dataSource.apply(snapshot, animatingDifferences: false)
        
        // Show empty state view if no places
        emptyStateView.isHidden = !commonPlaces.isEmpty
    }
    
    private func setupEmptyStateView() {
        emptyStateView = NNEmptyStateView(
            icon: UIImage(systemName: "mappin.and.ellipse"),
            title: "No Suggestions",
            subtitle: "We don't have any place suggestions at the moment.",
            actionButtonTitle: nil
        )
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        emptyStateView.isUserInteractionEnabled = true
        
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func handleCommonPlaceSelection(_ commonPlace: CommonPlace) {
        delegate?.commonPlacesViewController(self, didSelectPlace: commonPlace)
        dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDelegate
extension CommonPlacesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let selectedPlace = dataSource.itemIdentifier(for: indexPath) else { return }
        
        handleCommonPlaceSelection(selectedPlace)
    }
}

// MARK: - CommonPlaceCell
class CommonPlaceCell: UICollectionViewCell {
    static let reuseIdentifier = "CommonPlaceCell"
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = NNColors.primary
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .bodyL
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }()
    
    private let chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .tertiaryLabel
        imageView.image = UIImage(systemName: "chevron.right")
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        backgroundColor = NNColors.NNSystemBackground6
        layer.cornerRadius = 12
        
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),
            
            chevronImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12),
            
            contentView.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    func configure(with commonPlace: CommonPlace) {
        titleLabel.text = commonPlace.name
        iconImageView.image = UIImage(systemName: commonPlace.icon)
    }
}
