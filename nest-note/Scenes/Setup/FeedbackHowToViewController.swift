//
//  FeedbackHowToViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 5/24/25.
//

import UIKit

class FeedbackHowToViewController: NNViewController {
    
    // MARK: - UI Elements
    private let topImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(imageView, for: .rectanglePatternSmall)
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h1
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let ctaButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Sounds Good!")
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func loadView() {
        super.loadView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Share Feedback Anytime"
        descriptionLabel.text = "We'd love to hear from you! Drop us your thoughts and suggestions through the feedback button on your Profile page—your input makes all the difference."
        
        setupFauxView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Mark the feedback step as viewed/completed in SetupService
        SetupService.shared.markStepComplete(.feedback)
    }
    
    override func addSubviews() {
        view.addSubview(topImageView)
        topImageView.pinToTop(of: view)
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            
            titleLabel.topAnchor.constraint(equalTo: topImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        
        
    }
    
    override func setup() {
        ctaButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        ctaButton.isEnabled = true
    }
    
    private func setupFauxView() {
        let onboardingContainer = FauxAnimatedContainerViewController(scale: 0.7)
        
        addChild(onboardingContainer)
        view.addSubview(onboardingContainer.view)
        
        // Position and size the onboarding container
        onboardingContainer.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            onboardingContainer.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            onboardingContainer.view.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: -48),
            onboardingContainer.view.widthAnchor.constraint(equalTo: view.widthAnchor),
            onboardingContainer.view.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
        
        onboardingContainer.didMove(toParent: self)
        
        ctaButton.pinToBottom(of: view, addBlurEffect: true, blurMaskImage: UIImage(named: "testBG3"))
    }
}
