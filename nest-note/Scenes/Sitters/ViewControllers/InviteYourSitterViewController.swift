//
//  InviteYourSitterViewController.swift
//  nest-note
//

import UIKit

final class InviteYourSitterViewController: NNViewController {

    private enum InviteCardMetrics {
        static let width: CGFloat = 240
        static let height: CGFloat = 270
        static let tiltAngle: CGFloat = -6 * .pi / 180
    }

    private let inviteCode: String
    private let session: SessionItem

    private let topImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .rectanglePatternSmall, with: NNColors.primary)
        view.alpha = 0.4
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Now, invite your sitter"
        label.font = .h1
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let inviteCodeCaptionLabel: UILabel = {
        let label = UILabel()
        label.text = "INVITE CODE"
        label.font = .captionBoldS
        label.textColor = .tertiaryLabel
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let codeContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let codeLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemRounded(ofSize: 28)
        label.textAlignment = .center
        label.textColor = .label
        label.isUserInteractionEnabled = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var qrButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: "qrcode", withConfiguration: config), for: .normal)
        button.tintColor = .label
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(qrButtonTapped), for: .touchUpInside)
        return button
    }()

    private let footerLabel: UILabel = {
        let label = UILabel()
        label.text = "Share this code with your sitter"
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let inviteCardView: SessionInviteCardView = {
        let view = SessionInviteCardView(displayStyle: .reveal)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0
        return view
    }()

    private lazy var textButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(
            title: "Text",
            image: UIImage(systemName: "message"),
            backgroundColor: NNColors.primary.withAlphaComponent(0.15),
            foregroundColor: NNColors.primary
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var shareButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(
            title: "Share",
            image: UIImage(systemName: "square.and.arrow.up"),
            backgroundColor: NNColors.primary.withAlphaComponent(0.15),
            foregroundColor: NNColors.primary
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var copyButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(
            title: "Copy",
            image: UIImage(systemName: "doc.on.doc"),
            backgroundColor: NNColors.primary.withAlphaComponent(0.15),
            foregroundColor: NNColors.primary
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var actionButtonStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [textButton, shareButton, copyButton])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var glowView: UIView = {
        makeGlowView(radius: 28, opacity: 0.7)
    }()

    private lazy var glowView2: UIView = {
        makeGlowView(radius: 52, opacity: 0.5)
    }()

    private lazy var glowView3: UIView = {
        makeGlowView(radius: 76, opacity: 0.3)
    }()

    private let cardRestGuide = UILayoutGuide()
    private var inviteCardCenterYConstraint: NSLayoutConstraint?
    private var hasAnimatedInviteCard = false

    init(inviteCode: String, session: SessionItem) {
        self.inviteCode = inviteCode
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureContent()
        setupActions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateInviteCardIfNeeded()
    }

    override func setupNavigationBarButtons() {
        navigationItem.hidesBackButton = true
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        navigationItem.rightBarButtonItem = closeButton
    }

    override func addSubviews() {
        view.addSubview(topImageView)
        view.addSubview(titleLabel)
        view.addSubview(inviteCodeCaptionLabel)
        view.addSubview(codeContainerView)
        codeContainerView.addSubview(codeLabel)
        codeContainerView.addSubview(qrButton)
        view.addSubview(footerLabel)
        view.addSubview(glowView3)
        view.addSubview(glowView2)
        view.addSubview(glowView)
        view.addSubview(inviteCardView)
        view.addSubview(actionButtonStack)
    }

    override func constrainSubviews() {
        view.addLayoutGuide(cardRestGuide)

        inviteCardCenterYConstraint = inviteCardView.centerYAnchor.constraint(
            equalTo: view.bottomAnchor,
            constant: 200
        )

        NSLayoutConstraint.activate([
            topImageView.topAnchor.constraint(equalTo: view.topAnchor),
            topImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topImageView.heightAnchor.constraint(
                equalTo: view.widthAnchor,
                multiplier: NNAssetType.rectanglePatternSmall.heightMultiplier
            ),

            titleLabel.topAnchor.constraint(equalTo: topImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            inviteCodeCaptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            inviteCodeCaptionLabel.leadingAnchor.constraint(equalTo: codeContainerView.leadingAnchor),
            inviteCodeCaptionLabel.trailingAnchor.constraint(lessThanOrEqualTo: codeContainerView.trailingAnchor),

            codeContainerView.topAnchor.constraint(equalTo: inviteCodeCaptionLabel.bottomAnchor, constant: 8),
            codeContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            codeContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            codeContainerView.heightAnchor.constraint(equalToConstant: 64),

            codeLabel.centerXAnchor.constraint(equalTo: codeContainerView.centerXAnchor),
            codeLabel.centerYAnchor.constraint(equalTo: codeContainerView.centerYAnchor),
            codeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: codeContainerView.leadingAnchor, constant: 48),
            codeLabel.trailingAnchor.constraint(lessThanOrEqualTo: qrButton.leadingAnchor, constant: -8),

            qrButton.trailingAnchor.constraint(equalTo: codeContainerView.trailingAnchor, constant: -16),
            qrButton.centerYAnchor.constraint(equalTo: codeContainerView.centerYAnchor),
            qrButton.widthAnchor.constraint(equalToConstant: 36),
            qrButton.heightAnchor.constraint(equalToConstant: 36),

            footerLabel.topAnchor.constraint(equalTo: codeContainerView.bottomAnchor, constant: 12),
            footerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            footerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            actionButtonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            actionButtonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            actionButtonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            actionButtonStack.heightAnchor.constraint(equalToConstant: 44),

            // Rest zone between the code block and the bottom buttons
            cardRestGuide.topAnchor.constraint(equalTo: footerLabel.bottomAnchor),
            cardRestGuide.bottomAnchor.constraint(equalTo: actionButtonStack.topAnchor),
            cardRestGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardRestGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            inviteCardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            inviteCardView.widthAnchor.constraint(equalToConstant: InviteCardMetrics.width),
            inviteCardView.heightAnchor.constraint(equalToConstant: InviteCardMetrics.height),
            inviteCardCenterYConstraint!,

            glowView.centerXAnchor.constraint(equalTo: inviteCardView.centerXAnchor),
            glowView.centerYAnchor.constraint(equalTo: inviteCardView.centerYAnchor),
            glowView.widthAnchor.constraint(equalTo: inviteCardView.widthAnchor, multiplier: 0.88),
            glowView.heightAnchor.constraint(equalTo: inviteCardView.heightAnchor, multiplier: 0.48),

            glowView2.centerXAnchor.constraint(equalTo: inviteCardView.centerXAnchor),
            glowView2.centerYAnchor.constraint(equalTo: inviteCardView.centerYAnchor),
            glowView2.widthAnchor.constraint(equalTo: inviteCardView.widthAnchor, multiplier: 0.94),
            glowView2.heightAnchor.constraint(equalTo: inviteCardView.heightAnchor, multiplier: 0.54),

            glowView3.centerXAnchor.constraint(equalTo: inviteCardView.centerXAnchor),
            glowView3.centerYAnchor.constraint(equalTo: inviteCardView.centerYAnchor),
            glowView3.widthAnchor.constraint(equalTo: inviteCardView.widthAnchor, multiplier: 1.0),
            glowView3.heightAnchor.constraint(equalTo: inviteCardView.heightAnchor, multiplier: 0.6),
        ])
    }

    private func configureContent() {
        codeLabel.text = formattedInviteCode()

        let nest = NestService.shared.currentNest
        let invite = Invite(
            id: "invite-\(rawInviteCode())",
            nestID: nest?.id ?? session.nestID,
            nestName: nest?.name ?? "Your Nest",
            sessionID: session.id,
            sitterEmail: nil,
            status: .pending,
            createdBy: UserService.shared.currentUser?.id ?? ""
        )
        inviteCardView.configure(with: session, invite: invite)
        inviteCardView.transform = CGAffineTransform(rotationAngle: InviteCardMetrics.tiltAngle)
    }

    private func setupActions() {
        let codeTap = UITapGestureRecognizer(target: self, action: #selector(copyButtonTapped))
        codeLabel.addGestureRecognizer(codeTap)

        textButton.addTarget(self, action: #selector(textButtonTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
    }

    private func makeGlowView(radius: CGFloat, opacity: Float) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.alpha = 0
        view.layer.shadowColor = NNColors.primary.cgColor
        view.layer.shadowOffset = .zero
        view.layer.shadowRadius = radius
        view.layer.shadowOpacity = opacity
        view.layer.masksToBounds = false
        return view
    }

    private func configureGlowShadowPaths() {
        let cardWidth = InviteCardMetrics.width
        let cardHeight = InviteCardMetrics.height
        let glowLayers: [(UIView, CGFloat, CGFloat)] = [
            (glowView, 0.88, 0.48),
            (glowView2, 0.94, 0.54),
            (glowView3, 1.0, 0.6),
        ]

        for (glowLayer, widthMultiplier, heightMultiplier) in glowLayers {
            let width = cardWidth * widthMultiplier
            let height = cardHeight * heightMultiplier
            glowLayer.layer.shadowPath = UIBezierPath(
                ovalIn: CGRect(x: 0, y: 0, width: width, height: height)
            ).cgPath
        }
    }

    private func animateInviteCardIfNeeded() {
        guard !hasAnimatedInviteCard else { return }
        hasAnimatedInviteCard = true

        configureGlowShadowPaths()

        inviteCardView.alpha = 1
        glowView.alpha = 1
        glowView2.alpha = 1
        glowView3.alpha = 1

        inviteCardCenterYConstraint?.isActive = false
        inviteCardCenterYConstraint = inviteCardView.centerYAnchor.constraint(
            equalTo: cardRestGuide.centerYAnchor
        )
        inviteCardCenterYConstraint?.isActive = true

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5
        ) {
            self.view.layoutIfNeeded()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            guard let self else { return }
            let explosionY = self.inviteCardView.frame.maxY
            ExplosionManager.trigger(.atomic, at: CGPoint(x: view.center.x, y: explosionY))
            HapticsHelper.lightHaptic()
        }
    }

    private func rawInviteCode() -> String {
        let digits = inviteCode.filter(\.isNumber)
        guard digits.count >= 6 else { return inviteCode }
        return String(digits.prefix(6))
    }

    private func formattedInviteCode() -> String {
        let digits = rawInviteCode()
        guard digits.count >= 6 else { return inviteCode }
        return String(digits.prefix(3)) + "-" + String(digits.suffix(3))
    }

    private func inviteShareMessage() -> String {
        let code = rawInviteCode()
        let url = "nestnote://invite?code=\(code)"
        return "You've been invited to a NestNote session!\n\nUse this link to join: \(url)"
    }

    private func showCodeCopyFeedback() {
        HapticsHelper.lightHaptic()

        let copiedLabel = UILabel()
        copiedLabel.text = "Copied!"
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        copiedLabel.textAlignment = .center
        copiedLabel.font = .captionBoldM
        copiedLabel.layer.cornerRadius = 10
        copiedLabel.clipsToBounds = true
        copiedLabel.alpha = 0
        copiedLabel.translatesAutoresizingMaskIntoConstraints = false

        codeContainerView.addSubview(copiedLabel)
        NSLayoutConstraint.activate([
            copiedLabel.centerXAnchor.constraint(equalTo: codeContainerView.centerXAnchor),
            copiedLabel.centerYAnchor.constraint(equalTo: codeContainerView.centerYAnchor),
            copiedLabel.widthAnchor.constraint(equalToConstant: 100),
            copiedLabel.heightAnchor.constraint(equalToConstant: 40),
        ])

        UIView.animate(withDuration: 0.2) {
            copiedLabel.alpha = 1
        }

        UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
            copiedLabel.alpha = 0
        }) { _ in
            copiedLabel.removeFromSuperview()
        }
    }

    private func copyInviteCode() {
        UIPasteboard.general.string = formattedInviteCode()
        showCodeCopyFeedback()
    }

    @objc private func qrButtonTapped() {
        let qrViewController = QRCodeViewController(inviteCode: inviteCode)
        let navController = UINavigationController(rootViewController: qrViewController)
        navController.sheetPresentationController?.detents = [.medium()]
        present(navController, animated: true)
    }

    @objc private func textButtonTapped() {
        let message = inviteShareMessage()
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.insert(charactersIn: ":/")

        if let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: allowedCharacters),
           let smsURL = URL(string: "sms:?body=\(encodedMessage)") {
            UIApplication.shared.open(smsURL)
        }

        HapticsHelper.lightHaptic()
    }

    @objc private func shareButtonTapped() {
        let activityVC = UIActivityViewController(
            activityItems: [inviteShareMessage()],
            applicationActivities: nil
        )

        HapticsHelper.lightHaptic()

        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = shareButton
            popoverController.sourceRect = shareButton.bounds
        }

        present(activityVC, animated: true)
    }

    @objc private func copyButtonTapped() {
        copyInviteCode()
    }
}

#if DEBUG
extension InviteYourSitterViewController {
    static func makeDebugInstance() -> InviteYourSitterViewController {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2025, month: 1, day: 12)) ?? Date()
        let end = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15)) ?? Date()
        let nest = NestService.shared.currentNest
        let session = SessionItem(
            id: "debug-invite-reveal",
            title: "Weekend Sit",
            startDate: start,
            endDate: end,
            isMultiDay: true,
            nestID: nest?.id ?? "debug-nest"
        )
        return InviteYourSitterViewController(inviteCode: "169421", session: session)
    }
}
#endif
