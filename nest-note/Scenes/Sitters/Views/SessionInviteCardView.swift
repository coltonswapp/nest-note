//
//  SessionInviteCardView.swift
//  nest-note
//
//  Created by Colton Swapp on 3/5/25.
//
import UIKit

class SessionInviteCardView: UIView {
    
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
        label.font = .h2
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.text = "Debug Text"
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
        label.font = .h4
        label.text = "SESSION INVITE"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let sessionDateLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        return label
    }()
    
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
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // Pan/tilt gestures removed – card is static and presented using flip animation
    
    func updatePattern(size: CGFloat, spacing: CGFloat, alpha: CGFloat) {
        // Update alpha for the pattern view
        topPatternView.alpha = alpha
    }
    
    private func setupView() {
        backgroundColor = .clear
        layer.cornerRadius = 12
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 4, height: 8)
        layer.shadowRadius = 8
        
        // Shadow is applied on container; the image view clips to its rounded corners
        
        // Configure top pattern image using NNAssetType.rectanglePattern
        if let image = UIImage(named: NNAssetType.rectanglePattern.rawValue) {
            topPatternView.image = image
            topPatternView.contentMode = .scaleAspectFill
            topPatternView.alpha = NNAssetType.rectanglePattern.defaultAlpha
        }

        // Add content view (clipping container)
        addSubview(contentView)
        
        // Background pattern and perforation inside contentView so they clip
        contentView.addSubview(topPatternView)
        contentView.addSubview(perforationView)
        perforationView.layer.addSublayer(perforationLayer)
        
        // Badge setup
        inviteBadgeView.addSubview(inviteBadgeLabel)
        inviteBadgeView.backgroundColor = NNColors.primaryOpaque
        inviteBadgeView.layer.borderColor = NNColors.primary.cgColor
        inviteBadgeLabel.textColor = NNColors.primary
        
        // Add content elements
        [inviteBadgeView, appIconContainer, nestNameLabel, sessionDateLabel].forEach { view in
            view.isUserInteractionEnabled = false
            contentView.addSubview(view)
        }
        // Place the icon image inside the shadow container
        appIconContainer.addSubview(appIconView)
        
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
            topPatternView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.4),

            // Perforation directly under the pattern
            perforationView.topAnchor.constraint(equalTo: topPatternView.bottomAnchor),
            perforationView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            perforationView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            perforationView.heightAnchor.constraint(equalToConstant: 1),

            // Badge over the perforation (centered)
            inviteBadgeView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            inviteBadgeView.centerYAnchor.constraint(equalTo: perforationView.centerYAnchor),

            // Badge label padding
            inviteBadgeLabel.topAnchor.constraint(equalTo: inviteBadgeView.topAnchor, constant: 6),
            inviteBadgeLabel.leadingAnchor.constraint(equalTo: inviteBadgeView.leadingAnchor, constant: 14),
            inviteBadgeLabel.trailingAnchor.constraint(equalTo: inviteBadgeView.trailingAnchor, constant: -14),
            inviteBadgeLabel.bottomAnchor.constraint(equalTo: inviteBadgeView.bottomAnchor, constant: -6),

            // App icon container below perforation
            appIconContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            appIconContainer.topAnchor.constraint(equalTo: perforationView.bottomAnchor, constant: 48),
            appIconContainer.widthAnchor.constraint(equalToConstant: 100),
            appIconContainer.heightAnchor.constraint(equalTo: appIconContainer.widthAnchor),

            // Icon fills its container
            appIconView.topAnchor.constraint(equalTo: appIconContainer.topAnchor),
            appIconView.leadingAnchor.constraint(equalTo: appIconContainer.leadingAnchor),
            appIconView.trailingAnchor.constraint(equalTo: appIconContainer.trailingAnchor),
            appIconView.bottomAnchor.constraint(equalTo: appIconContainer.bottomAnchor),

            // Title and dates centered under icon
            nestNameLabel.topAnchor.constraint(equalTo: appIconContainer.bottomAnchor, constant: 24),
            nestNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nestNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            sessionDateLabel.topAnchor.constraint(equalTo: nestNameLabel.bottomAnchor, constant: 8),
            sessionDateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            sessionDateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }
    
    func configure(with session: SessionItem, invite: Invite) {
        // Configure nest name with debug print
        nestNameLabel.text = invite.nestName
        
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
