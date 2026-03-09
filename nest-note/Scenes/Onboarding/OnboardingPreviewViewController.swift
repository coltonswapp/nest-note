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

        ctaButton?.isEnabled = false
        ctaButton?.alpha = 0.6

        cardStackView.alpha = 0
        cardStackView.transform = CGAffineTransform(translationX: 0, y: 50)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false

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
        reviewItems = [
            .entry(CommonEntry(title: "WiFi Password", content: "SuperStrongPassword \n\n Entries are good for codes & passwords", category: "Common")),
            .routine(CommonRoutine(name: "Bedtime Routine", icon: "moon.stars.fill")),
            .place(CommonPlace(name: "School", icon: "graduationcap.fill")),

            .entry(CommonEntry(title: "Garage Code", content: "8005", category: "Common")),
            .routine(CommonRoutine(name: "After School", icon: "backpack.fill")),
            .place(CommonPlace(name: "Grandma's House", icon: "house.fill")),

            .entry(CommonEntry(title: "Emergency Contact", content: "John Doe: 555-123-4567 \n\n Entries are also good for emergency contacts", category: "Common")),
            .routine(CommonRoutine(name: "Morning Wake Up", icon: "sun.rise.fill")),
            .place(CommonPlace(name: "Favorite Park", icon: "tree.fill")),

            .entry(CommonEntry(title: "Allergies", content: "Peanuts, penicillin", category: "Common")),
            .routine(CommonRoutine(name: "Pet Care", icon: "pawprint.fill")),
            .place(CommonPlace(name: "Soccer Practice", icon: "soccerball"))
        ]

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

            view.setNeedsLayout()
            view.layoutIfNeeded()

            return view

        case .place(let commonPlace):
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

            return view
        }
    }

    // MARK: - CardStackViewDelegate

    func cardStackView(_ stackView: CardStackView, didTapCard card: UIView) {
        showToast(delay: 0.0, text: "Swipe left or right", subtitle: "Your nest can contain whatever you'd like")
    }

    func cardStackView(_ stackView: CardStackView, didRemoveCard card: UIView) {
        swipedCardCount += 1

        if swipedCardCount >= 3 && ctaButton?.isEnabled == false {
            UIView.animate(withDuration: 0.3) {
                self.ctaButton?.isEnabled = true
                self.ctaButton?.alpha = 1.0
            }
            ExplosionManager.trigger(.small, at: ctaButton?.center ?? CGPoint.zero)
        }
    }

    func cardStackView(_ stackView: CardStackView, didRestoreCard card: UIView) {}

    func cardStackView(_ stackView: CardStackView, didUpdateSwipe translation: CGFloat, velocity: CGFloat) {}

    func cardStackView(_ stackView: CardStackView, didFinishSwipe translation: CGFloat, velocity: CGFloat, dismissed: Bool) {}
}
