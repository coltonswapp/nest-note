//
//  EntryReviewViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 1/11/25.
//

import UIKit

// Add delegate protocol to notify when review is completed
protocol EntryReviewViewControllerDelegate: AnyObject {
    func entryReviewDidComplete()
}

class EntryReviewViewController: NNViewController, CardStackViewDelegate {

    // Add delegate property
    weak var reviewDelegate: EntryReviewViewControllerDelegate?
    
    private let outOfDateThreshold: Int = 1
    
    private let cardStackView: CardStackView = {
        let stack = CardStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalCentering
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var ignoreLabel: UILabel = {
        let label = UILabel()
        label.text = "IGNORE"
        label.textColor = .systemRed
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textAlignment = .center
        label.alpha = 0
        label.backgroundColor = UIColor.systemRed.withAlphaComponent(0.15)
        label.layer.cornerRadius = 20
        label.clipsToBounds = true
        label.transform = CGAffineTransform(rotationAngle: -15 * .pi / 180) // -15 degrees
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var looksGoodLabel: UILabel = {
        let label = UILabel()
        label.text = "LOOKS GOOD"
        label.textColor = .systemGreen
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textAlignment = .center
        label.alpha = 0
        label.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
        label.layer.cornerRadius = 20
        label.clipsToBounds = true
        label.transform = CGAffineTransform(rotationAngle: 15 * .pi / 180) // +15 degrees
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var previousButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Previous", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
        button.isEnabled = false
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }()
    
    // Remove the approve button - replaced with swipe labels
    
    private lazy var nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Next", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Ensure that your Nest information is current. Swipe left to skip, swipe right to mark as up-to-date, tap to edit."
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .bodyM
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var doneButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Done", image: nil)
        button.backgroundColor = NNColors.primary
        button.isEnabled = false
        button.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var loadingIndicator: UIActivityIndicatorView!
    private var isLoading = false {
        didSet {
            updateLoadingState()
        }
    }
    
    // Add property for entry repository
    private let entryRepository: EntryRepository
    
    // Review item wrapper to support multiple types
    private enum ReviewItem {
        case entry(BaseEntry)
        case place(PlaceItem)
        case routine(RoutineItem)
        
        var updatedAt: Date {
            switch self {
            case .entry(let e): return e.updatedAt
            case .place(let p): return p.updatedAt
            case .routine(let r): return r.updatedAt
            }
        }
    }
    
    // Backing data
    private var reviewItems: [ReviewItem] = []
    
    // Update initializer to accept repository
    init(entryRepository: EntryRepository) {
        self.entryRepository = entryRepository
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCardStack()
        cardStackView.delegate = self
        
        // Load outdated items across all types
        loadOutdatedItems()
    }
    
    override func setup() {
        setupLoadingIndicator()
        navigationItem.title = "Review Items"
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    override func setupNavigationBarButtons() {
        let closeButton = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeButtonTapped))
        let buttons = [closeButton]
        buttons.forEach { $0.tintColor = .label }
        navigationItem.rightBarButtonItems = buttons
        navigationController?.isModalInPresentation = true
    }
    
    override func addSubviews() {
        view.backgroundColor = .systemBackground
        
        [subtitleLabel, cardStackView, buttonStack, doneButton, ignoreLabel, looksGoodLabel].forEach {
            view.addSubview($0)
        }
        
        [previousButton, nextButton].forEach {
            buttonStack.addArrangedSubview($0)
        }
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            subtitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            cardStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            cardStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardStackView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),
            
            // Position swipe indicator labels on the left and right sides
            ignoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            ignoreLabel.centerYAnchor.constraint(equalTo: cardStackView.centerYAnchor),
            ignoreLabel.widthAnchor.constraint(equalToConstant: 100),
            ignoreLabel.heightAnchor.constraint(equalToConstant: 40),
            
            looksGoodLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            looksGoodLabel.centerYAnchor.constraint(equalTo: cardStackView.centerYAnchor),
            looksGoodLabel.widthAnchor.constraint(equalToConstant: 120),
            looksGoodLabel.heightAnchor.constraint(equalToConstant: 40),
            
            buttonStack.topAnchor.constraint(equalTo: cardStackView.bottomAnchor, constant: 20),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            doneButton.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 20),
            doneButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            doneButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupCardStack() {
        // Show loading indicator while fetching
        cardStackView.showLoading()
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func loadOutdatedItems() {
        Task {
            do {
                isLoading = true
                
                let calendar = Calendar.current
                let threshold = calendar.date(byAdding: .day, value: -outOfDateThreshold, to: Date()) ?? Date()

                // Gather items: entries via protocol, places and routines via repository services
                let entries = try await entryRepository.fetchOutdatedEntries(olderThan: outOfDateThreshold)
                var places: [PlaceItem] = []
                var routines: [RoutineItem] = []
                
                if let nestService = entryRepository as? NestService {
                    places = try await nestService.fetchPlaces()
                    routines = try await nestService.fetchItems(ofType: .routine)
                } else if let sitterService = entryRepository as? SitterViewService {
                    places = try await sitterService.fetchNestPlaces()
                    routines = try await sitterService.fetchNestRoutines()
                } else {
                    // Fallback: try fetchAllItems if implemented
                    let all = try await entryRepository.fetchAllItems()
                    places = all.compactMap { $0 as? PlaceItem }
                    routines = all.compactMap { $0 as? RoutineItem }
                }
                
                // Filter outdated by updatedAt threshold
                let outdatedPlaces = places.filter { $0.updatedAt < threshold }
                let outdatedRoutines = routines.filter { $0.updatedAt < threshold }
                
                // Build review items and sort oldest first
                var items: [ReviewItem] = []
                items.append(contentsOf: entries.map { .entry($0) })
                items.append(contentsOf: outdatedPlaces.map { .place($0) })
                items.append(contentsOf: outdatedRoutines.map { .routine($0) })
                items.sort { $0.updatedAt < $1.updatedAt }
                
                await MainActor.run {
                    reviewItems = items
                    
                    isLoading = false
                    if items.isEmpty {
                        // Show success state with better message - format with title and subtitle separated by double newline
                        cardStackView.showSuccess(message: "Everything looks up-to-date!\n\nWe'll let you know if items need updating the next time you create a session.")
                        
                        // Hide the button stack since there are no entries to review
                        buttonStack.isHidden = true
                        
                        // Enable and update the done button to be more prominent
                        doneButton.isEnabled = true
                        doneButton.setTitle("Done")
                        
                        // Add haptic feedback for positive reinforcement
                        HapticsHelper.successHaptic()
                    } else {
                        isLoading = false
                        // Show button stack since there are entries to review
                        buttonStack.isHidden = false
                        
                        // Build custom card views matching item type styles
                        let views: [UIView] = items.map { item in
                            switch item {
                            case .entry(let e):
                                let v = MiniEntryDetailView()
                                v.translatesAutoresizingMaskIntoConstraints = false
                                v.configure(key: e.title, value: e.content, lastModified: e.updatedAt)
                                return v
                            case .place(let p):
                                let v = MiniPlaceReviewView()
                                v.translatesAutoresizingMaskIntoConstraints = false
                                v.configure(with: p)
                                return v
                            case .routine(let r):
                                let v = MiniRoutineReviewView()
                                v.translatesAutoresizingMaskIntoConstraints = false
                                v.configure(with: r)
                                return v
                            }
                        }
                        
                        // Update card stack with custom views
                        cardStackView.setCardViews(views)
                        updateButtonStates()
                        
                        // Ensure progress label is visible using the public method
                        cardStackView.showProgressLabel()
                        
                        // Log the progress label text for debugging
                        Logger.log(level: .debug, category: .general, message: "Progress label text: \(cardStackView.progressLabel.text ?? "nil")")
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Handle error
                    Logger.log(level: .error, category: .nestService, message: "Error loading outdated items: \(error.localizedDescription)")
                    cardStackView.showError(message: "Failed to load items")
                    
                    // Hide button stack on error too
                    buttonStack.isHidden = true
                    
                    doneButton.isEnabled = true
                }
            }
        }
    }
    
    // Remove the now redundant methods since we can access the label directly
    private func ensureProgressLabelVisible() {
        cardStackView.showProgressLabel()
    }
    
    private func findProgressLabel() -> UILabel? {
        return cardStackView.progressLabel
    }
    
    @objc private func nextTapped() {
        cardStackView.next()
    }
    
    @objc private func previousTapped() {
        cardStackView.previous()
    }
    
    // Approve functionality now handled through swipe gestures
    
    private func updateButtonStates() {
        previousButton.isEnabled = cardStackView.canGoPrevious
        previousButton.setTitleColor(cardStackView.canGoPrevious ? .systemBlue : .secondaryLabel, for: .normal)
        
        nextButton.isEnabled = cardStackView.canGoNext
        nextButton.setTitleColor(cardStackView.canGoNext ? .systemBlue : .secondaryLabel, for: .normal)
    }
    
    private func updateLoadingState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.isLoading {
                self.loadingIndicator.startAnimating()
                self.buttonStack.isHidden = true
                self.cardStackView.isHidden = true
            } else {
                self.loadingIndicator.stopAnimating()
                self.buttonStack.isHidden = false
                self.cardStackView.isHidden = false
            }
        }
    }
    
