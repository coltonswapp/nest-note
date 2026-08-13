import UIKit

final class AboutEventsViewController: NNViewController {

    // MARK: - Properties

    private let topImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .rectanglePatternSmall, with: NNColors.primary)
        view.alpha = 0.4
        return view
    }()

    private let infoView = NNBulletStack(items: [
        NNBulletItem(
            title: "A timeline for the sit",
            description: "School pickup, soccer, bedtime — add the things that happen while you're out so sitters aren't hunting through texts.",
            iconName: "calendar.badge.clock"
        ),
        NNBulletItem(
            title: "Sitters see this session",
            description: "They get the plan for this job, not a standing view of your whole nest.",
            iconName: "person.2.fill"
        )
    ])

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "About Events"
        label.font = .h1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Timed notes for this session so sitters know what happens while you're out."
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let mockPreviewView: MockEventsPreviewView = {
        let view = MockEventsPreviewView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var gotItButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Got It")
        button.addTarget(self, action: #selector(gotItTapped), for: .touchUpInside)
        return button
    }()

    private var hasAnimatedBullets = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        infoView.prepareItemsForSlideIn()
        mockPreviewView.prepareForSlideIn()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAnimatedBullets else { return }
        hasAnimatedBullets = true

        infoView.animateItemsIn(initialDelay: 0.08) { [weak self] in
            self?.revealMockPreview()
        }
    }

    // MARK: - Setup

    private func setupView() {
        view.backgroundColor = .systemGroupedBackground
        scrollView.backgroundColor = .clear
        containerView.backgroundColor = .clear

        view.addSubview(topImageView)
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)

        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(infoView)
        containerView.addSubview(mockPreviewView)

        infoView.translatesAutoresizingMaskIntoConstraints = false

        gotItButton.pinToBottom(of: view, addBlurEffect: true)
        topImageView.pinToTop(of: view)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topImageView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: gotItButton.topAnchor),

            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            infoView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            infoView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 36),
            infoView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -36),

            mockPreviewView.topAnchor.constraint(equalTo: infoView.bottomAnchor, constant: 28),
            mockPreviewView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            mockPreviewView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            mockPreviewView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
        ])
    }

    private func revealMockPreview() {
        mockPreviewView.animateSlideIn(duration: 0.45, delay: 0.05)
    }

    // MARK: - Actions

    @objc private func gotItTapped() {
        dismiss(animated: true)
    }
}

// MARK: - Mock Events Preview

private final class MockEventsPreviewView: UIView {

    private let headerLabel: UILabel = {
        let label = UILabel()
        label.font = .captionBoldS
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let cardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 12
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.isUserInteractionEnabled = false
        return view
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d"
        headerLabel.text = dateFormatter.string(from: Date()).uppercased()

        addSubview(headerLabel)
        addSubview(cardView)
        cardView.addSubview(stackView)

        let events = Self.mockEvents()
        for (index, event) in events.enumerated() {
            if index > 0 {
                stackView.addArrangedSubview(Self.makeSeparator())
            }

            let cell = SessionEventCell()
            cell.translatesAutoresizingMaskIntoConstraints = false
            cell.configure(with: event)
            cell.isUserInteractionEnabled = false
            cell.backgroundColor = .secondarySystemGroupedBackground
            cell.contentView.backgroundColor = .secondarySystemGroupedBackground

            var backgroundConfig = UIBackgroundConfiguration.listCell()
            backgroundConfig.backgroundColor = .secondarySystemGroupedBackground
            cell.backgroundConfiguration = backgroundConfig

            stackView.addArrangedSubview(cell)
            cell.heightAnchor.constraint(equalToConstant: 56).isActive = true
        }

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            cardView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.topAnchor.constraint(equalTo: cardView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
        ])
    }

    private static func mockEvents() -> [SessionEvent] {
        let calendar = Calendar.current
        let today = Date()

        func date(hour: Int, minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        }

        return [
            SessionEvent(title: "School Pickup", startDate: date(hour: 15, minute: 0), eventColor: .blue),
            SessionEvent(title: "Soccer Practice", startDate: date(hour: 16, minute: 30), eventColor: .green),
            SessionEvent(title: "Bedtime", startDate: date(hour: 20, minute: 0), eventColor: .orange),
        ]
    }

    private static func makeSeparator() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = .separator

        container.addSubview(line)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 44),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }
}
