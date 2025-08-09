import UIKit
import UserNotifications
import FirebaseMessaging

class NotificationsViewController: NNViewController, UICollectionViewDelegate {
    
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
            let footerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(20))
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
        
        let fcmTokenCellRegistration = UICollectionView.CellRegistration<FCMTokenCell, Item> { cell, indexPath, item in
            if case let .fcmToken(token, uploadDate) = item {
                cell.configure(token: token, uploadDate: uploadDate)
            }
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .notification:
                return collectionView.dequeueConfiguredReusableCell(using: notificationCellRegistration, for: indexPath, item: item)
            case .fcmToken:
                return collectionView.dequeueConfiguredReusableCell(using: fcmTokenCellRegistration, for: indexPath, item: item)
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
        
        #if DEBUG
        snapshot.appendSections([.notifications, .fcmTokens])
        #else
        snapshot.appendSections([.notifications])
        #endif
        
        // Get current notification settings
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            Task {
                guard let self = self,
                      let user = UserService.shared.currentUser else { return }
                
                let isSystemAuthorized = settings.authorizationStatus == .authorized
                let preferences = user.personalInfo.notificationPreferences
                
                let notificationItems: [Item] = [
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
                
                snapshot.appendItems(notificationItems, toSection: .notifications)
                
                #if DEBUG
                // Fetch FCM tokens from Firestore
                do {
                    let fcmTokens = try await UserService.shared.fetchStoredFCMTokens()
                    let fcmTokenItems: [Item] = fcmTokens.map { tokenData in
                        .fcmToken(token: tokenData.token, uploadDate: tokenData.uploadedDate)
                    }
                    snapshot.appendItems(fcmTokenItems, toSection: .fcmTokens)
                } catch {
                    Logger.log(level: .error, category: .general, message: "Failed to fetch FCM tokens: \(error.localizedDescription)")
                    // Continue without FCM tokens on error
                }
                #endif
                
                await MainActor.run {
                    print("auth status: \(settings.authorizationStatus)")
                    self.notificationsEnabled = isSystemAuthorized
                    
                    // Force a layout update to refresh the footer visibility
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                    self.collectionView.collectionViewLayout.invalidateLayout()
                }
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
        case fcmTokens
        
        var title: String {
            switch self {
            case .notifications: return "Notification Preferences"
            case .fcmTokens: return "FCM Tokens"
            }
        }
    }
    
    enum Item: Hashable {
        case notification(title: String, description: String, isEnabled: Bool)
        case fcmToken(token: String, uploadDate: Date)
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return false
    }
}

// MARK: - NotificationCellDelegate
extension NotificationsViewController: NotificationCellDelegate {
    func notificationCell(_ cell: NotificationCell, didToggleSwitch isOn: Bool) {
        guard let user = UserService.shared.currentUser else { return }

        // If user is trying to enable notifications, check permissions first
        if isOn {
            UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                DispatchQueue.main.async {
                    switch settings.authorizationStatus {
                    case .notDetermined:
                        // Request permission
                        self?.requestNotificationPermission(for: cell)
                    case .denied:
                        // Show alert to go to settings
                        self?.showPermissionDeniedAlert(for: cell)
                    case .authorized:
                        // Update preferences normally
                        self?.updateNotificationPreferences(for: cell, isEnabled: true)
                    default:
                        // Handle other cases (provisional, ephemeral)
                        self?.updateNotificationPreferences(for: cell, isEnabled: true)
                    }
                }
            }
        } else {
            // Disabling notifications - update preferences directly
            updateNotificationPreferences(for: cell, isEnabled: false)
        }
    }
    
    private func requestNotificationPermission(for cell: NotificationCell) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    // Register for remote notifications
                    UIApplication.shared.registerForRemoteNotifications()
                    
                    // Update preferences
                    self?.updateNotificationPreferences(for: cell, isEnabled: true)
                    
                    // Refresh the entire view to update footer visibility
                    self?.applyInitialSnapshots()
                    
                    // Show success message
                    self?.showToast(text: "Notifications Enabled!", subtitle: "You'll receive important updates about your Nest", sentiment: .positive)
                } else {
                    // Permission denied, reset toggle
                    cell.resetToggle()
                    
                    // Show settings alert
                    self?.showPermissionDeniedAlert(for: cell)
                }
            }
        }
    }
    
    private func showPermissionDeniedAlert(for cell: NotificationCell) {
        cell.resetToggle() // Reset the toggle since permission is denied
        
        let alert = UIAlertController(
            title: "Notifications Disabled",
            message: "To enable notifications, please go to Settings > Notifications > NestNote and turn on Allow Notifications.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func updateNotificationPreferences(for cell: NotificationCell, isEnabled: Bool) {
        guard let user = UserService.shared.currentUser else { return }
        
        Task {
            do {
                var preferences = user.personalInfo.notificationPreferences ?? .default
                
                // Determine which preference to update based on the cell's title
                if cell.titleLabel.text == "Session Notifications" {
                    preferences.sessionNotifications = isEnabled
                } else if cell.titleLabel.text == "Other Notifications" {
                    preferences.otherNotifications = isEnabled
                }
                
                try await UserService.shared.updateNotificationPreferences(preferences)
                
                // If enabling, ensure FCM token is updated
                if isEnabled {
                    await handleNotificationEnable()
                }
                
                Logger.log(level: .info, category: .general, message: "Updated notification preference: \(cell.titleLabel.text ?? "Unknown") = \(isEnabled)")
                
            } catch {
                Logger.log(level: .error, category: .general, message: "Failed to update notification preferences: \(error.localizedDescription)")
                
                // Reset toggle on error
                await MainActor.run {
                    cell.resetToggle()
                }
            }
        }
    }
    
    private func handleNotificationEnable() async {
        do {
            // Request notification permissions if not already granted
            await UserService.shared.requestNotificationPermissions()
            
            // Get current FCM token and ensure it's saved to the database
            let fcmToken = try await Messaging.messaging().token()
            try await UserService.shared.updateFCMToken(fcmToken)
            Logger.log(level: .info, category: .general, message: "FCM token updated successfully when enabling notifications")
            
            // Refresh the UI to show updated FCM tokens
            await MainActor.run {
                self.applyInitialSnapshots()
            }
            
        } catch {
            Logger.log(level: .error, category: .general, message: "Failed to handle notification enable: \(error.localizedDescription)")
        }
    }
}

