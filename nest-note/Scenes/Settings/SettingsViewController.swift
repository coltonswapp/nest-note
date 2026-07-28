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
    private static let settingsPromoHeight: CGFloat = 136
    private static let settingsPromoVerticalPadding: CGFloat = 6
    private static let sitterReferralBannerHeight: CGFloat = 118
    private static let sitterReferralBannerVerticalPadding: CGFloat = 0

    private var hasProSubscription = true
    private var isFreeTrialEligible = false
    private var readinessScore: Int?
    private var isFirstAppearance = true
    
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
        refreshPromoVisibility()
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
        if isFirstAppearance {
            isFirstAppearance = false
        } else {
            applyInitialSnapshots()
        }
        refreshPromoVisibility()
    }

    private func refreshPromoVisibility() {
        Task {
            async let hasPro = SubscriptionService.shared.hasProSubscription()
            async let trialEligible = SubscriptionService.shared.isEligibleForFreeTrial()
            async let score = loadReadinessScoreIfNeeded()
            let (pro, trial, readinessScore) = await (hasPro, trialEligible, score)
            await MainActor.run {
                self.hasProSubscription = pro
                self.isFreeTrialEligible = trial
                self.readinessScore = readinessScore
                self.applyInitialSnapshots()
            }
        }
    }

    private func loadReadinessScoreIfNeeded() async -> Int? {
        guard FeatureFlagService.shared.isEnabled(.nestReadinessScoreEnabled),
              ModeManager.shared.isNestOwnerMode,
              UserService.shared.isSignedIn,
              let nestID = NestService.shared.currentNest?.id,
              NestReadinessBannerStore.isHomeBannerDismissed(for: nestID) else {
            return nil
        }

        let result = try? await NestReadinessService.shared.calculateReadiness(forceRefresh: false)
        return result?.totalScore
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
            content.text = "💚 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))"
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
            case .premiumPromo:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(Self.settingsPromoHeight)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 18, bottom: 20, trailing: 18)
                return section

            case .sitterReferral:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(Self.sitterReferralBannerHeight)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
                return section

            case .account:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(80))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 18, bottom: 20, trailing: 18)
                return section

            case .currentNest:
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.headerMode = .supplementary
                let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(32))
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
                return section
                
            case .myNest, .mySitting, .general, .support, .admin, .experimental:
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
        let sitterReferralCellRegistration = UICollectionView.CellRegistration<PremiumPromoCell, Item> { [weak self] cell, _, item in
            if case .sitterReferral = item {
                cell.configure(
                    variant: .stackedIconsLabel,
                    ctaTitle: SitterReferralCopy.bannerCtaTitle,
                    title: SitterReferralCopy.title,
                    subtitle: SitterReferralCopy.subtitle,
                    contentVerticalPadding: Self.sitterReferralBannerVerticalPadding
                )
                cell.onUpgradeTapped = { [weak self] in
                    self?.presentSitterReferralScreen()
                }
            }
        }

        let premiumPromoCellRegistration = UICollectionView.CellRegistration<PremiumPromoCell, Item> { [weak self] cell, _, item in
            if case .premiumPromo = item {
                cell.configure(
                    variant: .stackedIconsLabel,
                    ctaTitle: PremiumPromoCopy.ctaTitle(
                        isFreeTrialEligible: self?.isFreeTrialEligible ?? false
                    ),
                    title: PremiumPromoCopy.settingsTitle,
                    subtitle: PremiumPromoCopy.settingsSubtitle,
                    contentVerticalPadding: Self.settingsPromoVerticalPadding
                )
                cell.onUpgradeTapped = { [weak self] in
                    self?.presentPremiumPaywall()
                }
            }
        }

        let accountCellRegistration = UICollectionView.CellRegistration<AccountCell, Item> { cell, indexPath, item in
            if case let .account(email, name) = item {
                cell.configure(email: email, name: name)
            }
        }
        
        let listCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, indexPath, item in
            var content = cell.defaultContentConfiguration()
            
            switch item {
            case .readinessScore:
                break
            case .myNestItem(let title, let symbolName), .generalItem(let title, let symbolName), .supportItem(let title, let symbolName), .experimentalItem(let title, let symbolName):
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
                
                cell.contentConfiguration = content
                cell.accessories = [.disclosureIndicator()]
                
            case .adminItem(let title, let symbolName):
                content.text = title
                if title == "Debug as" {
                    content.secondaryText = FeatureFlagService.shared.getDebugUserStatus().capitalized
                    content.secondaryTextProperties.color = .secondaryLabel
                }
                let symbolConfiguration = UIImage.SymbolConfiguration(weight: .bold)
                let image = UIImage(systemName: symbolName, withConfiguration: symbolConfiguration)?
                    .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
                content.image = image
                content.imageProperties.tintColor = NNColors.primary
                content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
                content.imageToTextPadding = 16
                content.directionalLayoutMargins.top = 16
                content.directionalLayoutMargins.bottom = 16

                cell.contentConfiguration = content
                cell.accessories = [.disclosureIndicator()]
                
            default:
                break
            }
        }
        
        let readinessScoreCellRegistration = UICollectionView.CellRegistration<NestReadinessCompactCell, Item> { cell, _, item in
            if case let .readinessScore(score) = item {
                cell.configure(score: score)
            }
        }

        let currentNestCellRegistration = UICollectionView.CellRegistration<CurrentNestCell, Item> { cell, indexPath, item in
            if case let .currentNest(name, address) = item {
                let isNoNest = name.contains("Let's Setup")
                cell.configure(name: name, address: address, isNoNest: isNoNest)
            }
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .premiumPromo:
                return collectionView.dequeueConfiguredReusableCell(
                    using: premiumPromoCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .sitterReferral:
                return collectionView.dequeueConfiguredReusableCell(
                    using: sitterReferralCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .readinessScore:
                return collectionView.dequeueConfiguredReusableCell(
                    using: readinessScoreCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .account:
                return collectionView.dequeueConfiguredReusableCell(using: accountCellRegistration, for: indexPath, item: item)
            case .currentNest:
                return collectionView.dequeueConfiguredReusableCell(using: currentNestCellRegistration, for: indexPath, item: item)
            case .myNestItem, .generalItem, .supportItem, .adminItem, .experimentalItem:
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

        if !hasProSubscription && ModeManager.shared.isNestOwnerMode {
            snapshot.appendSections([.premiumPromo])
            snapshot.appendItems([.premiumPromo], toSection: .premiumPromo)
        }

        if shouldShowSitterReferralBanner {
            snapshot.appendSections([.sitterReferral])
            snapshot.appendItems([.sitterReferral], toSection: .sitterReferral)
        }
        
        // Determine sections based on app mode
        let sections: [Section]
        if UserService.shared.isSignedIn {
            if ModeManager.shared.isSitterMode {
                sections = [.account, .mySitting, .general, .support]
            } else {
                sections = [.account, .currentNest, .myNest, .general, .support]
            }
        } else {
            sections = [.account, .myNest, .general, .support]
        }
        
        snapshot.appendSections(sections)
        
        // Account section
        let currentUser = UserService.shared.currentUser
        snapshot.appendItems([.account(email: currentUser?.personalInfo.email.lowercased() ?? "Not signed in",
                                     name: currentUser?.personalInfo.name ?? "Tap to sign in")],
                           toSection: .account)
        
        // Current Nest section - only if user is signed in and is not in sitter mode
        if UserService.shared.isSignedIn && ModeManager.shared.isNestOwnerMode {
            var currentNestItems: [Item] = []
            if let currentNest = NestService.shared.currentNest {
                currentNestItems.append(.currentNest(name: currentNest.name, address: currentNest.address))
                appendReadinessItems(to: &currentNestItems, nestID: currentNest.id)
            } else {
                currentNestItems.append(.currentNest(name: "Let's Setup Your Nest", address: "Tap here to create your nest"))
            }
            snapshot.appendItems(currentNestItems, toSection: .currentNest)
        }
        
        // My Nest and My Sitting sections
        if UserService.shared.isSignedIn {
            if ModeManager.shared.isSitterMode {
                var sittingRows = [
                    ("Sessions", "calendar"),
                    ("Saved Nests", "heart"),
                ]
                if shouldShowSitterReferralEntry {
                    sittingRows.append((SitterReferralCopy.settingsRowTitle, "gift.fill"))
                }
                let sittingItems = sittingRows.map { Item.myNestItem(title: $0.0, symbolName: $0.1) }
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
            ("Rate App", "star"),
            ("Terms & Privacy", "doc.text")
        ].map { Item.generalItem(title: $0.0, symbolName: $0.1) }
        snapshot.appendItems(generalItems, toSection: .general)

        let supportItems = makeSupportItems()
        snapshot.appendItems(supportItems, toSection: .support)
        
        #if DEBUG
        snapshot.appendSections([.admin])
        let adminItems = [
            ("Survey Dashboard", "chart.bar.doc.horizontal"),
            ("Referral Admin", "person.badge.plus.fill"),
            ("Referral Analytics", "chart.line.uptrend.xyaxis"),
            ("Sitter Referral Payouts", "dollarsign.circle.fill"),
            ("View Logs", "doc.text.magnifyingglass"),
            ("UserDefaults Viewer", "list.bullet.rectangle"),
            ("Reset App State", "arrow.counterclockwise"),
            ("Debug as", "person.crop.circle.badge.checkmark"),
        ].map { Item.adminItem(title: $0.0, symbolName: $0.1) }
        snapshot.appendItems(adminItems, toSection: .admin)
        snapshot.appendSections([.experimental])
        var experimentalItems = [
            ("Test Crash", "exclamationmark.triangle"),
            ("Button Playground", "switch.2"),
            ("Explosion Playground", "sparkles.rectangle.stack"),
            ("Finish Screen", "slider.horizontal.below.rectangle"),
            ("Sitter Finish Screen", "person.crop.circle.badge.checkmark"),
            ("Sitter Payment Setup", "dollarsign.circle"),
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
            ("Test Invite Your Sitter", "person.wave.2.fill"),
            ("Toast Test", "text.bubble.fill"),
            ("Markdown Preview", "doc.richtext"),
            ("Sitters article (full)", "text.book.closed"),
            ("Sitters article (brief)", "text.book.closed.fill"),
            ("Test Schedule View", "calendar.day.timeline.left"),
            ("Test Routine Detail", "list.bullet.clipboard"),
            ("Reset Tooltips", "questionmark.circle.fill"),
            ("Test Subscription Status", "creditcard.circle"),
            ("Feature Info Paywall", "sparkles.rectangle.stack"),
            ("Waterfall Grid", "square.grid.2x2"),
            ("Sitter Referral Screen", "gift.fill"),
            ("Delete Sitter Referral Code", "trash"),
        ].map { Item.experimentalItem(title: $0.0, symbolName: $0.1) }

        if isNestReadinessEnabled, NestService.shared.currentNest != nil {
            experimentalItems.append(.experimentalItem(title: "Show on Home Screen", symbolName: "house.fill"))
        }

        snapshot.appendItems(experimentalItems, toSection: .experimental)
        #endif
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private var isNestReadinessEnabled: Bool {
        FeatureFlagService.shared.isEnabled(.nestReadinessScoreEnabled)
    }

    private func appendReadinessItems(to items: inout [Item], nestID: String) {
        guard isNestReadinessEnabled else { return }

        let showOnHome = !NestReadinessBannerStore.isHomeBannerDismissed(for: nestID)
        if !showOnHome, let score = readinessScore {
            items.append(.readinessScore(score: score))
        }
    }

    enum Section: String, Hashable, CaseIterable {
        case premiumPromo = "Premium"
        case sitterReferral = "Refer Friends"
        case account = "Account"
        case currentNest = "Current Nest"
        case myNest = "My Nest"
        case mySitting = "My Sitting"
        case general = "General"
        case support = "Support"
        case admin = "Admin"
        case experimental = "Experimental"
    }

    enum Item: Hashable {
        case premiumPromo
        case sitterReferral
        case account(email: String, name: String)
        case currentNest(name: String, address: String)
        case readinessScore(score: Int)
        case myNestItem(title: String, symbolName: String)
        case generalItem(title: String, symbolName: String)
        case supportItem(title: String, symbolName: String)
        case adminItem(title: String, symbolName: String)
        case experimentalItem(title: String, symbolName: String)
    }

    #if DEBUG
    private func handleDebugItemSelection(_ title: String) {
        switch title {
        case "Debug as":
            showDebugUserStatusPicker()
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
        case "Explosion Playground":
            navigationController?.pushViewController(ExplosionViewController(), animated: true)
        case "Finish Screen":
            let finishVC = OBFinishViewController()
            finishVC.enableDebugMode()
            let nav = UINavigationController(rootViewController: finishVC)
            present(nav, animated: true)
        case "Sitter Finish Screen":
            let finishVC = OBFinishViewController()
            finishVC.enableSitterDebugMode()
            let nav = UINavigationController(rootViewController: finishVC)
            present(nav, animated: true)
        case "Sitter Payment Setup":
            let venmoVC = OBVenmoViewController()
            venmoVC.enableDebugMode()
            let nav = UINavigationController(rootViewController: venmoVC)
            present(nav, animated: true)
        case "Onboarding":
            let coordinator = OnboardingCoordinator()
            coordinator.enablePreviewMode()
            present(coordinator.start(), animated: true)
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
        case "Test Invite Your Sitter":
            let vc = InviteYourSitterViewController.makeDebugInstance()
            let nav = UINavigationController(rootViewController: vc)
            present(nav, animated: true)
        case "Toast Test":
            let vc = ToastTestViewController()
            navigationController?.pushViewController(vc, animated: true)
        case "Markdown Preview":
            let vc = MarkdownTestViewController()
            navigationController?.pushViewController(vc, animated: true)
        case "Sitters article (full)":
            let vc = MarkdownTestViewController(markdown: SittersGettingFamiliesArticle.markdownFull)
            navigationController?.pushViewController(vc, animated: true)
        case "Sitters article (brief)":
            let vc = MarkdownTestViewController(markdown: SittersGettingFamiliesArticle.markdownBrief)
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
        case "Feature Info Paywall":
            showFeatureInfoPaywall()
        case "Waterfall Grid":
            presentWaterfallGridExperiment()
        case "Sitter Referral Screen":
            presentSitterReferralScreen()
        case "Delete Sitter Referral Code":
            deleteSitterReferralCodeForDebug()
        case "Show on Home Screen":
            showReadinessHomeBannerPicker()
        case "Referral Admin":
            let vc = ReferralAdminViewController()
            navigationController?.pushViewController(vc, animated: true)
        case "Referral Analytics":
            let vc = ReferralAnalyticsViewController()
            navigationController?.pushViewController(vc, animated: true)
        case "Sitter Referral Payouts":
            let vc = SitterReferralPayoutsViewController()
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }

    private func showDebugUserStatusPicker() {
        let currentStatus = FeatureFlagService.shared.getDebugUserStatus()

        let alert = UIAlertController(
            title: "Debug as",
            message: "Choose which subscription tier to simulate.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(
            title: currentStatus == "free" ? "Free ✓" : "Free",
            style: .default
        ) { [weak self] _ in
            FeatureFlagService.shared.setDebugUserStatus("free")
            self?.reconfigureDebugAsItem()
        })

        alert.addAction(UIAlertAction(
            title: currentStatus == "pro" ? "Pro ✓" : "Pro",
            style: .default
        ) { [weak self] _ in
            FeatureFlagService.shared.setDebugUserStatus("pro")
            self?.reconfigureDebugAsItem()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        DispatchQueue.main.async { [weak self] in
            guard let self, self.view.window != nil else { return }
            self.present(alert, animated: true)
        }
    }

    private func reconfigureDebugAsItem() {
        let debugAsItem = Item.adminItem(title: "Debug as", symbolName: "person.crop.circle.badge.checkmark")
        var snapshot = dataSource.snapshot()
        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems([debugAsItem])
        } else {
            snapshot.reloadItems([debugAsItem])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func showReadinessHomeBannerPicker() {
        guard let nestID = NestService.shared.currentNest?.id else { return }

        let showOnHome = !NestReadinessBannerStore.isHomeBannerDismissed(for: nestID)
        let alert = UIAlertController(
            title: "Show on Home Screen",
            message: "Choose where the Nest Score banner appears.",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(
            title: showOnHome ? "Show on Home Screen ✓" : "Show on Home Screen",
            style: .default
        ) { [weak self] _ in
            NestReadinessBannerStore.setHomeBannerVisible(true, for: nestID)
            self?.refreshPromoVisibility()
        })

        alert.addAction(UIAlertAction(
            title: showOnHome ? "Show in Settings Only" : "Show in Settings Only ✓",
            style: .default
        ) { [weak self] _ in
            NestReadinessBannerStore.setHomeBannerVisible(false, for: nestID)
            self?.refreshPromoVisibility()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(alert, animated: true)
    }
    #endif

    private func showLogs() {
        let vc = LogsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        #if DEBUG
        switch item {
        case .adminItem(let title, _), .experimentalItem(let title, _):
            handleDebugItemSelection(title)
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        default:
            break
        }
        #endif
        
        switch item {
        case .premiumPromo:
            presentPremiumPaywall()
        case .sitterReferral:
            presentSitterReferralScreen()
        case .readinessScore:
            presentReadinessDetail()
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
                // Check if there's a current nest (skip for sitter-only rows that don't need a nest)
                let hasCurrentNest = NestService.shared.currentNest != nil
                let skipsNestRequirement = ModeManager.shared.isSitterMode
                    && (title == "Sessions" || title == SitterReferralCopy.settingsRowTitle)
                if !hasCurrentNest && !skipsNestRequirement {
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
//                            NNTipManager.shared.dismissTip(SettingsTips.sessionsTip)
                        }
                    } else {
                        let sessionsVC = SitterSessionsViewController()
                        let nav = UINavigationController(rootViewController: sessionsVC)
                        present(nav, animated: true)
                    }
                case SitterReferralCopy.settingsRowTitle:
                    presentSitterReferralScreen()
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
                        // Force refresh subscription info before checking
                        await SubscriptionService.shared.refreshCustomerInfo()
                        let hasProSubscription = await SubscriptionService.shared.hasProSubscription()
                        await MainActor.run {
                            if hasProSubscription {
                                showSubscriptionStatus()
                            } else {
                                presentPremiumPaywall()
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
            case "Rate App":
                RatingManager.shared.requestRatingManually()
            case "Terms & Privacy":
                showPrivacyPolicy()
            default:
                print("Selected General item: \(title)")
            }
        case .supportItem(let title, _):
            switch title {
            case "How It Works":
                showHowItWorks()
            case "Text Support":
                showTextSupport()
            case "Contact Support":
                showContactPage()
            default:
                print("Selected Support item: \(title)")
            }

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
    
    private var shouldShowSitterReferralBanner: Bool {
        FeatureFlagService.shared.isEnabled(.sitterReferralProgramEnabled)
            && UserService.shared.isSignedIn
            && ModeManager.shared.isSitterMode
    }

    private var shouldShowSitterReferralEntry: Bool {
        shouldShowSitterReferralBanner
    }

    private func presentSitterReferralScreen() {
        let vc = SitterReferralViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    #if DEBUG
    private func deleteSitterReferralCodeForDebug() {
        guard let user = UserService.shared.currentUser else {
            showToast(text: "Sign in required")
            return
        }

        let existingCode = user.sitterReferralCode?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !existingCode.isEmpty else {
            showToast(text: "No referral code to delete")
            return
        }

        let alert = UIAlertController(
            title: "Delete Referral Code?",
            message: "Removes \(existingCode.uppercased()) from Firestore and your profile.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            Task {
                do {
                    try await SitterReferralService.shared.deleteReferralCode(for: user)
                    await MainActor.run {
                        self?.showToast(text: "Referral code deleted")
                    }
                } catch {
                    await MainActor.run {
                        self?.showToast(text: "Couldn't delete code. Try again.")
                    }
                }
            }
        })
        present(alert, animated: true)
    }
    #endif

    private func presentPremiumPaywall() {
        let paywall = FeatureInfoPaywallViewController()
        paywall.modalPresentationStyle = .pageSheet
        if let sheet = paywall.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(paywall, animated: true)
    }

    private func presentReadinessDetail() {
        let detailVC = NestReadinessDetailViewController()
        detailVC.delegate = self
        detailVC.modalPresentationStyle = .pageSheet
        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(detailVC, animated: true)
    }

    private func presentCategoryView(category: String) {
        guard NestService.shared.currentNest != nil else { return }

        Task {
            do {
                let (_, places) = try await NestService.shared.fetchEntriesAndPlaces()
                await MainActor.run {
                    let categoryVC = NestCategoryViewController(
                        category: category,
                        places: places,
                        entryRepository: NestService.shared
                    )
                    self.navigationController?.pushViewController(categoryVC, animated: true)
                }
            } catch {
                Logger.log(level: .error, category: .general, message: "Failed to fetch places for category view: \(error)")
                await MainActor.run {
                    let categoryVC = NestCategoryViewController(
                        category: category,
                        places: [],
                        entryRepository: NestService.shared
                    )
                    self.navigationController?.pushViewController(categoryVC, animated: true)
                }
            }
        }
    }

    #if DEBUG
    private func presentWaterfallGridExperiment() {
        guard UserService.shared.isSignedIn else {
            showSignInPrompt()
            return
        }

        guard NestService.shared.currentNest != nil else {
            showNestSetupPrompt()
            return
        }

        Task {
            do {
                let (groupedEntries, places) = try await NestService.shared.fetchEntriesAndPlaces()
                let category = Self.bestCategoryForWaterfallExperiment(from: groupedEntries)

                await MainActor.run {
                    let categoryVC = NestCategoryViewController(
                        category: category,
                        places: places,
                        entryRepository: NestService.shared,
                        itemDisplayLayout: .waterfallGrid
                    )
                    self.navigationController?.pushViewController(categoryVC, animated: true)
                }
            } catch {
                Logger.log(
                    level: .error,
                    category: .general,
                    message: "Failed to launch waterfall grid experiment: \(error)"
                )
                await MainActor.run {
                    self.showToast(text: "Couldn't load category data")
                }
            }
        }
    }

    private static func bestCategoryForWaterfallExperiment(from groupedEntries: [String: [BaseEntry]]) -> String {
        let topLevelCounts = groupedEntries.reduce(into: [String: Int]()) { counts, pair in
            let topLevel = pair.key.components(separatedBy: "/").first ?? pair.key
            counts[topLevel, default: 0] += pair.value.count
        }

        if let richest = topLevelCounts.max(by: { $0.value < $1.value })?.key, richest.isEmpty == false {
            return richest
        }

        return "Household"
    }
    #endif

    private func showRevenueCatPaywall() {
        let paywallViewController = PaywallViewController()
        
        paywallViewController.delegate = self
        present(paywallViewController, animated: true)
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

    private func showFeatureInfoPaywall() {
        presentPaywallPreview(FeatureInfoPaywallViewController())
    }

    private func presentPaywallPreview(_ paywallVC: UIViewController) {
        paywallVC.modalPresentationStyle = .pageSheet

        if let sheet = paywallVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }

        present(paywallVC, animated: true)
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

    private func makeSupportItems() -> [Item] {
        var items: [(String, String)] = [
            ("How It Works", "book.pages"),
        ]

        if FeatureFlagService.shared.isEnabled(.supportTextEnabled) {
            items.append(("Text Support", "message"))
        }

        items.append(("Contact Support", "questionmark.circle"))
        return items.map { Item.supportItem(title: $0.0, symbolName: $0.1) }
    }

    private func showHowItWorks() {
        let vc = MarkdownTestViewController(
            markdown: HowItWorksArticle.markdown,
            showsShareButton: false
        )
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showTextSupport() {
        var messageLines = ["Hi NestNote support, I need help with:"]

        if let userID = UserService.shared.currentUser?.id {
            messageLines.append("")
            messageLines.append("User ID: \(userID)")
        }

        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            messageLines.append("App version: \(version) (\(build))")
        }

        let body = messageLines.joined(separator: "\n")
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.insert(charactersIn: ":/")

        guard let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowedCharacters),
              let smsURL = URL(string: "sms:\(SupportContact.textSupportPhoneNumber)?body=\(encodedBody)") else {
            showTextSupportUnavailableAlert()
            return
        }

        guard UIApplication.shared.canOpenURL(smsURL) else {
            showTextSupportUnavailableAlert()
            return
        }

        UIApplication.shared.open(smsURL)
        HapticsHelper.lightHaptic()
    }

    private func showTextSupportUnavailableAlert() {
        let alert = UIAlertController(
            title: "Messages Not Available",
            message: "Text us at \(SupportContact.textSupportDisplayNumber) and we'll help you out.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Copy Number", style: .default) { _ in
            UIPasteboard.general.string = SupportContact.textSupportDisplayNumber
        })
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    private func showDeleteAccountConfirmation() {
        let firstAlert = UIAlertController(
            title: "Delete Account",
            message: "Are you sure you want to delete your account? This action cannot be undone and will permanently delete:\n\n• Your nest and all its data\n• All your entries, routines, and places\n• Your saved sitters\n• Your account information",
            preferredStyle: .alert
        )

        firstAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        firstAlert.addAction(UIAlertAction(title: "Continue", style: .destructive) { [weak self] _ in
            self?.showFinalDeleteConfirmation()
        })

        present(firstAlert, animated: true)
    }

    private func showFinalDeleteConfirmation() {
        let secondAlert = UIAlertController(
            title: "Final Confirmation",
            message: "This is your last chance. Once deleted, your account and all data cannot be recovered.\n\nType 'DELETE' below to confirm:",
            preferredStyle: .alert
        )

        secondAlert.addTextField { textField in
            textField.placeholder = "Type 'DELETE' here"
            textField.autocapitalizationType = .allCharacters
            textField.autocorrectionType = .no
        }

        secondAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        secondAlert.addAction(UIAlertAction(title: "Delete Account", style: .destructive) { [weak self] _ in
            guard let textField = secondAlert.textFields?.first,
                  let enteredText = textField.text,
                  enteredText.uppercased() == "DELETE" else {

                // Show error if user didn't type DELETE correctly
                let errorAlert = UIAlertController(
                    title: "Invalid Confirmation",
                    message: "You must type 'DELETE' exactly to confirm account deletion.",
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    // Show the confirmation dialog again
                    self?.showFinalDeleteConfirmation()
                })
                self?.present(errorAlert, animated: true)
                return
            }

            // User typed DELETE correctly, proceed with deletion
            self?.performAccountDeletion()
        })

        present(secondAlert, animated: true)
    }

    private func performAccountDeletion() {
        // Show loading indicator
        let loadingAlert = UIAlertController(
            title: "Deleting Account",
            message: "Please wait while we delete your account...",
            preferredStyle: .alert
        )
        present(loadingAlert, animated: true)

        loadingAlert.dismiss(animated: true) {
            let errorAlert = UIAlertController(
                title: "Not Available",
                message: "Account deletion is not currently available. Please contact support at support@nestnoteapp.com.",
                preferredStyle: .alert
            )
            errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(errorAlert, animated: true)
        }
    }


    private func showTestSurveyScreen() {
        let surveyVC = NNOnboardingSurveyViewController()

        // Set the title and subtitle manually without using configure(with:)
        surveyVC.loadViewIfNeeded()
        surveyVC.setupOnboarding(title: "What's your primary childcare experience?", subtitle: "Select the option that best describes your background")

        // Set test options with subtitles for single-select mode
        let optionsWithSubtitles = [
            SurveyOption(title: "Professional nanny"),
            SurveyOption(title: "Family babysitting"),
            SurveyOption(title: "Occasional babysitting"),
            SurveyOption(title: "First time babysitting"),
            SurveyOption(title: "Other experience")
        ]

        #if DEBUG
        // Test with single-select mode (isMultiSelect: false)
        surveyVC.setTestOptions(optionsWithSubtitles, isMultiSelect: false)
        #endif

        let nav = UINavigationController(rootViewController: surveyVC)
        present(nav, animated: true)
    }

    private func showTestFinishAnimation() {
        let finishVC = OBFinishViewController()
        let nav = UINavigationController(rootViewController: finishVC)
        present(nav, animated: true)
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
        TikTokTracker.shared.trackSubscribe()
        controller.dismiss(animated: true) {
            SubscriptionService.shared.notifySuccessfulPurchase()
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
        TikTokTracker.shared.trackSubscribe()
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

extension SettingsViewController: JoinSessionViewControllerDelegate {
    func joinSessionViewController(didAcceptInvite session: SitterSession) {
        // For nest owners redeeming a sitter-initiated request, this won't be called
        // since they go through the completion flow instead
        showToast(text: "Session created successfully")
    }
}

extension SettingsViewController: CreateSessionRequestViewControllerDelegate {
    func createSessionRequestViewController(_ controller: CreateSessionRequestViewController, didCreateRequest inviteCode: String, sessionID: String) {
        // Use InviteDetailViewController to show the code with copy/share functionality
        let inviteDetailVC = InviteDetailViewController()
        inviteDetailVC.configure(with: inviteCode, sessionID: sessionID, sitter: nil, isSitterInitiated: true)
        controller.navigationController?.pushViewController(inviteDetailVC, animated: true)
    }
}

extension SettingsViewController: NestReadinessDetailViewControllerDelegate {
    func readinessDetailViewController(_ controller: NestReadinessDetailViewController, didSelectCategory category: String) {
        controller.dismiss(animated: true) { [weak self] in
            self?.presentCategoryView(category: category)
        }
    }
}
