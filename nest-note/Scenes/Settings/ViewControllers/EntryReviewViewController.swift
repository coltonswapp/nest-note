//
//  EntryReviewViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 1/11/25.
//

import UIKit

class EntryReviewViewController: NNViewController, CardStackViewDelegate {

    private let cardStackView: CardStackView = {
        let stack = CardStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalCentering
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
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Ensure that your Nest information is current. Swipe left to skip, swipe right to mark as up-to-date, tap to edit."
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var doneButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Done", image: nil)
        button.backgroundColor = NNColors.primary
        button.isEnabled = false
        button.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCardStack()
        cardStackView.delegate = self
    }
    
    override func setup() {
        navigationItem.title = "Review Entries"
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    override func setupNavigationBarButtons() {
        let closeButton = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeButtonTapped))
        let buttons = [closeButton]
        buttons.forEach { $0.tintColor = .label }
        navigationItem.rightBarButtonItems = buttons
        navigationController?.isModalInPresentation = true
    }
    
    override func addSubviews() {
        view.backgroundColor = .systemBackground
        
        [subtitleLabel, cardStackView, buttonStack, doneButton].forEach {
            view.addSubview($0)
        }
        
        [previousButton, approveButton, nextButton].forEach {
            buttonStack.addArrangedSubview($0)
        }
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            subtitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            cardStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            cardStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardStackView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),
            
            buttonStack.topAnchor.constraint(equalTo: cardStackView.bottomAnchor, constant: 20),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            approveButton.heightAnchor.constraint(equalToConstant: 46.0),
            approveButton.widthAnchor.constraint(equalToConstant: view.frame.width * 0.4),
            
            doneButton.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 20),
            doneButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            doneButton.heightAnchor.constraint(equalToConstant: 50)
        ])
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
    
    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
    
    // Card stack delegate methods
    func cardStackView(_ stackView: CardStackView, didTapCard card: UIView) {
        let vc = EntryDetailViewController(category: "Test Category", sourceFrame: card.frame)
        present(vc, animated: true)
    }
    
    func cardStackView(_ stackView: CardStackView, didRemoveCard card: UIView) {
        updateButtonStates()
        
        if !stackView.canGoNext {
            doneButton.isEnabled = true
        }
    }
    
    func cardStackView(_ stackView: CardStackView, didRestoreCard card: UIView) {
        updateButtonStates()
    }
    
    func cardStackView(_ stackView: CardStackView, didUpdateSwipe translation: CGFloat, velocity: CGFloat) {
        return
    }
    
    func cardStackView(_ stackView: CardStackView, didFinishSwipe translation: CGFloat, velocity: CGFloat, dismissed: Bool) {
        return
    }
}