    @objc private func doneButtonTapped() {
        // Notify delegate that review is complete before dismissing
        reviewDelegate?.entryReviewDidComplete()
        dismiss(animated: true)
    }
    
    // Also call the delegate in the X button action
    @objc override func closeButtonTapped() {
        // Notify delegate that review is complete before dismissing
        if doneButton.isEnabled {
            reviewDelegate?.entryReviewDidComplete()
        }
        super.closeButtonTapped()
    }
    
    // Card stack delegate methods
    func cardStackView(_ stackView: CardStackView, didTapCard card: UIView) {
        guard let index = stackView.topCardIndex,
              index < reviewItems.count else { return }
        
        switch reviewItems[index] {
        case .entry(let entry):
            let vc = EntryDetailViewController(category: entry.category, entry: entry, sourceFrame: card.frame)
            vc.entryDelegate = self
            present(vc, animated: true)
        case .place(let place):
            let isReadOnly = !(entryRepository is NestService)
            let vc = PlaceDetailViewController(place: place, isReadOnly: isReadOnly)
            vc.placeListDelegate = self
            present(vc, animated: true)
        case .routine(let routine):
            let isReadOnly = !(entryRepository is NestService)
            let vc = RoutineDetailViewController(category: routine.category, routine: routine, sourceFrame: card.frame, isReadOnly: isReadOnly)
            vc.routineDelegate = self
            present(vc, animated: true)
        }
    }
    
