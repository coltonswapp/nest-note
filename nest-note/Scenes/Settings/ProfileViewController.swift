//
//  ProfileViewController.swift
//  nest-note
//

import UIKit
import FirebaseAuth

class ProfileViewController: NNViewController, UICollectionViewDelegate {
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<NNSectionHeaderView>!
    private var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        configureActivityIndicator()
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
        navigationItem.title = "Profile"
    }
    
    override func setupNavigationBarButtons() {
        let closeButton = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeButtonTapped))
        let buttons = [closeButton]
        buttons.forEach { $0.tintColor = .label }
        navigationItem.rightBarButtonItems = buttons
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
            
            // Standardize header size to match SettingsViewController
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
        
        let modeSwitchCellRegistration = UICollectionView.CellRegistration<ModeSwitchCell, Item> { cell, indexPath, _ in
            cell.configure()
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .info:
                return collectionView.dequeueConfiguredReusableCell(using: infoCellRegistration, for: indexPath, item: item)
            case .action:
                return collectionView.dequeueConfiguredReusableCell(using: actionCellRegistration, for: indexPath, item: item)
            case .modeSwitch:
                return collectionView.dequeueConfiguredReusableCell(using: modeSwitchCellRegistration, for: indexPath, item: item)
            }
        }
        
        dataSource.supplementaryViewProvider = { [weak self] (collectionView, kind, indexPath) in
            collectionView.dequeueConfiguredReusableSupplementary(using: self!.headerRegistration, for: indexPath)
        }
    }
    
    private func configureActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.info, .actions, .danger])
        
        // Info section
        if let user = UserService.shared.currentUser,
           let creationDate = Auth.auth().currentUser?.metadata.creationDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            
            let infoItems: [Item] = [
                .info(title: "Name", detail: user.personalInfo.name),
                .info(title: "Email", detail: user.personalInfo.email),
                .info(title: "Primary Role", detail: user.primaryRole.rawValue.capitalized),
                .info(title: "Member Since", detail: dateFormatter.string(from: creationDate)),
                .info(title: "Phone", detail: user.personalInfo.phone ?? "--"),
                .info(title: "User ID", detail: user.id ?? "--"),
                .modeSwitch
            ]
            snapshot.appendItems(infoItems, toSection: .info)
        }
        
        // Actions section
        snapshot.appendItems([.action(title: "Sign Out", imageName: "rectangle.portrait.and.arrow.right")], toSection: .actions)
        
        // Danger section
        snapshot.appendItems([.action(title: "Delete Account", imageName: "trash", destructive: true)], toSection: .danger)
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch item {
        case .info(let title, _):
            switch title {
            case "Name":
                let editVC = EditUserInfoViewController(type: .name)
                let nav = UINavigationController(rootViewController: editVC)
                present(nav, animated: true)
            default:
                break
            }
        case .action(let title, _, _):
            switch title {
            case "Sign Out":
                handleSignOut()
            case "Delete Account":
                handleDeleteAccount()
            default:
                break
            }
        default:
            break
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    
    private func handleSignOut() {
        let alert = UIAlertController(
            title: "Sign Out",
            message: "Are you sure you want to sign out?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { [weak self] _ in
            Task {
                do {
                    // Show activity indicator
                    await MainActor.run {
                        self?.activityIndicator.startAnimating()
                        self?.collectionView.isUserInteractionEnabled = false
                    }
                    
                    // First reset the app state
                    await Launcher.shared.reset()
                    
                    // Dismiss all modals (profile and settings)
                    await MainActor.run {
                        // Get the root view controller
                        guard let rootVC = self?.view.window?.rootViewController else { return }
                        
                        // Dismiss all modals from the root view controller
                        rootVC.dismiss(animated: true) {
                            // After dismissal, the LaunchCoordinator will detect that the user is not signed in
                            // and present the LandingViewController with isModalInPresentation = true
                        }
                    }
                } catch {
                    // Hide activity indicator in case of error
                    await MainActor.run {
                        self?.activityIndicator.stopAnimating()
                        self?.collectionView.isUserInteractionEnabled = true
                    }
                    
                    // Show error alert
                    await MainActor.run {
                        let errorAlert = UIAlertController(
                            title: "Error",
                            message: "Failed to sign out: \(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(errorAlert, animated: true)
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    private func handleDeleteAccount() {
        let alert = UIAlertController(
            title: "Delete Account",
            message: "Are you sure you want to delete your account? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            // TODO: Implement account deletion
            Logger.log(level: .info, category: .auth, message: "User requested account deletion")
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
            case .info: return "Account Information"
            case .actions: return "Actions"
            case .danger: return "Danger Zone"
            }
        }
    }
    
    enum Item: Hashable {
        case info(title: String, detail: String)
        case action(title: String, imageName: String, destructive: Bool = false)
        case modeSwitch
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

private class ModeSwitchCell: UICollectionViewListCell {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        label.text = "CURRENT MODE"
        return label
    }()
    
    private let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [AppMode.nestOwner.rawValue, AppMode.sitter.rawValue])
        control.selectedSegmentIndex = ModeManager.shared.currentMode == .nestOwner ? 0 : 1
        return control
    }()
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, segmentedControl])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        return stack
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupActions()
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
    
    private func setupActions() {
        segmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
    }
    
    @objc private func modeChanged() {
        let newMode: AppMode = segmentedControl.selectedSegmentIndex == 0 ? .nestOwner : .sitter
        ModeManager.shared.currentMode = newMode
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    func configure() {
        // Update segment control state
        segmentedControl.selectedSegmentIndex = ModeManager.shared.currentMode == .nestOwner ? 0 : 1
    }
}
