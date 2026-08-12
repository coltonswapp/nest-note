//
//  WaterfallToFolderExperimentCoordinator.swift
//  nest-note
//
//  DEBUG experiment hosting the chaos-waterfall → folder dual-state screen.
//

#if DEBUG
import UIKit

/// Navigation controller that lets `OBWaterfallToFolderViewController` consume
/// back/pop before leaving the screen (detail → overview).
private final class WaterfallToFolderExperimentNavigationController: UINavigationController {
    override func popViewController(animated: Bool) -> UIViewController? {
        if let screen = topViewController as? OBWaterfallToFolderViewController,
           screen.handleBackIfNeeded() {
            return nil
        }
        return super.popViewController(animated: animated)
    }
}

final class WaterfallToFolderExperimentCoordinator: NSObject, UINavigationControllerDelegate, OnboardingContainerDelegate {

    private let navigationController: WaterfallToFolderExperimentNavigationController
    private let containerViewController: OnboardingContainerViewController
    /// Match onboarding chrome where this beat sits early in the flow (~20%).
    private let totalSteps = 5
    /// Keeps the coordinator alive for the duration of the presented flow.
    private var selfRetain: WaterfallToFolderExperimentCoordinator?

    override init() {
        self.navigationController = WaterfallToFolderExperimentNavigationController()

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        navigationController.navigationBar.isHidden = true

        self.containerViewController = OnboardingContainerViewController(
            navigationController: navigationController,
            totalSteps: totalSteps
        )

        super.init()

        containerViewController.delegate = self
        navigationController.delegate = self
    }

    func start() -> UIViewController {
        selfRetain = self

        let screen = OBWaterfallToFolderViewController()
        screen.onContinue = { [weak self] in
            self?.endFlow()
        }

        navigationController.setViewControllers([screen], animated: false)
        containerViewController.updateSurveyStatus(false)
        containerViewController.updateProgress(step: 1)
        return containerViewController
    }

    private func endFlow(animated: Bool = true) {
        containerViewController.dismiss(animated: animated) { [weak self] in
            self?.selfRetain = nil
        }
    }

    // MARK: - UINavigationControllerDelegate

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        containerViewController.updateSurveyStatus(false)
        containerViewController.updateProgress(step: 1)
    }

    // MARK: - OnboardingContainerDelegate

    func onboardingContainerDidRequestAbort(_ container: OnboardingContainerViewController) {
        endFlow()
    }

    func onboardingContainerDidRequestSkipSurvey(_ container: OnboardingContainerViewController) {
        endFlow()
    }
}
#endif
