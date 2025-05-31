import UIKit

protocol CardStackViewDelegate: AnyObject {
    func cardStackView(_ stackView: CardStackView, didTapCard card: UIView)
    func cardStackView(_ stackView: CardStackView, didRemoveCard card: UIView)
    func cardStackView(_ stackView: CardStackView, didRestoreCard card: UIView)
    func cardStackView(_ stackView: CardStackView, didUpdateSwipe translation: CGFloat, velocity: CGFloat)
    func cardStackView(_ stackView: CardStackView, didFinishSwipe translation: CGFloat, velocity: CGFloat, dismissed: Bool)
}

enum SwipeDirection {
    case left
    case right
    
    var translation: CGFloat {
        switch self {
        case .left: return -UIScreen.main.bounds.width
        case .right: return UIScreen.main.bounds.width
        }
    }
}

class CardStackView: UIView {
    // MARK: - Properties
    private let maxVisibleCards = 3
    private let minRotation: CGFloat = -4
    private let maxRotation: CGFloat = 4
    
    private var cards: [UIView] = []
    private var reviewedCards: [UIView] = []
    private var initialCardFrame: CGRect?
    
    // Add these properties
    private var cardData: [(key: String, value: String, date: Date)] = []
    private var currentIndex: Int = 0 {
        didSet {
            updateProgressLabel()
        }
    }
    
    weak var delegate: CardStackViewDelegate?
    
    // Add to existing properties
    private var swipeDirections: [UIView: SwipeDirection] = [:]
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var activeCard: UIView?
    
    // Constants for swipe detection
    private let minimumSwipeVelocity: CGFloat = 500
    
    // Configurable props
    var minimumDismissPercentage: CGFloat = 0.75 {
        didSet { layoutCards() }
    }
    
    var verticalOffset: CGFloat = 44 {
        didSet {
            updateCardTransforms()
            layoutCards()
        }
    }
    
    var scaleRatio: CGFloat = 0.85 {
        didSet {
            updateCardTransforms()
            layoutCards()
        }
    }
    
    var rotationRange: CGFloat = 12 {  // This will be ±4 degrees
        didSet {
            updateCardTransforms()
            layoutCards()
        }
    }
    
