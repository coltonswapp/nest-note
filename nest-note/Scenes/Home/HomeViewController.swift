//
//  HomeViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//

import UIKit
import SwiftUI
import Combine

import FirebaseFunctions
import FirebaseAuth

class HomeViewController: NNViewController, UICollectionViewDelegate {
    
    private var cancellables = Set<AnyCancellable>()
    
    func testFirebaseFunction() async {
        if let user = Auth.auth().currentUser {
            print("User is logged in with ID: \(user.uid)")
            
            // Get a fresh token
            do {
                let idToken = try await user.getIDToken(forcingRefresh: true)
                print("Successfully retrieved fresh token")
            } catch {
                print("Error refreshing token: \(error)")
            }
        } else {
            print("No user is logged in!")
            return
        }
        
        // Then call the function
        let functions = Functions.functions()
        do {
            let result = try await functions.httpsCallable("helloNestNote").call(["testKey": "testValue"])
            if let data = result.data as? [String: Any] {
                print("Function response: \(data)")
            }
        } catch {
            print("Error calling Firebase function: \(error.localizedDescription)")
            print("Detailed error: \(error)")
        }
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        applyInitialSnapshots()
        collectionView.delegate = self
        
        SessionManager.shared.setHomeViewController(self)
        
        // Add notification observer for session bar visibility changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionBarVisibilityChanged),
            name: NSNotification.Name("SessionBarVisibilityChanged"),
            object: nil
        )
        
