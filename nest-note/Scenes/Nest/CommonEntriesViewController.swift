//
//  CommonEntriesViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 1/21/25
//

import UIKit
import RevenueCat
import RevenueCatUI

// Add a delegate protocol at the top of the file before class declaration
protocol CommonEntriesViewControllerDelegate: EntryDetailViewControllerDelegate {
    func commonEntriesViewController(_ controller: CommonEntriesViewController, didSelectEntry entry: BaseEntry)
    func showUpgradePrompt()
}

class CommonEntriesViewController: UIViewController, CollectionViewLoadable, PaywallPresentable, PaywallViewControllerDelegate {
    // MARK: - Properties
    private let entryRepository: EntryRepository
    private let category: String
    private let sessionVisibilityLevel: VisibilityLevel
    
    // MARK: - PaywallPresentable
    var proFeature: ProFeature {
        return .unlimitedEntries
    }
    
    // Add delegate property
    weak var delegate: CommonEntriesViewControllerDelegate?
    
    // Required by CollectionViewLoadable
    var loadingIndicator: UIActivityIndicatorView!
    var refreshControl: UIRefreshControl!
    
    var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, CommonEntry>!
    
    private var instructionLabel: BlurBackgroundLabel!
    
    private var emptyStateView: NNEmptyStateView!
    
    // Sections for the collection view - using same sections as NestCategoryViewController
    enum Section: Int, CaseIterable {
        case codes, other
    }
    
    // Model for common entries
    struct CommonEntry: Hashable {
        let id = UUID().uuidString
        let title: String
        let content: String
        let category: String
        let visibility: VisibilityLevel
        
        // Convert to BaseEntry
        func toBaseEntry() -> BaseEntry {
            return BaseEntry(title: title, content: content, visibilityLevel: visibility, category: category)
        }
        
        // Match the BaseEntry extension logic
        var shouldUseHalfWidthCell: Bool {
            return title.count <= 15 && content.count <= 15
        }
    }
    
    private var entries: [CommonEntry] = []
    
    init(category: String, entryRepository: EntryRepository, sessionVisibilityLevel: VisibilityLevel? = nil) {
        self.category = category
        self.entryRepository = entryRepository
        // If it's a NestService (owner), they get extended access. Otherwise use provided level or default to halfDay
        self.sessionVisibilityLevel = entryRepository is NestService ? .extended : (sessionVisibilityLevel ?? .halfDay)
        super.init(nibName: nil, bundle: nil)
        self.title = category
        
        // Load dummy data for the specific category
        loadDummyData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupCollectionView()
        setupLoadingIndicator()
        configureDataSource()
        
        collectionView.delegate = self
        
        setupEmptyStateView()
        navigationItem.weeTitle = "Example Entries"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        // Set the navigation bar tint color to NNColors.primary
        navigationController?.navigationBar.tintColor = NNColors.primary
        
        setupInstructionLabel()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applySnapshot()
    }
    
    // MARK: - CollectionViewLoadable Implementation
    func handleLoadedData() {
        // Not needed with static data
    }
    
    func loadData(showLoadingIndicator: Bool) async {
        // Not needed with static data
    }
    
