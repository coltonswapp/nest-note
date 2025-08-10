//
//  CommonItemsViewController.swift
//  nest-note
//
//  Created by Claude Code on 8/9/25.
//

import UIKit
import FirebaseFirestore
import CoreLocation

protocol CommonItemsViewControllerDelegate: AnyObject {
    func commonItemsViewController(_ controller: CommonItemsViewController, didSelectEntry entry: CommonEntry)
    func commonItemsViewController(_ controller: CommonItemsViewController, didSelectPlace place: CommonPlace)
    func commonItemsViewController(_ controller: CommonItemsViewController, didSelectRoutine routine: CommonRoutine)
}

class CommonItemsViewController: NNViewController, NNCategoryFilterViewDelegate {
    
    // MARK: - Properties
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, AnyHashable>!
    private var filterView: NNCategoryFilterView!
    private var instructionLabel: BlurBackgroundLabel!
    weak var delegate: CommonItemsViewControllerDelegate?

    // Context for creation flows
    private let category: String
    private let entryRepository: EntryRepository
    
    enum Section: Int, CaseIterable, NNCategoryFilterOption {
        case codes, other, places, routines
        
        var displayTitle: String {
            switch self {
            case .codes, .other: return "Entries"
            case .places: return "Places"
            case .routines: return "Routines"
            }
        }
    }
    
    // Data arrays
    private let commonEntries: [CommonEntry] = [
        // House & Safety Entries
        CommonEntry(title: "Garage Code", content: "8005", category: "Common"),
        CommonEntry(title: "Front Door", content: "2208", category: "Common"),
        CommonEntry(title: "Trash Day", content: "Wednesday", category: "Common"),
        CommonEntry(title: "WiFi Password", content: "SuperStrongPassword", category: "Common"),
        CommonEntry(title: "Alarm Code", content: "4321", category: "Common"),
        CommonEntry(title: "Thermostat", content: "68°F", category: "Common"),
        CommonEntry(title: "Trash Pickup", content: "Wednesday Morning", category: "Common"),
        CommonEntry(title: "Shed", content: "1357", category: "Common"),
        CommonEntry(title: "Power Outage", content: "Flashlights in kitchen drawer", category: "Common"),
        CommonEntry(title: "Recycling", content: "Blue bin, Fridays", category: "Common"),
        CommonEntry(title: "Yard Service", content: "Every Monday, 11am-2pm", category: "Common"),
        CommonEntry(title: "Water Shutoff", content: "Basement, north wall", category: "Common"),
        CommonEntry(title: "Gas Shutoff", content: "Outside, east side of house", category: "Common"),
        
        // Emergency & Medical Entries
        CommonEntry(title: "Emergency Contact", content: "John Doe: 555-123-4567", category: "Common"),
        CommonEntry(title: "Nearest Hospital", content: "City General - 10 Main St", category: "Common"),
        CommonEntry(title: "Fire Evacuation", content: "Meet at mailbox", category: "Common"),
        CommonEntry(title: "Poison Control", content: "1-800-222-1222", category: "Common"),
        CommonEntry(title: "Home Doctor", content: "Dr. Smith: 555-987-6543", category: "Common"),
        CommonEntry(title: "911", content: "Address", category: "Common"),
        CommonEntry(title: "EpiPen", content: "Top shelf", category: "Common"),
        CommonEntry(title: "Safe", content: "3456", category: "Common"),
        CommonEntry(title: "Allergies", content: "Peanuts, penicillin", category: "Common"),
        CommonEntry(title: "Insurance", content: "BlueCross #12345678", category: "Common"),
        CommonEntry(title: "Urgent Care", content: "WalkIn Clinic - 55 Grove St", category: "Common"),
        CommonEntry(title: "Power Company", content: "CityPower: 555-789-0123", category: "Common"),
        CommonEntry(title: "Plumber", content: "Joe's Plumbing: 555-456-7890", category: "Common"),
        CommonEntry(title: "Neighbor Help", content: "Mrs. Wilson: 555-234-5678", category: "Common"),
        
        // Pet Care Entries
        CommonEntry(title: "Dog Food", content: "1 cup", category: "Common"),
        CommonEntry(title: "Cat", content: "Indoor", category: "Common"),
        CommonEntry(title: "Fish", content: "Feed 2x", category: "Common"),
        CommonEntry(title: "Toys", content: "In bin", category: "Common"),
        CommonEntry(title: "Treat Rules", content: "Max 2 per day", category: "Common"),
        CommonEntry(title: "Pet Names", content: "Dog: Max, Cat: Luna, Fish: Bubbles", category: "Common"),
        CommonEntry(title: "No-Go Areas", content: "Keep pets out of formal dining room", category: "Common"),
        CommonEntry(title: "Pet Sitter", content: "Emily: 555-222-3333", category: "Common"),
        CommonEntry(title: "Leash Location", content: "Hanging by front door", category: "Common"),
        CommonEntry(title: "Pet Emergency", content: "Animal Hospital: 555-789-4561", category: "Common")
    ]
    
