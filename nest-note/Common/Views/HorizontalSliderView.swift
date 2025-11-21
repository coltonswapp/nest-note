import UIKit

class HorizontalSliderView: UIVisualEffectView {

    private var offset: CGFloat = 0
    private var opacity: Double = SliderConstants.one
    private var gestureTranslation: CGFloat = 0
    private var hasPlayedEndHaptic = false
    private let isStaticThumb: Bool

    private let knobContainer = UIView()
    private let knobView = UIView()
    private let iconView = UIImageView()

    // Haptic properties
    private var hapticIntensity: Float = 0.8
    private var hapticFrequency: Float = 1.0 // 100% frequency
    private var hapticInterval: Float = 1.0 // 0.01 interval (1% progress)
    private var lastHapticProgress: Float = 0.0
    private var currentProgress: Float = 0.0

    private let textLabel: UILabel = {
        let label = UILabel()
        label.text = "Slide to Enter"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .quaternaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let shimmerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.clear
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var shimmerLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.4).cgColor,
            UIColor.white.withAlphaComponent(0.4).cgColor,
            UIColor.clear.cgColor
        ]
        layer.locations = [0, 0.3, 0.7, 1]

        // 10 degree angle: convert to start/end points
        let angle = 10 * CGFloat.pi / 180
        let startPoint = CGPoint(x: 0.5 - cos(angle) * 0.5, y: 0.5 - sin(angle) * 0.5)
        let endPoint = CGPoint(x: 0.5 + cos(angle) * 0.5, y: 0.5 + sin(angle) * 0.5)

        layer.startPoint = startPoint
        layer.endPoint = endPoint
        return layer
    }()

    var onSlideComplete: (() -> Void)?

    init(effect: UIVisualEffect?, isStaticThumb: Bool = true) {
        self.isStaticThumb = isStaticThumb
        super.init(effect: effect)
        setupSlider()
    }

    convenience init(isStaticThumb: Bool = true) {
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .regular)
            glassEffect.isInteractive = true
            glassEffect.tintColor = .systemGray3.withAlphaComponent(0.4)
            self.init(effect: glassEffect, isStaticThumb: isStaticThumb)
        } else {
            let blurEffect = UIBlurEffect(style: .systemMaterial)
            self.init(effect: blurEffect, isStaticThumb: isStaticThumb)
        }
    }

    required init?(coder: NSCoder) {
        self.isStaticThumb = true
        super.init(coder: coder)
        setupSlider()
    }

    private func setupSlider() {
        setupAppearance()
        setupKnob()
        setupText()
        setupConstraints()
        setupGesture()
        resetPosition()
    }

    private func setupAppearance() {
        layer.cornerRadius = SliderConstants.height / SliderConstants.double
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        if #available(iOS 26.0, *) {
            cornerConfiguration = .corners(radius: .fixed(SliderConstants.height / SliderConstants.double))
        } else {
            backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        }
    }

    private func setupKnob() {
        knobView.backgroundColor = .white.withAlphaComponent(1.0)

        if isStaticThumb {
            knobView.layer.cornerRadius = (SliderConstants.knobSize - SliderConstants.knobSizeOffset) / SliderConstants.double
        } else {
            knobView.layer.cornerRadius = (SliderConstants.knobSize - SliderConstants.knobSizeOffset) / SliderConstants.double
        }

        knobView.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image = UIImage(systemName: "arrow.right", withConfiguration: config)
        iconView.tintColor = .black
        iconView.translatesAutoresizingMaskIntoConstraints = false

        knobContainer.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(knobContainer)
        knobContainer.addSubview(knobView)
        knobView.addSubview(iconView)
    }

    private func setupText() {
        contentView.addSubview(textLabel)
        contentView.addSubview(shimmerView)
        shimmerView.layer.addSublayer(shimmerLayer)

        // Create a mask layer that matches the text shape
        let maskLayer = CALayer()
        shimmerView.layer.mask = maskLayer
    }

    private func setupConstraints() {
        knobLeadingConstraint = knobContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: SliderConstants.height),

            knobContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            knobContainer.widthAnchor.constraint(equalToConstant: SliderConstants.knobSize),
            knobContainer.heightAnchor.constraint(equalToConstant: SliderConstants.knobSize),
            knobLeadingConstraint!,

            knobView.centerXAnchor.constraint(equalTo: knobContainer.centerXAnchor),
            knobView.centerYAnchor.constraint(equalTo: knobContainer.centerYAnchor),
            knobView.widthAnchor.constraint(equalToConstant: SliderConstants.knobSize - SliderConstants.knobSizeOffset),
            knobView.heightAnchor.constraint(equalToConstant: SliderConstants.knobSize - SliderConstants.knobSizeOffset),

            iconView.centerXAnchor.constraint(equalTo: knobView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: knobView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: SliderConstants.knobSize * 0.3),
            iconView.heightAnchor.constraint(equalToConstant: SliderConstants.knobSize * 0.3),

            textLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            textLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 16),
            textLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),

            shimmerView.leadingAnchor.constraint(equalTo: textLabel.leadingAnchor),
            shimmerView.trailingAnchor.constraint(equalTo: textLabel.trailingAnchor),
            shimmerView.topAnchor.constraint(equalTo: textLabel.topAnchor),
            shimmerView.bottomAnchor.constraint(equalTo: textLabel.bottomAnchor)
        ])
    }

    private var knobLeadingConstraint: NSLayoutConstraint!

    private func setupGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        knobContainer.addGestureRecognizer(panGesture)
        knobContainer.isUserInteractionEnabled = true
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard opacity == SliderConstants.one else { return }

        let translation = gesture.translation(in: self)

        switch gesture.state {
        case .began:
            stopShimmerAnimation()
            resetHapticProgress()

        case .changed:
            gestureTranslation = translation.x

            if gestureTranslation <= 0 {
                offset = 0
                currentProgress = 0.0
            } else {
                let startPosition: CGFloat = 0
                let endPosition = frame.width - SliderConstants.knobSize
                let dragRange = endPosition

                let clampedTranslation = min(gestureTranslation, dragRange)
                let progress = clampedTranslation / dragRange
                offset = startPosition + (endPosition - startPosition) * progress

                // Update current progress for haptic system (0-100 scale)
                currentProgress = Float(progress * 100)
                checkForHapticTrigger()

                // Update text opacity based on progress
                textLabel.alpha = 1.0 - progress * 2

                // Update shimmer opacity based on progress
                shimmerView.alpha = 1.0 - progress * 2

                if progress >= 1.0 && !hasPlayedEndHaptic {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    hasPlayedEndHaptic = true
                } else if progress < 1.0 {
                    hasPlayedEndHaptic = false
                }
            }

            updateKnobPosition()

        case .ended, .cancelled:
            resetHapticProgress()
            hasPlayedEndHaptic = false

            let rightPosition = frame.width - SliderConstants.knobSize
            if offset >= rightPosition * 0.98 {
                // Success haptic sequence
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)

                UIView.animate(withDuration: 0.3) {
                    self.opacity = 0
                    self.alpha = CGFloat(self.opacity)
                }

                DispatchQueue.main.async {
                    self.onSlideComplete?()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.resetPosition()
                }
            } else {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                UIView.animate(withDuration: 0.1, animations: {
                    self.offset = 0
                    self.textLabel.alpha = 1.0
                    self.shimmerView.alpha = 1.0
                    self.updateKnobPosition()
                }) { _ in
                    self.startShimmerAnimation()
                }
            }

        default:
            break
        }
    }

    private func updateKnobPosition() {
        guard let constraint = knobLeadingConstraint else { return }
        constraint.constant = offset
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shimmerLayer.frame = shimmerView.bounds

        // Update the mask layer to match the text
        if let maskLayer = shimmerView.layer.mask {
            maskLayer.frame = shimmerView.bounds

            // Create a text layer that matches our label
            let textLayer = CATextLayer()
            textLayer.string = textLabel.text
            textLayer.font = textLabel.font
            textLayer.fontSize = textLabel.font.pointSize
            textLayer.alignmentMode = .center
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.frame = maskLayer.bounds
            textLayer.contentsScale = UIScreen.main.scale

            maskLayer.sublayers?.removeAll()
            maskLayer.addSublayer(textLayer)
        }
    }

    func resetPosition() {
        offset = 0
        resetHapticProgress()
        updateKnobPosition()
        textLabel.alpha = 1.0
        shimmerView.alpha = 1.0

        DispatchQueue.main.asyncAfter(deadline: .now() + SliderConstants.half) {
            UIView.animate(withDuration: 0.3) {
                self.opacity = SliderConstants.one
                self.alpha = CGFloat(self.opacity)
            } completion: { _ in
                self.startShimmerAnimation()
            }
        }
    }

    private func startShimmerAnimation() {
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-0.8, -0.6, -0.4, -0.2]
        animation.toValue = [1.2, 1.4, 1.6, 1.8]
        animation.duration = 1.8
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shimmerLayer.add(animation, forKey: "shimmer")
    }

    private func stopShimmerAnimation() {
        shimmerLayer.removeAnimation(forKey: "shimmer")
    }

    // MARK: - Haptic Methods

    private func checkForHapticTrigger() {
        let progressDifference = currentProgress - lastHapticProgress

        if progressDifference >= hapticInterval {
            // Trigger haptic based on frequency setting (100% = always trigger)
            let shouldTrigger = Float.random(in: 0...1) < hapticFrequency

            if shouldTrigger {
                let impactGenerator = UIImpactFeedbackGenerator(style: .light)
                impactGenerator.impactOccurred(intensity: CGFloat(hapticIntensity))
            }

            lastHapticProgress = currentProgress
        }
    }

    private func resetHapticProgress() {
        lastHapticProgress = 0.0
        currentProgress = 0.0
    }

}

struct SliderConstants {
    static let knobSize: CGFloat = 72.0
    static let knobSizeOffset: CGFloat = 8.0
    static let defaultWidth: CGFloat = 250
    static let height: CGFloat = 72.0
    static let radius: CGFloat = 5
    static let double: CGFloat = 2
    static let one: Double = 1.0
    static let half: Double = 0.5
}
