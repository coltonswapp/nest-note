//
//  OnboardingContainerViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 11/4/24.
//

import UIKit

final class OnboardingContainerViewController: UIViewController {
    
    // MARK: - Delegate
    weak var delegate: OnboardingContainerDelegate?
    
    // MARK: - UI Elements
    let progressBar: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .bar)
        progress.progressTintColor = .systemGreen
        progress.trackTintColor = .systemGray5
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.clipsToBounds = true
        return progress
    }()
    
    private let ellipsisButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .label
        button.showsMenuAsPrimaryAction = true
        return button
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Properties
    private let onboardingNavigationController: UINavigationController
    private var totalSteps: Int
    private var currentStep: Int = 0
    private var isCurrentStepSurvey: Bool = false
    
    // MARK: - Initialization
    init(navigationController: UINavigationController, totalSteps: Int) {
        self.onboardingNavigationController = navigationController
        self.totalSteps = totalSteps
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        addChildViewController()
        updateProgress(step: 0)
        
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true
        progressBar.layer.sublayers![1].cornerRadius = 2
        progressBar.subviews[1].clipsToBounds = true
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(progressBar)
        view.addSubview(ellipsisButton)
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            progressBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            progressBar.trailingAnchor.constraint(equalTo: ellipsisButton.leadingAnchor, constant: -8),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            
            ellipsisButton.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            ellipsisButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            ellipsisButton.widthAnchor.constraint(equalToConstant: 44),
            ellipsisButton.heightAnchor.constraint(equalToConstant: 44),
            
            containerView.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 24),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        setupEllipsisMenu()
    }
    
    private func setupEllipsisMenu() {
        let backToLogin = UIAction(
            title: "Back to Login",
            image: UIImage(systemName: "arrow.left.circle"),
            attributes: []
        ) { [weak self] _ in
            self?.delegate?.onboardingContainerDidRequestAbort(self!)
        }
        
        let help = UIAction(
            title: "Help",
            image: UIImage(systemName: "questionmark.circle"),
            attributes: []
        ) { [weak self] _ in
            // TODO: Implement help action
            print("Help tapped")
        }
        
        var menuChildren: [UIAction] = [backToLogin]
        
        // Only add skip survey option if we're currently on a survey step
        if isCurrentStepSurvey {
            let skipSurvey = UIAction(
                title: "Skip Survey",
                image: UIImage(systemName: "forward.circle"),
                attributes: []
            ) { [weak self] _ in
                self?.delegate?.onboardingContainerDidRequestSkipSurvey(self!)
            }
            menuChildren.append(skipSurvey)
        }
        
        menuChildren.append(help)
        
        let menu = UIMenu(
            title: "",
            options: .displayInline,
            children: menuChildren
        )
        
        ellipsisButton.menu = menu
    }
    
    private func addChildViewController() {
        addChild(onboardingNavigationController)
        containerView.addSubview(onboardingNavigationController.view)
        onboardingNavigationController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            onboardingNavigationController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            onboardingNavigationController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            onboardingNavigationController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            onboardingNavigationController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        onboardingNavigationController.didMove(toParent: self)
    }
    
    // MARK: - Progress Updates
    func updateTotalSteps(_ count: Int) {
        self.totalSteps = count
        // Recalculate progress if needed
        updateProgress(step: currentStep)
    }
    
    func updateProgress(step: Int) {
        self.currentStep = step
        let progress = max(0.1, Float(step) / Float(totalSteps))
        setProgessTo(progress: progress)
    }
    
    func setProgessTo(progress: Float) {
        UIView.animate(withDuration: 0.2) {
            self.progressBar.setProgress(progress, animated: true)
        }
    }
    
    func updateSurveyStatus(_ isSurvey: Bool) {
        guard isCurrentStepSurvey != isSurvey else { return }
        isCurrentStepSurvey = isSurvey
        setupEllipsisMenu() // Refresh the menu
    }
}

// MARK: - Delegate Protocol
protocol OnboardingContainerDelegate: AnyObject {
    func onboardingContainerDidRequestAbort(_ container: OnboardingContainerViewController)
    func onboardingContainerDidRequestSkipSurvey(_ container: OnboardingContainerViewController)
}