    private let commonPlaces: [CommonPlace] = [
        CommonPlace(name: "Grandma's House", icon: "house.fill"),
        CommonPlace(name: "School", icon: "graduationcap.fill"),
        CommonPlace(name: "Bus Stop", icon: "bus.fill"),
        CommonPlace(name: "Dance Studio", icon: "figure.dance"),
        CommonPlace(name: "Soccer Practice", icon: "soccerball"),
        CommonPlace(name: "Favorite Park", icon: "tree.fill"),
        CommonPlace(name: "Rec Center", icon: "building.2.fill"),
        CommonPlace(name: "Swimming Pool", icon: "figure.pool.swim")
    ]
    
    private let commonRoutines: [CommonRoutine] = [
        CommonRoutine(name: "Morning Wake Up", icon: "sun.rise.fill"),
        CommonRoutine(name: "Bedtime Routine", icon: "moon.stars.fill"),
        CommonRoutine(name: "After School", icon: "backpack.fill"),
        CommonRoutine(name: "Pet Care", icon: "pawprint.fill"),
        CommonRoutine(name: "Meal Prep", icon: "fork.knife"),
        CommonRoutine(name: "Bath Time", icon: "bathtub.fill"),
        CommonRoutine(name: "Homework Time", icon: "pencil.and.scribble"),
        CommonRoutine(name: "Screen Time Setup", icon: "tv.fill"),
        CommonRoutine(name: "Leaving House", icon: "door.left.hand.open"),
        CommonRoutine(name: "Coming Home", icon: "house.fill"),
        CommonRoutine(name: "Emergency Protocol", icon: "exclamationmark.triangle.fill"),
        CommonRoutine(name: "Quiet Time", icon: "book.closed.fill")
    ]
    
    private var enabledSections: Set<Section> = [.codes, .other] {
        didSet {
            applySnapshot()
        }
    }
    
    // MARK: - Init / Lifecycle

    init(category: String, entryRepository: EntryRepository) {
        self.category = category
        self.entryRepository = entryRepository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        configureDataSource() // Ensure dataSource exists before filterView may emit delegate events
        setupFilterView()
        applySnapshot()
        setupInstructionLabel()
        collectionView.delegate = self
    }
    
    // MARK: - Setup
    
    override func setup() {
        title = "Common Items"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    override func setupNavigationBarButtons() {
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
    }

    private func setupInstructionLabel() {
        instructionLabel = BlurBackgroundLabel(backgroundColor: NNColors.primaryOpaque, foregroundColor: NNColors.primary)
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.text = "These are example items. Tap an item to make it your own."
        instructionLabel.font = .bodyL

        view.addSubview(instructionLabel)

        NSLayoutConstraint.activate([
            instructionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.7)
        ])
    }
    
    private func setupFilterView() {
        filterView = NNCategoryFilterView()
        filterView.delegate = self
        filterView.frame.size.height = 55

        // Configure available sections (Entries, Places, Routines)
        let availableSections: [Section] = [.codes, .places, .routines]
        filterView.configure(
            with: availableSections,
            allowsMultipleSelection: false,
            showsAllOption: false,
            defaultSelection: .codes
        )

        addNavigationBarPalette(filterView)
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.contentInset.bottom = 50
        collectionView.verticalScrollIndicatorInsets.bottom = 50
        
        view.addSubview(collectionView)
        
        // Register cells (reusing existing cells from NestCategoryViewController)
        collectionView.register(HalfWidthCell.self, forCellWithReuseIdentifier: HalfWidthCell.reuseIdentifier)
        collectionView.register(FullWidthCell.self, forCellWithReuseIdentifier: FullWidthCell.reuseIdentifier)
        collectionView.register(PlaceCell.self, forCellWithReuseIdentifier: PlaceCell.reuseIdentifier)
        collectionView.register(RoutineCell.self, forCellWithReuseIdentifier: RoutineCell.reuseIdentifier)
        
        // Register section headers
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SectionHeader")
    }
    
    // MARK: - Layout
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            guard let self = self else { return nil }
            
            let enabledSectionsArray = Array(self.enabledSections).sorted { $0.rawValue < $1.rawValue }
            guard sectionIndex < enabledSectionsArray.count else { return nil }
            
