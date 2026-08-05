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
    func commonItemsViewController(_ controller: CommonItemsViewController, didSelectNote entry: CommonNote)
    func commonItemsViewController(_ controller: CommonItemsViewController, didSelectPlace place: CommonPlace)
    func commonItemsViewController(_ controller: CommonItemsViewController, didSelectRoutine routine: CommonRoutine)
    func commonItemsViewController(_ controller: CommonItemsViewController, didSelectContact contact: CommonContact)
}

class CommonItemsViewController: NNViewController, NNCategoryFilterViewDelegate {
    
    // MARK: - Properties
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, AnyHashable>!
    private var filterView: NNCategoryFilterView!
    private var instructionLabel: BlurBackgroundLabel!
    weak var delegate: CommonItemsViewControllerDelegate?

    private var waterfallLayout: WaterfallCollectionLayout?
    private var waterfallHeightCache: [IndexPath: CGFloat] = [:]
    private lazy var waterfallSizingCell = WaterfallGridCell(frame: .zero)
    private var sectionOrder: [Section] = []

    // Context for creation flows
    private let category: String
    private let nestItemRepository: NestItemRepository
    
    enum Section: Int, CaseIterable, NNCategoryFilterOption {
        case codes, other, contacts, places, routines
        
        var displayTitle: String {
            switch self {
            case .codes, .other: return "Notes"
            case .contacts: return "Contacts"
            case .places: return "Places"
            case .routines: return "Routines"
            }
        }
    }
    
    // Data arrays
    private let commonNotes: [CommonNote] = [
        // House & Safety Entries
        CommonNote(title: "Garage Code", content: "8005", category: "Common"),
        CommonNote(title: "Front Door", content: "2208", category: "Common"),
        CommonNote(title: "Trash Day", content: "Wednesday", category: "Common"),
        CommonNote(title: "WiFi Password", content: "SuperStrongPassword", category: "Common"),
        CommonNote(title: "Alarm Code", content: "4321", category: "Common"),
        CommonNote(title: "Thermostat", content: "68°F", category: "Common"),
        CommonNote(title: "Trash Pickup", content: "Wednesday Morning", category: "Common"),
        CommonNote(title: "Shed", content: "1357", category: "Common"),
        CommonNote(title: "Power Outage", content: "Flashlights in kitchen drawer", category: "Common"),
        CommonNote(title: "Recycling", content: "Blue bin, Fridays", category: "Common"),
        CommonNote(title: "Yard Service", content: "Every Monday, 11am-2pm", category: "Common"),
        CommonNote(title: "Water Shutoff", content: "Basement, north wall", category: "Common"),
        CommonNote(title: "Gas Shutoff", content: "Outside, east side of house", category: "Common"),
        
        // Emergency & Medical Entries
        CommonNote(title: "Emergency Contact", content: "John Doe: 555-123-4567", category: "Common"),
        CommonNote(title: "Nearest Hospital", content: "City General - 10 Main St", category: "Common"),
        CommonNote(title: "Fire Evacuation", content: "Meet at mailbox", category: "Common"),
        CommonNote(title: "Poison Control", content: "1-800-222-1222", category: "Common"),
        CommonNote(title: "Home Doctor", content: "Dr. Smith: 555-987-6543", category: "Common"),
        CommonNote(title: "911", content: "Address", category: "Common"),
        CommonNote(title: "EpiPen", content: "Top shelf", category: "Common"),
        CommonNote(title: "Safe", content: "3456", category: "Common"),
        CommonNote(title: "Allergies", content: "Peanuts, penicillin", category: "Common"),
        CommonNote(title: "Insurance", content: "BlueCross #12345678", category: "Common"),
        CommonNote(title: "Urgent Care", content: "WalkIn Clinic - 55 Grove St", category: "Common"),
        CommonNote(title: "Power Company", content: "CityPower: 555-789-0123", category: "Common"),
        CommonNote(title: "Plumber", content: "Joe's Plumbing: 555-456-7890", category: "Common"),
        CommonNote(title: "Neighbor Help", content: "Mrs. Wilson: 555-234-5678", category: "Common"),
        
        // Pet Care Entries
        CommonNote(title: "Dog Food", content: "1 cup", category: "Common"),
        CommonNote(title: "Cat", content: "Indoor", category: "Common"),
        CommonNote(title: "Fish", content: "Feed 2x", category: "Common"),
        CommonNote(title: "Toys", content: "In bin", category: "Common"),
        CommonNote(title: "Treat Rules", content: "Max 2 per day", category: "Common"),
        CommonNote(title: "Pet Names", content: "Dog: Max, Cat: Luna, Fish: Bubbles", category: "Common"),
        CommonNote(title: "No-Go Areas", content: "Keep pets out of formal dining room", category: "Common"),
        CommonNote(title: "Pet Sitter", content: "Emily: 555-222-3333", category: "Common"),
        CommonNote(title: "Leash Location", content: "Hanging by front door", category: "Common"),
        CommonNote(title: "Pet Emergency", content: "Animal Hospital: 555-789-4561", category: "Common")
    ]
    