// MARK: - NotificationCell
class NotificationCell: UICollectionViewListCell {
    weak var delegate: NotificationCellDelegate?
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
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
        
        // Always enable the switch - we'll handle permission requests when toggled
        toggleSwitch.isEnabled = true
    }
    
    func resetToggle() {
        toggleSwitch.setOn(false, animated: true)
    }
    
    @objc private func switchValueChanged() {
        delegate?.notificationCell(self, didToggleSwitch: toggleSwitch.isOn)
    }
}

// MARK: - NotificationFooterView
class NotificationFooterView: UICollectionReusableView {
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
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
        let text = "Notifications are disabled. Toggle a notification above to enable, or manually enable in Settings."
        let attributedString = NSMutableAttributedString(string: text)
        let range = (text as NSString).range(of: "Settings")
        
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

// MARK: - FCMTokenCell
class FCMTokenCell: UICollectionViewListCell {
    private let tokenLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        return label
    }()
    
    private lazy var labelsStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [tokenLabel, dateLabel])
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
        
        labelsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            labelsStackView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            labelsStackView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            labelsStackView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 8),
            labelsStackView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(token: String, uploadDate: Date) {
        // Show first 20 and last 20 characters of token with ellipsis in middle
        let tokenDisplay: String
        if token.count > 40 {
            let start = String(token.prefix(20))
            let end = String(token.suffix(20))
            tokenDisplay = "\(start)...\(end)"
        } else {
            tokenDisplay = token
        }
        
        tokenLabel.text = tokenDisplay
        
        // Format the upload date
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        dateLabel.text = "Uploaded: \(formatter.string(from: uploadDate))"
    }
}

// MARK: - NotificationCellDelegate Protocol
protocol NotificationCellDelegate: AnyObject {
    func notificationCell(_ cell: NotificationCell, didToggleSwitch isOn: Bool)
} 
