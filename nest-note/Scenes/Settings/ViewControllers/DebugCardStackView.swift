//
//  EntryReviewViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 1/1/25.
//

import UIKit

class DebugCardStackView: UIViewController {
    private let cardStackView: CardStackView = {
        let stack = CardStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var previousButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Previous", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()
    
    private lazy var approveButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(title: "Looks good 👍", image: nil, backgroundColor: .systemBlue, foregroundColor: .white)
        button.addTarget(self, action: #selector(approveTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Next", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var debugLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 3
        label.textAlignment = .center
        label.text = "Distance: 0.0\nVelocity: 0.0\nProgress: 0%"
        return label
    }()
    
    private let sliderStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var dismissPercentageSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0.3
        slider.maximumValue = 1.0
        slider.value = Float(cardStackView.minimumDismissPercentage)
        slider.addTarget(self, action: #selector(dismissPercentageChanged), for: .valueChanged)
        return slider
    }()
    
    private lazy var verticalOffsetSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 150
        slider.value = Float(cardStackView.verticalOffset)
        slider.addTarget(self, action: #selector(verticalOffsetChanged), for: .valueChanged)
        return slider
    }()
    
    private lazy var scaleRatioSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0.7
        slider.maximumValue = 1.0
        slider.value = Float(cardStackView.scaleRatio)
        slider.addTarget(self, action: #selector(scaleRatioChanged), for: .valueChanged)
        return slider
    }()
    
    private lazy var rotationRangeSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 10
        slider.value = Float(cardStackView.rotationRange)
        slider.addTarget(self, action: #selector(rotationRangeChanged), for: .valueChanged)
        return slider
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCardStack()
        cardStackView.delegate = self
        title = "Review Entries"
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(cardStackView)
        view.addSubview(buttonStack)
        view.addSubview(debugLabel)
        view.addSubview(sliderStack)
        
        [previousButton, approveButton, nextButton].forEach { buttonStack.addArrangedSubview($0) }
        
        // Create grid layout for sliders
        let dismissLabel = makeSliderLabel(text: String(format: "Dismiss: %.0f%%", cardStackView.minimumDismissPercentage * 100))
        let offsetLabel = makeSliderLabel(text: String(format: "Offset: %.0f", cardStackView.verticalOffset))
        let scaleLabel = makeSliderLabel(text: String(format: "Scale: %.2f", cardStackView.scaleRatio))
        let rotationLabel = makeSliderLabel(text: String(format: "Rotation: ±%.1f°", cardStackView.rotationRange))
        
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 16
        grid.translatesAutoresizingMaskIntoConstraints = false
        
        let topRow = UIStackView()
        topRow.distribution = .fillEqually
        topRow.spacing = 16
        
        let bottomRow = UIStackView()
        bottomRow.distribution = .fillEqually
        bottomRow.spacing = 16
        
        let leftTop = makeSliderContainer(label: dismissLabel, slider: dismissPercentageSlider)
        let rightTop = makeSliderContainer(label: offsetLabel, slider: verticalOffsetSlider)
        let leftBottom = makeSliderContainer(label: scaleLabel, slider: scaleRatioSlider)
        let rightBottom = makeSliderContainer(label: rotationLabel, slider: rotationRangeSlider)
        
        topRow.addArrangedSubview(leftTop)
        topRow.addArrangedSubview(rightTop)
        bottomRow.addArrangedSubview(leftBottom)
        bottomRow.addArrangedSubview(rightBottom)
        
        grid.addArrangedSubview(topRow)
        grid.addArrangedSubview(bottomRow)
        
        view.addSubview(grid)
        
        NSLayoutConstraint.activate([
            cardStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardStackView.heightAnchor.constraint(equalToConstant: 300),
            
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            debugLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            debugLabel.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -20),
            debugLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            debugLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            approveButton.heightAnchor.constraint(equalToConstant: 46.0),
            approveButton.widthAnchor.constraint(equalToConstant: view.frame.width * 0.4),
            
            grid.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func makeSliderLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12)
        return label
    }
    
    private func makeSliderContainer(label: UILabel, slider: UISlider) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(slider)
        return stack
    }
    
