import UIKit

/// Dedicated sitter referral destination — pattern header, benefits, and shareable code.
final class SitterReferralViewController: NNViewController {

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
        label.text = SitterReferralCopy.title
        label.font = .h1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = SitterReferralCopy.screenSubtitle
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let venmoNoteLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private lazy var codeCopyButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(
            title: "--------",
            image: nil,
            backgroundColor: NNColors.primary.withAlphaComponent(0.15),
            foregroundColor: NNColors.primary
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        button.setContentInsets(UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4))
        button.titleLabel.adjustsFontSizeToFitWidth = true
        button.titleLabel.minimumScaleFactor = 0.7
        button.addTarget(self, action: #selector(codeCopyTapped), for: .touchUpInside)
        return button
    }()

    private lazy var primaryActionButton: NNLoadingButton = {
        let button = NNLoadingButton(
            title: SitterReferralCopy.generateCodeTitle,
            titleColor: .white,
            fillStyle: .fill(NNColors.primary)
        )
        button.addTarget(self, action: #selector(primaryActionTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var bottomButtonStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [primaryActionButton, codeCopyButton])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fill
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let bottomActionBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var codeCopyWidthConstraint: NSLayoutConstraint!

    private var referralCode: String?
    private var isGeneratingCode = false
    private var isSharing = false

    init() {
        self.infoView = NNBulletStack(items: [
            NNBulletItem(
                title: "Walk in ready for anything",
                description: "Families share emergency contacts, routines, and house details in NestNote before you arrive.",
                iconName: "list.bullet.clipboard.fill"
            ),
            NNBulletItem(
                title: "Get paid without the chase",
                description: "NestNote surfaces your rates to families and sends payment reminders so you're not following up.",
                iconName: "banknote.fill"
            ),
            NNBulletItem(
                title: "Share your code",
                description: "Send families your referral code when they download NestNote and sign up.",
                iconName: "square.and.arrow.up"
            ),
            NNBulletItem(
                title: "Get $10 via Venmo",
                description: "We pay you after their first paid subscription (not during a free trial).",
                iconName: "dollarsign.circle.fill"
            ),
        ])
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupNavigationBar()
        restoreExistingCodeIfAvailable()
        updateVenmoNote()
    }

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

        view.addSubview(topImageView)
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        view.addSubview(bottomActionBar)
        bottomActionBar.addSubview(bottomButtonStack)

        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(infoView)
        containerView.addSubview(venmoNoteLabel)

        infoView.translatesAutoresizingMaskIntoConstraints = false

        setupBottomBlurEffect()
        topImageView.pinToTop(of: view)

        codeCopyWidthConstraint = codeCopyButton.widthAnchor.constraint(
            equalTo: bottomButtonStack.widthAnchor,
            multiplier: 0.32
        )

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topImageView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomActionBar.topAnchor, constant: -8),

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

            venmoNoteLabel.topAnchor.constraint(equalTo: infoView.bottomAnchor, constant: 24),
            venmoNoteLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 28),
            venmoNoteLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -28),
            venmoNoteLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),

            bottomActionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bottomActionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bottomActionBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            bottomActionBar.heightAnchor.constraint(equalToConstant: 55),

            bottomButtonStack.topAnchor.constraint(equalTo: bottomActionBar.topAnchor),
            bottomButtonStack.leadingAnchor.constraint(equalTo: bottomActionBar.leadingAnchor),
            bottomButtonStack.trailingAnchor.constraint(equalTo: bottomActionBar.trailingAnchor),
            bottomButtonStack.bottomAnchor.constraint(equalTo: bottomActionBar.bottomAnchor),

            codeCopyWidthConstraint,
        ])

        showPendingCodeState()
    }

    private func setupBottomBlurEffect() {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        blur.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(blur, belowSubview: bottomActionBar)

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blur.topAnchor.constraint(equalTo: bottomActionBar.topAnchor, constant: -16),
        ])
    }

    private func restoreExistingCodeIfAvailable() {
        guard let user = UserService.shared.currentUser else {
            primaryActionButton.isEnabled = false
            return
        }

        let existing = user.sitterReferralCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""

        guard !existing.isEmpty else { return }

        referralCode = existing
        showGeneratedCodeState(code: existing, animated: false)
    }

    private func showPendingCodeState() {
        guard referralCode == nil else { return }

        codeCopyButton.isHidden = true
        codeCopyButton.alpha = 1
        codeCopyButton.transform = .identity
        codeCopyWidthConstraint.isActive = false
        primaryActionButton.stopLoading()
        primaryActionButton.setTitle(SitterReferralCopy.generateCodeTitle)
        primaryActionButton.isEnabled = UserService.shared.currentUser != nil
    }

    private func showGeneratedCodeState(code: String, animated: Bool = true) {
        referralCode = code
        codeCopyButton.setTitle(code)
        codeCopyButton.isUserInteractionEnabled = true
        primaryActionButton.stopLoading()
        primaryActionButton.setTitle(SitterReferralCopy.ctaTitle)
        primaryActionButton.isEnabled = true
        codeCopyWidthConstraint.isActive = true

        guard animated else {
            codeCopyButton.isHidden = false
            return
        }

        codeCopyButton.isHidden = false
        codeCopyButton.alpha = 0
        codeCopyButton.transform = CGAffineTransform(scaleX: 0.85, y: 0.85).translatedBy(x: 12, y: 0)
        view.layoutIfNeeded()

        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.72,
            initialSpringVelocity: 0.6,
            options: [.allowUserInteraction]
        ) {
            self.codeCopyButton.alpha = 1
            self.codeCopyButton.transform = .identity
        }
    }

    private func showGeneratingCodeState() {
        codeCopyButton.isHidden = true
        codeCopyWidthConstraint.isActive = false
        primaryActionButton.startLoading()
    }

    private func updateVenmoNote() {
        let venmo = UserService.shared.currentUser?.personalInfo.venmoUsername?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if venmo.isEmpty {
            venmoNoteLabel.text = SitterReferralCopy.missingVenmoNote
            venmoNoteLabel.isHidden = false
        } else {
            venmoNoteLabel.isHidden = true
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func primaryActionTapped() {
        if referralCode == nil {
            generateReferralCode()
        } else {
            shareInviteTapped()
        }
    }

    private func generateReferralCode() {
        guard !isGeneratingCode else { return }
        guard let user = UserService.shared.currentUser else { return }

        isGeneratingCode = true
        showGeneratingCodeState()

        Task {
            do {
                let code = try await SitterReferralService.shared.getOrCreateCode(for: user)
                await MainActor.run {
                    isGeneratingCode = false
                    showGeneratedCodeState(code: code, animated: true)
                }
            } catch {
                await MainActor.run {
                    isGeneratingCode = false
                    codeCopyButton.isHidden = true
                    codeCopyWidthConstraint.isActive = false
                    primaryActionButton.stopLoading(withSuccess: false)
                    primaryActionButton.setTitle(SitterReferralCopy.generateCodeTitle)
                    primaryActionButton.isEnabled = UserService.shared.currentUser != nil
                    showToast(text: "Couldn't create your code. Try again.")
                }
            }
        }
    }

    @objc private func codeCopyTapped() {
        guard let code = referralCode, !code.isEmpty else { return }

        UIPasteboard.general.string = code
        codeCopyButton.showCopiedFeedback()
        HapticsHelper.lightHaptic()
        triggerCodeCopyExplosion()
    }

    private func triggerCodeCopyExplosion() {
        let center = CGPoint(x: codeCopyButton.bounds.midX, y: codeCopyButton.bounds.midY)
        let explosionPoint: CGPoint
        if let window = view.window {
            explosionPoint = codeCopyButton.convert(center, to: window)
        } else {
            explosionPoint = codeCopyButton.convert(center, to: view)
        }
        ExplosionManager.trigger(.small, at: explosionPoint)
    }

    private func shareInviteTapped() {
        guard !isSharing, let code = referralCode, !code.isEmpty else { return }
        guard let user = UserService.shared.currentUser else { return }

        isSharing = true
        let message = SitterReferralLinkBuilder.inviteMessage(
            sitterName: user.personalInfo.name,
            code: code
        )

        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        activityVC.completionWithItemsHandler = { [weak self] _, completed, _, _ in
            guard let self else { return }
            self.isSharing = false
            if completed {
                HapticsHelper.lightHaptic()
                Tracker.shared.trackSitterReferralInviteCopied(
                    hasVenmo: !(user.personalInfo.venmoUsername ?? "").isEmpty
                )
            }
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = primaryActionButton
            popover.sourceRect = primaryActionButton.bounds
        }

        present(activityVC, animated: true)
    }
}