    private func setupInstructionLabel() {
        instructionLabel = BlurBackgroundLabel(with: .systemThickMaterial)
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.text = "These are example entries. Tap \none to make it your own."
        instructionLabel.font = .bodyL
        instructionLabel.textColor = .secondaryLabel
        
        view.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)
        ])
    }
    
    private func loadDummyData() {
        // Only load entries for the current category
        switch category {
        case "Household":
            entries = [
                // Existing entries
                CommonEntry(title: "Garage Code", content: "8005", category: category, visibility: .always),
                CommonEntry(title: "Front Door", content: "2208", category: category, visibility: .always),
                CommonEntry(title: "Trash Day", content: "Wednesday", category: category, visibility: .halfDay),
                CommonEntry(title: "WiFi Password", content: "SuperStrongPassword", category: category, visibility: .always),
                CommonEntry(title: "Alarm Code", content: "4321", category: category, visibility: .always),
                CommonEntry(title: "Thermostat", content: "68°F", category: category, visibility: .halfDay),
                CommonEntry(title: "Trash Pickup", content: "Wednesday Morning", category: category, visibility: .halfDay),
                
                CommonEntry(title: "Shed", content: "1357", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Power Outage", content: "Flashlights in kitchen drawer", category: category, visibility: .halfDay),
                CommonEntry(title: "Recycling", content: "Blue bin, Fridays", category: category, visibility: .halfDay),
                CommonEntry(title: "Yard Service", content: "Every Monday, 11am-2pm", category: category, visibility: .overnight),
                CommonEntry(title: "Water Shutoff", content: "Basement, north wall", category: category, visibility: .halfDay),
                CommonEntry(title: "Gas Shutoff", content: "Outside, east side of house", category: category, visibility: .halfDay)
            ]
            
        case "Emergency":
            entries = [
                // Existing entries
                CommonEntry(title: "Emergency Contact", content: "John Doe: 555-123-4567", category: category, visibility: .always),
                CommonEntry(title: "Nearest Hospital", content: "City General - 10 Main St", category: category, visibility: .always),
                CommonEntry(title: "Fire Evacuation", content: "Meet at mailbox", category: category, visibility: .always),
                CommonEntry(title: "Poison Control", content: "1-800-222-1222", category: category, visibility: .always),
                CommonEntry(title: "Home Doctor", content: "Dr. Smith: 555-987-6543", category: category, visibility: .halfDay),
                
                // New entries
                CommonEntry(title: "911", content: "Address", category: category, visibility: .always), // Short entry
                CommonEntry(title: "EpiPen", content: "Top shelf", category: category, visibility: .always), // Short entry
                CommonEntry(title: "Safe", content: "3456", category: category, visibility: .always), // Short entry
                CommonEntry(title: "Allergies", content: "Peanuts, penicillin", category: category, visibility: .always),
                CommonEntry(title: "Insurance", content: "BlueCross #12345678", category: category, visibility: .halfDay),
                CommonEntry(title: "Urgent Care", content: "WalkIn Clinic - 55 Grove St", category: category, visibility: .halfDay),
                CommonEntry(title: "Power Company", content: "CityPower: 555-789-0123", category: category, visibility: .halfDay),
                CommonEntry(title: "Plumber", content: "Joe's Plumbing: 555-456-7890", category: category, visibility: .halfDay),
                CommonEntry(title: "Neighbor Help", content: "Mrs. Wilson: 555-234-5678", category: category, visibility: .halfDay)
            ]
            
        case "Rules & Guidelines":
            entries = [
                // Existing entries
                CommonEntry(title: "Bedtime", content: "9:00 PM on weekdays", category: category, visibility: .halfDay),
                CommonEntry(title: "Screen Time", content: "2 hours max per day", category: category, visibility: .halfDay),
                CommonEntry(title: "House Rules", content: "No shoes indoors", category: category, visibility: .always),
                CommonEntry(title: "Chores", content: "Take out trash on Wednesday", category: category, visibility: .halfDay),
                
                // New entries
                CommonEntry(title: "Snacks", content: "After 3pm", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "No TV", content: "After 8pm", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Bath", content: "7:30pm", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Books", content: "2 at bed", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Meal Times", content: "Breakfast 7am, Lunch 12pm, Dinner 6pm", category: category, visibility: .halfDay),
                CommonEntry(title: "Off-Limits", content: "Dad's office and workshop", category: category, visibility: .always),
                CommonEntry(title: "Study Hour", content: "4pm-5pm weekdays", category: category, visibility: .halfDay),
                CommonEntry(title: "Playroom Rules", content: "Clean up before moving to next activity", category: category, visibility: .halfDay),
                CommonEntry(title: "Phone Use", content: "Only after homework is completed", category: category, visibility: .halfDay),
                CommonEntry(title: "Guest Policy", content: "Parents must approve all visitors", category: category, visibility: .halfDay),
                CommonEntry(title: "Allowance", content: "$5 weekly, given on Sunday", category: category, visibility: .overnight)
            ]
            
        case "Pets":
            entries = [
                // Existing entries
                CommonEntry(title: "Feeding Schedule", content: "Morning: 7am, Evening: 6pm", category: category, visibility: .halfDay),
                CommonEntry(title: "Vet Contact", content: "Dr. Smith: 555-987-6543", category: category, visibility: .halfDay),
                CommonEntry(title: "Walking Schedule", content: "Morning and evening", category: category, visibility: .halfDay),
                CommonEntry(title: "Medication", content: "Flea medicine on the 1st", category: category, visibility: .always),
                
                // New entries
                CommonEntry(title: "Dog Food", content: "1 cup", category: category, visibility: .always), // Short entry
                CommonEntry(title: "Cat", content: "Indoor", category: category, visibility: .always), // Short entry
                CommonEntry(title: "Fish", content: "Feed 2x", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Toys", content: "In bin", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Treat Rules", content: "Max 2 per day", category: category, visibility: .halfDay),
                CommonEntry(title: "Pet Names", content: "Dog: Max, Cat: Luna, Fish: Bubbles", category: category, visibility: .always),
                CommonEntry(title: "No-Go Areas", content: "Keep pets out of formal dining room", category: category, visibility: .halfDay),
                CommonEntry(title: "Pet Sitter", content: "Emily: 555-222-3333", category: category, visibility: .overnight),
                CommonEntry(title: "Leash Location", content: "Hanging by front door", category: category, visibility: .halfDay),
                CommonEntry(title: "Pet Emergency", content: "Animal Hospital: 555-789-4561", category: category, visibility: .always),
                CommonEntry(title: "Special Needs", content: "Dog afraid of thunderstorms", category: category, visibility: .halfDay)
            ]
            
        case "School & Education":
            entries = [
                // Existing entries
                CommonEntry(title: "School Hours", content: "8:30am - 3:15pm", category: category, visibility: .halfDay),
                CommonEntry(title: "Bus Schedule", content: "Pickup: 7:45am, Drop-off: 3:30pm", category: category, visibility: .halfDay),
                CommonEntry(title: "Teacher Contact", content: "Ms. Johnson: johnson@school.edu", category: category, visibility: .halfDay),
                CommonEntry(title: "Homework Time", content: "4:00pm - 5:30pm", category: category, visibility: .halfDay),
                
                // New entries
                CommonEntry(title: "Math Help", content: "Dad", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Books", content: "20 mins", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Band", content: "Tuesdays", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Tutor", content: "Thursdays", category: category, visibility: .overnight), // Short entry
                CommonEntry(title: "School Address", content: "123 Learning Lane", category: category, visibility: .halfDay),
                CommonEntry(title: "Principal", content: "Dr. Martinez: 555-321-9876", category: category, visibility: .halfDay),
                CommonEntry(title: "Library Day", content: "Wednesday - books due back", category: category, visibility: .halfDay),
                CommonEntry(title: "School Nurse", content: "Ms. Garcia: 555-321-8765", category: category, visibility: .halfDay),
                CommonEntry(title: "Study Buddies", content: "Alex and Jamie on Mondays", category: category, visibility: .overnight),
                CommonEntry(title: "School Website", content: "www.cityschool.edu/portal", category: category, visibility: .halfDay),
                CommonEntry(title: "Class Schedule", content: "In blue folder on desk", category: category, visibility: .halfDay),
                CommonEntry(title: "Project Due", content: "Science fair - May 15", category: category, visibility: .halfDay)
            ]
            
        case "Social & Interpersonal":
            entries = [
                // Existing entries
                CommonEntry(title: "Playdate Rules", content: "No more than 2 friends at a time", category: category, visibility: .overnight),
                CommonEntry(title: "Known Allergies", content: "None", category: category, visibility: .halfDay),
                CommonEntry(title: "Approved Friends", content: "Sarah, Jake, Emma", category: category, visibility: .overnight),
                CommonEntry(title: "Parent Contacts", content: "Sarah's mom: 555-111-2222", category: category, visibility: .halfDay),
                
                // New entries
                CommonEntry(title: "Calm Down", content: "Count to 10", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Shy", content: "Be patient", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Upset", content: "Hug helps", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Nap", content: "With bear", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Comfort Item", content: "Blue blanket in bedroom", category: category, visibility: .halfDay),
                CommonEntry(title: "Mood Signs", content: "Quiet when overwhelmed", category: category, visibility: .halfDay),
                CommonEntry(title: "Social Cues", content: "Needs reminders to share", category: category, visibility: .halfDay),
                CommonEntry(title: "Friend Homes", content: "Allowed at Jake and Emma's", category: category, visibility: .overnight),
                CommonEntry(title: "Fears", content: "Afraid of the dark, use night light", category: category, visibility: .halfDay),
                CommonEntry(title: "Family Photos", content: "In living room bookshelf", category: category, visibility: .halfDay),
                CommonEntry(title: "Cultural Notes", content: "No meat on Fridays", category: category, visibility: .halfDay),
                CommonEntry(title: "Conversation", content: "Loves talking about dinosaurs", category: category, visibility: .halfDay)
            ]
            
        default:
            entries = [
                CommonEntry(title: "Playdate Rules", content: "No more than 2 friends at a time", category: category, visibility: .overnight),
                CommonEntry(title: "Trash Day", content: "Wednesday", category: category, visibility: .halfDay),
                CommonEntry(title: "Water Shutoff", content: "Basement, north wall", category: category, visibility: .halfDay),
                CommonEntry(title: "EpiPen", content: "Top shelf", category: category, visibility: .always), // Short entry
                CommonEntry(title: "Power Company", content: "CityPower: 555-789-0123", category: category, visibility: .halfDay),
                CommonEntry(title: "House Rules", content: "No shoes indoors", category: category, visibility: .always),
                CommonEntry(title: "No TV", content: "After 8pm", category: category, visibility: .halfDay), // Short entry
                CommonEntry(title: "Phone Use", content: "Only after homework is completed", category: category, visibility: .halfDay),
                CommonEntry(title: "Dog Food", content: "1 cup", category: category, visibility: .always), // Short entry
                CommonEntry(title: "School Address", content: "123 Learning Lane", category: category, visibility: .halfDay),
                CommonEntry(title: "Parent Contacts", content: "Sarah's mom: 555-111-2222", category: category, visibility: .halfDay),
            ]
        }
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        
        let buttonHeight: CGFloat = 50
        let buttonPadding: CGFloat = 10
        let totalInset = buttonHeight + buttonPadding * 2
        collectionView.contentInset.bottom = totalInset
        collectionView.verticalScrollIndicatorInsets.bottom = totalInset
        
        // Register cells
        collectionView.register(FullWidthCell.self, forCellWithReuseIdentifier: FullWidthCell.reuseIdentifier)
        collectionView.register(HalfWidthCell.self, forCellWithReuseIdentifier: HalfWidthCell.reuseIdentifier)
        
        collectionView.allowsSelection = true
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            guard let self = self else { return nil }
            
            let section = Section(rawValue: sectionIndex)!
            switch section {
            case .codes:
                return self.createHalfWidthSection()
            case .other:
                return self.createInsetGroupedSection()
            }
        }
        return layout
    }
    
    private func createHalfWidthSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(90))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(90))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 4, bottom: 12, trailing: 4)
        
        return section
    }
    
    private func createInsetGroupedSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        section.interGroupSpacing = 8
        
        return section
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, CommonEntry>(collectionView: collectionView) {
            [weak self] (collectionView, indexPath, entry) -> UICollectionViewCell? in
            guard let self = self else { return nil }
            
            let section = Section(rawValue: indexPath.section)!

            switch section {
            case .codes:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HalfWidthCell.reuseIdentifier, for: indexPath) as! HalfWidthCell
                cell.valueContainerBackgroundColor = NNColors.NNSystemBackground6
                cell.valueLabelBackgroundColor = .tertiaryLabel
                cell.configure(
                    key: entry.title,
                    value: entry.content,
                    entryVisibility: entry.visibility,
                    sessionVisibility: self.sessionVisibilityLevel
                )
                
                return cell
            case .other:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullWidthCell.reuseIdentifier, for: indexPath) as! FullWidthCell
                cell.valueContainerBackgroundColor = NNColors.NNSystemBackground6
                cell.valueLabelBackgroundColor = .tertiaryLabel
                cell.configure(
                    key: entry.title,
                    value: entry.content,
                    entryVisibility: entry.visibility,
                    sessionVisibility: self.sessionVisibilityLevel
                )
                
                return cell
            }
        }
    }
    
    private func createSnapshot() -> NSDiffableDataSourceSnapshot<Section, CommonEntry> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, CommonEntry>()
        
        snapshot.appendSections([.codes, .other])
        
        // Filter and sort entries based on cell type
        let codesEntries = entries.filter { $0.shouldUseHalfWidthCell }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        let otherEntries = entries.filter { !$0.shouldUseHalfWidthCell }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        
        snapshot.appendItems(codesEntries, toSection: .codes)
        snapshot.appendItems(otherEntries, toSection: .other)
        
        return snapshot
    }
    
    private func applySnapshot() {
        let snapshot = createSnapshot()
        dataSource.apply(snapshot, animatingDifferences: false)
        
        // Show empty state view if no entries
        emptyStateView.isHidden = !entries.isEmpty
    }
    
    private func setupEmptyStateView() {
        emptyStateView = NNEmptyStateView(
            icon: UIImage(systemName: "square.grid.2x2"),
            title: "No Suggestions",
            subtitle: "We don't have any suggestions for this category at the moment.",
            actionButtonTitle: nil
        )
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        emptyStateView.isUserInteractionEnabled = true
        
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

extension CommonEntriesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let selectedEntry = dataSource.itemIdentifier(for: indexPath),
              let cell = collectionView.cellForItem(at: indexPath) else { return }
        
        // Only allow adding entries for nest owners
        guard entryRepository is NestService else { return }
        
        Logger.log(level: .info, category: .nestService, message: "Selected common entry: \(selectedEntry.title)")
        
        Task {
            // Check entry limit for free tier users
            let hasUnlimitedEntries = await SubscriptionService.shared.isFeatureAvailable(.unlimitedEntries)
            if !hasUnlimitedEntries {
                do {
                    let currentCount = try await (entryRepository as! NestService).getCurrentEntryCount()
                    if currentCount >= 10 {
                        await MainActor.run {
                            self.dismiss(animated: true) {
                                self.delegate?.showUpgradePrompt()
                            }
                        }
                        return
                    }
                } catch {
                    Logger.log(level: .error, category: .nestService, message: "Failed to check entry count: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                let cellFrame = collectionView.convert(cell.frame, to: nil)
                
                let editEntryVC = EntryDetailViewController(
                    category: selectedEntry.category,
                    title: selectedEntry.title,
                    content: selectedEntry.content,
                    sourceFrame: cellFrame
                )
                editEntryVC.entryDelegate = self
                self.present(editEntryVC, animated: true)
            }
        }
    }
}

extension CommonEntriesViewController: EntryDetailViewControllerDelegate {
    func entryDetailViewController(didSaveEntry entry: BaseEntry?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dismiss(animated: true, completion: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.delegate?.entryDetailViewController(didSaveEntry: entry)
        }
    }
    
    func entryDetailViewController(didDeleteEntry entry: BaseEntry) {
        //
    }
}