            let section = enabledSectionsArray[sectionIndex]
            
            switch section {
            case .codes:
                return self.createHalfWidthSectionWithHeader(needsBottomPadding: !self.enabledSections.contains(.other))
            case .other:
                let hasCodesSection = self.enabledSections.contains(.codes)
                return hasCodesSection ? self.createFullWidthSection() : self.createFullWidthSectionWithHeader()
            case .places:
                return self.createPlacesSection()
            case .routines:
                return self.createRoutinesSection()
            }
        }
        return layout
    }
    
    private static let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(32))
    
    private func createHalfWidthSectionWithHeader(needsBottomPadding: Bool = false) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(90))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(90))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
        let section = NSCollectionLayoutSection(group: group)
        
        let bottomPadding: CGFloat = needsBottomPadding ? 30 : 4
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: bottomPadding, trailing: 4)
        
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: CommonItemsViewController.headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    private func createFullWidthSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 30, trailing: 12)
        section.interGroupSpacing = 8
        return section
    }
    
    private func createFullWidthSectionWithHeader() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 30, trailing: 12)
        section.interGroupSpacing = 8
        
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: CommonItemsViewController.headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    private func createPlacesSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .fractionalWidth(0.6)
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(0.6)
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item, item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 40, trailing: 8)
        
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: CommonItemsViewController.headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    private func createRoutinesSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .absolute(140)
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(140)
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item, item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 40, trailing: 8)
        
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: CommonItemsViewController.headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    // MARK: - Data Source
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, AnyHashable>(collectionView: collectionView) { [weak self] (collectionView, indexPath, item) -> UICollectionViewCell? in
            guard let self = self else { return nil }
            
            let enabledSectionsArray = Array(self.enabledSections).sorted { $0.rawValue < $1.rawValue }
            let section = enabledSectionsArray[indexPath.section]
            
            switch section {
            case .codes:
                if let entry = item as? CommonEntry {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HalfWidthCell.reuseIdentifier, for: indexPath) as! HalfWidthCell
                    // Style as placeholders/suggestions
                    cell.valueContainerBackgroundColor = NNColors.NNSystemBackground6
                    cell.valueLabelBackgroundColor = .tertiaryLabel
                    cell.configure(
                        key: entry.title,
                        value: entry.content,
                        isNestOwner: true,
                        isEditMode: false,
                        isSelected: false,
                        isModalInPresentation: true
                    )
                    return cell
                }
            case .other:
                if let entry = item as? CommonEntry {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                    // Style as placeholders/suggestions
                    cell.valueContainerBackgroundColor = NNColors.NNSystemBackground6
                    cell.valueLabelBackgroundColor = .tertiaryLabel
                    cell.configure(
                        key: entry.title,
                        value: entry.content,
                        isNestOwner: true,
                        isEditMode: false,
                        isSelected: false,
                        isModalInPresentation: true
                    )
                    return cell
                }
            case .places:
                if let place = item as? CommonPlace {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PlaceCell.reuseIdentifier, for: indexPath) as! PlaceCell
                    
                    // Create PlaceItem from CommonPlace
                    let placeItem = PlaceItem(
                        nestId: "common",
                        category: "Common",
                        title: place.name,
                        alias: place.name,
                        address: "Sample Address",
                        coordinate: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
                        isTemporary: false
                    )
                    
                    cell.configure(
                        with: placeItem,
                        isGridLayout: true,
                        isEditMode: false,
                        isSelected: false,
                        shouldLoadThumbnail: false
                    )
                    
                    // Set our placeholder image immediately
                    let randomImageNumber = Int.random(in: 1...5)
                    let placeholderImage = UIImage(named: "map-placeholder\(randomImageNumber)")
                    cell.thumbnailImageView.image = placeholderImage ?? UIImage(systemName: "mappin.circle")
                    
                    return cell
                }
            case .routines:
                if let routine = item as? CommonRoutine {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RoutineCell.reuseIdentifier, for: indexPath) as! RoutineCell
                    
                    // Create RoutineItem from CommonRoutine
                    let routineItem = RoutineItem(
                        title: routine.name,
                        category: "Common",
                        routineActions: ["Sample action 1", "Sample action 2", "Sample action 3"]
                    )
                    
                    cell.configure(
                        with: routineItem,
                        isEditMode: false,
                        isSelected: false
                    )
                    return cell
                }
            }
            
            return nil
        }
        
        // Configure supplementary view provider for section headers
        dataSource.supplementaryViewProvider = { [weak self] (collectionView, kind, indexPath) -> UICollectionReusableView? in
            guard let self = self,
                  kind == UICollectionView.elementKindSectionHeader else { return nil }
            
            let enabledSectionsArray = Array(self.enabledSections).sorted { $0.rawValue < $1.rawValue }
            let section = enabledSectionsArray[indexPath.section]
            
            let shouldShowHeader: Bool
            switch section {
            case .codes:
                shouldShowHeader = true
            case .other:
                shouldShowHeader = !self.enabledSections.contains(.codes)
            default:
                shouldShowHeader = true
            }
            
            if !shouldShowHeader {
                return nil
            }
            
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: "SectionHeader",
                for: indexPath
            )
            
            let title: String
            switch section {
            case .codes, .other:
                title = "ENTRIES"
            case .places:
                title = "PLACES"
            case .routines:
                title = "ROUTINES"
            }
            
            header.subviews.forEach { $0.removeFromSuperview() }
            
            let label = UILabel()
            label.text = title
            label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            label.textColor = UIColor.secondaryLabel
            label.translatesAutoresizingMaskIntoConstraints = false
            
            header.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
                label.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8)
            ])
            
            return header
        }
    }
    
    private func applySnapshot(animated: Bool = false) {
        guard dataSource != nil else { return }
        var snapshot = NSDiffableDataSourceSnapshot<Section, AnyHashable>()
        
        let enabledSectionsArray = Array(enabledSections).sorted { $0.rawValue < $1.rawValue }
        
        for section in enabledSectionsArray {
            snapshot.appendSections([section])
            
            switch section {
            case .codes:
                let codesEntries = commonEntries.filter { $0.shouldUseHalfWidthCell }
                    .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                snapshot.appendItems(codesEntries, toSection: section)
            case .other:
                let otherEntries = commonEntries.filter { !$0.shouldUseHalfWidthCell }
                    .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                snapshot.appendItems(otherEntries, toSection: section)
            case .places:
                let sortedPlaces = commonPlaces.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                snapshot.appendItems(sortedPlaces, toSection: section)
            case .routines:
                let sortedRoutines = commonRoutines.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                snapshot.appendItems(sortedRoutines, toSection: section)
            }
        }
        
        dataSource.apply(snapshot, animatingDifferences: animated)
    }
    
    // MARK: - NNCategoryFilterViewDelegate
    func categoryFilterView(_ filterView: NNCategoryFilterView, didUpdateSelection selection: NNCategoryFilterView.Selection) {
        switch selection {
        case .all:
            // Not used in single-select; default to entries
            enabledSections = [.codes, .other]
        case .specific(let ids):
            if ids.contains(Section.codes) {
                enabledSections = [.codes, .other]
            } else if ids.contains(Section.places) {
                enabledSections = [.places]
            } else if ids.contains(Section.routines) {
                enabledSections = [.routines]
            }
        }

        self.applySnapshot(animated: true)
        DispatchQueue.main.async {
            filterView.updateDisplayedState()
        }
    }
}

