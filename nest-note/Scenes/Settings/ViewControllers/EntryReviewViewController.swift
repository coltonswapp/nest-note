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
    
    private lazy var approveButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(title: "Looks good 👍", image: nil, backgroundColor: .systemBlue, foregroundColor: .white)
        button.addTarget(self, action: #selector(approveTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
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
        label.font = .systemFont(ofSize: 14)
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
    
    // Add property for entry repository
    private let entryRepository: EntryRepository
    
    // Add property to store outdated entries
    private var outdatedEntries: [BaseEntry] = []
    
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
        
        // Load outdated entries
        loadOutdatedEntries()
    }
    
    override func setup() {
        navigationItem.title = "Review Entries"
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
        
        [subtitleLabel, cardStackView, buttonStack, doneButton].forEach {
            view.addSubview($0)
        }
        
        [previousButton, approveButton, nextButton].forEach {
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
            
            buttonStack.topAnchor.constraint(equalTo: cardStackView.bottomAnchor, constant: 20),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            approveButton.heightAnchor.constraint(equalToConstant: 46.0),
            approveButton.widthAnchor.constraint(equalToConstant: view.frame.width * 0.4),
            
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
    
    private func loadOutdatedEntries() {
        Task {
            do {
                // Fetch entries older than 90 days using the protocol method
                let entries = try await entryRepository.fetchOutdatedEntries(olderThan: 90)
                
                await MainActor.run {
                    outdatedEntries = entries
                    if entries.isEmpty {
                        // Show success state with better message
                        cardStackView.showSuccess(message: "Great job! 🎉\nYour Nest is up to date.")
                        
                        // Hide the button stack since there are no entries to review
                        buttonStack.isHidden = true
                        
                        // Enable and update the done button to be more prominent
                        doneButton.isEnabled = true
                        doneButton.setTitle("Done")
                        
                        // Add haptic feedback for positive reinforcement
                        HapticsHelper.successHaptic()
                        
                        // Update subtitle to reflect the successful state
                        subtitleLabel.text = "All your entries are current. Check back later to maintain your Nest."
                    } else {
                        // Show button stack since there are entries to review
                        buttonStack.isHidden = false
                        
                        // Convert entries to card data format
                        let cardData = entries.map { entry in
                            return (entry.title, entry.content, entry.updatedAt)
                        }
                        
                        // Update card stack with real data
                        cardStackView.setCardData(cardData)
                        updateButtonStates()
                        
                        // Ensure progress label is visible using the public method
                        cardStackView.showProgressLabel()
                        
                        // Log the progress label text for debugging
                        Logger.log(level: .debug, category: .general, message: "Progress label text: \(cardStackView.progressLabel.text ?? "nil")")
                    }
                }
            } catch {
                await MainActor.run {
                    // Handle error
                    Logger.log(level: .error, category: .nestService, message: "Error loading outdated entries: \(error.localizedDescription)")
                    cardStackView.showError(message: "Failed to load entries")
                    
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
    
    @objc private func approveTapped() {
        // Get the top card index to find the corresponding entry
        guard let topCardIndex = cardStackView.topCardIndex,
              topCardIndex < outdatedEntries.count else {
            // If there's no valid card, just call the regular approve (visual effect only)
            cardStackView.approveCard()
            return
        }
        
        // Get the entry to update
        var updatedEntry = outdatedEntries[topCardIndex]
        updatedEntry.updatedAt = Date()
        
        // Update in the repository
        Task {
            do {
                try await entryRepository.updateEntry(updatedEntry)
                
                await MainActor.run {
                    // Update the entry in our local array instead of removing it
                    outdatedEntries[topCardIndex] = updatedEntry
                    
                    // Show visual feedback
                    HapticsHelper.mediumHaptic()
                    
                    // Trigger the card stack animation
                    cardStackView.approveCard()
                }
            } catch {
                await MainActor.run {
                    // Show error feedback but still move the card
                    showToast(text: "Error updating entry", sentiment: .negative)
                    Logger.log(level: .error, category: .nestService, message: "Error updating entry: \(error.localizedDescription)")
                    
                    // Still approve the card visually
                    cardStackView.approveCard()
                }
            }
        }
    }
    
    private func updateButtonStates() {
        previousButton.isEnabled = cardStackView.canGoPrevious
        previousButton.setTitleColor(cardStackView.canGoPrevious ? .systemBlue : .secondaryLabel, for: .normal)
        
        nextButton.isEnabled = cardStackView.canGoNext
        nextButton.setTitleColor(cardStackView.canGoNext ? .systemBlue : .secondaryLabel, for: .normal)
    }
    
    @objc private func doneButtonTapped() {
        // Notify delegate that review is complete before dismissing
        reviewDelegate?.entryReviewDidComplete()
        dismiss(animated: true)
    }
    
    // Also call the delegate in the X button action
    @objc override func closeButtonTapped() {
        // Notify delegate that review is complete before dismissing
        reviewDelegate?.entryReviewDidComplete()
        super.closeButtonTapped()
    }
    
    // Card stack delegate methods
    func cardStackView(_ stackView: CardStackView, didTapCard card: UIView) {
        // Find the corresponding entry
        guard let index = stackView.topCardIndex,
              index < outdatedEntries.count else {
            return
        }
        
        let entry = outdatedEntries[index]
        
        // Open the entry for editing
        let vc = EntryDetailViewController(category: entry.category, entry: entry, sourceFrame: card.frame)
        vc.entryDelegate = self
        present(vc, animated: true)
    }
    
    func cardStackView(_ stackView: CardStackView, didRemoveCard card: UIView) {
        updateButtonStates()
        
        if !stackView.canGoNext {
            doneButton.isEnabled = true
        }
    }
    
    func cardStackView(_ stackView: CardStackView, didRestoreCard card: UIView) {
        updateButtonStates()
    }
    
    func cardStackView(_ stackView: CardStackView, didUpdateSwipe translation: CGFloat, velocity: CGFloat) {
        // No additional action needed
    }
    
    func cardStackView(_ stackView: CardStackView, didFinishSwipe translation: CGFloat, velocity: CGFloat, dismissed: Bool) {
        // This is called when a card is swiped by the user
        if dismissed && translation > 0 {
            // Right swipe - update the entry's timestamp
            guard let topCardIndex = stackView.topCardIndex,
                  topCardIndex < outdatedEntries.count else {
                return
            }
            
            // Get and update the entry
            var updatedEntry = outdatedEntries[topCardIndex]
            updatedEntry.updatedAt = Date()
            
            // Update in the local array instead of removing it
            outdatedEntries[topCardIndex] = updatedEntry
            
            // Update in the repository
            Task {
                do {
                    try await entryRepository.updateEntry(updatedEntry)
                } catch {
                    await MainActor.run {
                        showToast(text: "Error updating entry", sentiment: .negative)
                        Logger.log(level: .error, category: .nestService, message: "Error updating entry on swipe: \(error.localizedDescription)")
                    }
                }
            }
        }
        // For left swipes, we don't need to update the entry
    }
}

// Add this extension to handle entry updates
extension EntryReviewViewController: EntryDetailViewControllerDelegate {
    func entryDetailViewController(didSaveEntry entry: BaseEntry?) {
        guard let entry = entry else {
            // Handle deletion - just show a toast, no need to refresh the entire stack
            // We can keep the card in the visual stack but mark it as deleted if needed
            if let editingEntry = entry {
                showToast(text: "Entry deleted")
                Logger.log(level: .info, category: .nestService, message: "Entry deleted: \(editingEntry.id)")
            }
            return
        }
        
        // Update the entry in our local array
        if let index = outdatedEntries.firstIndex(where: { $0.id == entry.id }) {
            // Update the entry in the local array instead of removing it
            outdatedEntries[index] = entry
            
            // Update in the repository
            Task {
                do {
                    try await entryRepository.updateEntry(entry)
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
        //
    }
}
