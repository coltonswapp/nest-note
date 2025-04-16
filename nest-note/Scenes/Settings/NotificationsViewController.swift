import UIKit
import UserNotifications

class NotificationsViewController: NNViewController, UICollectionViewDelegate {
    
    private let bottomImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(imageView, for: .halfMoonBottom)
        return imageView
    }()
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<NNSectionHeaderView>!
    private var footerRegistration: UICollectionView.SupplementaryRegistration<NotificationFooterView>!
    
    private var notificationsEnabled: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        applyInitialSnapshots()
        collectionView.delegate = self
        
        // Add observers for notification authorization changes and app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotificationAuthorizationChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
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
        view.addSubview(bottomImageView)

        bottomImageView.pinToBottom(of: view)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        config.footerMode = .supplementary
        
        return UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
            
            // Standardize header size
            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(32))
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            
            // Footer size
            let footerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
            let footer = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: footerSize,
                elementKind: UICollectionView.elementKindSectionFooter,
                alignment: .bottom
            )
            
            section.boundarySupplementaryItems = [header, footer]
            
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
        
        footerRegistration = UICollectionView.SupplementaryRegistration<NotificationFooterView>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] (footerView, string, indexPath) in
            guard let self = self else { return }
            footerView.configure { [weak self] in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            footerView.isHidden = self.notificationsEnabled
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
            if kind == UICollectionView.elementKindSectionHeader {
                return collectionView.dequeueConfiguredReusableSupplementary(using: self!.headerRegistration, for: indexPath)
            } else if kind == UICollectionView.elementKindSectionFooter {
                return collectionView.dequeueConfiguredReusableSupplementary(using: self!.footerRegistration, for: indexPath)
            }
            return nil
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
                print("auth status: \(settings.authorizationStatus)")
                self.notificationsEnabled = isSystemAuthorized
                
                // Force a layout update to refresh the footer visibility
                self.dataSource.apply(snapshot, animatingDifferences: false)
                self.collectionView.collectionViewLayout.invalidateLayout()
            }
        }
    }
    
    @objc private func handleNotificationAuthorizationChange() {
        // Since we're already handling updates in willEnterForeground, we can remove this
        // to avoid duplicate updates
    }
    
    @objc private func handleAppDidEnterBackground() {
        // Store the current state if needed
    }
    
    @objc private func handleAppWillEnterForeground() {
        // Get current notification settings and update UI
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.notificationsEnabled = settings.authorizationStatus == .authorized
                
                // Force supplementary views to update
                if let layout = self.collectionView.collectionViewLayout as? UICollectionViewCompositionalLayout {
                    var config = layout.configuration
                    layout.configuration = config
                }
                
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.reloadData()
            }
        }
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
    
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return false
    }
}

// MARK: - NotificationCellDelegate
extension NotificationsViewController: NotificationCellDelegate {
    func notificationCell(_ cell: NotificationCell, didToggleSwitch isOn: Bool) {
        guard let user = UserService.shared.currentUser else { return }

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
        
        
       // Disable the switch if notifications are not authorized
       UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
           DispatchQueue.main.async {
               self?.toggleSwitch.isEnabled = settings.authorizationStatus == .authorized
           }
       }
    }
    
    @objc private func switchValueChanged() {
        delegate?.notificationCell(self, didToggleSwitch: toggleSwitch.isOn)
    }
}

// MARK: - NotificationFooterView
class NotificationFooterView: UICollectionReusableView {
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private var settingsAction: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        backgroundColor = .systemGroupedBackground
        addSubview(messageLabel)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        messageLabel.isUserInteractionEnabled = true
        messageLabel.addGestureRecognizer(tapGesture)
        
        // Set initial state
        updateMessageLabel()
    }
    
    func configure(settingsAction: @escaping () -> Void) {
        self.settingsAction = settingsAction
        updateMessageLabel()
    }
    
    private func updateMessageLabel() {
        let text = "Notifications for NestNote are disabled.\n Go to Settings"
        let attributedString = NSMutableAttributedString(string: text)
        let range = (text as NSString).range(of: "Go to Settings")
        
        // Add URL attribute to make it look like a link
        attributedString.addAttributes([
            .foregroundColor: NNColors.primary,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ], range: range)
        
        self.messageLabel.attributedText = attributedString
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        settingsAction?()
    }
}

// MARK: - NotificationCellDelegate Protocol
protocol NotificationCellDelegate: AnyObject {
    func notificationCell(_ cell: NotificationCell, didToggleSwitch isOn: Bool)
} 
