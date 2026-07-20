//
//  SessionInviteCardView.swift
//  nest-note
//
//  Created by Colton Swapp on 3/5/25.
//
import UIKit

protocol SessionInviteCardViewDelegate: AnyObject {
    func sessionInviteCardViewDidTapInviteCode(_ card: SessionInviteCardView)
    func sessionInviteCardViewDidTapQRCode(_ card: SessionInviteCardView)
}

class SessionInviteCardView: UIView {

    enum DisplayStyle {
        case standard
        case compact
        /// Standard ticket chrome with slightly smaller body content (keeps pattern size).
        case reveal
        case codeReveal
    }

    weak var delegate: SessionInviteCardViewDelegate?

    private let displayStyle: DisplayStyle
    // Add content view to manage hierarchy
    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.layer.cornerRadius = 12
        return view
    }()

    // Top pattern image (uses NNAssetType.rectanglePattern)
    private let topPatternView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        return imageView
    }()

    // Perforation dashed separator
    private let perforationView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let perforationLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.lineWidth = 2
        layer.lineDashPattern = [6, 6]
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.systemGray5.cgColor
        return layer
    }()
    
    private let nestNameLabel: UILabel = {
        let label = UILabel()
        label.font = .h1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.text = "Debug Nest"
        return label
    }()
    
    // Badge styled like NNCategoryFilterView's enabled chip
    private let inviteBadgeView: UIView = {
        let view = UIView()
        view.layer.borderWidth = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let inviteBadgeLabel: UILabel = {
        let label = UILabel()
        label.font = .h3
        label.text = "SESSION INVITE"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let sessionDateLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyXL
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        return label
    }()

    private let inviteCodeLabel: UILabel = {
        let label = UILabel()
        label.font = .h1
        label.textAlignment = .center
        label.textColor = .label
        label.isUserInteractionEnabled = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let inviteCodeUnderline: UIView = {
        let view = UIView()
        view.backgroundColor = .label
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var qrButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(UIImage(systemName: "qrcode", withConfiguration: config), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .secondarySystemGroupedBackground
        button.layer.cornerRadius = 18
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.15
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(qrButtonTapped), for: .touchUpInside)
        return button
    }()

    private var sessionDateBottomConstraint: NSLayoutConstraint?
    
    // App icon with shadow: use a container for shadow, inner image for rounded mask
    private let appIconContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        // Shadow on container (not clipped)
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.2
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.masksToBounds = false
        return view
    }()
    
    private let appIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "icon_pattern-preview")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        return imageView
    }()
    
    override init(frame: CGRect) {
        self.displayStyle = .standard
        super.init(frame: frame)
        setupView()
    }

    init(displayStyle: DisplayStyle, frame: CGRect = .zero) {
        self.displayStyle = displayStyle
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        self.displayStyle = .standard
        super.init(coder: coder)
        setupView()
    }
    
    // Pan/tilt gestures removed – card is static and presented using flip animation
    
    func updatePattern(size: CGFloat, spacing: CGFloat, alpha: CGFloat) {
        // Update alpha for the pattern view
        topPatternView.alpha = alpha
    }
    
    private func setupView() {
        applyTypography()

        backgroundColor = .clear
        layer.cornerRadius = 12
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 4, height: 8)
        layer.shadowRadius = 8
        
        // Shadow is applied on container; the image view clips to its rounded corners
        
        // Configure top pattern image using NNAssetType.rectanglePattern
        applyBannerTint(NNColors.primary)

        // Add content view (clipping container)
        addSubview(contentView)
        
        // Background pattern and perforation inside contentView so they clip
        contentView.addSubview(topPatternView)
        contentView.addSubview(perforationView)
        perforationView.layer.addSublayer(perforationLayer)
        
        // Badge setup
        inviteBadgeView.addSubview(inviteBadgeLabel)
        
        // Add content elements
        [inviteBadgeView, appIconContainer, nestNameLabel, sessionDateLabel].forEach { view in
            view.isUserInteractionEnabled = false
            contentView.addSubview(view)
        }
        // Place the icon image inside the shadow container
        appIconContainer.addSubview(appIconView)

        contentView.addSubview(inviteCodeLabel)
        contentView.addSubview(inviteCodeUnderline)
        addSubview(qrButton)

        let codeTap = UITapGestureRecognizer(target: self, action: #selector(inviteCodeTapped))
        inviteCodeLabel.addGestureRecognizer(codeTap)

        let metrics = layoutMetrics(for: displayStyle)
        let isCodeReveal = displayStyle == .codeReveal

        appIconContainer.isHidden = isCodeReveal
        nestNameLabel.isHidden = isCodeReveal
        sessionDateLabel.isHidden = isCodeReveal
        inviteCodeLabel.isHidden = !isCodeReveal
        inviteCodeUnderline.isHidden = !isCodeReveal
        qrButton.isHidden = !isCodeReveal
        
        NSLayoutConstraint.activate([
            // Content view constraints
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Top pattern view (only top section)
            topPatternView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -12),
            topPatternView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topPatternView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            topPatternView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: metrics.patternHeightMultiplier),

            // Perforation directly under the pattern
            perforationView.topAnchor.constraint(equalTo: topPatternView.bottomAnchor),
            perforationView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            perforationView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            perforationView.heightAnchor.constraint(equalToConstant: 1),

            // Badge over the perforation (centered)
            inviteBadgeView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            inviteBadgeView.centerYAnchor.constraint(equalTo: perforationView.centerYAnchor),

            // Badge label padding
            inviteBadgeLabel.topAnchor.constraint(equalTo: inviteBadgeView.topAnchor, constant: metrics.badgeVerticalPadding),
            inviteBadgeLabel.leadingAnchor.constraint(equalTo: inviteBadgeView.leadingAnchor, constant: metrics.badgeHorizontalPadding),
            inviteBadgeLabel.trailingAnchor.constraint(equalTo: inviteBadgeView.trailingAnchor, constant: -metrics.badgeHorizontalPadding),
            inviteBadgeLabel.bottomAnchor.constraint(equalTo: inviteBadgeView.bottomAnchor, constant: -metrics.badgeVerticalPadding),
        ])

        if isCodeReveal {
            NSLayoutConstraint.activate([
                inviteCodeLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                inviteCodeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 24),
                inviteCodeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: metrics.horizontalPadding),
                inviteCodeLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -metrics.horizontalPadding),

                inviteCodeUnderline.topAnchor.constraint(equalTo: inviteCodeLabel.bottomAnchor, constant: 4),
                inviteCodeUnderline.leadingAnchor.constraint(equalTo: inviteCodeLabel.leadingAnchor),
                inviteCodeUnderline.trailingAnchor.constraint(equalTo: inviteCodeLabel.trailingAnchor),
                inviteCodeUnderline.heightAnchor.constraint(equalToConstant: 2),

                qrButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                qrButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
                qrButton.widthAnchor.constraint(equalToConstant: 36),
                qrButton.heightAnchor.constraint(equalToConstant: 36),
            ])
        } else {
            NSLayoutConstraint.activate([
                // App icon container below perforation
                appIconContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                appIconContainer.topAnchor.constraint(equalTo: perforationView.bottomAnchor, constant: metrics.iconTopSpacing),
                appIconContainer.widthAnchor.constraint(equalToConstant: metrics.iconSize),
                appIconContainer.heightAnchor.constraint(equalTo: appIconContainer.widthAnchor),

                // Icon fills its container
                appIconView.topAnchor.constraint(equalTo: appIconContainer.topAnchor),
                appIconView.leadingAnchor.constraint(equalTo: appIconContainer.leadingAnchor),
                appIconView.trailingAnchor.constraint(equalTo: appIconContainer.trailingAnchor),
                appIconView.bottomAnchor.constraint(equalTo: appIconContainer.bottomAnchor),

                // Title and dates centered under icon
                nestNameLabel.topAnchor.constraint(equalTo: appIconContainer.bottomAnchor, constant: metrics.titleTopSpacing),
                nestNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: metrics.horizontalPadding),
                nestNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -metrics.horizontalPadding),

                sessionDateLabel.topAnchor.constraint(equalTo: nestNameLabel.bottomAnchor, constant: metrics.dateTopSpacing),
                sessionDateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: metrics.horizontalPadding),
                sessionDateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -metrics.horizontalPadding)
            ])

            if let bottomPadding = metrics.bottomPadding {
                sessionDateBottomConstraint = sessionDateLabel.bottomAnchor.constraint(
                    equalTo: contentView.bottomAnchor,
                    constant: -bottomPadding
                )
                sessionDateBottomConstraint?.isActive = true
            }
        }
    }

    private func applyTypography() {
        switch displayStyle {
        case .standard:
            nestNameLabel.font = .h1
            inviteBadgeLabel.font = .h3
            sessionDateLabel.font = .bodyXL
            appIconView.layer.cornerRadius = 16
        case .compact:
            // Midway between standard and the previous compact sizes
            nestNameLabel.font = .h2
            inviteBadgeLabel.font = .h4
            sessionDateLabel.font = .bodyM
            appIconView.layer.cornerRadius = 14
        case .reveal:
            nestNameLabel.font = .h2
            inviteBadgeLabel.font = .h4
            sessionDateLabel.font = .bodyM
            appIconView.layer.cornerRadius = 12
        case .codeReveal:
            inviteBadgeLabel.font = .h3
            inviteCodeLabel.font = .boldSystemRounded(ofSize: 32)
        }
    }

    private struct LayoutMetrics {
        let badgeVerticalPadding: CGFloat
        let badgeHorizontalPadding: CGFloat
        let iconTopSpacing: CGFloat
        let iconSize: CGFloat
        let titleTopSpacing: CGFloat
        let dateTopSpacing: CGFloat
        let horizontalPadding: CGFloat
        let bottomPadding: CGFloat?
        let patternHeightMultiplier: CGFloat
    }

    private func layoutMetrics(for style: DisplayStyle) -> LayoutMetrics {
        switch style {
        case .standard:
            return LayoutMetrics(
                badgeVerticalPadding: 6,
                badgeHorizontalPadding: 14,
                iconTopSpacing: 48,
                iconSize: 75,
                titleTopSpacing: 24,
                dateTopSpacing: 8,
                horizontalPadding: 20,
                bottomPadding: nil,
                patternHeightMultiplier: 0.4
            )
        case .compact:
            return LayoutMetrics(
                badgeVerticalPadding: 5,
                badgeHorizontalPadding: 12,
                iconTopSpacing: 32,
                iconSize: 63,
                titleTopSpacing: 14,
                dateTopSpacing: 6,
                horizontalPadding: 20,
                bottomPadding: 20,
                patternHeightMultiplier: 0.36
            )
        case .reveal:
            return LayoutMetrics(
                badgeVerticalPadding: 4,
                badgeHorizontalPadding: 10,
                iconTopSpacing: 36,
                iconSize: 56,
                titleTopSpacing: 16,
                dateTopSpacing: 6,
                horizontalPadding: 18,
                bottomPadding: 24,
                patternHeightMultiplier: 0.4
            )
        case .codeReveal:
            return LayoutMetrics(
                badgeVerticalPadding: 6,
                badgeHorizontalPadding: 14,
                iconTopSpacing: 0,
                iconSize: 0,
                titleTopSpacing: 0,
                dateTopSpacing: 0,
                horizontalPadding: 20,
                bottomPadding: nil,
                patternHeightMultiplier: 0.4
            )
        }
    }
    
    func applyBannerTint(_ color: UIColor) {
        if let image = UIImage(named: NNAssetType.rectanglePattern.rawValue)?.withRenderingMode(.alwaysTemplate) {
            topPatternView.image = image
            topPatternView.contentMode = .scaleAspectFill
            topPatternView.tintColor = color
            topPatternView.alpha = NNAssetType.rectanglePattern.defaultAlpha
        }

        inviteBadgeView.backgroundColor = NNColors.primaryOpaque
        inviteBadgeView.layer.borderColor = NNColors.primary.cgColor
        inviteBadgeLabel.textColor = NNColors.primary
    }

    func configure(withInviteCode code: String) {
        applyBannerTint(NNColors.primary)
        inviteBadgeLabel.text = "SESSION INVITE"

        let digits = code.filter(\.isNumber)
        guard digits.count >= 6 else {
            inviteCodeLabel.text = code
            return
        }
        let normalized = String(digits.prefix(6))
        inviteCodeLabel.text = String(normalized.prefix(3)) + "-" + String(normalized.suffix(3))
    }
    
    func configure(with session: SessionItem, invite: Invite, bannerTintColor: UIColor? = nil) {
        applyBannerTint(bannerTintColor ?? NNColors.primary)

        // Configure nest name - if owner is viewing a sitter-initiated request with "Unknown Nest",
        // show the current nest's name instead (since the owner will be accepting it into their nest)
        if ModeManager.shared.isNestOwnerMode,
           invite.type == .sitterInitiated,
           invite.nestName == "Unknown Nest",
           let currentNestName = NestService.shared.currentNest?.name,
           !currentNestName.isEmpty {
            nestNameLabel.text = currentNestName
        } else {
            nestNameLabel.text = invite.nestName
        }
        
        // Set badge text based on invite type
        if invite.type == .sitterInitiated {
            inviteBadgeLabel.text = "SESSION REQUEST"
        } else {
            inviteBadgeLabel.text = "SESSION INVITE"
        }
        
        // Force layout update
        setNeedsLayout()
        layoutIfNeeded()
        
        // Configure session date with cleaner format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = ", yyyy"
        
        let startDateStr = dateFormatter.string(from: session.startDate)
        let endDateStr = dateFormatter.string(from: session.endDate)
        let yearStr = yearFormatter.string(from: session.endDate)
        
        // Only show year once at the end
        if session.isMultiDay {
            sessionDateLabel.text = "\(startDateStr) - \(endDateStr)\(yearStr)"
        } else {
            // For single day, also show time
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let startTimeStr = timeFormatter.string(from: session.startDate)
            let endTimeStr = timeFormatter.string(from: session.endDate)
            
            sessionDateLabel.text = """
                \(startDateStr)\(yearStr)
                \(startTimeStr) - \(endTimeStr)
                """
        }
    }

    @objc private func inviteCodeTapped() {
        delegate?.sessionInviteCardViewDidTapInviteCode(self)
    }

    @objc private func qrButtonTapped() {
        delegate?.sessionInviteCardViewDidTapQRCode(self)
    }

    func showCopyFeedback(text: String = "Copied!", duration: TimeInterval = 1.0) {
        HapticsHelper.lightHaptic()

        let copiedLabel = UILabel()
        copiedLabel.text = text
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        copiedLabel.textAlignment = .center
        copiedLabel.font = .captionBoldM
        copiedLabel.layer.cornerRadius = 10
        copiedLabel.clipsToBounds = true
        copiedLabel.alpha = 0
        copiedLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(copiedLabel)
        NSLayoutConstraint.activate([
            copiedLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            copiedLabel.centerYAnchor.constraint(equalTo: inviteCodeLabel.centerYAnchor),
            copiedLabel.widthAnchor.constraint(equalToConstant: 100),
            copiedLabel.heightAnchor.constraint(equalToConstant: 40),
        ])

        UIView.animate(withDuration: 0.2) {
            copiedLabel.alpha = 1
        }

        UIView.animate(withDuration: 0.5, delay: duration, options: [], animations: {
            copiedLabel.alpha = 0
        }) { _ in
            copiedLabel.removeFromSuperview()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Update dashed line path
        perforationLayer.frame = perforationView.bounds
        let path = UIBezierPath()
        let midY: CGFloat = perforationView.bounds.height / 2
        path.move(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: perforationView.bounds.width, y: midY))
        perforationLayer.path = path.cgPath
        // Update colors on trait changes dynamically
        perforationLayer.strokeColor = UIColor.systemGray3.withAlphaComponent(0.3).cgColor
        
        inviteBadgeView.layer.cornerRadius = inviteBadgeView.frame.size.height / 2
    }
}

// Helper extension for duration formatting
private extension SessionItem {
    var formattedDuration: String {
        let duration = endDate.timeIntervalSince(startDate)
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
}

// Add extension for clamping values
private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