    // Add progress label
    public lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.font = .bodyM
        return label
    }()
    
    // Replace success stack with an NNEmptyStateView
    private lazy var emptyStateView: NNEmptyStateView = {
        let view = NNEmptyStateView(
            icon: UIImage(systemName: "party.popper.fill"),
            title: "Everything looks up-to-date!",
            subtitle: "We'll let you know if entries need updating the next time you create a session."
        )
        view.alpha = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Transform Helpers
    private struct CardTransform {
        let translation: CGFloat
        let scale: CGFloat
        let rotation: CGFloat
        
        func apply(to card: UIView) {
            let translation = CGAffineTransform(translationX: 0, y: translation)
            let scaling = CGAffineTransform(scaleX: scale, y: scale)
            let rotating = CGAffineTransform(rotationAngle: rotation * .pi / 180)
            
            card.transform = translation
                .concatenating(scaling)
                .concatenating(rotating)
        }
    }
    
    private lazy var cardTransforms: [CardTransform] = {
        return (0..<maxVisibleCards).map { index in
            let scale = pow(scaleRatio, CGFloat(index))
            let yOffset = verticalOffset * CGFloat(index)
            
            // No rotation for the front card
            if index == 0 {
                return CardTransform(translation: yOffset, scale: scale, rotation: 0)
            }
            
            // Random rotation between 1-3 degrees, alternating positive/negative
            let baseRotation = CGFloat.random(in: 1...3)
            let rotation = index % 2 == 0 ? baseRotation : -baseRotation
            
            return CardTransform(translation: yOffset, scale: scale, rotation: rotation)
        }
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        clipsToBounds = false
        
        // Add our views
        [progressLabel, emptyStateView].forEach { addSubview($0) }
        
        NSLayoutConstraint.activate([
            progressLabel.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            progressLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // Center empty state view
            emptyStateView.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            emptyStateView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - Public Methods
    func setCardData(_ data: [(key: String, value: String, date: Date)]) {
        self.cardData = data
        currentIndex = 0  // This will trigger updateProgressLabel
        initializeVisibleCards()
        
        // Ensure progress label is visible
        showProgressLabel()
        
        // Log the current progress for debugging
        Logger.log(level: .debug, category: .general, message: "CardStackView: Set card data, progress: \(progressLabel.text ?? "nil"), count: \(data.count)")
    }
    
    private func initializeVisibleCards() {
        // Only create the first 3 cards
        let visibleCount = min(3, cardData.count)
        cards = (0..<visibleCount).map { index in
            createCard(from: cardData[index])
        }
        
        // Add cards in reverse for proper z-index
        for card in cards.reversed() {
            addSubview(card)
            setupConstraints(for: card)
        }
        
        layoutCards()
        setupGesturesForTopCard()
    }
    
    private func createCard(from data: (key: String, value: String, date: Date)) -> MiniEntryDetailView {
        let card = MiniEntryDetailView()
        card.configure(key: data.key, value: data.value, lastModified: data.date)
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }
    
    func next() {
        HapticsHelper.superLightHaptic()
        cycleToNextCard()
    }
    
    func previous() {
        progressLabel.alpha = 1.0
        HapticsHelper.superLightHaptic()
        restorePreviousCard()
    }
    
    var canGoNext: Bool {
        return currentIndex < cardData.count
    }
    
    var canGoPrevious: Bool {
        return !reviewedCards.isEmpty
    }
    
    private func layoutCards() {
        // Reset all cards to their original state
        cards.forEach { card in
            card.alpha = 1.0
            card.transform = .identity
        }
        
        // Only show the maximum number of visible cards
        let visibleCards = Array(cards.prefix(maxVisibleCards))
        
        // Hide any cards beyond the visible limit
        cards.dropFirst(maxVisibleCards).forEach { $0.alpha = 0 }
        
        // Update z-index for proper stacking
        for (index, card) in cards.enumerated() {
            card.layer.zPosition = CGFloat(cards.count - index)
        }
        
        // Layout visible cards with transform
        for (index, card) in visibleCards.enumerated() {
            if index == 0 {
                card.transform = .identity
            } else {
                // Use the pre-calculated transforms
                cardTransforms[index].apply(to: card)
            }
        }
    }
    
    private func cycleToNextCard(withDirection direction: SwipeDirection? = nil) {
        guard !cards.isEmpty else { return }
        
        // Check if this is the last card
        let isLastCard = currentIndex == cardData.count
        let cardToRemove = cards.removeFirst()
        
        if !isLastCard {   
            currentIndex += 1
        }
        
        // Create and add new card if there's more data
        if currentIndex + 2 < cardData.count {
            let newCard = createCard(from: cardData[currentIndex + 2])
            newCard.alpha = 0
            
            if let lastCard = cards.last {
                insertSubview(newCard, belowSubview: lastCard)
            } else {
                addSubview(newCard)
            }
            
            setupConstraints(for: newCard)
            cards.append(newCard)
        }
        
        // Animate removal and position updates
        UIView.animate(withDuration: 0.45,
                      delay: 0,
                      usingSpringWithDamping: 0.8,
                      initialSpringVelocity: 0.5,
                      options: [.curveEaseOut, .allowUserInteraction],
                      animations: {
            // Slide card off in the specified direction
            let translation = direction?.translation ?? -UIScreen.main.bounds.width
            cardToRemove.transform = CGAffineTransform(translationX: translation, y: 0)
            
            // Update remaining cards
            self.cards.enumerated().forEach { index, card in
                self.cardTransforms[index].apply(to: card)
                card.alpha = 1
                card.layer.zPosition = CGFloat(self.cards.count - index)
            }
            
            // Show spinner if this is the last card
            if isLastCard {
                self.emptyStateView.alpha = 1
            }
        }) { _ in
            cardToRemove.removeFromSuperview()
            self.reviewedCards.append(cardToRemove)
            self.delegate?.cardStackView(self, didRemoveCard: cardToRemove)
            self.setupGesturesForTopCard()
            
            // If this was the last card, animate spinner success
            if isLastCard {
                self.showSuccessState()
            }
        }
    }
    
    private func restorePreviousCard() {
        guard !reviewedCards.isEmpty, currentIndex > 0 else { return }
        
        currentIndex -= 1
        let cardToRestore = reviewedCards.removeLast()
        let direction = swipeDirections[cardToRestore] ?? .left
        
        // Remove last card if we have more than 3
        if cards.count >= 3 {
            let lastCard = cards.removeLast()
            lastCard.removeFromSuperview()
        }
        
        // Add card back to view hierarchy
        insertSubview(cardToRestore, aboveSubview: cards.first ?? self)
        setupConstraints(for: cardToRestore)
        
        // Position off-screen from the same direction it was dismissed
        cardToRestore.transform = CGAffineTransform(translationX: direction.translation, y: 0)
        cards.insert(cardToRestore, at: 0)
        
        // Animate restoration
        UIView.animate(withDuration: 0.3,
                      delay: 0,
                      usingSpringWithDamping: 0.7,
                      initialSpringVelocity: 0.5,
                      options: [.curveEaseOut],
                      animations: {
            cardToRestore.transform = .identity
            self.layoutCards()
        }) { _ in
            self.delegate?.cardStackView(self, didRestoreCard: cardToRestore)
            self.setupGesturesForTopCard()
        }
    }
    
    private lazy var feedbackOverlay: UIView = {
        let view = UIView()
        view.alpha = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Helper to calculate swipe percentage
    private func calculateSwipePercentage(for translation: CGFloat, cardWidth: CGFloat) -> CGFloat {
        let percentage = abs(translation / cardWidth)
        return min(1.0, percentage) * 100
    }
    
    // Update handlePan to include visual and haptic feedback
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let card = gesture.view else { return }
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)
        
        // Get card width once at the start
        let cardWidth = card.bounds.width
        let percentage = calculateSwipePercentage(for: translation.x, cardWidth: cardWidth)
        delegate?.cardStackView(self, didUpdateSwipe: translation.x, velocity: velocity.x)
        
        switch gesture.state {
        case .began:
            // Add overlay container at the same frame as the card
            
            // Add feedback overlay to container
            card.addSubview(feedbackOverlay)
            NSLayoutConstraint.activate([
                feedbackOverlay.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                feedbackOverlay.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                feedbackOverlay.topAnchor.constraint(equalTo: card.topAnchor),
                feedbackOverlay.bottomAnchor.constraint(equalTo: card.bottomAnchor)
            ])
            
            feedbackOverlay.layer.cornerRadius = card.layer.cornerRadius
            
        case .changed:
            let transform = CGAffineTransform(translationX: translation.x, y: 0)
            let rotationAngle = translation.x / card.bounds.width * (.pi / 8)
            card.transform = transform.rotated(by: rotationAngle)
            
            feedbackOverlay.backgroundColor = translation.x > 0 ?
                NNColors.primary.withAlphaComponent(0.15) :
                .clear
            feedbackOverlay.alpha = percentage / 100
            
        case .ended, .cancelled:
            // Use the same cardWidth here
            let percentage = calculateSwipePercentage(for: translation.x, cardWidth: cardWidth)
            let shouldDismiss = percentage > (minimumDismissPercentage * 100 - 1) || 
                              abs(velocity.x) > minimumSwipeVelocity
            
            delegate?.cardStackView(self, didFinishSwipe: translation.x, velocity: velocity.x, dismissed: shouldDismiss)
            
            if shouldDismiss {
                let direction: SwipeDirection = translation.x > 0 ? .right : .left
                swipeDirections[card] = direction
                
                HapticsHelper.lightHaptic()
                cycleToNextCard(withDirection: direction)
            } else {
                UIView.animate(withDuration: 0.3,
                             delay: 0,
                             usingSpringWithDamping: 0.8,
                             initialSpringVelocity: 0.5,
                             options: [.curveEaseOut],
                             animations: {
                    card.transform = .identity
                    self.feedbackOverlay.alpha = 0
                })
            }
            
        default:
            break
        }
    }
    
    private func setupGesturesForTopCard() {
        // Remove gestures from previous active card
        if let previousCard = activeCard {
            previousCard.isUserInteractionEnabled = false
            previousCard.gestureRecognizers?.forEach { previousCard.removeGestureRecognizer($0) }
        }
        
        guard let topCard = cards.first else { return }
        activeCard = topCard
        topCard.isUserInteractionEnabled = true
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCardTap(_:)))
        topCard.addGestureRecognizer(tapGesture)
        
        // Add pan gesture
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        topCard.addGestureRecognizer(panGestureRecognizer)
    }
    
    @objc private func handleCardTap(_ gesture: UITapGestureRecognizer) {
        guard let card = gesture.view else { return }
        delegate?.cardStackView(self, didTapCard: card)
    }
    
    private func setupConstraints(for card: UIView) {
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 12),
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.widthAnchor.constraint(equalTo: widthAnchor, constant: -60),
            // Use multiplier instead of calculating height manually
            card.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.85)  // 85% of stack view height
        ])
    }
    
    // Helper method to generate random rotation with more variation
    private func generateRandomRotation(forIndex index: Int) -> CGFloat {
        guard index > 0 else { return 0 }  // No rotation for front card
        
        // Create more random distribution
        let minRotation: CGFloat = 8  // Minimum rotation of 8 degrees
        let maxRotation: CGFloat = rotationRange
        let baseRotation = CGFloat.random(in: minRotation...maxRotation)
        
        // Store rotation for consistency when cards are restored
        let rotation = index % 2 == 0 ? baseRotation : -baseRotation
        return rotation
    }
    
    // Update transform creation to use consistent rotations
    private func updateCardTransforms() {
        cardTransforms = (0..<maxVisibleCards).map { index in
            let scale = pow(scaleRatio, CGFloat(index))
            let yOffset = verticalOffset * CGFloat(index)
            
            if index == 0 {
                return CardTransform(translation: yOffset, scale: scale, rotation: 0)
            }
            
            // Use the same rotation generation for consistency
            let rotation = generateRandomRotation(forIndex: index)
            
            return CardTransform(translation: yOffset, scale: scale, rotation: rotation)
        }
    }
    
    private func updateProgressLabel() {
        progressLabel.text = "\(currentIndex + 1)/\(cardData.count)"
        
        // Always make sure the label is visible when updating it
        progressLabel.alpha = 1.0
        
        // Log the updated value
        Logger.log(level: .debug, category: .general, message: "CardStackView: Updated progress label to \(progressLabel.text ?? "nil")")
    }
    
    private func showSuccessState() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.progressLabel.alpha = 0
            self.emptyStateView.alpha = 1
        }
    }
    
    // Add public method for programmatic right swipe
    func approveCard() {
        guard let topCard = cards.first else { return }
        
        // Check if this is the last card
        let isLastCard = currentIndex == cardData.count - 1
        
        // Store swipe direction for potential restoration
        swipeDirections[topCard] = .right
        
        // Trigger haptic
        HapticsHelper.lightHaptic()
        
        // Remove the card from the array immediately
        cards.removeFirst()
        currentIndex += 1
        
        // Keep progress label visible during the transition
        showProgressLabel()
        
        // Create and add new card if needed
        if currentIndex + 2 < cardData.count {
            let newCard = createCard(from: cardData[currentIndex + 2])
            newCard.alpha = 0
            if let lastCard = cards.last {
                insertSubview(newCard, belowSubview: lastCard)
            } else {
                addSubview(newCard)
            }
            setupConstraints(for: newCard)
            cards.append(newCard)
        }
        
        // Animate both the exit and the stack update simultaneously
        UIView.animate(withDuration: 0.45,
                      delay: 0,
                      usingSpringWithDamping: 0.8,
                      initialSpringVelocity: 0.5,
                      options: [.curveEaseOut],
                      animations: {
            // Animate exit of top card
            topCard.transform = CGAffineTransform(translationX: UIScreen.main.bounds.width, y: 0)
                .rotated(by: .pi / 8)
            topCard.alpha = 0
            
            // Simultaneously animate the rest of the stack
            self.cards.enumerated().forEach { index, card in
                self.cardTransforms[index].apply(to: card)
                card.alpha = 1
                card.layer.zPosition = CGFloat(self.cards.count - index)
            }
        }) { [weak self] _ in
            guard let self = self else { return }
            
            topCard.removeFromSuperview()
            self.reviewedCards.append(topCard)
            self.delegate?.cardStackView(self, didRemoveCard: topCard)
            self.setupGesturesForTopCard()
            
            // If this was the last card, animate success state
            if isLastCard {
                self.showSuccessState()
            } else {
                // Otherwise ensure progress label stays visible
                self.showProgressLabel()
            }
        }
    }
    
    // Add these methods to public interface
    func showLoading() {
        // Remove existing cards
        cards.forEach { $0.removeFromSuperview() }
        cards = []
        reviewedCards = []
    }
    
    func showError(message: String) {
        // Remove loading indicator if it exists
        viewWithTag(999)?.removeFromSuperview()
        
        // Create error view
        let errorView = UIView()
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.tag = 998
        addSubview(errorView)
        
        let imageView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        imageView.tintColor = .systemRed
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textAlignment = .center
        messageLabel.textColor = .secondaryLabel
        messageLabel.font = .bodyL
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        errorView.addSubview(imageView)
        errorView.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            errorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: centerYAnchor),
            errorView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            errorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            
            imageView.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: errorView.topAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 50),
            imageView.heightAnchor.constraint(equalToConstant: 50),
            
            messageLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            messageLabel.leadingAnchor.constraint(equalTo: errorView.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: errorView.trailingAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: errorView.bottomAnchor)
        ])
        
        // Hide progress label
        progressLabel.alpha = 0
    }
    
    func showSuccess(message: String) {
        // Remove any existing views
        viewWithTag(999)?.removeFromSuperview()
        viewWithTag(998)?.removeFromSuperview()
        
        // Remove all cards
        cards.forEach { $0.removeFromSuperview() }
        cards = []
        reviewedCards = []
        
        // Split the message into title and subtitle at the first newline
        let components = message.components(separatedBy: "\n\n")
        let title = components.first ?? message
        let subtitle = components.count > 1 ? components.dropFirst().joined(separator: "\n\n") : ""
        
        // Update empty state view content
        emptyStateView.configure(
            icon: UIImage(systemName: "party.popper.fill"),
            title: title,
            subtitle: subtitle
        )
        
        // Show empty state view with animation
        UIView.animate(withDuration: 0.3) {
            self.emptyStateView.alpha = 1.0
        }
        
        // Hide progress label
        progressLabel.alpha = 0
    }
    
    // Fix the naming conflict
    var topCardIndex: Int? {
        // If we have no cards, return nil
        guard !cards.isEmpty else { return nil }
        
        // Otherwise return the index in cardData for the top card
        return currentIndex
    }
    
    // Add method to make progress label visible
    public func showProgressLabel() {
        progressLabel.alpha = 1.0
    }
} 