// MARK: - Data Models

struct CommonEntry: Hashable {
    let title: String
    let content: String
    let category: String
    
    var shouldUseHalfWidthCell: Bool {
        return (title.count + content.count) <= 15
    }
}

struct CommonPlace: Hashable {
    let id: String = UUID().uuidString
    let name: String
    let icon: String
}

struct CommonRoutine: Hashable {
    let name: String
    let icon: String
}

// MARK: - Selection handling
extension CommonItemsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let enabledSectionsArray = Array(self.enabledSections).sorted { $0.rawValue < $1.rawValue }
        guard indexPath.section < enabledSectionsArray.count else { return }
        let section = enabledSectionsArray[indexPath.section]

        switch section {
        case .codes, .other:
            guard let entry = dataSource.itemIdentifier(for: indexPath) as? CommonEntry else { return }
            delegate?.commonItemsViewController(self, didSelectEntry: entry)
        case .places:
            guard let place = dataSource.itemIdentifier(for: indexPath) as? CommonPlace else { return }
            delegate?.commonItemsViewController(self, didSelectPlace: place)
        case .routines:
            guard let routine = dataSource.itemIdentifier(for: indexPath) as? CommonRoutine else { return }
            delegate?.commonItemsViewController(self, didSelectRoutine: routine)
        }
    }
}

// Protocols

protocol CommonEntriesViewControllerDelegate: EntryDetailViewControllerDelegate {
    func commonEntriesViewController(didSelectEntry entry: BaseEntry)
    func showUpgradePrompt()
}

protocol CommonPlacesViewControllerDelegate: AnyObject {
    func commonPlacesViewController(didSelectPlace commonPlace: CommonPlace)
}
