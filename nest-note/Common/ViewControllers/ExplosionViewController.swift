//
//  ExplosionViewController.swift
//  nest-note
//
//  Created by Claude on 11/18/25.
//

import UIKit

class ExplosionViewController: UIViewController {

    // MARK: - Properties
    private let controlsContainer = UIVisualEffectView()
    private let explosionSegmentedControl = UISegmentedControl(items: ["Tiny", "Small", "Medium", "Large", "Atomic", "Random"])
    private let instructionLabel = UILabel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupControls()
        setupConstraints()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Global Explosions"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Back",
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )

        // Add tap gesture to trigger explosions anywhere on screen
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        view.addGestureRecognizer(tapGesture)
    }

    private func setupControls() {
        // Setup controls container with glass effect
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .regular)
            glassEffect.isInteractive = true
            controlsContainer.effect = glassEffect
            controlsContainer.cornerConfiguration = .corners(radius: .fixed(16.0))
        } else {
            let blurEffect = UIBlurEffect(style: .systemMaterial)
            controlsContainer.effect = blurEffect
            controlsContainer.layer.cornerRadius = 16
            controlsContainer.clipsToBounds = true
        }

        controlsContainer.translatesAutoresizingMaskIntoConstraints = false

        // Setup instruction label
        instructionLabel.text = "Tap Anywhere"
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textAlignment = .center
        instructionLabel.textColor = .secondaryLabel
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false

        // Setup segmented control
        explosionSegmentedControl.selectedSegmentIndex = 1 // Default to Medium
        explosionSegmentedControl.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        controlsContainer.contentView.addSubview(instructionLabel)
        controlsContainer.contentView.addSubview(explosionSegmentedControl)
        view.addSubview(controlsContainer)
    }


    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Controls container at bottom
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            // Instruction label
            instructionLabel.topAnchor.constraint(equalTo: controlsContainer.contentView.topAnchor, constant: 20),
            instructionLabel.leadingAnchor.constraint(equalTo: controlsContainer.contentView.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: controlsContainer.contentView.trailingAnchor, constant: -20),

            // Segmented control
            explosionSegmentedControl.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 16),
            explosionSegmentedControl.leadingAnchor.constraint(equalTo: controlsContainer.contentView.leadingAnchor, constant: 20),
            explosionSegmentedControl.trailingAnchor.constraint(equalTo: controlsContainer.contentView.trailingAnchor, constant: -20),
            explosionSegmentedControl.bottomAnchor.constraint(equalTo: controlsContainer.contentView.bottomAnchor, constant: -20),
            explosionSegmentedControl.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    // MARK: - Actions
    @objc private func screenTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)

        // Haptic feedback
        HapticsHelper.lightHaptic()

        // Trigger explosion based on selected segment
        let selectedIndex = explosionSegmentedControl.selectedSegmentIndex

        switch selectedIndex {
        case 0:
            ExplosionManager.trigger(.tiny, at: location)
        case 1:
            ExplosionManager.trigger(.small, at: location)
        case 2:
            ExplosionManager.trigger(.medium, at: location)
        case 3:
            ExplosionManager.trigger(.large, at: location)
        case 4:
            ExplosionManager.trigger(.atomic, at: location)
        case 5:
            ExplosionManager.triggerRandom(at: location)
        default:
            ExplosionManager.trigger(.medium, at: location)
        }
    }


    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Helper Methods
}
