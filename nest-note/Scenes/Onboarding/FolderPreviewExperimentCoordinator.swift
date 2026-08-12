//
//  FolderPreviewExperimentCoordinator.swift
//  nest-note
//
//  DEBUG experiment that mirrors OnboardingCoordinator chrome (progress bar,
//  hidden nav bar, survey → folder preview) for the animated folder screen.
//

#if DEBUG
import UIKit

/// Navigation controller that lets `OBFolderPreviewViewController` consume
/// back/pop before leaving the screen (detail → grid).
private final class FolderPreviewExperimentNavigationController: UINavigationController {
    override func popViewController(animated: Bool) -> UIViewController? {
        if let folderPreview = topViewController as? OBFolderPreviewViewController,
           folderPreview.handleBackIfNeeded() {
            return nil
        }
        return super.popViewController(animated: animated)
    }
}

final class FolderPreviewExperimentCoordinator: NSObject, UINavigationControllerDelegate, OnboardingContainerDelegate {

    private let navigationController: FolderPreviewExperimentNavigationController
    private let containerViewController: OnboardingContainerViewController
    private var selectedResponsibilities: [String] = []
    private var currentStepIndex = 0
    private let totalSteps = 2
    /// Keeps the coordinator alive for the duration of the presented flow.
    private var selfRetain: FolderPreviewExperimentCoordinator?

    override init() {
        self.navigationController = FolderPreviewExperimentNavigationController()

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
        let survey = makeCareResponsibilitiesSurvey()
        currentStepIndex = 0
        navigationController.setViewControllers([survey], animated: false)
        containerViewController.updateSurveyStatus(true)
        containerViewController.updateProgress(step: 0)
        return containerViewController
    }

    private func endFlow(animated: Bool = true) {
        containerViewController.dismiss(animated: animated) { [weak self] in
            self?.selfRetain = nil
        }
    }

    // MARK: - Steps

    private func makeCareResponsibilitiesSurvey() -> NNOnboardingSurveyViewController {
        let question = SurveyQuestion(
            id: "care_responsibilities",
            title: "What are your sitters typically responsible for?",
            subtitle: "We'll make some default folders for these items.",
            options: ["Household", "Children", "Pets", "Plants"],
            optionSubtitles: nil,
            isMultiSelect: true,
            layout: nil,
            category: "setup",
            order: 1
        )

        let survey = NNOnboardingSurveyViewController()
        survey.onboardingStepId = question.id
        survey.configure(with: question)
        survey.preselectOptions(["Household"])
        survey.onContinueWithAnswers = { [weak self] _, answers in
            self?.selectedResponsibilities = answers
            self?.showFolderPreview()
        }
        return survey
    }

    private func showFolderPreview() {
        let folders = OBFolderPreviewViewController.folders(fromCareResponsibilities: selectedResponsibilities)
        let preview = OBFolderPreviewViewController(folders: folders)
        preview.onContinue = { [weak self] in
            self?.endFlow()
        }

        currentStepIndex = 1
        containerViewController.updateSurveyStatus(false)
        navigationController.pushViewController(preview, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.containerViewController.updateProgress(step: self.currentStepIndex)
        }
    }

    // MARK: - UINavigationControllerDelegate

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        if viewController is NNOnboardingSurveyViewController {
            currentStepIndex = 0
            containerViewController.updateSurveyStatus(true)
        } else if viewController is OBFolderPreviewViewController {
            currentStepIndex = 1
            containerViewController.updateSurveyStatus(false)
        }
        containerViewController.updateProgress(step: currentStepIndex)
    }

    // MARK: - OnboardingContainerDelegate

    func onboardingContainerDidRequestAbort(_ container: OnboardingContainerViewController) {
        endFlow()
    }

    func onboardingContainerDidRequestSkipSurvey(_ container: OnboardingContainerViewController) {
        // Skip survey with a sensible default selection for the experiment.
        selectedResponsibilities = ["Household", "Children", "Pets"]
        showFolderPreview()
    }
}
#endif
