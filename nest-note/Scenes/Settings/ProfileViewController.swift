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
        
        // Add observer for mode changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleModeChange),
            name: ModeManager.modeDidChangeNotification,
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
        
        let modeSwitchCellRegistration = UICollectionView.CellRegistration<ModeSwitchCell, Item> { [weak self] cell, indexPath, _ in
            cell.configure()
            cell.delegate = self
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
            return collectionView.dequeueConfiguredReusableSupplementary(using: self!.headerRegistration, for: indexPath)
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
        snapshot.appendItems([.action(title: "Sign Out", imageName: "rectangle.portrait.and.arrow.right"),
                              .action(title: "Give Feedback", imageName: "paperplane.fill")], toSection: .actions)
        
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
            case "Give Feedback":
                handleFeedback()
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
    
    private func handleFeedback() {
        present(NNFeedbackViewController(), animated: true)
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
    
    @objc private func handleModeChange() {
        // Update the UI when the mode changes (but not when we trigger it)
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
    
    // MARK: - Mode Switching
    
    func confirmModeSwitch(from currentMode: AppMode, to newMode: AppMode) {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Switch to \(newMode.rawValue) Mode?",
            message: "Are you sure you want to switch from \(currentMode.rawValue) to \(newMode.rawValue) mode? This will refresh the app.",
            preferredStyle: .alert
        )
        
        // Cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            // Revert the segmented control to the current mode
            self?.revertModeSwitchCell(to: currentMode)
        })
        
        // Confirm action
        alert.addAction(UIAlertAction(title: "Switch", style: .default) { [weak self] _ in
            self?.performModeSwitch(to: newMode)
        })
        
        present(alert, animated: true)
    }
    
    private func revertModeSwitchCell(to mode: AppMode) {
        // Find the mode switch cell and revert its segmented control
        guard let snapshot = dataSource?.snapshot(),
              let modeSwitchItem = snapshot.itemIdentifiers(inSection: .info).first(where: { item in
                  if case .modeSwitch = item { return true }
                  return false
              }),
              let indexPath = dataSource?.indexPath(for: modeSwitchItem),
              let cell = collectionView?.cellForItem(at: indexPath) as? ModeSwitchCell else {
            return
        }
        
        // Revert the segmented control to the correct state
        cell.revertToMode(mode)
    }
    
    private func performModeSwitch(to newMode: AppMode) {
        // 1. Update the mode first
        ModeManager.shared.currentMode = newMode
        Logger.log(level: .info, message: "Saving new AppMode: \(newMode.rawValue)")
        
        // 2. Provide haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()

        // 3. Get shared LaunchCoordinator
        guard let launchCoordinator = LaunchCoordinator.shared else {
            Logger.log(level: .error, message: "LaunchCoordinator shared instance not available")
            return
        }
        
        // 4. First dismiss all modals
        dismissAllViewControllers() {
            NotificationCenter.default.post(name: .modeDidChange, object: nil)

            Task {
                do {
                    try await Task.sleep(for: .seconds(2.0)) // TODO: Remove for prod
                    Logger.log(level: .info, message: "Using shared LaunchCoordinator to switch modes...")
                    try await launchCoordinator.switchMode(to: newMode)

                } catch {
                    Logger.log(level: .error, message: "Failed to complete mode transition: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - ModeSwitchCellDelegate
extension ProfileViewController: ModeSwitchCellDelegate {
    func modeSwitchCell(didSelectMode newMode: AppMode) {
        let currentMode = ModeManager.shared.currentMode
        
        // Only show confirmation if mode is actually changing
        if currentMode != newMode {
            confirmModeSwitch(from: currentMode, to: newMode)
        }
    }
}

// MARK: - ModeSwitchCellDelegate
protocol ModeSwitchCellDelegate: AnyObject {
    func modeSwitchCell(didSelectMode mode: AppMode)
}

private class ModeSwitchCell: UICollectionViewListCell {
    weak var delegate: ModeSwitchCellDelegate?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .captionBold
        label.textColor = .secondaryLabel
        label.text = "CURRENT MODE"
        return label
    }()
    
    private let infoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "info.circle"), for: .normal)
        button.tintColor = .tertiaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [AppMode.nestOwner.rawValue, AppMode.sitter.rawValue])
        control.selectedSegmentIndex = ModeManager.shared.currentMode == .nestOwner ? 0 : 1
        return control
    }()
    
    private lazy var titleStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, infoButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 4
        return stack
    }()
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleStackView, segmentedControl])
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
        infoButton.addTarget(self, action: #selector(infoButtonTapped), for: .touchUpInside)
    }
    
    @objc private func modeChanged() {
        let newMode: AppMode = segmentedControl.selectedSegmentIndex == 0 ? .nestOwner : .sitter
        delegate?.modeSwitchCell(didSelectMode: newMode)
    }
    
    @objc private func infoButtonTapped() {
        // Find the containing view controller
        var responder: UIResponder? = self
        while responder != nil {
            responder = responder?.next
            if let viewController = responder as? UIViewController {
                let modeInfoVC = ModeInfoViewController()
                viewController.present(modeInfoVC, animated: true)
                break
            }
        }
    }
    
    func configure() {
        // Update segment control state
        segmentedControl.selectedSegmentIndex = ModeManager.shared.currentMode == .nestOwner ? 0 : 1
    }
    
    func revertToMode(_ mode: AppMode) {
        // Revert the segmented control to the specified mode without triggering the change handler
        segmentedControl.selectedSegmentIndex = mode == .nestOwner ? 0 : 1
    }
}
