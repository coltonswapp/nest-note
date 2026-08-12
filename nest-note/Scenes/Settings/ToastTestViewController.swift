import UIKit

class ToastTestViewController: NNViewController {

    private enum Param: Int, CaseIterable {
        case duration
        case damping
        case velocity
        case initialScale
        case translateY

        var range: ClosedRange<Float> {
            switch self {
            case .duration: return 0.15...0.8
            case .damping: return 0.35...1.0
            case .velocity: return 0...1.5
            case .initialScale: return 0.5...1.0
            case .translateY: return 0...100
            }
        }

        func value(from tuning: ToastAnimationTuning) -> Float {
            switch self {
            case .duration: return Float(tuning.duration)
            case .damping: return Float(tuning.damping)
            case .velocity: return Float(tuning.velocity)
            case .initialScale: return Float(tuning.initialScale)
            case .translateY: return Float(tuning.translateY)
            }
        }

        func apply(_ value: Float, to tuning: inout ToastAnimationTuning) {
            let v = CGFloat(value)
            switch self {
            case .duration: tuning.duration = TimeInterval(v)
            case .damping: tuning.damping = v
            case .velocity: tuning.velocity = v
            case .initialScale: tuning.initialScale = v
            case .translateY: tuning.translateY = v
            }
        }

        func labelText(for tuning: ToastAnimationTuning) -> String {
            switch self {
            case .duration:
                return String(format: "Duration: %.2fs", tuning.duration)
            case .damping:
                return String(format: "Damping: %.2f", tuning.damping)
            case .velocity:
                return String(format: "Velocity: %.2f", tuning.velocity)
            case .initialScale:
                return String(format: "Initial Scale: %.2f", tuning.initialScale)
            case .translateY:
                return String(format: "Translate Y: %.0f", tuning.translateY)
            }
        }
    }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var valueLabels: [Param: UILabel] = [:]
    private var sliders: [Param: UISlider] = [:]

    override func setup() {
        // NNViewController already calls setup() from loadView — don't call it again from viewDidLoad
        // or we'll duplicate rows and the label dictionary will point at the wrong instances.
        navigationItem.title = "Toast Test"
        view.backgroundColor = .systemBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        // Clear in case setup is ever invoked more than once.
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        valueLabels.removeAll()
        sliders.removeAll()
        scrollView.removeFromSuperview()

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32)
        ])

        contentStack.addArrangedSubview(makeSectionLabel("Variants"))
        contentStack.addArrangedSubview(makeButtonRow([
            ("Single", #selector(showSingleLineToast)),
            ("Subtitle", #selector(showSubtitleToast)),
            ("Action", #selector(showActionToast))
        ]))
        contentStack.addArrangedSubview(makeButtonRow([
            ("Positive", #selector(showPositiveToast)),
            ("Negative", #selector(showNegativeToast))
        ]))

        contentStack.addArrangedSubview(makeSectionLabel("Enter Spring"))
        for param in Param.allCases {
            contentStack.addArrangedSubview(makeSliderRow(for: param))
        }

        contentStack.addArrangedSubview(makeButtonRow(buttons: [
            makeButton(title: "Print Values", action: #selector(printValues)),
            makeButton(title: "Reset", action: #selector(resetDefaults))
        ]))

        configureEdgeMenu()
        syncSlidersFromTuning()
    }

    private func configureEdgeMenu() {
        let actions = ToastPresentationEdge.allCases.map { edge in
            UIAction(
                title: edge.menuTitle,
                state: ToastManager.shared.presentationEdge == edge ? .on : .off
            ) { [weak self] _ in
                ToastManager.shared.presentationEdge = edge
                self?.configureEdgeMenu()
                self?.showToast(
                    text: "Toasts from \(edge.menuTitle.lowercased())",
                    sentiment: .positive
                )
            }
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Edge",
            menu: UIMenu(title: "Appear From", options: .singleSelection, children: actions)
        )
    }

    // MARK: - UI

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        return label
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = .secondarySystemFill
        config.baseForegroundColor = .label
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeButtonRow(_ items: [(String, Selector)]) -> UIStackView {
        makeButtonRow(buttons: items.map { makeButton(title: $0.0, action: $0.1) })
    }

    private func makeButtonRow(buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.spacing = 10
        row.distribution = .fillEqually
        return row
    }

    private func makeSliderRow(for param: Param) -> UIStackView {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel

        let slider = UISlider()
        slider.minimumValue = param.range.lowerBound
        slider.maximumValue = param.range.upperBound
        slider.tag = param.rawValue
        slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)

        valueLabels[param] = label
        sliders[param] = slider

        let stack = UIStackView(arrangedSubviews: [label, slider])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }

    private func syncSlidersFromTuning() {
        let tuning = ToastManager.shared.animationTuning
        for param in Param.allCases {
            sliders[param]?.value = param.value(from: tuning)
            valueLabels[param]?.text = param.labelText(for: tuning)
        }
    }

    // MARK: - Actions

    @objc private func sliderChanged(_ slider: UISlider) {
        guard let param = Param(rawValue: slider.tag) else { return }
        var tuning = ToastManager.shared.animationTuning
        param.apply(slider.value, to: &tuning)
        ToastManager.shared.animationTuning = tuning
        valueLabels[param]?.text = param.labelText(for: tuning)
    }

    @objc private func printValues() {
        let t = ToastManager.shared.animationTuning
        print(
            """
            ToastAnimationTuning(
                duration: \(String(format: "%.2f", t.duration)),
                damping: \(String(format: "%.2f", t.damping)),
                velocity: \(String(format: "%.2f", t.velocity)),
                initialScale: \(String(format: "%.2f", t.initialScale)),
                translateY: \(String(format: "%.1f", t.translateY)),
                dismissDuration: \(String(format: "%.2f", t.dismissDuration)),
                dismissTranslateY: \(String(format: "%.1f", t.dismissTranslateY))
            )
            """
        )
        showToast(text: "Printed to console", sentiment: .positive)
    }

    @objc private func resetDefaults() {
        ToastManager.shared.animationTuning = ToastAnimationTuning()
        syncSlidersFromTuning()
        showToast(text: "Reset to defaults", sentiment: .positive)
    }

    @objc private func showSingleLineToast() {
        showToast(text: "Note Saved", sentiment: .positive)
    }

    @objc private func showSubtitleToast() {
        showToast(
            text: "Note Saved",
            subtitle: "Lorem ipsum dolar sit amet",
            sentiment: .positive
        )
    }

    @objc private func showActionToast() {
        showToast(
            text: "Session Created",
            sentiment: .positive,
            actionTitle: "Go to sessions",
            onAction: { [weak self] in
                self?.showToast(text: "Action tapped", sentiment: .positive)
            }
        )
    }

    @objc private func showPositiveToast() {
        showToast(text: "Operation successful!", sentiment: .positive)
    }

    @objc private func showNegativeToast() {
        showToast(text: "Operation failed!", sentiment: .negative)
    }
}
