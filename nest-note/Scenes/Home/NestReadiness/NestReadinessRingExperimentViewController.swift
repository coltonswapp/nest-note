#if DEBUG
import UIKit

final class NestReadinessRingExperimentViewController: NNViewController {

    private var config = NestReadinessRingAnimationConfig.experimentDefault
    private var previewScore = 72
    private var pendingWorkItem: DispatchWorkItem?

    private let ringView: NestReadinessRingView = {
        let view = NestReadinessRingView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        return scroll
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()

    private let scoreValueLabel = NestReadinessRingExperimentViewController.makeValueLabel()
    private let delayValueLabel = NestReadinessRingExperimentViewController.makeValueLabel()
    private let durationValueLabel = NestReadinessRingExperimentViewController.makeValueLabel()
    private let midProgressValueLabel = NestReadinessRingExperimentViewController.makeValueLabel()
    private let midKeyTimeValueLabel = NestReadinessRingExperimentViewController.makeValueLabel()
    private let bezierValueLabels: [UILabel] = (0..<8).map { _ in NestReadinessRingExperimentViewController.makeValueLabel() }
    private var bezierRowViews: [UIView] = []

    private let curveStyleControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Basic", "Two Phase"])
        control.selectedSegmentIndex = 0
        return control
    }()

    private let bezierPresetControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Linear", "Ease Out", "Ease In", "Ease In Out"])
        control.selectedSegmentIndex = 1
        return control
    }()

    private lazy var scoreSlider = makeSlider(min: 0, max: 100, value: Float(previewScore))
    private lazy var delaySlider = makeSlider(min: 0, max: 1.2, value: Float(config.startDelay))
    private lazy var durationSlider = makeSlider(min: 0.15, max: 2.0, value: Float(config.duration))
    private lazy var midProgressSlider = makeSlider(min: 0.05, max: 0.95, value: 0.82)
    private lazy var midKeyTimeSlider = makeSlider(min: 0.05, max: 0.95, value: 0.62)
    private lazy var bezierSliders: [UISlider] = {
        let defaults: [Float] = [0, 0, 0.2, 1, 0, 0, 0.2, 1]
        return defaults.map { makeSlider(min: 0, max: 1, value: $0) }
    }()

    private let twoPhaseStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.isHidden = true
        return stack
    }()

    private let bezierStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        return stack
    }()

    private let snippetLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let explosionSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.isOn = true
        return toggle
    }()

    override func setup() {
        title = "Readiness Ring Lab"
        view.backgroundColor = .systemGroupedBackground
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        syncControlsFromConfig()
        updateSnippet()
        replayPreview()
    }

    override func addSubviews() {
        buildControls()

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(ringView)
        contentStack.addArrangedSubview(makeButtonRow())
        contentStack.addArrangedSubview(makeCard(title: "Preview", arrangedSubviews: [
            makeLabeledRow(title: "Score", valueLabel: scoreValueLabel, control: scoreSlider),
            makeLabeledRow(title: "Start Delay", valueLabel: delayValueLabel, control: delaySlider),
            makeLabeledRow(title: "Duration", valueLabel: durationValueLabel, control: durationSlider),
            makeLabeledRow(title: "Explosion", valueLabel: nil, control: explosionSwitch)
        ]))
        contentStack.addArrangedSubview(makeCard(title: "Curve", arrangedSubviews: [
            curveStyleControl,
            bezierPresetControl,
            bezierStack,
            twoPhaseStack
        ]))
        contentStack.addArrangedSubview(makeCard(title: "Swift Config", arrangedSubviews: [snippetLabel]))
    }

    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),

            ringView.heightAnchor.constraint(equalToConstant: 220)
        ])
    }

    private func buildControls() {
        let bezierTitles = [
            "X1", "Y1", "X2", "Y2",
            "Phase 2 X1", "Phase 2 Y1", "Phase 2 X2", "Phase 2 Y2"
        ]

        for (index, title) in bezierTitles.enumerated() {
            let prefix = index < 4 ? "Bezier " : ""
            let row = makeLabeledRow(
                title: "\(prefix)\(title)",
                valueLabel: bezierValueLabels[index],
                control: bezierSliders[index]
            )
            bezierRowViews.append(row)
            bezierStack.addArrangedSubview(row)
        }

        twoPhaseStack.addArrangedSubview(
            makeLabeledRow(title: "Mid Progress", valueLabel: midProgressValueLabel, control: midProgressSlider)
        )
        twoPhaseStack.addArrangedSubview(
            makeLabeledRow(title: "Mid Key Time", valueLabel: midKeyTimeValueLabel, control: midKeyTimeSlider)
        )

        curveStyleControl.addTarget(self, action: #selector(curveStyleChanged), for: .valueChanged)
        bezierPresetControl.addTarget(self, action: #selector(bezierPresetChanged), for: .valueChanged)
        scoreSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        delaySlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        durationSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        midProgressSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        midKeyTimeSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        bezierSliders.forEach { $0.addTarget(self, action: #selector(sliderChanged), for: .valueChanged) }
        explosionSwitch.addAction(UIAction { [weak self] _ in
            self?.sliderChanged()
        }, for: .valueChanged)
    }

    private func makeButtonRow() -> UIStackView {
        let replay = NNSmallPrimaryButton(
            title: "Replay",
            backgroundColor: NNColors.primary.withAlphaComponent(0.15),
            foregroundColor: NNColors.primary
        )
        replay.addTarget(self, action: #selector(replayTapped), for: .touchUpInside)

        let reset = NNSmallPrimaryButton(
            title: "Reset",
            backgroundColor: UIColor.systemRed.withAlphaComponent(0.12),
            foregroundColor: .systemRed
        )
        reset.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)

        let copy = NNSmallPrimaryButton(
            title: "Copy Config",
            backgroundColor: UIColor.secondarySystemFill,
            foregroundColor: .label
        )
        copy.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [replay, reset, copy])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        return stack
    }

    private func makeCard(title: String, arrangedSubviews: [UIView]) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.text = title

        let stack = UIStackView(arrangedSubviews: [titleLabel] + arrangedSubviews)
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    private func makeLabeledRow(title: String, valueLabel: UILabel?, control: UIView) -> UIView {
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.text = title
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let topRow = UIStackView(arrangedSubviews: [titleLabel])
        if let valueLabel {
            topRow.addArrangedSubview(valueLabel)
        }
        topRow.axis = .horizontal
        topRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topRow, control])
        stack.axis = .vertical
        stack.spacing = 6
        return stack
    }

    private static func makeValueLabel() -> UILabel {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }

    private func makeSlider(min: Float, max: Float, value: Float) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = min
        slider.maximumValue = max
        slider.value = value
        return slider
    }

    @objc private func curveStyleChanged() {
        let isTwoPhase = curveStyleControl.selectedSegmentIndex == 1
        twoPhaseStack.isHidden = !isTwoPhase
        bezierPresetControl.isHidden = isTwoPhase
        bezierRowViews.enumerated().forEach { index, row in
            row.isHidden = !isTwoPhase && index >= 4
        }
        sliderChanged()
    }

    @objc private func bezierPresetChanged() {
        let preset: NestReadinessRingAnimationConfig.BezierControlPoints
        switch bezierPresetControl.selectedSegmentIndex {
        case 0: preset = .linear
        case 1: preset = .easeOut
        case 2: preset = .easeIn
        default: preset = .easeInOut
        }
        applyBezierPreset(preset, startingAt: 0)
        sliderChanged()
    }

    private func applyBezierPreset(_ preset: NestReadinessRingAnimationConfig.BezierControlPoints, startingAt index: Int) {
        let values: [Float] = [preset.x1, preset.y1, preset.x2, preset.y2]
        for offset in 0..<4 {
            bezierSliders[index + offset].value = values[offset]
        }
    }

    @objc private func sliderChanged() {
        previewScore = Int(scoreSlider.value.rounded())
        config.startDelay = TimeInterval(delaySlider.value)
        config.duration = TimeInterval(durationSlider.value)
        config.playsExplosion = explosionSwitch.isOn

        if curveStyleControl.selectedSegmentIndex == 0 {
            config.curveStyle = .basic(controlPoints: bezierControlPoints(startingAt: 0))
        } else {
            config.curveStyle = .twoPhase(
                midProgressFraction: CGFloat(midProgressSlider.value),
                midKeyTime: CGFloat(midKeyTimeSlider.value),
                firstSegment: bezierControlPoints(startingAt: 0),
                secondSegment: bezierControlPoints(startingAt: 4)
            )
        }

        syncValueLabels()
        updateSnippet()
    }

    private func bezierControlPoints(startingAt index: Int) -> NestReadinessRingAnimationConfig.BezierControlPoints {
        NestReadinessRingAnimationConfig.BezierControlPoints(
            x1: bezierSliders[index].value,
            y1: bezierSliders[index + 1].value,
            x2: bezierSliders[index + 2].value,
            y2: bezierSliders[index + 3].value
        )
    }

    private func syncControlsFromConfig() {
        scoreSlider.value = Float(previewScore)
        delaySlider.value = Float(config.startDelay)
        durationSlider.value = Float(config.duration)
        explosionSwitch.isOn = config.playsExplosion

        switch config.curveStyle {
        case .basic(let controlPoints):
            curveStyleControl.selectedSegmentIndex = 0
            applyBezierPreset(controlPoints, startingAt: 0)
        case .twoPhase(let midProgressFraction, let midKeyTime, let firstSegment, let secondSegment):
            curveStyleControl.selectedSegmentIndex = 1
            midProgressSlider.value = Float(midProgressFraction)
            midKeyTimeSlider.value = Float(midKeyTime)
            applyBezierPreset(firstSegment, startingAt: 0)
            applyBezierPreset(secondSegment, startingAt: 4)
        }

        curveStyleChanged()
        syncValueLabels()
    }

    private func syncValueLabels() {
        scoreValueLabel.text = "\(previewScore)"
        delayValueLabel.text = String(format: "%.2fs", config.startDelay)
        durationValueLabel.text = String(format: "%.2fs", config.duration)
        midProgressValueLabel.text = String(format: "%.2f", midProgressSlider.value)
        midKeyTimeValueLabel.text = String(format: "%.2f", midKeyTimeSlider.value)

        for (index, label) in bezierValueLabels.enumerated() {
            label.text = String(format: "%.2f", bezierSliders[index].value)
        }
    }

    private func updateSnippet() {
        snippetLabel.text = config.swiftSnippet
    }

    @objc private func replayTapped() {
        replayPreview()
    }

    @objc private func resetTapped() {
        config = .experimentDefault
        previewScore = 72
        syncControlsFromConfig()
        updateSnippet()
        replayPreview()
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = config.swiftSnippet
        ToastManager.shared.showToast(delay: 0, text: "Copied ring config")
    }

    private func replayPreview() {
        pendingWorkItem?.cancel()
        ringView.animationConfig = config
        ringView.prepareForArrivalAnimation()
        ringView.setScore(previewScore)

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let result = Self.mockResult(score: self.previewScore)
            self.ringView.configure(
                result: result,
                animated: true,
                celebrateCompletion: self.config.playsExplosion
            )
        }
        pendingWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + config.startDelay, execute: work)
    }

    private static func mockResult(score: Int) -> NestReadinessResult {
        NestReadinessResult(
            totalScore: score,
            tier: NestReadinessTier.tier(for: score),
            components: [],
            boostSuggestions: [],
            qualifyingItemCount: 0
        )
    }
}
#endif
