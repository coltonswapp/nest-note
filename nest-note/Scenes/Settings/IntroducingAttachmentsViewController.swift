import UIKit

/// Education screen explaining nest item attachments with a live stack demo.
final class IntroducingAttachmentsViewController: NNViewController {

    // MARK: - Properties

    var onFinished: (() -> Void)?

    private let topImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .rectanglePatternSmall, with: NNColors.primary)
        view.alpha = 0.4
        return view
    }()

    private let infoView: NNBulletStack

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
        label.text = "About Attachments"
        label.font = .h1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Link related notes, contacts, places, and routines so everything sitters need lives in one place."
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let tapHintLabel: UILabel = {
        let label = UILabel()
        label.text = "Tap the stack, then a card for details"
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var attachmentStackView: AttachmentStackView = {
        let stack = AttachmentStackView(stackSize: 80, expansionDirection: .left)
        stack.delegate = self
        return stack
    }()

    private var hasAnimatedBullets = false

    // MARK: - Initialization

    init() {
        self.infoView = NNBulletStack(items: [
            NNBulletItem(
                title: "Keep context together",
                description: "Attach a pediatrician contact to a medication note so sitters never hunt for the right number.",
                iconName: "link"
            ),
            NNBulletItem(
                title: "Guide sitters faster",
                description: "Pin a bedtime routine or favorite place next to the note that explains what to do.",
                iconName: "person.crop.circle.badge.checkmark"
            ),
            NNBulletItem(
                title: "Stay organized",
                description: "Related items travel together — open one note and the attachments you need are already there.",
                iconName: "rectangle.stack.fill"
            ),
        ])
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupNavigationBar()
        configureDemoAttachments()
        infoView.prepareItemsForSlideIn()
        tapHintLabel.alpha = 0
        attachmentStackView.alpha = 0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAnimatedBullets else { return }
        hasAnimatedBullets = true

        infoView.animateItemsIn(initialDelay: 0.08) { [weak self] in
            self?.revealAttachmentDemo()
        }
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
    }

    private func setupView() {
        view.backgroundColor = .systemBackground
        view.clipsToBounds = false

        view.addSubview(topImageView)
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        view.addSubview(tapHintLabel)
        view.addSubview(attachmentStackView)

        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(infoView)

        infoView.translatesAutoresizingMaskIntoConstraints = false
        topImageView.pinToTop(of: view)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topImageView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: attachmentStackView.topAnchor, constant: -16),

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
            infoView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),

            attachmentStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            attachmentStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            tapHintLabel.centerYAnchor.constraint(equalTo: attachmentStackView.centerYAnchor),
            tapHintLabel.trailingAnchor.constraint(equalTo: attachmentStackView.leadingAnchor, constant: -12),
            tapHintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
        ])
    }

    private func configureDemoAttachments() {
        let demoItems: [any BaseItem] = [
            ContactItem(
                category: "Contacts",
                title: "Dr. Patel",
                content: "(555) 014-2200 · Pediatrician"
            ),
            NoteItem(
                title: "Allergy meds",
                content: "Children's Benadryl in the kitchen cabinet. Dose is on the bottle.",
                category: "Health"
            ),
            RoutineItem(
                title: "Bedtime",
                category: "Routines",
                routineActions: ["PJs", "Brush teeth", "Two books"],
                frequency: "Nightly"
            ),
        ]
        attachmentStackView.configure(items: demoItems, showsPlus: false)
    }

    private func revealAttachmentDemo() {
        UIView.animate(
            withDuration: 0.45,
            delay: 0.05,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.2,
            options: [.curveEaseOut]
        ) {
            self.tapHintLabel.alpha = 1
            self.attachmentStackView.alpha = 1
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        finish()
    }

    private func finish() {
        AttachmentsIntroStore.markSeen()
        dismiss(animated: true) { [onFinished] in
            onFinished?()
        }
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension IntroducingAttachmentsViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        AttachmentsIntroStore.markSeen()
        onFinished?()
    }
}

// MARK: - AttachmentStackViewDelegate

extension IntroducingAttachmentsViewController: AttachmentStackViewDelegate {
    func attachmentStackView(_ stackView: AttachmentStackView, didTapItem item: any BaseItem) {
        presentReadOnlyDetail(for: item, from: stackView)
    }

    func attachmentStackViewDidTapPlus(_ stackView: AttachmentStackView) {
        // Demo stack does not show plus.
    }

    func attachmentStackView(_ stackView: AttachmentStackView, didChangeExpanded isExpanded: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.tapHintLabel.alpha = isExpanded ? 0 : 1
        }
    }

    private func presentReadOnlyDetail(for item: any BaseItem, from stackView: AttachmentStackView) {
        let sourceFrame = stackView.convert(stackView.bounds, to: nil)

        switch item {
        case let contact as ContactItem:
            let vc = ContactDetailViewController(
                category: contact.category,
                contact: contact,
                sourceFrame: sourceFrame,
                isReadOnly: true
            )
            present(vc, animated: true)

        case let note as NoteItem:
            let vc = NoteDetailViewController(
                category: note.category,
                entry: note,
                sourceFrame: sourceFrame,
                isReadOnly: true
            )
            present(vc, animated: true)

        case let routine as RoutineItem:
            let vc = RoutineDetailViewController(
                category: routine.category,
                routine: routine,
                sourceFrame: sourceFrame,
                isReadOnly: true
            )
            present(vc, animated: true)

        case let place as PlaceItem:
            let vc = PlaceDetailViewController(
                place: place,
                thumbnail: nil,
                isReadOnly: true,
                sourceFrame: sourceFrame
            )
            present(vc, animated: true)

        default:
            break
        }
    }
}
