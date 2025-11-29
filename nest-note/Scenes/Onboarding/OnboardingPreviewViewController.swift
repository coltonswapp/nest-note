import UIKit
import CoreLocation

class OnboardingPreviewViewController: NNOnboardingViewController, CardStackViewDelegate {

    // MARK: - UI Elements
    private let cardStackView: CardStackView = {
        let stack = CardStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var reviewItems: [ReviewItem] = []
    private var swipedCardCount = 0

    // MARK: - Review Item Model
    private enum ReviewItem {
        case entry(CommonEntry)
        case routine(CommonRoutine)
        case place(CommonPlace)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupOnboarding(
            title: "NestNote offers flexible organization",
            subtitle: "Entries, routines, and places—swipe to see how they work"
        )
        setupContent()
        addCTAButton(title: "Continue")
        setupActions()
        setupCardStack()

        // Initially disable the continue button
        ctaButton?.isEnabled = false
        ctaButton?.alpha = 0.6
        
        cardStackView.setEmptyState(title: "Simple Enough?", subtitle: "There's more examples inside for you to get inspired!", imageName: "bird.fill")

        // Initially hide the card stack for animation
        cardStackView.alpha = 0
        cardStackView.transform = CGAffineTransform(translationX: 0, y: 50)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false

        // Animate in the card stack with a slight delay
        UIView.animate(withDuration: 0.6,
                      delay: 0.3,
                      usingSpringWithDamping: 0.8,
                      initialSpringVelocity: 0.5,
                      options: [.curveEaseOut],
                      animations: {
            self.cardStackView.alpha = 1.0
            self.cardStackView.transform = .identity
        })
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Re-enable the interactive pop gesture when leaving this view controller
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    private func setupActions() {
        ctaButton?.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
    }

    @objc private func continueButtonTapped() {
        (coordinator as? OnboardingCoordinator)?.next()
    }

    override func setupContent() {
        view.addSubview(cardStackView)
        cardStackView.delegate = self

        NSLayoutConstraint.activate([
            cardStackView.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 20),
            cardStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardStackView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.52)
        ])
    }

    private func setupCardStack() {
        // Create sample data using Common models for better placeholder data
        reviewItems = [
            // First set - Entry, Routine, Place pattern
            .entry(CommonEntry(title: "WiFi Password", content: "SuperStrongPassword \n\n Entries are good for codes & passwords", category: "Common")),
            .routine(CommonRoutine(name: "Bedtime Routine", icon: "moon.stars.fill")),
            .place(CommonPlace(name: "School", icon: "graduationcap.fill")),

            // Second set
            .entry(CommonEntry(title: "Garage Code", content: "8005", category: "Common")),
            .routine(CommonRoutine(name: "After School", icon: "backpack.fill")),
            .place(CommonPlace(name: "Grandma's House", icon: "house.fill")),

            // Third set
            .entry(CommonEntry(title: "Emergency Contact", content: "John Doe: 555-123-4567 \n\n Entries are also good for emergency contacts", category: "Common")),
            .routine(CommonRoutine(name: "Morning Wake Up", icon: "sun.rise.fill")),
            .place(CommonPlace(name: "Favorite Park", icon: "tree.fill")),

            // Fourth set
            .entry(CommonEntry(title: "Allergies", content: "Peanuts, penicillin", category: "Common")),
            .routine(CommonRoutine(name: "Pet Care", icon: "pawprint.fill")),
            .place(CommonPlace(name: "Soccer Practice", icon: "soccerball"))
        ]

        // Create card views for the first 3 items to start
        let cardViews = reviewItems.map { item in
            createCardView(for: item)
        }

        cardStackView.setCardViews(cardViews)
    }

    private func createCardView(for item: ReviewItem) -> UIView {
        switch item {
        case .entry(let commonEntry):
            let view = MiniEntryDetailView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.configure(key: commonEntry.title, value: commonEntry.content, lastModified: Date())
            return view

        case .routine(let commonRoutine):
            // Convert CommonRoutine to RoutineItem for display with realistic actions
            let actions: [String]
            switch commonRoutine.name {
            case "Bedtime Routine":
                actions = ["Brush teeth", "Read story", "Turn on nightlight", "Close door halfway"]
            case "After School":
                actions = ["Hang up backpack", "Wash hands", "Have snack", "Start homework"]
            case "Morning Wake Up":
                actions = ["Wake up gently", "Brush teeth", "Get dressed", "Eat breakfast"]
            case "Pet Care":
                actions = ["Fill water bowl", "Give food", "Let outside", "Clean accidents"]
            default:
                actions = ["Step 1", "Step 2", "Step 3", "Step 4"]
            }

            let routine = RoutineItem(
                title: commonRoutine.name,
                category: "Demo",
                routineActions: actions
            )
            let view = MiniRoutineReviewView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.configure(with: routine)

            // Force layout to fix bullet alignment issue
            view.setNeedsLayout()
            view.layoutIfNeeded()

            return view

        case .place(let commonPlace):
            // Convert CommonPlace to PlaceItem for display
            let place = PlaceItem(
                nestId: "demo-nest",
                category: "Demo",
                title: commonPlace.name,
                address: "382 Eagle Nest Way, Birdsville CA",
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            let view = MiniPlaceReviewView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.configure(with: place)

            // Set placeholder thumbnail after a brief delay to override the async loading
            let randomImageNumber = Int.random(in: 1...5)
            let placeholderImage = UIImage(named: "map-placeholder\(randomImageNumber)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                view.thumbnailImageView.image = placeholderImage ?? UIImage(systemName: "mappin.circle")
            }

            return view
        }
    }

    // MARK: - CardStackViewDelegate

    func cardStackView(_ stackView: CardStackView, didTapCard card: UIView) {
        // Show a brief tooltip or highlight that they can swipe
        showToast(delay: 0.0, text: "Swipe left or right", subtitle: "Your nest can contain whatever you'd like")
    }

    func cardStackView(_ stackView: CardStackView, didRemoveCard card: UIView) {
        swipedCardCount += 1

        // Enable continue button after swiping through 3 cards
        if swipedCardCount >= 3 && ctaButton?.isEnabled == false {
            UIView.animate(withDuration: 0.3) {
                self.ctaButton?.isEnabled = true
                self.ctaButton?.alpha = 1.0
            }
            ExplosionManager.trigger(.small, at: ctaButton?.center ?? CGPoint.zero)
        }
    }

    func cardStackView(_ stackView: CardStackView, didRestoreCard card: UIView) {
        // Optional: Could decrement count if we want to require consecutive swipes
    }

    func cardStackView(_ stackView: CardStackView, didUpdateSwipe translation: CGFloat, velocity: CGFloat) {
        // Optional: Could add visual feedback during swipe
    }

    func cardStackView(_ stackView: CardStackView, didFinishSwipe translation: CGFloat, velocity: CGFloat, dismissed: Bool) {
        // Optional: Could add specific feedback based on swipe direction
    }
}