    private let commonContacts: [CommonContact] = [
        CommonContact(title: "Emergency Contact", phoneNumber: "555-123-4567"),
        CommonContact(title: "Neighbor", phoneNumber: "555-234-5678"),
        CommonContact(title: "Grandma", phoneNumber: "555-345-6789"),
        CommonContact(title: "Pediatrician", phoneNumber: "555-987-6543"),
        CommonContact(title: "Dentist", phoneNumber: "555-876-5432"),
        CommonContact(title: "Veterinarian", phoneNumber: "555-789-4561"),
        CommonContact(title: "Pet Sitter", phoneNumber: "555-222-3333"),
        CommonContact(title: "School Office", phoneNumber: "555-111-2222"),
        CommonContact(title: "Poison Control", phoneNumber: "1-800-222-1222"),
        CommonContact(title: "Plumber", phoneNumber: "555-456-7890"),
        CommonContact(title: "Electrician", phoneNumber: "555-654-3210"),
        CommonContact(title: "Power Company", phoneNumber: "555-789-0123"),
        CommonContact(title: "Locksmith", phoneNumber: "555-321-0987"),
        CommonContact(title: "Landlord", phoneNumber: "555-555-0100"),
        CommonContact(title: "HVAC", phoneNumber: "555-444-7788")
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

    private static let sampleRoutineActions = [
        "Check all doors",
        "Turn off lights",
        "Set thermostat",
        "Lock windows",
        "Arm security system"
    ]
    
    private var enabledSections: Set<Section> = [.codes, .other] {
        didSet {
            applySnapshot()
        }
    }
    
    // MARK: - Init / Lifecycle

    init(category: String, nestItemRepository: NestItemRepository) {
        self.category = category
        self.nestItemRepository = nestItemRepository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        configureDataSource()
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
        view.backgroundColor = .systemGroupedBackground
    }

    private func setupInstructionLabel() {
        instructionLabel = BlurBackgroundLabel()
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

        let availableSections: [Section] = [.codes, .contacts, .places, .routines]
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
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.contentInset.top = 8
        collectionView.verticalScrollIndicatorInsets.top = 8
        collectionView.contentInset.bottom = 50
        collectionView.verticalScrollIndicatorInsets.bottom = 50
        
        view.addSubview(collectionView)
        
        collectionView.register(
            WaterfallGridCell.self,
            forCellWithReuseIdentifier: WaterfallGridCell.reuseIdentifier
        )
        collectionView.register(
            UICollectionReusableView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "SectionHeader"
        )
    }
    
    // MARK: - Layout
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = WaterfallCollectionLayout()
        layout.delegate = self
        waterfallLayout = layout
        return layout
    }
    
    // MARK: - Data Source
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, AnyHashable>(collectionView: collectionView) {
            [weak self] (collectionView, indexPath, item) -> UICollectionViewCell? in
            guard let self else { return nil }
            guard indexPath.section < self.sectionOrder.count else { return nil }

            let section = self.sectionOrder[indexPath.section]
            return self.dequeueWaterfallCell(in: collectionView, for: item, section: section, at: indexPath)
        }
        
        dataSource.supplementaryViewProvider = { [weak self] (collectionView, kind, indexPath) -> UICollectionReusableView? in
            guard let self,
                  kind == UICollectionView.elementKindSectionHeader,
                  indexPath.section < self.sectionOrder.count else { return nil }

            let section = self.sectionOrder[indexPath.section]
            guard self.shouldShowWaterfallHeader(for: section) else { return nil }
            
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: "SectionHeader",
                for: indexPath
            )
            
