//
//  SettingsViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 10/6/24.
//

import UIKit
import RevenueCat
import RevenueCatUI
import SafariServices
import TipKit

class SettingsViewController: NNViewController, UICollectionViewDelegate, NNTippable {
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<NNSectionHeaderView>!
    private var footerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!
    
    private var nestCreationCoordinator: NestCreationCoordinator?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func loadView() {
        super.loadView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupRegistrations()
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
        
        // Add observer for mode changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleModeChange),
            name: ModeManager.modeDidChangeNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Reload data when returning to this screen (e.g., after sign out)
        applyInitialSnapshots()
    }

    override func setup() {
        navigationItem.title = "Menu"
        navigationController?.navigationBar.prefersLargeTitles = false
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
    
    func showTips() {
        
        trackScreenVisit()
        
        let snapshot = dataSource.snapshot()
        
        // Find accountSection & cell to display tip
        if let accountSection = snapshot.sectionIdentifiers.firstIndex(of: .account),
           let _ = snapshot.itemIdentifiers(inSection: .account).first {
            
            let accountIndexPath = IndexPath(item: 0, section: accountSection)
            
            // Make sure the cell is visible
            if let accountCell = collectionView.cellForItem(at: accountIndexPath) {
                
                // Show the tooltip anchored to the bottom of the setup cell
                if NNTipManager.shared.shouldShowTip(SettingsTips.profileTip) {
                    NNTipManager.shared.showTip(
                        SettingsTips.profileTip,
                        sourceView: accountCell,
                        in: self,
                        pinToEdge: .bottom,
                        offset: CGPoint(x: 0, y: 8)
                    )
                }
            }
        }
        
        if let myNestSection = snapshot.sectionIdentifiers.firstIndex(of: .myNest),
           let _ = snapshot.itemIdentifiers(inSection: .myNest).first {
            
            let sessionsIndexPath = IndexPath(item: 0, section: myNestSection)
            
            // Make sure the cell is visible
            if let sessionsCell = collectionView.cellForItem(at: sessionsIndexPath) {
                
                // Show the tooltip anchored to the bottom of the setup cell
                if NNTipManager.shared.shouldShowTip(SettingsTips.sessionsTip) {
                    NNTipManager.shared.showTip(
                        SettingsTips.sessionsTip,
                        sourceView: sessionsCell,
                        in: self,
                        pinToEdge: .bottom,
                        offset: CGPoint(x: 0, y: 0)
                    )
                }
            }
        }
    }
    
    private func setupRegistrations() {
        headerRegistration = UICollectionView.SupplementaryRegistration<NNSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] (headerView, string, indexPath) in
            guard let self = self,
                  let section = self.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            headerView.configure(title: section.rawValue)
        }

        footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionFooter) { (supplementaryView, string, indexPath) in
            var content = supplementaryView.defaultContentConfiguration()
            content.text = "❤️ \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))"
            content.textProperties.alignment = .center
            content.textProperties.font = UIFont.preferredFont(forTextStyle: .footnote)
            content.textProperties.color = .secondaryLabel
            supplementaryView.contentConfiguration = content
        }
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
            case .account, .currentNest:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(80))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 18, bottom: 20, trailing: 18)
                return section
                
            case .myNest, .mySitting, .general, .debug:
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.headerMode = .supplementary
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
        
        let listCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, indexPath, item in
            var content = cell.defaultContentConfiguration()
            
            switch item {
            case .myNestItem(let title, let symbolName), .generalItem(let title, let symbolName), .debugItem(let title, let symbolName):
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
                
                // Check if this is a myNest cell and apply disabled style if there's no current nest
                let section = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section]
                let hasCurrentNest = NestService.shared.currentNest != nil
                
                // Don't disable Sessions cell in sitter mode
                let isSitterModeSessionsCell = ModeManager.shared.isSitterMode && title == "Sessions" && section == .mySitting
                
                if section == .myNest && !hasCurrentNest && UserService.shared.isSignedIn && !isSitterModeSessionsCell {
                    // Apply disabled appearance
                    cell.alpha = 0.6
                } else {
                    cell.alpha = 1.0
                }
            default:
                break
            }
            
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
        }
        
        let currentNestCellRegistration = UICollectionView.CellRegistration<CurrentNestCell, Item> { cell, indexPath, item in
            if case let .currentNest(name, address) = item {
                // Check if this is the "no nest" placeholder
                let isNoNest = name.contains("Let's Setup")
                cell.configure(name: name, address: address, isNoNest: isNoNest)
            }
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch self.dataSource.snapshot().sectionIdentifiers[indexPath.section] {
            case .account:
                return collectionView.dequeueConfiguredReusableCell(using: accountCellRegistration, for: indexPath, item: item)
            case .currentNest:
                return collectionView.dequeueConfiguredReusableCell(using: currentNestCellRegistration, for: indexPath, item: item)
            case .myNest, .mySitting, .general, .debug:
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
        
        // Determine sections based on app mode
        let sections: [Section]
        if UserService.shared.isSignedIn {
            if ModeManager.shared.isSitterMode {
                sections = [.account, .mySitting, .general]
            } else {
                sections = [.account, .currentNest, .myNest, .general]
            }
        } else {
            sections = [.account, .myNest, .general]
        }
        
        snapshot.appendSections(sections)
        
        // Account section
        let currentUser = UserService.shared.currentUser
        snapshot.appendItems([.account(email: currentUser?.personalInfo.email.lowercased() ?? "Not signed in",
                                     name: currentUser?.personalInfo.name ?? "Tap to sign in")],
                           toSection: .account)
        
        // Current Nest section - only if user is signed in and is not in sitter mode
        if UserService.shared.isSignedIn && ModeManager.shared.isNestOwnerMode {
            if let currentNest = NestService.shared.currentNest {
                snapshot.appendItems([.currentNest(name: currentNest.name, address: currentNest.address)],
                                   toSection: .currentNest)
            } else {
                snapshot.appendItems([.currentNest(name: "Let's Setup Your Nest", address: "Tap here to create your nest")],
                                   toSection: .currentNest)
            }
        }
        
        // My Nest and My Sitting sections
        if UserService.shared.isSignedIn {
            if ModeManager.shared.isSitterMode {
                let sittingItems = [
                    ("Sessions", "calendar"),
                    ("Saved Nests", "heart"),
                ].map { Item.myNestItem(title: $0.0, symbolName: $0.1) }
                snapshot.appendItems(sittingItems, toSection: .mySitting)
            } else {
                let nestItems = [
                    ("Sessions", "calendar"),
                    ("Nest Members", "person.2.fill"),
                    ("Permanent Access", "person.badge.key.fill"),
                    ("Saved Sitters", "heart"),
                    ("Subscription", "creditcard")
                ].map { Item.myNestItem(title: $0.0, symbolName: $0.1) }
                snapshot.appendItems(nestItems, toSection: .myNest)
            }
        } else {
            // Default items for signed out state
            let defaultItems = [
                ("Nest Members", "person.2.fill"),
                ("Permanent Access", "person.badge.key.fill"),
                ("Saved Sitters", "heart"),
                ("Upcoming Sessions", "calendar"),
                ("Session History", "clock"),
                ("Subscription", "creditcard")
            ].map { Item.myNestItem(title: $0.0, symbolName: $0.1) }
            snapshot.appendItems(defaultItems, toSection: .myNest)
        }
        
        let generalItems = [
            ("Notifications", "bell"),
            ("App Icon", "app"),
            ("Terms & Privacy", "doc.text"),
            ("Support", "questionmark.circle"),
            ("Reset Setup", "arrow.counterclockwise")
        ].map { Item.generalItem(title: $0.0, symbolName: $0.1) }
        snapshot.appendItems(generalItems, toSection: .general)
        
        #if DEBUG
        snapshot.appendSections([.debug])
        let debugItems = [
            ("Reset App State", "arrow.counterclockwise"),
            ("View Logs", "text.alignleft"),
            ("UserDefaults Viewer", "externaldrive.fill"),
            ("Survey Dashboard", "chart.bar.fill"),
            ("Test Crash", "exclamationmark.triangle"),
            ("Button Playground", "switch.2"),
            ("Onboarding", "sparkles"),
            ("Create Session", "calendar.badge.plus"),
            ("Test Category Sheet", "rectangle.stack.badge.plus"),
            ("Test Entry Sheet", "note.text.badge.plus"),
            ("Test Session Sheet", "calendar.badge.plus"),
            ("Test Calendar Events", "calendar.badge.clock"),
            ("Test Event Creation", "calendar.badge.plus"),
            ("Test Invite Sitter Screen", "person.badge.plus"),
            ("Glassy Button Playground", "slider.horizontal.3"),
            ("Entry Review", "rectangle.portrait.on.rectangle.portrait.angled.fill"),
            ("Debug Card Stack", "rectangle.stack"),
            ("Test Session Bar", "rectangle.bottomthird.inset.filled"),
            ("Load Debug Sessions", "folder.badge.plus"),
            ("Test Add Place", "mappin.and.ellipse.circle.fill"),
            ("Test Place List", "list.star"),
            ("Test Place Map", "map.fill"),
            ("Test Invite Card", "rectangle.stack.badge.person.crop"),
            ("Test Invite Card Animation", "rectangle.portrait.inset.filled"),
            ("Toast Test", "text.bubble.fill"),
            ("Test Schedule View", "calendar.day.timeline.left"),
            ("Test Routine Detail", "list.bullet.clipboard"),
            ("Reset Tooltips", "questionmark.circle.fill"),
            ("Test Subscription Status", "creditcard.circle"),
        ].map { Item.debugItem(title: $0.0, symbolName: $0.1) }
        snapshot.appendItems(debugItems, toSection: .debug)
        #endif
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    enum Section: String, Hashable, CaseIterable {
        case account = "Account"
        case currentNest = "Current Nest"
        case myNest = "My Nest"
        case mySitting = "My Sitting"
        case general = "General"
        case debug = "Debug"
    }

    enum Item: Hashable {
        case account(email: String, name: String)
        case currentNest(name: String, address: String)
        case myNestItem(title: String, symbolName: String)
        case generalItem(title: String, symbolName: String)
        case debugItem(title: String, symbolName: String)
    }

    #if DEBUG
    private func handleDebugItemSelection(_ title: String) {
        switch title {
        case "Reset App State":
            // Add reset logic
            print("Resetting app state...")
        case "View Logs":
            // Show logs view
            print("Showing logs...")
            showLogs()
        case "UserDefaults Viewer":
            let vc = UserDefaultsViewerViewController()
            navigationController?.pushViewController(vc, animated: true)
        case "Test Crash":
            fatalError("Forced crash from debug menu")
        case "Button Playground":
            navigationController?.pushViewController(ButtonPlayground(), animated: true)
        case "Onboarding":
            present(OnboardingCoordinator().start(), animated: true)
        case "Create Session":
            let vc = EditSessionViewController()
            vc.modalPresentationStyle = .pageSheet
            present(vc, animated: true)
        case "Test Category Sheet":
            let vc = CategoryDetailViewController(sourceFrame: nil)
            present(vc, animated: true)
        case "Test Entry Sheet":
            let vc = EntryDetailViewController(category: "Test Category", sourceFrame: nil)
            vc.entryDelegate = self
            present(vc, animated: true)
        case "Test Session Sheet":
            let vc = SessionDetailViewController(sourceFrame: nil)
//            vc.sessionDelegate = self
            present(vc, animated: true)
        case "Test Calendar Events":
            let dateRange = DateInterval(
                start: Date.from(year: 2024, month: 12, day: 9)!,
                end: Date.from(year: 2024, month: 12, day: 12)!
            )
            let vc = SessionCalendarViewController(nestID: "", dateRange: dateRange)
            let nav = UINavigationController(rootViewController: vc)
            present(nav, animated: true)
        case "Test Event Creation":
            let vc = SessionEventViewController(entryRepository: NestService.shared)
            present(vc, animated: true)
        case "Glassy Button Playground":
            navigationController?.pushViewController(GlassyButtonPlayground(), animated: true)
        case "Entry Review":
            break
//            let reviewVC = UINavigationController(rootViewController: EntryReviewViewController())
//            present(reviewVC, animated: true)
        case "Debug Card Stack":
            let reviewVC = DebugCardStackView()
            present(reviewVC, animated: true)
        case "Test Session Bar":
            let sessionDebugVC = SessionDebugViewController()
            navigationController?.pushViewController(sessionDebugVC, animated: true)
        case "Load Debug Sessions":
            SessionService.shared.loadDebugSessions()
            // If the sessions view is visible, refresh it
            if let sessionsVC = presentedViewController as? UINavigationController,
               let topVC = sessionsVC.topViewController as? NestSessionsViewController {
                topVC.refreshSessions()
            }
        case "Test Add Place":
            let viewController = SelectPlaceViewController()
            let nav = UINavigationController(rootViewController: viewController)
            present(nav, animated: true)
        case "Test Place List":
            let viewController = PlaceListViewController()
            let nav = UINavigationController(rootViewController: viewController)
            present(nav, animated: true)
        case "Test Place Map":
            let viewController = PlacesMapViewController()
            navigationController?.pushViewController(viewController, animated: true)
        case "Test Invite Card":
            let vc = InviteCardDebugViewController()
            navigationController?.pushViewController(vc, animated: true)
        case "Test Invite Card Animation":
            let vc = InviteCardAnimationDebugViewController()
            navigationController?.pushViewController(vc, animated: true)
        case "Toast Test":
            let vc = ToastTestViewController()
            navigationController?.pushViewController(vc, animated: true)
        case "Survey Dashboard":
            let vc = SurveyDashboardViewController()
            let nav = UINavigationController(rootViewController: vc)
            present(nav, animated: true)
        case "Test Schedule View":
            let vc = CalendarViewController()
            let nav = UINavigationController(rootViewController: vc)
            present(nav, animated: true)
        case "Test Routine Detail":
            let mockRoutine = RoutineItem(
                title: "House Night-time",
                category: "Household",
                routineActions: [
                    "Lock garage door",
                    "Lock front, side, & back door",
                    "Put down shades with remote (on fridge)",
                    "Turn off all lights, leave porch light on"
                ]
            )
            let vc = RoutineDetailViewController(category: "Household", routine: mockRoutine, sourceFrame: nil)
            vc.routineDelegate = self
            present(vc, animated: true)
        case "Reset Tooltips":
            resetTooltipsDatastore()
        case "Test Subscription Status":
            showSubscriptionStatus()
        default:
            break
        }
    }
    #endif

    private func showLogs() {
        let vc = LogsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        switch item {
        case .account(let email, let name):
            if UserService.shared.isSignedIn {
                showUserProfile()
                NNTipManager.shared.dismissTip(SettingsTips.profileTip)
            } else {
                showUserSignIn()
            }
        case .currentNest(let name, _):
            // Check if this is the "no nest" placeholder
            if name.contains("Let's Setup") {
                showNestSetup()
            } else {
                // Regular nest detail flow
                let vc = NestDetailViewController()
                let nav = UINavigationController(rootViewController: vc)
                nav.isModalInPresentation = true
                present(nav, animated: true)
            }
        case .myNestItem(let title, _):
            if UserService.shared.isSignedIn {
                // Check if there's a current nest (skip check for Sessions in sitter mode)
                let hasCurrentNest = NestService.shared.currentNest != nil
                if !hasCurrentNest && !(ModeManager.shared.isSitterMode && title == "Sessions") {
                    // Show prompt to set up nest first
                    showNestSetupPrompt()
                    collectionView.deselectItem(at: indexPath, animated: true)
                    return
                }
                
                switch title {
                case "Sessions":
                    if ModeManager.shared.isNestOwnerMode {
                        let sessionsVC = NestSessionsViewController()
                        let nav = UINavigationController(rootViewController: sessionsVC)
                        present(nav, animated: true) {
                            NNTipManager.shared.dismissTip(SettingsTips.sessionsTip)
                        }
                    } else {
                        let sessionsVC = SitterSessionsViewController()
                        let nav = UINavigationController(rootViewController: sessionsVC)
                        present(nav, animated: true)
                    }
                case "Saved Sitters":
                    let sitterListVC = SitterListViewController(displayMode: .default)
                    let nav = UINavigationController(rootViewController: sitterListVC)
                    present(nav, animated: true)
                case "Nest Members":
                    let featurePreviewVC = NNFeaturePreviewViewController(
                        feature: SurveyService.Feature.nestMembers
                    )
                    featurePreviewVC.modalPresentationStyle = .formSheet
                    present(featurePreviewVC, animated: true)
                case "Permanent Access":
                    let featurePreviewVC = NNFeaturePreviewViewController(
                        feature: SurveyService.Feature.permanentAccess
                    )
                    featurePreviewVC.modalPresentationStyle = .formSheet
                    present(featurePreviewVC, animated: true)
                case "Subscription":
                    Task {
                        let hasProSubscription = await SubscriptionService.shared.hasProSubscription()
                        await MainActor.run {
                            if hasProSubscription {
                                showSubscriptionStatus()
                            } else {
                                showRevenueCatPaywall()
                            }
                        }
                    }
                default:
                    print("Selected My Nest item: \(title)")
                }
            } else {
                showSignInPrompt()
            }
        case .generalItem(let title, _):
            switch title {
            case "Notifications":
                let vc = NotificationsViewController()
                navigationController?.pushViewController(vc, animated: true)
            case "App Icon":
                let vc = AppIconViewController()
                let nav = UINavigationController(rootViewController: vc)
                present(nav, animated: true)
            case "Reset Setup":
                showResetSetupConfirmation()
            case "Terms & Privacy":
                showPrivacyPolicy()
            case "Support":
                showContactPage()
            default:
                print("Selected General item: \(title)")
            }
        
        #if DEBUG
        case .debugItem(let title, _):
            handleDebugItemSelection(title)
        #endif
            
        default:
            return
        }
        
        // Optionally, deselect the item
        collectionView.deselectItem(at: indexPath, animated: true)
    }

    func showUserSignIn() {
        let vc = LandingViewController()
        vc.delegate = self
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    func showUserProfile() {
        let vc = ProfileViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.isModalInPresentation = true
        present(nav, animated: true)
    }

    private func showSignInPrompt() {
        let alert = UIAlertController(
            title: "Sign In Required",
            message: "Please sign in to access this feature",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign In", style: .default) { [weak self] _ in
            self?.showUserSignIn()
        })
        
        present(alert, animated: true)
    }

    private func showNestSetupPrompt() {
        let alert = UIAlertController(
            title: "Nest Setup Required",
            message: "Please set up your nest before accessing this feature",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Set Up Nest", style: .default) { [weak self] _ in
            self?.showNestSetup()
        })
        
        present(alert, animated: true)
    }

    private func showNestSetup() {
        
        nestCreationCoordinator = NestCreationCoordinator()
        guard let nestCreationCoordinator else { return }
        present(nestCreationCoordinator.start(), animated: true)
    }
    
    private func showRevenueCatPaywall() {
        let paywallViewController = PaywallViewController()
        
        paywallViewController.delegate = self
        present(paywallViewController, animated: true)
        
        // Mark the final setup step as complete when paywall is viewed
        SetupService.shared.markStepComplete(.finalStep)
    }
    
    private func showSubscriptionStatus() {
        let subscriptionStatusVC = SubscriptionStatusViewController()
        subscriptionStatusVC.modalPresentationStyle = .pageSheet
        
        if let sheet = subscriptionStatusVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = false
        }
        
        present(subscriptionStatusVC, animated: true)
    }
    
    private func showResetSetupConfirmation() {
        let alert = UIAlertController(
            title: "Reset Setup",
            message: "This will reset your setup progress and you'll need to go through the setup flow again. Are you sure?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            SetupService.shared.resetSetupForCurrentUser()
            
            // Show confirmation
            let successAlert = UIAlertController(
                title: "Setup Reset",
                message: "Your setup has been reset. You'll see the setup flow on your next visit to the home screen.",
                preferredStyle: .alert
            )
            successAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(successAlert, animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showPrivacyPolicy() {
        guard let url = URL(string: "https://www.nestnoteapp.com/privacypolicy") else { return }
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true)
    }
    
    private func showContactPage() {
        guard let url = URL(string: "https://www.nestnoteapp.com/contact") else { return }
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true)
    }

    @objc private func handleUserInformationUpdate() {
        applyInitialSnapshots()
    }
    
    @objc private func handleModeChange() {
        applyInitialSnapshots()
    }
    
    private func resetTooltipsDatastore() {
        let alert = UIAlertController(
            title: "Reset Tooltips",
            message: "This will reset all tooltip data and they will show again. Are you sure?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            print("🔄 [TipKit Debug] SettingsViewController: User confirmed tooltip reset")
            NNTipManager.shared.resetAllTips()
            
            // Show confirmation
            let successAlert = UIAlertController(
                title: "Tooltips Reset",
                message: "All tooltip data has been reset. Tips will show again when appropriate.",
                preferredStyle: .alert
            )
            successAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(successAlert, animated: true)
        })
        
        present(alert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// Add extension for AuthenticationDelegate
extension SettingsViewController: AuthenticationDelegate {
    
    func authenticationComplete() {
        // Reload the collection view data
        applyInitialSnapshots()
        self.showToast(text: "Signed in")
    }
    
    func signUpTapped() {
        let coordinator = OnboardingCoordinator()
        let onboardingVC = coordinator.start()
        coordinator.authenticationDelegate = self
        self.present(onboardingVC, animated: true)
    }
    
    func signUpComplete() {
        applyInitialSnapshots()
        self.showToast(text: "Welcome to NestNote")
    }
}

extension SettingsViewController: EntryDetailViewControllerDelegate {
    func entryDetailViewController(didDeleteEntry: BaseEntry) {
        showToast(text: "Entry saved: \(didDeleteEntry.title)")
    }
    
    func entryDetailViewController(didSaveEntry entry: BaseEntry?) {
        //
    }
}

extension SettingsViewController: PaywallViewControllerDelegate {
    func paywallViewController(_ controller: PaywallViewController, didFinishPurchasingWith customerInfo: CustomerInfo) {
        controller.dismiss(animated: true) {
            self.showToast(text: "Subscription activated!")
            Logger.log(level: .info, category: .purchases, message: "Subscription purchase completed")
            
            // Refresh subscription status after purchase
            Task {
                await SubscriptionService.shared.refreshCustomerInfo()
            }
        }
    }
    
    func paywallViewController(_ controller: PaywallViewController, didFailPurchasingWith error: Error) {
        Logger.log(level: .error, category: .purchases, message: "Subscription purchase failed: \(error.localizedDescription)")
        showToast(text: "Purchase failed. Please try again.")
    }
    
    func paywallViewController(_ controller: PaywallViewController, didFinishRestoringWith customerInfo: CustomerInfo) {
        controller.dismiss(animated: true) {
            self.showToast(text: "Subscription restored!")
            Logger.log(level: .info, category: .purchases, message: "Subscription restored successfully")
            
            // Refresh subscription status after restore
            Task {
                await SubscriptionService.shared.refreshCustomerInfo()
            }
        }
    }
    
    func paywallViewController(_ controller: PaywallViewController, didFailRestoringWith error: Error) {
        Logger.log(level: .error, category: .purchases, message: "Subscription restore failed: \(error.localizedDescription)")
        showToast(text: "Restore failed. Please try again.")
    }
}

extension SettingsViewController: RoutineDetailViewControllerDelegate {
    func routineDetailViewController(didSaveRoutine routine: RoutineItem?) {
        if let routine = routine {
            showToast(text: "Routine saved: \(routine.title)")
        }
    }
    
    func routineDetailViewController(didDeleteRoutine routine: RoutineItem) {
        showToast(text: "Routine deleted: \(routine.title)")
    }
}