        NestService.shared.$currentNest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadDataForCurrentUser()
            }
            .store(in: &cancellables)
        
        Task {
            await testFirebaseFunction()
        }
    }
    
    override func setup() {
        navigationItem.title = "NestNote"
        navigationItem.weeTitle = "Welcome to"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        // Set the navigation bar tint color to NNColors.primary
        navigationController?.navigationBar.tintColor = NNColors.primary
    }
    
    override func setupNavigationBarButtons() {
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(settingsButtonTapped))
        let buttons = [settingsButton]
        buttons.forEach { $0.tintColor = .label }
        navigationItem.rightBarButtonItems = buttons
    }
    
    override func addSubviews() {
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
        ])
    }
    
    enum Section: Int, Hashable, CaseIterable {
        case currentSession
        case nest
        case quickAccess
        case upcomingEvents
        
        init?(rawValue: Int) {
            switch rawValue {
            case 0: self = .currentSession
            case 1: self = .nest
            case 2: self = .quickAccess
            case 3: self = .upcomingEvents
            default: return nil
            }
        }
    }
    
    enum Item: Hashable {
        case currentSession(title: String, duration: String)
        case nest(name: String, address: String)
        case quickAccess(String)
        case upcomingEvents
        case sessionEvent(SessionEvent)
        case moreEvents(Int)
    }
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    private var upcomingEvents: [SessionEvent] = [] {
        didSet {
            // Update the events cell when events change
            if let eventsItem = dataSource.snapshot().itemIdentifiers(inSection: .upcomingEvents).first {
                var snapshot = dataSource.snapshot()
                snapshot.reloadItems([eventsItem])
                dataSource.apply(snapshot, animatingDifferences: true)
            }
        }
    }
    
    private func configureCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            switch self.dataSource.snapshot().sectionIdentifiers[sectionIndex] {
            case .currentSession:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(60))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(60))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 2, trailing: 18)
                
                // Add footer
                let footerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(20))
                let footer = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: footerSize,
                    elementKind: UICollectionView.elementKindSectionFooter,
                    alignment: .bottom
                )
                section.boundarySupplementaryItems = [footer]
                
                return section
                
            case .nest:
                // Full width item with fixed height of 220
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 2, trailing: 18)
                
                return section
                
            case .quickAccess:
                // Two column grid with fixed height of 180
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(160))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 13, bottom: 12, trailing: 13)
                
                return section
                
            case .upcomingEvents:
                var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                configuration.showsSeparators = true
                configuration.separatorConfiguration.color = .separator
                
                // Customize insets if needed
                configuration.leadingSwipeActionsConfigurationProvider = nil
                configuration.trailingSwipeActionsConfigurationProvider = nil
                
                let section = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: layoutEnvironment)
                
                // Add header for "Upcoming Events" title
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.9), heightDimension: .estimated(50))
                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
                section.boundarySupplementaryItems = [header]
                
                // Add section insets to match iOS standard insetGrouped style
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: 0,
                    leading: 16,
                    bottom: 0,
                    trailing: 16
                )
                
                return section
            }
        }
        
        return layout
    }
    
    private func configureDataSource() {
        // Cell registrations
        let nestCellRegistration = UICollectionView.CellRegistration<NestCell, Item> { cell, indexPath, item in
            if case let .nest(name, address) = item {
                let image = UIImage(systemName: "house.lodge.fill")
                cell.configure(with: name, subtitle: address, image: image)
                cell.imageView.tintColor = .label
            }
            
            cell.backgroundColor = .secondarySystemGroupedBackground
            cell.layer.cornerRadius = 12
            cell.layer.masksToBounds = true
        }
        
        let quickAccessCellRegistration = UICollectionView.CellRegistration<QuickAccessCell, Item> { cell, indexPath, item in
            if case let .quickAccess(title) = item {
                let image: UIImage?
                if indexPath.row == 0 {
                    image = UIImage(systemName: "house")
                } else {
                    image = UIImage(systemName: "light.beacon.max")
                }
                cell.configure(with: title, image: image)
                cell.imageView.tintColor = .label
            }
            
            cell.backgroundColor = .secondarySystemGroupedBackground
            cell.layer.cornerRadius = 12
            cell.layer.masksToBounds = true
        }
        
        let eventsCellRegistration = UICollectionView.CellRegistration<EventsCell, Item> { cell, indexPath, item in
            if case .upcomingEvents = item {
                cell.configure(eventCount: self.upcomingEvents.count)
            }
        }
        
        let sessionEventRegistration = UICollectionView.CellRegistration<SessionEventCell, Item> { cell, indexPath, item in
            if case let .sessionEvent(event) = item {
                cell.includeDate = true
                cell.configure(with: event)
            }
        }
        
        let moreEventsRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, indexPath, item in
            if case let .moreEvents(count) = item {
                var content = cell.defaultContentConfiguration()
                let text = "+\(count) more"
                
                let attributedString = NSAttributedString(
                    string: text,
                    attributes: [
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .foregroundColor: UIColor.secondaryLabel
                    ]
                )
                
                content.attributedText = attributedString
                content.textProperties.alignment = .center
                cell.contentConfiguration = content
            }
        }
        
        let currentSessionCellRegistration = UICollectionView.CellRegistration<CurrentSessionCell, Item> { cell, indexPath, item in
            if case let .currentSession(title, duration) = item {
                cell.configure(title: title, duration: duration)
                
                // Configure the cell's background
                var backgroundConfig = UIBackgroundConfiguration.listCell()
                backgroundConfig.backgroundColor = NNColors.primaryAlt
                backgroundConfig.cornerRadius = 12
                cell.backgroundConfiguration = backgroundConfig
            }
        }
        
        // DataSource
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch self.dataSource.snapshot().sectionIdentifiers[indexPath.section] {
            case .currentSession:
                return collectionView.dequeueConfiguredReusableCell(using: currentSessionCellRegistration, for: indexPath, item: item)
            case .nest:
                return collectionView.dequeueConfiguredReusableCell(using: nestCellRegistration, for: indexPath, item: item)
            case .quickAccess:
                return collectionView.dequeueConfiguredReusableCell(using: quickAccessCellRegistration, for: indexPath, item: item)
            case .upcomingEvents:
                switch item {
                case .upcomingEvents:
                    return collectionView.dequeueConfiguredReusableCell(using: eventsCellRegistration, for: indexPath, item: item)
                case .sessionEvent:
                    return collectionView.dequeueConfiguredReusableCell(using: sessionEventRegistration, for: indexPath, item: item)
                case .moreEvents:
                    return collectionView.dequeueConfiguredReusableCell(using: moreEventsRegistration, for: indexPath, item: item)
                default:
                    fatalError("Unexpected item type in upcomingEvents section")
                }
            }
        }
        
        // Update the header registration
        let headerRegistration = UICollectionView.SupplementaryRegistration<UpcomingEventsHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { (supplementaryView, string, indexPath) in
            supplementaryView.fullScheduleButton.addTarget(self, action: #selector(self.fullScheduleButtonTapped), for: .touchUpInside)
        }
        
        // In configureDataSource(), add the footer registration
        let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { supplementaryView, elementKind, indexPath in
            var configuration = supplementaryView.defaultContentConfiguration()
            
            // Configure footer based on section
            if case .currentSession = self.dataSource.snapshot().sectionIdentifiers[indexPath.section] {
                configuration.text = "Tap for session details"
                configuration.textProperties.font = .preferredFont(forTextStyle: .footnote)
                configuration.textProperties.color = .tertiaryLabel
                configuration.textProperties.alignment = .center
            }
            
            supplementaryView.contentConfiguration = configuration
        }
        
        // Update the supplementaryViewProvider
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            if kind == UICollectionView.elementKindSectionHeader {
                return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            } else {
                return collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
            }
        }
    }
    
    func reloadDataForCurrentUser() {
        // Reload the data for the current user
        Task {
            await updateNestCell()
            loadUpcomingEvents()
        }
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        
        snapshot.appendSections([.currentSession, .nest, .quickAccess, .upcomingEvents])
        
        // Add current session
        snapshot.appendItems([.currentSession(title: "Finch Family Session", duration: "Dec. 4-6")], toSection: .currentSession)
        
        // Nest section will be populated by updateNestCell()
        snapshot.appendItems([.quickAccess("Household"), .quickAccess("Emergency")], toSection: .quickAccess)
        snapshot.appendItems([.upcomingEvents], toSection: .upcomingEvents) // Just add the header cell
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    // Add property for nest service
    private let nestService = NestService.shared
    
    // Add method to update nest cell
    private func updateNestCell() async {
        var snapshot = dataSource.snapshot()
        
        // Remove existing nest items
        let nestItems = snapshot.itemIdentifiers(inSection: .nest)
        snapshot.deleteItems(nestItems)
        
        // Add new nest item
        if let currentNest = nestService.currentNest {
            snapshot.appendItems([.nest(name: currentNest.name, address: currentNest.address)], toSection: .nest)
        } else {
            // Fallback if no nest is set
            snapshot.appendItems([.nest(name: "No Nest Selected", address: "Please set up your nest")], toSection: .nest)
        }
        
        await dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    // MARK: - Navigation
    
    private func showMyNest() {
        guard let _ = nestService.currentNest else { return }
        navigationController?.pushViewController(NestViewController(), animated: true)
    }
    
    // MARK: - Bar Button Actions
    @objc func settingsButtonTapped() {
        present(UINavigationController(rootViewController: SettingsViewController()), animated: true)
    }
    
    @objc func fullScheduleButtonTapped() {
        print("Full Schedule button tapped")
        present(UINavigationController(rootViewController: CalendarViewController()), animated: true)
//        present(CalendarViewController(), animated: true)
        // Add your logic here to show the full schedule
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        switch item {
        case .nest(let name, _):
            showMyNest()
            
        case .quickAccess(let type):
            guard let _ = nestService.currentNest else { return }
            let categoryVC = NestCategoryViewController(category: type)
            navigationController?.pushViewController(categoryVC, animated: true)
            
        case .upcomingEvents:
            fullScheduleButtonTapped()
        default:
            break
        }
        
        // Optionally, deselect the item
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionViewInsets()
    }
    
    private func updateCollectionViewInsets() {
        let bottomInset = SessionManager.shared.getRequiredBottomInset()
        collectionView.contentInset.bottom = bottomInset
        collectionView.scrollIndicatorInsets.bottom = bottomInset
    }
    
    @objc private func sessionBarVisibilityChanged() {
        UIView.animate(withDuration: 0.3) {
            self.updateCollectionViewInsets()
        }
    }
    
    private func loadUpcomingEvents() {
        // Generate random events
        upcomingEvents = SessionEventGenerator.generateRandomEvents(
            in: DateInterval(start: Date(), 
                            end: Date().addingTimeInterval(2700)), 
            count: 6
        )
        
        // Update the snapshot to show events
        var snapshot = dataSource.snapshot()
        let upcomingEventsItems = snapshot.itemIdentifiers(inSection: .upcomingEvents)
        snapshot.deleteItems(upcomingEventsItems)
        
        // Add header cell
        snapshot.appendItems([.upcomingEvents], toSection: .upcomingEvents)
        
        // Add visible events (up to 3)
        let visibleEvents = upcomingEvents.prefix(3)
        snapshot.appendItems(visibleEvents.map { .sessionEvent($0) }, toSection: .upcomingEvents)
        
        // Add "more" cell if needed
        if upcomingEvents.count > 3 {
            snapshot.appendItems([.moreEvents(upcomingEvents.count - 3)], toSection: .upcomingEvents)
        }
        
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}