            header.subviews.forEach { $0.removeFromSuperview() }
            
            let label = UILabel()
            label.text = self.waterfallHeaderTitle(for: section)
            label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            label.textColor = UIColor.secondaryLabel
            label.translatesAutoresizingMaskIntoConstraints = false
            
            header.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(
                    equalTo: header.leadingAnchor,
                    constant: NestCategoryViewController.waterfallSectionHeaderLeadingInset
                ),
                label.bottomAnchor.constraint(
                    equalTo: header.bottomAnchor,
                    constant: -NestCategoryViewController.sectionHeaderLabelBottomInset
                )
            ])
            
            return header
        }
    }
    
    private func applySnapshot(animated: Bool = false) {
        guard dataSource != nil else { return }

        waterfallHeightCache.removeAll()
        var snapshot = NSDiffableDataSourceSnapshot<Section, AnyHashable>()
        var order: [Section] = []
        
        let enabledSectionsArray = Array(enabledSections).sorted { $0.rawValue < $1.rawValue }
        var didAddEntries = false
        
        for section in enabledSectionsArray {
            switch section {
            case .codes, .other:
                guard !didAddEntries else { continue }
                let sortedEntries = commonNotes.sorted {
                    $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                guard !sortedEntries.isEmpty else { continue }
                snapshot.appendSections([.codes])
                snapshot.appendItems(sortedEntries, toSection: .codes)
                order.append(.codes)
                didAddEntries = true
            case .contacts:
                let sortedContacts = commonContacts.sorted {
                    $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                guard !sortedContacts.isEmpty else { continue }
                snapshot.appendSections([.contacts])
                snapshot.appendItems(sortedContacts, toSection: .contacts)
                order.append(.contacts)
            case .places:
                let sortedPlaces = commonPlaces.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                guard !sortedPlaces.isEmpty else { continue }
                snapshot.appendSections([.places])
                snapshot.appendItems(sortedPlaces, toSection: .places)
                order.append(.places)
            case .routines:
                let sortedRoutines = commonRoutines.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                guard !sortedRoutines.isEmpty else { continue }
                snapshot.appendSections([.routines])
                snapshot.appendItems(sortedRoutines, toSection: .routines)
                order.append(.routines)
            }
        }

        sectionOrder = order
        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            self?.waterfallLayout?.invalidateLayout()
        }
    }
    
    // MARK: - NNCategoryFilterViewDelegate
    func categoryFilterView(_ filterView: NNCategoryFilterView, didUpdateSelection selection: NNCategoryFilterView.Selection) {
        switch selection {
        case .all:
            enabledSections = [.codes, .other]
        case .specific(let ids):
            if ids.contains(Section.codes) {
                enabledSections = [.codes, .other]
            } else if ids.contains(Section.contacts) {
                enabledSections = [.contacts]
            } else if ids.contains(Section.places) {
                enabledSections = [.places]
            } else if ids.contains(Section.routines) {
                enabledSections = [.routines]
            }
        }

        applySnapshot(animated: true)
        DispatchQueue.main.async {
            filterView.updateDisplayedState()
        }
    }
}

// MARK: - Waterfall Grid

private extension CommonItemsViewController {
    func dequeueWaterfallCell(
        in collectionView: UICollectionView,
        for item: AnyHashable,
        section: Section,
        at indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: WaterfallGridCell.reuseIdentifier,
            for: indexPath
        ) as! WaterfallGridCell

        switch section {
        case .codes, .other:
            if let entry = item as? CommonNote {
                cell.configure(
                    title: entry.title,
                    content: entry.content,
                    contentLineLimit: WaterfallGridCell.entryContentLineLimit
                )
            }
        case .contacts:
            if let contact = item as? CommonContact {
                cell.configure(
                    title: contact.title,
                    content: contact.phoneNumber
                )
            }
        case .places:
            if let place = item as? CommonPlace {
                let imageNumber = (abs(place.name.hashValue) % 5) + 1
                let placeholderImage = UIImage(named: "map-placeholder\(imageNumber)")
                    ?? UIImage(systemName: "mappin.circle")
                cell.configure(
                    title: place.name,
                    content: "Sample Address",
                    thumbnail: placeholderImage,
                    layoutStyle: .place,
                    showsPlaceThumbnail: true
                )
            }
        case .routines:
            if let routine = item as? CommonRoutine {
                cell.configure(
                    title: routine.name,
                    content: WaterfallGridCell.routinePreviewText(for: Self.sampleRoutineActions)
                )
            }
        }

