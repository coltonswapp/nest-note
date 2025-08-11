//
//  InviteDetailViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 3/1/25.
//

import UIKit
import FirebaseFunctions
import FirebaseAuth

class InviteDetailViewController: NNViewController {
    
    weak var delegate: InviteSitterViewControllerDelegate?
    
    // Closure to call when invite is created or skipped
    var onInviteCreation: (() -> Void)?
    
    private var sessionID: String?
    private var inviteID: String?
    private var selectedSitter: SitterItem? {
        didSet {
            updateButtonState()
        }
    }
    private var inviteCode: String?
    private var inviteExists: Bool = false
    
    // Track original state for change detection
    private var originalSitter: SitterItem?
    
    // Computed property to check for unsaved changes
    private var hasUnsavedChanges: Bool {
        // For existing invites, check if sitter has changed
        if inviteExists {
            return selectedSitter?.email != originalSitter?.email
        } else {
            // For new invites, check if a sitter has been selected
            return selectedSitter != nil && !selectedSitter!.email.isEmpty
        }
    }
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, AnyHashable>!
    private var createUpdateButton: NNLoadingButton!
    private var actionButtonsStackView: UIStackView!
    private var skipButton: UIButton?
    private var skipLabel: UILabel?
    private var skipStack: UIStackView?
    
    private lazy var copyButton = NNCircularIconButtonWithLabel(
        icon: UIImage(systemName: "doc.on.doc"),
        title: "Copy",
        foregroundColor: .label
    )
    
    private lazy var messageButton = NNCircularIconButtonWithLabel(
        icon: UIImage(systemName: "message"),
        title: "Message",
        foregroundColor: .label
    )
    
    private lazy var shareButton = NNCircularIconButtonWithLabel(
        icon: UIImage(systemName: "square.and.arrow.up"),
        title: "Share",
        foregroundColor: .label
    )
    
    private lazy var deleteButton = NNCircularIconButtonWithLabel(
        icon: UIImage(systemName: "trash"),
        title: "Delete",
        backgroundColor: .systemRed.withAlphaComponent(0.15),
        foregroundColor: .systemRed
    )
    
    enum Section: Hashable {
        case sitter
        case code
    }
    
    init(sitter: SitterItem? = nil, sessionID: String? = nil) {
        self.selectedSitter = sitter
        self.sessionID = sessionID
        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupActionButtons()
        setupCreateUpdateButton()
        title = "Session Invite"
        
        // Hide back button - no need to go back after this point
        navigationItem.hidesBackButton = true
    }
    
    override func addSubviews() {
        
    }
    
    override func constrainSubviews() {
    }
    
    override func setup() {
        // No additional setup needed
    }
    
