import UIKit
import UserNotifications

class NotificationsViewController: NNViewController, UICollectionViewDelegate {
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<NNSectionHeaderView>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        applyInitialSnapshots()
        collectionView.delegate = self
        
        // Add observer for notification authorization changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotificationAuthorizationChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    override func setup() {
        navigationItem.title = "Notifications"
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
        
        let notificationCellRegistration = UICollectionView.CellRegistration<NotificationCell, Item> { cell, indexPath, item in
            if case let .notification(title, description, isEnabled) = item {
                cell.configure(title: title, description: description, isEnabled: isEnabled)
                cell.delegate = self
            }
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .notification:
                return collectionView.dequeueConfiguredReusableCell(using: notificationCellRegistration, for: indexPath, item: item)
            }
        }
        
        dataSource.supplementaryViewProvider = { [weak self] (collectionView, kind, indexPath) in
            collectionView.dequeueConfiguredReusableSupplementary(using: self!.headerRegistration, for: indexPath)
        }
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.notifications])
        
        // Get current notification settings
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self = self,
                      let user = UserService.shared.currentUser else { return }
                
                let isSystemAuthorized = settings.authorizationStatus == .authorized
                let preferences = user.personalInfo.notificationPreferences
                
                let items: [Item] = [
                    .notification(
                        title: "Session Notifications",
                        description: "Receive notifications about your sessions starting & ending",
                        isEnabled: isSystemAuthorized && preferences?.sessionNotifications ?? false
                    ),
                    .notification(
                        title: "Other Notifications",
                        description: "Receive updates about your nest",
                        isEnabled: isSystemAuthorized && preferences?.otherNotifications ?? false
                    )
                ]
                
                snapshot.appendItems(items, toSection: .notifications)
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
        }
    }
    
    @objc private func handleNotificationAuthorizationChange() {
        applyInitialSnapshots()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Types
    
    enum Section: Hashable {
        case notifications
        
        var title: String {
            switch self {
            case .notifications: return "Notification Preferences"
            }
        }
    }
    
    enum Item: Hashable {
        case notification(title: String, description: String, isEnabled: Bool)
    }
}

// MARK: - NotificationCellDelegate
extension NotificationsViewController: NotificationCellDelegate {
    func notificationCell(_ cell: NotificationCell, didToggleSwitch isOn: Bool) {
        guard let user = UserService.shared.currentUser else { return }
        
        // Get the current notification settings
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let isSystemAuthorized = settings.authorizationStatus == .authorized
            
            // If turning on and system notifications are not authorized, request authorization
            if isOn && !isSystemAuthorized {
                self?.requestNotificationAuthorization()
                return
            }
            
            // If turning off and system notifications are authorized, direct to settings
            if !isOn && isSystemAuthorized {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    DispatchQueue.main.async {
                        UIApplication.shared.open(url)
                    }
                    
                }
                return
            }
            
            // Update user preferences in Firestore
            Task {
                do {
                    var preferences = user.personalInfo.notificationPreferences
                    
                    // Determine which preference to update based on the cell's title
                    if cell.titleLabel.text == "Session Notifications" {
                        preferences?.sessionNotifications = isOn
                    } else if cell.titleLabel.text == "Other Notifications" {
                        preferences?.otherNotifications = isOn
                    }
                    
                    try await UserService.shared.updateNotificationPreferences(preferences ?? .default)
                } catch {
                    Logger.log(level: .error, category: .general, message: "Failed to update notification preferences: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    self?.applyInitialSnapshots()
                } else if let error = error {
                    Logger.log(level: .error, category: .general, message: "Failed to request notification authorization: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - NotificationCell
class NotificationCell: UICollectionViewListCell {
    weak var delegate: NotificationCellDelegate?
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17)
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()
    
    private let toggleSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        return toggle
    }()
    
    private lazy var labelsStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
        stack.axis = .vertical
        stack.spacing = 4
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
        contentView.addSubview(labelsStackView)
        contentView.addSubview(toggleSwitch)
        
        labelsStackView.translatesAutoresizingMaskIntoConstraints = false
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            labelsStackView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            labelsStackView.trailingAnchor.constraint(equalTo: toggleSwitch.leadingAnchor, constant: -16),
            labelsStackView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 8),
            labelsStackView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -8),
            
            toggleSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            toggleSwitch.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        ])
    }
    
    func configure(title: String, description: String, isEnabled: Bool) {
        titleLabel.text = title
        descriptionLabel.text = description
        toggleSwitch.isOn = isEnabled
    }
    
    @objc private func switchValueChanged() {
        delegate?.notificationCell(self, didToggleSwitch: toggleSwitch.isOn)
    }
}

// MARK: - NotificationCellDelegate Protocol
protocol NotificationCellDelegate: AnyObject {
    func notificationCell(_ cell: NotificationCell, didToggleSwitch isOn: Bool)
} 