    private func setupCardStack() {
        let testData = [
            ("Garage Code", "4321", Date()),
            ("WiFi Password", "NestNote123", Date().addingTimeInterval(-86400)),
            ("Emergency Contact", "John Smith", Date().addingTimeInterval(-172800)),
            ("Pet Instructions", "Feed twice daily", Date().addingTimeInterval(-259200)),
            ("House Rules", "No shoes inside", Date().addingTimeInterval(-345600)),
            ("Security System", "1234", Date().addingTimeInterval(-432000))
        ]
        
        cardStackView.setCardData(testData)
    }
    
    @objc private func nextTapped() {
        cardStackView.next()
    }
    
    @objc private func previousTapped() {
        cardStackView.previous()
    }
    
    @objc private func approveTapped() {
        cardStackView.approveCard()
    }
    
    private func updateButtonStates() {
        previousButton.isEnabled = cardStackView.canGoPrevious
        previousButton.setTitleColor(cardStackView.canGoPrevious ? .systemBlue : .secondaryLabel, for: .normal)
        
        nextButton.isEnabled = cardStackView.canGoNext
        nextButton.setTitleColor(cardStackView.canGoNext ? .systemBlue : .secondaryLabel, for: .normal)
    }
    
    @objc private func dismissPercentageChanged(_ slider: UISlider) {
        cardStackView.minimumDismissPercentage = CGFloat(slider.value)
        if let container = slider.superview as? UIStackView,
           let label = container.arrangedSubviews.first as? UILabel {
            label.text = String(format: "Dismiss: %.0f%%", slider.value * 100)
        }
    }
    
    @objc private func verticalOffsetChanged(_ slider: UISlider) {
        cardStackView.verticalOffset = CGFloat(slider.value)
        if let container = slider.superview as? UIStackView,
           let label = container.arrangedSubviews.first as? UILabel {
            label.text = String(format: "Offset: %.0f", slider.value)
        }
    }
    
    @objc private func scaleRatioChanged(_ slider: UISlider) {
        cardStackView.scaleRatio = CGFloat(slider.value)
        if let container = slider.superview as? UIStackView,
           let label = container.arrangedSubviews.first as? UILabel {
            label.text = String(format: "Scale: %.2f", slider.value)
        }
    }
    
    @objc private func rotationRangeChanged(_ slider: UISlider) {
        cardStackView.rotationRange = CGFloat(slider.value)
        if let container = slider.superview as? UIStackView,
           let label = container.arrangedSubviews.first as? UILabel {
            label.text = String(format: "Rotation: ±%.1f°", slider.value)
        }
    }
}

extension DebugCardStackView: CardStackViewDelegate {
    func cardStackView(_ stackView: CardStackView, didTapCard card: UIView) {
        let vc = EntryDetailViewController(category: "Test Category", sourceFrame: card.frame)
        present(vc, animated: true)
    }
    
    func cardStackView(_ stackView: CardStackView, didRemoveCard card: UIView) {
        updateButtonStates()
    }
    
    func cardStackView(_ stackView: CardStackView, didRestoreCard card: UIView) {
        updateButtonStates()
    }
    
    func cardStackView(_ stackView: CardStackView, didUpdateSwipe translation: CGFloat, velocity: CGFloat) {
        let percentage = min(100, abs(translation / 300 * 100))
        debugLabel.text = String(format: "Distance: %.1f\nVelocity: %.1f\nProgress: %.0f%%",
                               abs(translation),
                               abs(velocity),
                               percentage)
    }
    
    func cardStackView(_ stackView: CardStackView, didFinishSwipe translation: CGFloat, velocity: CGFloat, dismissed: Bool) {
        debugLabel.text = String(format: "Final Distance: %.1f\nFinal Velocity: %.1f\nDismissed: %@",
                               abs(translation),
                               abs(velocity),
                               dismissed ? "Yes" : "No")
    }
}