        return cell
    }

    func configureWaterfallSizingCell(for item: AnyHashable, section: Section, columnWidth: CGFloat) {
        waterfallSizingCell.prepareForReuse()

        switch section {
        case .codes, .other:
            if let entry = item as? CommonNote {
                waterfallSizingCell.configure(
                    title: entry.title,
                    content: entry.content,
                    contentLineLimit: WaterfallGridCell.entryContentLineLimit
                )
            }
        case .contacts:
            if let contact = item as? CommonContact {
                waterfallSizingCell.configure(
                    title: contact.title,
                    content: contact.phoneNumber
                )
            }
        case .places:
            if let place = item as? CommonPlace {
                waterfallSizingCell.configure(
                    title: place.name,
                    content: "Sample Address",
                    thumbnail: UIImage(),
                    layoutStyle: .place,
                    showsPlaceThumbnail: true
                )
            }
        case .routines:
            if let routine = item as? CommonRoutine {
                waterfallSizingCell.configure(
                    title: routine.name,
                    content: WaterfallGridCell.routinePreviewText(for: Self.sampleRoutineActions)
                )
            }
        }

        waterfallSizingCell.updateThumbnailHeight(forColumnWidth: columnWidth)
    }

    func measuredWaterfallHeight(for indexPath: IndexPath, columnWidth: CGFloat) -> CGFloat {
        if let cached = waterfallHeightCache[indexPath] {
            return cached
        }

        guard let item = dataSource.itemIdentifier(for: indexPath),
              indexPath.section < sectionOrder.count else {
            return 120
        }

        let section = sectionOrder[indexPath.section]
        configureWaterfallSizingCell(for: item, section: section, columnWidth: columnWidth)

        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.size = CGSize(width: columnWidth, height: 0)
        let fitted = waterfallSizingCell.preferredLayoutAttributesFitting(attributes)
        waterfallHeightCache[indexPath] = fitted.size.height
        return fitted.size.height
    }

    func shouldShowWaterfallHeader(for section: Section) -> Bool {
        switch section {
        case .codes:
            return true
        case .other:
            return !sectionOrder.contains(.codes)
        default:
            return true
        }
    }

    func waterfallHeaderTitle(for section: Section) -> String {
        switch section {
        case .codes, .other: return "NOTES"
        case .contacts: return "CONTACTS"
        case .places: return "PLACES"
        case .routines: return "ROUTINES"
        }
    }
}

extension CommonItemsViewController: WaterfallCollectionLayoutDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        layout: WaterfallCollectionLayout,
        heightForItemAt indexPath: IndexPath,
        columnWidth: CGFloat
    ) -> CGFloat {
        measuredWaterfallHeight(for: indexPath, columnWidth: columnWidth)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout: WaterfallCollectionLayout,
        shouldShowHeaderForSection section: Int
    ) -> Bool {
        guard section < sectionOrder.count else { return false }
        return shouldShowWaterfallHeader(for: sectionOrder[section])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout: WaterfallCollectionLayout,
        heightForHeaderInSection section: Int
    ) -> CGFloat {
        NestCategoryViewController.waterfallSectionHeaderHeight
    }
}

// MARK: - Data Models

struct CommonNote: Hashable {
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

struct CommonContact: Hashable {
    let title: String
    let phoneNumber: String
}

// MARK: - Selection handling
extension CommonItemsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard indexPath.section < sectionOrder.count else { return }
        let section = sectionOrder[indexPath.section]

        switch section {
        case .codes, .other:
            guard let entry = dataSource.itemIdentifier(for: indexPath) as? CommonNote else { return }
            delegate?.commonItemsViewController(self, didSelectNote: entry)
        case .contacts:
            guard let contact = dataSource.itemIdentifier(for: indexPath) as? CommonContact else { return }
            delegate?.commonItemsViewController(self, didSelectContact: contact)
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

protocol CommonNotesViewControllerDelegate: NoteDetailViewControllerDelegate {
    func commonNotesViewController(didSelectNote entry: NoteItem)
    func showUpgradePrompt()
}

protocol CommonPlacesViewControllerDelegate: AnyObject {
    func commonPlacesViewController(didSelectPlace commonPlace: CommonPlace)
}
