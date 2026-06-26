import UIKit

final class NestReadinessRingView: UIView {
    var animatesOnSet: Bool = true

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 44, weight: .bold).rounded()
        label.textAlignment = .center
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var targetProgress: CGFloat = 0
    private var displayScore: Int = 0
    private var shouldCelebrateCompletion = false
    private var scoreDisplayLink: CADisplayLink?
    private var scoreDisplayLinkTarget: ScoreDisplayLinkTarget?
    var animationConfig = NestReadinessRingAnimationConfig.production

    private var lastHapticProgress: Float = 0
    private var hapticIntensity: Float = 0.8
    private var hapticFrequency: Float = 1.0
    private var hapticInterval: Float = 2.0
    private let lightHapticGenerator = UIImpactFeedbackGenerator(style: .light)

    deinit {
        stopScoreDisplayLink()
    }

    private final class ScoreDisplayLinkTarget {
        weak var ringView: NestReadinessRingView?

        @objc func update() {
            ringView?.updateScoreLabelFromRingProgress()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupLayers()
        addSubview(scoreLabel)
        NSLayoutConstraint.activate([
            scoreLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            scoreLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateRingPaths()
    }

    func configure(result: NestReadinessResult, animated: Bool, celebrateCompletion: Bool = false) {
        displayScore = result.totalScore
        targetProgress = min(1, max(0, CGFloat(result.totalScore) / 100))

        guard animated, animatesOnSet else {
            stopScoreDisplayLink()
            progressLayer.removeAnimation(forKey: "progress")
            progressLayer.strokeEnd = targetProgress
            scoreLabel.text = "\(result.totalScore)"
            return
        }

        scoreLabel.text = "0"
        animateProgress(to: targetProgress, celebrateCompletion: celebrateCompletion)
    }

    func prepareForArrivalAnimation() {
        stopScoreDisplayLink()
        resetHapticProgress()
        progressLayer.removeAnimation(forKey: "progress")
        progressLayer.strokeEnd = 0
        scoreLabel.text = "0"
    }

    func setScore(_ score: Int) {
        displayScore = score
        targetProgress = min(1, max(0, CGFloat(score) / 100))
    }

    private func setupLayers() {
        [trackLayer, progressLayer].forEach { layer in
            layer.fillColor = UIColor.clear.cgColor
            layer.lineCap = .round
            layer.lineWidth = 12
            self.layer.addSublayer(layer)
        }

        trackLayer.strokeColor = NestReadinessColors.progressTrack.cgColor
        progressLayer.strokeColor = NNColors.primary.cgColor
        progressLayer.strokeEnd = 0
    }

    private struct RingGeometry {
        let center: CGPoint
        let radius: CGFloat
    }

    private func ringGeometry() -> RingGeometry? {
        let lineWidth = trackLayer.lineWidth
        let inset = lineWidth / 2 + 12
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - inset
        guard radius > 0 else { return nil }
        return RingGeometry(center: center, radius: radius)
    }

    private func progressTipPoint(for progress: CGFloat) -> CGPoint {
        guard let geometry = ringGeometry() else { return center }
        let startAngle = -CGFloat.pi / 2
        let angle = startAngle + progress * 2 * CGFloat.pi
        return CGPoint(
            x: geometry.center.x + geometry.radius * cos(angle),
            y: geometry.center.y + geometry.radius * sin(angle)
        )
    }

    private static func explosionPreset(for score: Int) -> ExplosionPreset {
        switch score {
        case 0..<25: return .tiny
        case 25..<50: return .small
        case 50..<75: return .medium
        default: return .large
        }
    }

    private func updateRingPaths() {
        guard let geometry = ringGeometry() else { return }

        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + CGFloat.pi * 2

        let path = UIBezierPath(
            arcCenter: geometry.center,
            radius: geometry.radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        ).cgPath

        trackLayer.path = path
        progressLayer.path = path
    }

    private func animateProgress(to progress: CGFloat, celebrateCompletion: Bool) {
        layoutIfNeeded()

        let from = progressLayer.presentation()?.strokeEnd ?? progressLayer.strokeEnd
        shouldCelebrateCompletion = celebrateCompletion && animationConfig.playsExplosion
        resetHapticProgress()
        lightHapticGenerator.prepare()

        let animation = animationConfig.makeAnimation(from: from, to: progress)
        animation.delegate = self

        progressLayer.strokeEnd = progress
        progressLayer.add(animation, forKey: "progress")
        startScoreDisplayLink()
    }

    private func startScoreDisplayLink() {
        stopScoreDisplayLink()
        let target = ScoreDisplayLinkTarget()
        target.ringView = self
        scoreDisplayLinkTarget = target
        let link = CADisplayLink(target: target, selector: #selector(ScoreDisplayLinkTarget.update))
        link.add(to: .main, forMode: .common)
        scoreDisplayLink = link
    }

    private func stopScoreDisplayLink() {
        scoreDisplayLink?.invalidate()
        scoreDisplayLink = nil
        scoreDisplayLinkTarget = nil
    }

    fileprivate func updateScoreLabelFromRingProgress() {
        let strokeEnd = progressLayer.presentation()?.strokeEnd ?? progressLayer.strokeEnd
        let isAnimating = progressLayer.animation(forKey: "progress") != nil

        guard isAnimating || strokeEnd < targetProgress else {
            scoreLabel.text = "\(displayScore)"
            stopScoreDisplayLink()
            return
        }

        guard targetProgress > 0 else {
            scoreLabel.text = "0"
            return
        }

        let normalizedProgress = min(1, max(0, strokeEnd / targetProgress))
        let score = min(displayScore, Int(round(normalizedProgress * CGFloat(displayScore))))
        scoreLabel.text = "\(score)"

        if isAnimating {
            checkForHapticTrigger(normalizedProgress: normalizedProgress)
        }
    }

    private func resetHapticProgress() {
        lastHapticProgress = 0
    }

    private func checkForHapticTrigger(normalizedProgress: CGFloat) {
        let currentProgress = Float(normalizedProgress * 100)
        let progressDifference = currentProgress - lastHapticProgress

        guard progressDifference >= hapticInterval else { return }

        if Float.random(in: 0...1) < hapticFrequency {
            let ramp = min(1, max(0, normalizedProgress))
            let intensity = CGFloat(0.35 + 0.65 * ramp) * CGFloat(hapticIntensity)
            lightHapticGenerator.prepare()
            lightHapticGenerator.impactOccurred(intensity: intensity)
        }

        lastHapticProgress = currentProgress
    }

    private func finishScoreAnimation() {
        stopScoreDisplayLink()
        resetHapticProgress()
        scoreLabel.text = "\(displayScore)"
    }

    private func triggerScoreExplosion() {
        HapticsHelper.mediumHaptic()
        guard let window else { return }
        let tipInWindow = convert(progressTipPoint(for: targetProgress), to: window)
        ExplosionManager.trigger(Self.explosionPreset(for: displayScore), at: tipInWindow)
    }
}

extension NestReadinessRingView: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        finishScoreAnimation()
        guard flag, shouldCelebrateCompletion else { return }
        shouldCelebrateCompletion = false
        triggerScoreExplosion()
    }
}
