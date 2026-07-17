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

    private let codeCard: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let codeCaptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Your referral code"
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let codeLabel: UILabel = {
        let label = UILabel()
        label.text = "••••••"
        label.font = UIFont.monospacedSystemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        return label
    }()

    private lazy var copyCodeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Copy Code"
        config.image = UIImage(systemName: "doc.on.doc")
        config.imagePadding = 6
        config.baseForegroundColor = NNColors.primary
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(copyCodeTapped), for: .touchUpInside)
        return button
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

    private lazy var shareInviteButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: SitterReferralCopy.ctaTitle)
        button.addTarget(self, action: #selector(shareInviteTapped), for: .touchUpInside)
        return button
    }()

    private var referralCode: String?
    private var isLoadingCode = false
    private var isSharing = false

    init() {
        self.infoView = NNBulletStack(items: [
            NNBulletItem(
                title: "Share your code",
                description: "Send families your referral code when they download NestNote and sign up.",
                iconName: "square.and.arrow.up"
            ),
            NNBulletItem(
                title: "They subscribe at full price",
                description: "Your code rewards you — it doesn’t discount their plan.",
                iconName: "creditcard"
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
        loadReferralCode()
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

        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(infoView)
        containerView.addSubview(codeCard)
        codeCard.addSubview(codeCaptionLabel)
        codeCard.addSubview(codeLabel)
        codeCard.addSubview(copyCodeButton)
        containerView.addSubview(venmoNoteLabel)

        infoView.translatesAutoresizingMaskIntoConstraints = false

        shareInviteButton.pinToBottom(of: view, addBlurEffect: true)
        topImageView.pinToTop(of: view)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topImageView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: shareInviteButton.topAnchor),

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

            codeCard.topAnchor.constraint(equalTo: infoView.bottomAnchor, constant: 28),
            codeCard.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            codeCard.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            codeCaptionLabel.topAnchor.constraint(equalTo: codeCard.topAnchor, constant: 16),
            codeCaptionLabel.leadingAnchor.constraint(equalTo: codeCard.leadingAnchor, constant: 16),
            codeCaptionLabel.trailingAnchor.constraint(equalTo: codeCard.trailingAnchor, constant: -16),

            codeLabel.topAnchor.constraint(equalTo: codeCaptionLabel.bottomAnchor, constant: 8),
            codeLabel.leadingAnchor.constraint(equalTo: codeCard.leadingAnchor, constant: 16),
            codeLabel.trailingAnchor.constraint(equalTo: codeCard.trailingAnchor, constant: -16),

            copyCodeButton.topAnchor.constraint(equalTo: codeLabel.bottomAnchor, constant: 4),
            copyCodeButton.centerXAnchor.constraint(equalTo: codeCard.centerXAnchor),
            copyCodeButton.bottomAnchor.constraint(equalTo: codeCard.bottomAnchor, constant: -10),

            venmoNoteLabel.topAnchor.constraint(equalTo: codeCard.bottomAnchor, constant: 16),
            venmoNoteLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 28),
            venmoNoteLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -28),
            venmoNoteLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
        ])
    }

    private func loadReferralCode() {
        guard !isLoadingCode else { return }
        guard let user = UserService.shared.currentUser else {
            codeLabel.text = "Sign in required"
            shareInviteButton.isEnabled = false
            copyCodeButton.isEnabled = false
            return
        }

        isLoadingCode = true
        shareInviteButton.isEnabled = false
        copyCodeButton.isEnabled = false
        codeLabel.text = "Generating…"

        Task {
            do {
                let code = try await SitterReferralService.shared.getOrCreateCode(for: user)
                await MainActor.run {
                    referralCode = code
                    codeLabel.text = code
                    shareInviteButton.isEnabled = true
                    copyCodeButton.isEnabled = true
                    isLoadingCode = false
                }
            } catch {
                await MainActor.run {
                    codeLabel.text = "Couldn't load"
                    shareInviteButton.isEnabled = false
                    copyCodeButton.isEnabled = false
                    isLoadingCode = false
                    showToast(text: "Couldn't create your code. Try again.")
                }
            }
        }
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

    @objc private func copyCodeTapped() {
        guard let code = referralCode, !code.isEmpty else { return }
        UIPasteboard.general.string = code
        HapticsHelper.lightHaptic()
        showToast(text: "Code copied!")
    }

    @objc private func shareInviteTapped() {
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
            popover.sourceView = shareInviteButton
            popover.sourceRect = shareInviteButton.bounds
        }

        present(activityVC, animated: true)
    }
}