    func cardStackView(_ stackView: CardStackView, didRemoveCard card: UIView) {
        updateButtonStates()
        
        if !stackView.canGoNext {
            doneButton.isEnabled = true
            
            // If all items have been reviewed, ensure the success message shows
            if reviewItems.isEmpty || stackView.topCardIndex == nil {
                Logger.log(level: .debug, category: .general, message: "All cards reviewed, showing success state")
            }
        }
    }
    
    func cardStackView(_ stackView: CardStackView, didRestoreCard card: UIView) {
        updateButtonStates()
    }
    
    func cardStackView(_ stackView: CardStackView, didUpdateSwipe translation: CGFloat, velocity: CGFloat) {
        // Calculate the swipe percentage (0-100)
        let cardWidth = UIScreen.main.bounds.width
        let percentage = min(abs(translation) / cardWidth, 1.0)
        
        if translation < 0 {
            // Swiping left - show IGNORE label
            ignoreLabel.alpha = percentage * 0.8  // Max opacity of 0.8
            looksGoodLabel.alpha = 0
        } else if translation > 0 {
            // Swiping right - show LOOKS GOOD label
            looksGoodLabel.alpha = percentage * 0.8  // Max opacity of 0.8
            ignoreLabel.alpha = 0
        } else {
            // No swipe - hide both labels
            ignoreLabel.alpha = 0
            looksGoodLabel.alpha = 0
        }
    }
    