    override func setupNavigationBarButtons() {
        let closeButton = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeButtonTapped))
        let buttons = [closeButton]
        buttons.forEach { $0.tintColor = .label }
        navigationItem.rightBarButtonItems = buttons
    }
    
    private func setupCollectionView() {
        // Create a placeholder layout first
        let placeholderLayout = UICollectionViewFlowLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: placeholderLayout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        view.addSubview(collectionView)
        
        // Register cells and headers
        collectionView.register(SitterCell.self, forCellWithReuseIdentifier: SitterCell.reuseIdentifier)
        collectionView.register(CodeCell.self, forCellWithReuseIdentifier: CodeCell.reuseIdentifier)
        collectionView.register(
            NNSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "SectionHeader"
        )
        collectionView.register(
            SectionFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: "SectionFooter"
        )
        
        configureDataSource()
        applySnapshot()
        
        // Now set the proper layout after data source is configured
        collectionView.setCollectionViewLayout(createLayout(), animated: false)
        
        // Set delegate to control selection behavior
        collectionView.delegate = self
    }
    
    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            // Get the section identifier
            guard let sectionIdentifier = self.dataSource?.sectionIdentifier(for: sectionIndex) else {
                // Fallback configuration
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.headerMode = .supplementary
                config.footerMode = .supplementary
                return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
            }
            
            // Configure different appearances based on section
            var config: UICollectionLayoutListConfiguration
            switch sectionIdentifier {
            case .sitter, .code:
                // Use insetGrouped for sitter and code sections
                config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            }
            
            config.headerMode = .supplementary
            config.footerMode = .supplementary
            
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
            
            // Use the same header sizing pattern as ProfileViewController
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(32)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            
            let footerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(44)
            )
            let footer = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: footerSize,
                elementKind: UICollectionView.elementKindSectionFooter,
                alignment: .bottom
            )
            
            section.boundarySupplementaryItems = [header, footer]
            
            return section
        }
    }
    
    private func setupActionButtons() {
        actionButtonsStackView = UIStackView()
        actionButtonsStackView.axis = .horizontal
        actionButtonsStackView.distribution = .fillEqually
        actionButtonsStackView.alignment = .center
        actionButtonsStackView.spacing = 24
        actionButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        actionButtonsStackView.addArrangedSubview(copyButton)
        actionButtonsStackView.addArrangedSubview(messageButton)
        actionButtonsStackView.addArrangedSubview(shareButton)
        actionButtonsStackView.addArrangedSubview(deleteButton)
        
        view.addSubview(actionButtonsStackView)
        
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        messageButton.addTarget(self, action: #selector(messageButtonTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        
        // Set initial visibility
        updateActionButtonsVisibility()
    }
    
    private func setupCreateUpdateButton() {
        let buttonTitle = inviteExists ? "Update Invite" : "Create Invite"
        createUpdateButton = NNLoadingButton(
            title: buttonTitle,
            titleColor: .white,
            fillStyle: .fill(NNColors.primary)
        )
        createUpdateButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
        createUpdateButton.addTarget(self, action: #selector(createUpdateButtonTapped), for: .touchUpInside)
        
        // Set initial button state
        updateButtonState()
        
        // Constrain action buttons above the bottom button
        NSLayoutConstraint.activate([
            actionButtonsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            actionButtonsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            actionButtonsStackView.bottomAnchor.constraint(equalTo: createUpdateButton.topAnchor, constant: -24)
        ])
    }
    // Skip button removed for open-invite flow
    
    @objc private func createUpdateButtonTapped() {
        if inviteExists {
            updateInvite()
        } else {
            // Open invite fallback: auto-create code if missing
            Task { [weak self] in
                guard let self = self, let sessionID = self.sessionID else { return }
                do {
                    let invite = try await SessionService.shared.createOpenInvite(sessionID: sessionID)
                    await MainActor.run {
                        self.inviteCode = invite.code
                        self.inviteID = invite.id
                        self.inviteExists = true
                        self.updateActionButtonsVisibility()
                        self.applySnapshot()
                        self.createUpdateButton.isEnabled = false
                    }
                } catch {
                    await MainActor.run {
                        self.showToast(text: "Failed to create invite")
                    }
                }
            }
        }
    }
    
    private func createInvite() {
        guard let selectedSitter = selectedSitter,
              let sessionID = sessionID else { return }
        
        createUpdateButton.startLoading()
        
        Task {
            do {
                let invite = try await SessionService.shared.createInvite(
                    sitterEmail: selectedSitter.email,
                    sitterName: selectedSitter.name,
                    sessionID: sessionID
                )
                
                // Send email invite
                await self.sendEmailInvite(to: selectedSitter, for: sessionID, inviteCode: invite.code)
                
                await MainActor.run {
                    self.createUpdateButton.stopLoading(withSuccess: true)
                    self.inviteCode = invite.code
                    self.inviteID = invite.id
                    self.inviteExists = true
                    self.updateActionButtonsVisibility()
                    
                    self.applySnapshot()
                    self.delegate?.inviteSitterViewControllerDidSendInvite(to: selectedSitter, inviteId: invite.id)
                    
                    // Call the closure to notify that invite creation is complete
                    self.onInviteCreation?()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.updateButtonTitle()
                        self.createUpdateButton.isEnabled = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.createUpdateButton.stopLoading()
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to create invite: \(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    private func updateInvite() {
        guard let inviteID = inviteID,
              let sessionID = sessionID,
              let selectedSitter = selectedSitter else { return }
        
        createUpdateButton.startLoading()
        
        Task {
            do {
                try await SessionService.shared.updateInvite(
                    inviteID: inviteID,
                    sessionID: sessionID,
                    sitterEmail: selectedSitter.email,
                    sitterName: selectedSitter.name
                )
                
                await MainActor.run {
                    self.createUpdateButton.stopLoading()
                    self.showToast(text: "Invite updated successfully")
                    self.delegate?.inviteSitterViewControllerDidSendInvite(to: selectedSitter, inviteId: inviteID)
                    self.navigationController?.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.createUpdateButton.stopLoading()
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to update invite: \(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    func configure(with code: String, sessionID: String, sitter: SitterItem? = nil) {
        self.inviteCode = code
        self.inviteID = "invite-\(code)"
        self.sessionID = sessionID
        self.selectedSitter = sitter
        self.originalSitter = sitter // Store original state
        self.inviteExists = true
        
        updateButtonTitle()
        updateButtonState()
        updateActionButtonsVisibility()
        
        
        // Only apply snapshot if view has loaded
        if isViewLoaded {
            applySnapshot()
        }
    }
    
    func configure(with sitter: SitterItem, sessionID: String) {
        self.selectedSitter = sitter
        self.originalSitter = nil // No original sitter for new invites
        self.sessionID = sessionID
        self.inviteExists = false
        
        updateButtonTitle()
        updateButtonState()
        updateActionButtonsVisibility()
        
        
        // Only apply snapshot if view has loaded
        if isViewLoaded {
            applySnapshot()
        }
    }
    
    private func updateButtonTitle() {
        let buttonTitle = inviteExists ? "Update Invite" : "Create Invite"
        createUpdateButton?.setTitle(buttonTitle)
    }
    
    private func updateButtonState() {
        guard createUpdateButton != nil else { return }
        
        // Enable button only if there are unsaved changes
        let shouldEnable = hasUnsavedChanges
        createUpdateButton.isEnabled = shouldEnable
        createUpdateButton.alpha = shouldEnable ? 1.0 : 0.5
    }
    
    private func updateActionButtonsVisibility() {
        guard actionButtonsStackView != nil else { return }
        
        let shouldShow = inviteExists
        actionButtonsStackView.isHidden = !shouldShow
        
        // Enable/disable individual buttons
        copyButton.alpha = shouldShow ? 1.0 : 0.5
        messageButton.alpha = shouldShow ? 1.0 : 0.5
        shareButton.alpha = shouldShow ? 1.0 : 0.5
        deleteButton.alpha = shouldShow ? 1.0 : 0.5
        
        copyButton.isUserInteractionEnabled = shouldShow
        messageButton.isUserInteractionEnabled = shouldShow
        shareButton.isUserInteractionEnabled = shouldShow
        deleteButton.isUserInteractionEnabled = shouldShow
    }
    
    private func configureDataSource() {
        let headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] (headerView, string, indexPath) in
            guard let section = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            let title = section == .sitter ? "SITTER" : section == .code ? "INVITE CODE" : ""
            headerView.configure(title: title)
        }
        
        let footerRegistration = UICollectionView.SupplementaryRegistration<SectionFooterView>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] (footerView, string, indexPath) in
            guard let self else { return }
            guard let section = dataSource.sectionIdentifier(for: indexPath.section) else { return }
            if section == .code {
                footerView.configure(text: "Share this code. Anyone with it can join this session.")
            }
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, AnyHashable>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            if let sitterItem = item as? SitterCellItem {
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: SitterCell.reuseIdentifier,
                    for: indexPath
                ) as? SitterCell else {
                    fatalError("Could not create SitterCell")
                }
                cell.configure(with: sitterItem.sitter)
                cell.delegate = self
                return cell
            } else if let codeItem = item as? CodeCellItem {
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: CodeCell.reuseIdentifier,
                    for: indexPath
                ) as? CodeCell else {
                    fatalError("Could not create CodeCell")
                }
                cell.configure(with: codeItem.code)
                cell.backgroundConfiguration = nil
                return cell
            }
            
            fatalError("Unknown item type")
        }
        
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            if kind == UICollectionView.elementKindSectionHeader {
                return collectionView.dequeueConfiguredReusableSupplementary(
                    using: headerRegistration,
                    for: indexPath
                )
            } else if kind == UICollectionView.elementKindSectionFooter {
                return collectionView.dequeueConfiguredReusableSupplementary(
                    using: footerRegistration,
                    for: indexPath
                )
            }
            return nil
        }
    }
        
    private func applySnapshot() {
        // Ensure dataSource is initialized before applying snapshot
        guard dataSource != nil else { return }
        
        var snapshot = NSDiffableDataSourceSnapshot<Section, AnyHashable>()
        
        // Sitter section
        snapshot.appendSections([.sitter])
        if let sitter = selectedSitter {
            snapshot.appendItems([SitterCellItem(sitter: sitter)], toSection: .sitter)
        } else {
            // Show placeholder for "Invite a Sitter"
            let placeholderSitter = SitterItem(id: "placeholder", name: "Invite a Sitter", email: "")
            snapshot.appendItems([SitterCellItem(sitter: placeholderSitter)], toSection: .sitter)
        }
        
        // Code section
        snapshot.appendSections([.code])
        let code = inviteCode ?? "000-000"
        snapshot.appendItems([CodeCellItem(code: code)], toSection: .code)
        
        
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    // MARK: - Email Functions
    
    private func sendEmailInvite(to sitter: SitterItem, for sessionID: String, inviteCode: String) async {
        // Check if user is authenticated
        guard let user = Auth.auth().currentUser else {
            Logger.log(level: .error, category: .sessionService, message: "User not authenticated for email invite")
            return
        }
        
        // Refresh the auth token to ensure it's valid
        do {
            let idToken = try await user.getIDToken(forcingRefresh: true)
            Logger.log(level: .info, category: .sessionService, message: "Successfully refreshed auth token for email invite - User ID: \(user.uid)")
            Logger.log(level: .info, category: .sessionService, message: "Token length: \(idToken.count)")
        } catch {
            Logger.log(level: .error, category: .sessionService, message: "Failed to refresh auth token: \(error.localizedDescription)")
            return
        }
        
        // Create Functions instance after token refresh - explicitly set region
        let functions = Functions.functions(region: "us-central1")
        
        // Create invite link with new format
        let inviteLink = "https://nestnoteapp.com/invite?code=\(inviteCode)"
        
        // Get session details and nest info for the email
        guard let currentNest = NestService.shared.currentNest else {
            Logger.log(level: .error, category: .sessionService, message: "No current nest found for email invite")
            return
        }
        
        do {
            let session = try await SessionService.shared.getSession(nestID: currentNest.id, sessionID: sessionID)
            guard let session = session else {
                Logger.log(level: .error, category: .sessionService, message: "Session not found for email invite")
                return
            }
            
            let emailData: [String: Any] = [
                "sitterEmail": sitter.email,
                "sitterName": sitter.name,
                "sessionData": [
                    "title": session.title
                ],
                "nestName": currentNest.name,
                "inviteLink": inviteLink
            ]
            
            Logger.log(level: .info, category: .sessionService, message: "About to call sendSessionInviteEmail with data: \(emailData)")
            let result = try await functions.httpsCallable("sendSessionInviteEmail").call(emailData)
            Logger.log(level: .info, category: .sessionService, message: "Email invite sent successfully to \(sitter.email)")
        } catch {
            Logger.log(level: .error, category: .sessionService, message: "Failed to send email invite: \(error.localizedDescription)")
            Logger.log(level: .error, category: .sessionService, message: "Detailed error: \(error)")
        }
    }
}
    
    // MARK: - UICollectionViewDelegate
extension InviteDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return false }
        
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return false }
        
        // Only allow selection for SitterCellItem
        if item is SitterCellItem {
            return true
        }
        
        // Allow selection for CodeCellItem to show alert
        if item is CodeCellItem {
            return true
        }
        
        return false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        if item is CodeCellItem {
            // Show alert when user taps on code cell
            let alert = UIAlertController(
                title: "Create Invite",
                message: "Select a Sitter, then tap the \"Create Invite\" button below.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            present(alert, animated: true)
        }
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - Data Items
struct SitterCellItem: Hashable {
    let id = UUID()
    let sitter: SitterItem
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SitterCellItem, rhs: SitterCellItem) -> Bool {
        return lhs.id == rhs.id
    }
}

struct CodeCellItem: Hashable {
    let id = UUID()
    let code: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CodeCellItem, rhs: CodeCellItem) -> Bool {
        return lhs.id == rhs.id
    }
}


// MARK: - SitterCellDelegate
extension InviteDetailViewController: SitterCellDelegate {
    func sitterCellDidTapSelect() {
        let sitterListVC = SitterListViewController(displayMode: .selectSitter, selectedSitter: selectedSitter)
        sitterListVC.delegate = self
        let navController = UINavigationController(rootViewController: sitterListVC)
        present(navController, animated: true)
    }
}

// MARK: - SitterListViewControllerDelegate
extension InviteDetailViewController: SitterListViewControllerDelegate {
    func sitterListViewController(didSelectSitter sitter: SitterItem) {
        selectedSitter = sitter
        applySnapshot()
        // updateButtonState() is automatically called via didSet on selectedSitter
    }
    
    func didDeleteSitterInvite() {
        delegate?.inviteDetailViewControllerDidDeleteInvite()
    }
}

// MARK: - Action Button Methods
extension InviteDetailViewController {
    @objc private func copyButtonTapped() {
        guard let code = inviteCode else { return }
        let url = "nestnote://invite?code=\(code)"
        UIPasteboard.general.string = url
        
        HapticsHelper.lightHaptic()
        showToast(delay: 0.0, text: "Invite link copied!")
    }
    
    @objc private func messageButtonTapped() {
        guard let code = inviteCode else { return }
        let url = "nestnote://invite?code=\(code)"
        let message = "You've been invited to a NestNote session!\n\nUse this link to join: \(url)"
        
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.insert(charactersIn: ":/")
        
        if let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: allowedCharacters),
           let smsURL = URL(string: "sms:?body=\(encodedMessage)") {
            UIApplication.shared.open(smsURL)
        }
        
        HapticsHelper.lightHaptic()
    }
    
    @objc private func shareButtonTapped() {
        guard let code = inviteCode else { return }
        let url = "nestnote://invite?code=\(code)"
        let message = "You've been invited to a NestNote session!\n\nUse this link to join: \(url)"
        
        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        
        HapticsHelper.lightHaptic()
        
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(activityVC, animated: true)
    }
    
    @objc private func deleteButtonTapped() {
        let alert = UIAlertController(
            title: "Delete Invite?",
            message: "This will remove the sitter's access to this session. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self,
                  let inviteID = self.inviteID,
                  let sessionID = self.sessionID else { return }
            
            Task {
                do {
                    try await SessionService.shared.deleteInvite(inviteID: inviteID, sessionID: sessionID)
                    
                    await MainActor.run {
                        self.showToast(text: "Invite deleted")
                        self.delegate?.inviteDetailViewControllerDidDeleteInvite()
                        self.navigationController?.dismiss(animated: true)
                    }
                } catch {
                    await MainActor.run {
                        let alert = UIAlertController(
                            title: "Error",
                            message: "Failed to delete invite: \(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
}


// MARK: - SitterCell
protocol SitterCellDelegate: AnyObject {
    func sitterCellDidTapSelect()
}

class SitterCell: UICollectionViewListCell {
    static let reuseIdentifier = "SitterCell"
    
    weak var delegate: SitterCellDelegate?
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = NNColors.primary
        
        let symbolConfig = UIImage.SymbolConfiguration(weight: .semibold)
        imageView.image = UIImage(systemName: "figure.arms.open", withConfiguration: symbolConfig)
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.up.chevron.down")
        imageView.tintColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
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
        contentView.addSubview(iconImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -8),
            
            chevronImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 24),
            chevronImageView.heightAnchor.constraint(equalToConstant: 24),
            
            contentView.heightAnchor.constraint(equalToConstant: 56)
        ])
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cellTapped))
        contentView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func cellTapped() {
        delegate?.sitterCellDidTapSelect()
    }
    
    func configure(with sitter: SitterItem) {
        // Use email as fallback if name is empty, but only if email is not empty
        let displayName: String
        if sitter.name.isEmpty {
            if !sitter.email.isEmpty {
                displayName = sitter.email
            } else {
                displayName = "Invite a Sitter"
            }
        } else {
            displayName = sitter.name
        }
        
        nameLabel.text = displayName
        nameLabel.textColor = displayName == "Invite a Sitter" ? .secondaryLabel : .label
        iconImageView.tintColor = displayName == "Invite a Sitter" ? .secondaryLabel : NNColors.primary
    }
}

// MARK: - SectionFooterView
class SectionFooterView: UICollectionReusableView {
    static let reuseIdentifier = "SectionFooterView"
    
    private let textLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(textLabel)
        
        NSLayoutConstraint.activate([
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
    func configure(text: String) {
        textLabel.text = text
        isHidden = text.isEmpty
    }
}

// MARK: - CodeCell
class CodeCell: UICollectionViewListCell {
    static let reuseIdentifier = "CodeCell"
    
    private let codeLabel: UILabel = {
        let label = UILabel()
        label.font = .h1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(codeLabel)
        
        NSLayoutConstraint.activate([
            codeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            codeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            codeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            codeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            contentView.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    func configure(with code: String) {
        if code == "000-000" {
            codeLabel.text = code
            codeLabel.textColor = .tertiaryLabel
        } else {
            let formattedCode = String(code.prefix(3)) + "-" + String(code.suffix(3))
            codeLabel.text = formattedCode
            codeLabel.textColor = .label
        }
    }
}

// MARK: - CodeActionCell
protocol CodeActionCellDelegate: AnyObject {
    func codeActionCellDidTapCopy()
    func codeActionCellDidTapMessage()
    func codeActionCellDidTapShare()
    func codeActionCellDidTapDelete()
}

class CodeActionCell: UICollectionViewListCell {
    static let reuseIdentifier = "CodeActionCell"
    
    weak var delegate: CodeActionCellDelegate?
    
    private let buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var copyButton = NNCircularIconButtonWithLabel(
        icon: UIImage(systemName: "doc.on.doc"),
        title: "Copy",
        backgroundColor: .systemBackground,
        foregroundColor: .label
    )
    
    private lazy var messageButton = NNCircularIconButtonWithLabel(
        icon: UIImage(systemName: "message"),
        title: "Message",
        backgroundColor: .systemBackground,
        foregroundColor: .label
    )
    
    private lazy var shareButton = NNCircularIconButtonWithLabel(
        icon: UIImage(systemName: "square.and.arrow.up"),
        title: "Share",
        backgroundColor: .systemBackground,
        foregroundColor: .label
    )
    
    private lazy var deleteButton = NNCircularIconButtonWithLabel(
        icon: UIImage(systemName: "trash"),
        title: "Delete",
        backgroundColor: .systemRed.withAlphaComponent(0.15),
        foregroundColor: .systemRed
    )
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Remove background configuration
        backgroundConfiguration = nil
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(buttonStack)
        
        buttonStack.addArrangedSubview(copyButton)
        buttonStack.addArrangedSubview(messageButton)
        buttonStack.addArrangedSubview(shareButton)
        buttonStack.addArrangedSubview(deleteButton)
        
        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -0),
//            buttonStack.heightAnchor.constraint(equalToConstant: 90)
        ])
        
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        messageButton.addTarget(self, action: #selector(messageButtonTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
    }
    
    @objc private func copyButtonTapped() {
        delegate?.codeActionCellDidTapCopy()
    }
    
    @objc private func messageButtonTapped() {
        delegate?.codeActionCellDidTapMessage()
    }
    
    @objc private func shareButtonTapped() {
        delegate?.codeActionCellDidTapShare()
    }
    
    @objc private func deleteButtonTapped() {
        delegate?.codeActionCellDidTapDelete()
    }
    
    func configure(enabled: Bool) {
        copyButton.alpha = enabled ? 1.0 : 0.5
        messageButton.alpha = enabled ? 1.0 : 0.5
        shareButton.alpha = enabled ? 1.0 : 0.5
        deleteButton.alpha = enabled ? 1.0 : 0.5
        
        copyButton.isUserInteractionEnabled = enabled
        messageButton.isUserInteractionEnabled = enabled
        shareButton.isUserInteractionEnabled = enabled
        deleteButton.isUserInteractionEnabled = enabled
    }
}
