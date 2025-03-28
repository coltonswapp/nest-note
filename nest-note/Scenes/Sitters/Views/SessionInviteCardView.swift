//
//  SessionInviteCardView.swift
//  nest-note
//
//  Created by Colton Swapp on 3/5/25.
//
import UIKit

class SessionInviteCardView: UIView {
    
    // Transform properties
    private var currentYaw: CGFloat = 0
    private var currentPitch: CGFloat = 0
    private var maxRotation: CGFloat = 0.66  // Maximum rotation in radians
    private var transformSensitivity: CGFloat = 0.001  // Adjust this to control rotation sensitivity
    
    // Configurable animation properties
    private var yawFrequency: CGFloat = 0.5
    private var pitchFrequency: CGFloat = 0.7
    private var yawAmplitude: CGFloat = 0.15
    private var pitchAmplitude: CGFloat = 0.1
    
    // Add content view to manage hierarchy
    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let nestNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .left
        label.text = "Debug Text"
        return label
    }()
    
    private let divider: UIView = {
        let view = UIView()
        view.backgroundColor = .quaternaryLabel
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let sessionDateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .left
        label.numberOfLines = 0
        return label
    }()
    
    private let backgroundTileView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "bird_tile")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.alpha = 0.6
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let footnoteLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.text = "Session Invite"  // Default text
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let dateInvitedLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupGestureRecognizers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupGestureRecognizers()
    }
    
    private func setupGestureRecognizers() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        case .changed:
            // Convert pan translation to rotation
            let newYaw = (translation.x * transformSensitivity).clamped(to: -maxRotation...maxRotation)
            let newPitch = (translation.y * transformSensitivity).clamped(to: -maxRotation...maxRotation)
            
            updateTransform(yaw: newYaw, pitch: newPitch)
            
        case .ended, .cancelled:
            // Reset transform with animation
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                self.updateTransform(yaw: 0, pitch: 0)
            }
            
        case .began:
            HapticsHelper.superLightHaptic()
        default:
            break
        }
    }
    
    private func updateTransform(yaw: CGFloat, pitch: CGFloat) {
        currentYaw = yaw
        currentPitch = pitch
        
        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / 500.0  // Add perspective
        
        // Apply rotations
        transform = CATransform3DRotate(transform, yaw, 0, 1, 0)   // Yaw (Y-axis rotation)
        transform = CATransform3DRotate(transform, pitch, 1, 0, 0) // Pitch (X-axis rotation)
        
        self.layer.transform = transform
    }
    
    // Add method to update animation properties
    func updateAnimationProperties(yawFreq: CGFloat, pitchFreq: CGFloat, yawAmp: CGFloat, pitchAmp: CGFloat) {
        yawFrequency = yawFreq
        pitchFrequency = pitchFreq
        yawAmplitude = yawAmp
        pitchAmplitude = pitchAmp
    }
    
    func updatePattern(size: CGFloat, spacing: CGFloat, alpha: CGFloat) {
        // Update just the alpha since we're using a static image
        backgroundTileView.alpha = alpha
    }
    
    private func setupView() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 4, height: 8)
        layer.shadowRadius = 8
        
        // First add background tile at the bottom
        addSubview(backgroundTileView)
        
        // Add content view above blur
        addSubview(contentView)
        
        // Add all content elements to the content view instead of directly to self
        [nestNameLabel, divider, sessionDateLabel, footnoteLabel, dateInvitedLabel].forEach { view in
            view.isUserInteractionEnabled = false
            contentView.addSubview(view)
        }
        
        NSLayoutConstraint.activate([
            // Content view constraints
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Background tile constraints
            backgroundTileView.topAnchor.constraint(equalTo: topAnchor),
            backgroundTileView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundTileView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundTileView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Existing constraints, but relative to contentView instead of self
            nestNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            nestNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nestNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            divider.topAnchor.constraint(equalTo: nestNameLabel.bottomAnchor, constant: 20),
            divider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            divider.heightAnchor.constraint(equalToConstant: 1),
            
            sessionDateLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 20),
            sessionDateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            sessionDateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            footnoteLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            footnoteLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            dateInvitedLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            dateInvitedLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
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
        
        // Configure invite date with same format
        let inviteDateStr = dateFormatter.string(from: invite.createdAt)
        let inviteYearStr = yearFormatter.string(from: invite.createdAt)
        dateInvitedLabel.text = "\(inviteDateStr)\(inviteYearStr)"
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