    func cardStackView(_ stackView: CardStackView, didFinishSwipe translation: CGFloat, velocity: CGFloat, dismissed: Bool) {
        // Hide swipe indicators when swipe finishes
        UIView.animate(withDuration: 0.2) {
            self.ignoreLabel.alpha = 0
            self.looksGoodLabel.alpha = 0
        }
        
        // This is called when a card is swiped by the user
        if dismissed && translation > 0 {
            guard let topCardIndex = stackView.topCardIndex,
                  topCardIndex < reviewItems.count else { return }
            
            Task {
                do {
                    switch reviewItems[topCardIndex] {
                    case .entry(var e):
                        e.updatedAt = Date()
                        try await entryRepository.updateEntry(e)
                        await MainActor.run { self.reviewItems[topCardIndex] = .entry(e) }
                    case .place(var p):
                        p.updatedAt = Date()
                        if let nest = self.entryRepository as? NestService {
                            try await nest.updatePlace(p)
                            await MainActor.run { self.reviewItems[topCardIndex] = .place(p) }
                        }
                    case .routine(var r):
                        r.updatedAt = Date()
                        if let nest = self.entryRepository as? NestService {
                            try await nest.updateRoutine(r)
                            await MainActor.run { self.reviewItems[topCardIndex] = .routine(r) }
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.showToast(text: "Error updating item", sentiment: .negative)
                        Logger.log(level: .error, category: .nestService, message: "Error updating item on swipe: \(error.localizedDescription)")
                    }
                }
            }
        }
        // For left swipes, we don't need to update the entry
    }
    
    // MARK: - Card View Updates
    
    /// Updates the card view at the specified index to reflect changes in the underlying data
    private func updateCardViewForUpdatedItem(at index: Int) {
        guard index >= 0 && index < reviewItems.count else { 
            Logger.log(level: .info, category: .general, message: "Cannot update card view: index \(index) out of bounds (reviewItems count: \(reviewItems.count))")
            return 
        }
        
        let item = reviewItems[index]
        
        // Create a new card view with the updated data
        let newCardView: UIView
        switch item {
        case .entry(let entry):
            let entryView = MiniEntryDetailView()
            entryView.translatesAutoresizingMaskIntoConstraints = false
            entryView.configure(key: entry.title, value: entry.content, lastModified: entry.updatedAt)
            newCardView = entryView
        case .place(let place):
            let placeView = MiniPlaceReviewView()
            placeView.translatesAutoresizingMaskIntoConstraints = false
            placeView.configure(with: place)
            newCardView = placeView
        case .routine(let routine):
            let routineView = MiniRoutineReviewView()
            routineView.translatesAutoresizingMaskIntoConstraints = false
            routineView.configure(with: routine)
            newCardView = routineView
        }
        
        // Update the card view in the CardStackView
        cardStackView.updateCardView(at: index, with: newCardView)
        
        Logger.log(level: .debug, category: .general, message: "Updated card view for item at index \(index)")
    }
}

// Add this extension to handle entry updates
extension EntryReviewViewController: EntryDetailViewControllerDelegate {
    func entryDetailViewController(didSaveEntry entry: BaseEntry?) {
        guard let entry = entry else {
            // Entry was deleted through the edit screen
            // The didDeleteEntry delegate method will handle this case
            return
        }
        
        // Update the entry in our local array
        if let index = reviewItems.firstIndex(where: { if case .entry(let e) = $0 { return e.id == entry.id } else { return false } }) {
            reviewItems[index] = .entry(entry)
            
            // Update the corresponding card view to reflect the changes
            updateCardViewForUpdatedItem(at: index)
            
            // Update in the repository
            Task {
                do {
                    try await entryRepository.updateEntry(entry)
                    
                    await MainActor.run {
                        // Show a success toast
                        showToast(text: "Entry updated")
                        
                        // Automatically advance to the next card since this one is now updated
                        if cardStackView.canGoNext {
                            // Add a slight delay to ensure the toast is visible first
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.cardStackView.approveCard()
                                self.updateButtonStates()
                                
                                // Give haptic feedback for the automatic advance
                                HapticsHelper.lightHaptic()
                            }
                        } else {
                            // If this was the last card, make sure the done button is enabled
                            doneButton.isEnabled = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        showToast(text: "Error updating entry", sentiment: .negative)
                        Logger.log(level: .error, category: .nestService, message: "Error updating entry: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func entryDetailViewController(didDeleteEntry entry: BaseEntry) {
        // Show toast for user feedback
        showToast(text: "Entry deleted")
        Logger.log(level: .info, category: .nestService, message: "Entry deleted: \(entry.id)")
        
        // Remove from our items
        if let index = reviewItems.firstIndex(where: { if case .entry(let e) = $0 { return e.id == entry.id } else { return false } }) {
            reviewItems.remove(at: index)
            
            // Automatically advance to the next card after deletion
            if cardStackView.canGoNext {
                // Add a slight delay to ensure the toast is visible first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.cardStackView.approveCard()
                    self.updateButtonStates()
                    
                    // Give haptic feedback for the automatic advance
                    HapticsHelper.lightHaptic()
                }
            } else {
                // If this was the last card, make sure the done button is enabled
                doneButton.isEnabled = true
                
                // If we deleted all entries, show success state
                if reviewItems.isEmpty {
                    cardStackView.showSuccess(message: "Everything looks up-to-date!\n\nWe'll let you know if items need updating the next time you create a session.")
                }
            }
        }
    }
}

// MARK: - PlaceListViewControllerDelegate (used by PlaceDetailViewController)
extension EntryReviewViewController: PlaceListViewControllerDelegate {
    func placeListViewController(didUpdatePlace place: PlaceItem) {
        if let index = reviewItems.firstIndex(where: { if case .place(let p) = $0 { return p.id == place.id } else { return false } }) {
            reviewItems[index] = .place(place)
            
            // Update the corresponding card view to reflect the changes
            updateCardViewForUpdatedItem(at: index)
            
            showToast(text: "Place updated")
            if cardStackView.canGoNext {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.cardStackView.approveCard()
                    self.updateButtonStates()
                    HapticsHelper.lightHaptic()
                }
            } else {
                doneButton.isEnabled = true
            }
        }
    }
    
    func placeListViewController(didDeletePlace place: PlaceItem) {
        if let index = reviewItems.firstIndex(where: { if case .place(let p) = $0 { return p.id == place.id } else { return false } }) {
            reviewItems.remove(at: index)
            showToast(text: "Place deleted")
            if cardStackView.canGoNext {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.cardStackView.approveCard()
                    self.updateButtonStates()
                    HapticsHelper.lightHaptic()
                }
            } else {
                doneButton.isEnabled = true
                if reviewItems.isEmpty {
                    cardStackView.showSuccess(message: "Everything looks up-to-date!\n\nWe'll let you know if items need updating the next time you create a session.")
                }
            }
        }
    }
}

// MARK: - RoutineDetailViewControllerDelegate
extension EntryReviewViewController: RoutineDetailViewControllerDelegate {
    func routineDetailViewController(didSaveRoutine routine: RoutineItem?) {
        guard let routine else { return }
        if let index = reviewItems.firstIndex(where: { if case .routine(let r) = $0 { return r.id == routine.id } else { return false } }) {
            reviewItems[index] = .routine(routine)
            
            // Update the corresponding card view to reflect the changes
            updateCardViewForUpdatedItem(at: index)
            
            showToast(text: "Routine updated")
            if cardStackView.canGoNext {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.cardStackView.approveCard()
                    self.updateButtonStates()
                    HapticsHelper.lightHaptic()
                }
            } else {
                doneButton.isEnabled = true
            }
        }
    }
    
    func routineDetailViewController(didDeleteRoutine routine: RoutineItem) {
        if let index = reviewItems.firstIndex(where: { if case .routine(let r) = $0 { return r.id == routine.id } else { return false } }) {
            reviewItems.remove(at: index)
            showToast(text: "Routine deleted")
            if cardStackView.canGoNext {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.cardStackView.approveCard()
                    self.updateButtonStates()
                    HapticsHelper.lightHaptic()
                }
            } else {
                doneButton.isEnabled = true
                if reviewItems.isEmpty {
                    cardStackView.showSuccess(message: "Everything looks up-to-date!\n\nWe'll let you know if items need updating the next time you create a session.")
                }
            }
        }
    }
}
