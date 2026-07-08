//
//  OBFinishViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 7/8/25.
//

import UIKit
import MessageUI
import SwiftUI

final class OBFinishViewController: NNOnboardingViewController, MFMailComposeViewControllerDelegate {

    // MARK: - Retry Tracking
    private static var failureCount: Int {
        get { UserDefaults.standard.integer(forKey: "OBFinishViewController.failureCount") }
        set { UserDefaults.standard.set(newValue, forKey: "OBFinishViewController.failureCount") }
    }

    private static func resetFailureCount() {
        UserDefaults.standard.removeObject(forKey: "OBFinishViewController.failureCount")
    }

    // MARK: - UI Elements
    private lazy var activityIndicator: NNLoadingSpinner = {
        let indicator = NNLoadingSpinner()
        indicator.configure(with: NNColors.primary)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private lazy var nestCreationCardView: NestCreationCardView = {
        let cardView = NestCreationCardView()
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.alpha = 0
        return cardView
    }()

    private lazy var glowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.clear
        view.alpha = 0
        view.layer.shadowColor = NNColors.primary.cgColor
        view.layer.shadowOffset = CGSize.zero
        view.layer.shadowRadius = 40
        view.layer.shadowOpacity = 0.8
        view.layer.masksToBounds = false
        let width = 280 * 1.05
        let height = 350 * 0.6
        let shadowPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: width, height: height))
        view.layer.shadowPath = shadowPath.cgPath
        return view
    }()

    private lazy var glowView2: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.clear
        view.alpha = 0
        view.layer.shadowColor = NNColors.primary.cgColor
        view.layer.shadowOffset = CGSize.zero
        view.layer.shadowRadius = 80
        view.layer.shadowOpacity = 0.6
        view.layer.masksToBounds = false
        let width = 280 * 1.1
        let height = 350 * 0.7
        let shadowPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: width, height: height))
        view.layer.shadowPath = shadowPath.cgPath
        return view
    }()

    private lazy var glowView3: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.clear
        view.alpha = 0
        view.layer.shadowColor = NNColors.primary.cgColor
        view.layer.shadowOffset = CGSize.zero
        view.layer.shadowRadius = 120
        view.layer.shadowOpacity = 0.4
        view.layer.masksToBounds = false
        let width = 280 * 1.15
        let height = 350 * 0.8
        let shadowPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: width, height: height))
        view.layer.shadowPath = shadowPath.cgPath
        return view
    }()

    private lazy var slideToEnterView: HorizontalSliderView = {
        let slider = HorizontalSliderView()
        slider.isHidden = true
        slider.onSlideComplete = { [weak self] in
            self?.handleSlideComplete()
        }
        return slider
    }()

    private lazy var inviteCarouselHostingController: UIHostingController<SitterInviteCarouselView> = {
        let controller = UIHostingController(
            rootView: SitterInviteCarouselView { [weak self] color in
                self?.updateGlowTint(color)
            }
        )
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = .clear
        controller.view.alpha = 0
        return controller
    }()

    private lazy var supportButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Get Support", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = NNColors.primaryAlt
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(supportButtonTapped), for: .touchUpInside)
        button.isHidden = true
        button.alpha = 0
        return button
    }()

    private var isDebugMode = false
    private var debugForceSitterFinish = false
    private var cardBottomConstraint: NSLayoutConstraint?
    private var carouselCenterYConstraint: NSLayoutConstraint?
    private var hasStartedSlideAnimation = false
    private var hasStartedCardAnimation = false
    private var hasStartedInitialSetup = false
    private var isSetupInProgress = false
    private var setupTask: Task<Void, Never>?
    private var lastSetupError: Error?

    private var isSitterFinish: Bool {
        if debugForceSitterFinish { return true }
        return (coordinator as? OnboardingCoordinator)?.currentRole == .sitter
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let userRole = debugForceSitterFinish ? NestUser.UserType.sitter : ((coordinator as? OnboardingCoordinator)?.currentRole ?? .nestOwner)

        if userRole == .sitter {
            setupOnboarding(
                title: "Finishing up...",
                subtitle: "Preparing your perch..."
            )
        } else {
            setupOnboarding(
                title: "Finishing up...",
                subtitle: "Gathering twigs, grass, and leaves for your nest..."
            )
        }

        setupContent()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        guard !hasStartedInitialSetup else { return }
        hasStartedInitialSetup = true
        beginFinishFlow()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    
    private func beginFinishFlow() {
        guard !isSetupInProgress else { return }
        isSetupInProgress = true
        activityIndicator.reset()

        setupTask?.cancel()
        setupTask = Task {
            defer { self.isSetupInProgress = false }

            do {
                try await (coordinator as? OnboardingCoordinator)?.finishSetup()

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.activityIndicator.animateState(success: true) {
                        (self.coordinator as? OnboardingCoordinator)?.updateProgressTo(1.0)
                        self.playSuccessTransition()
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.handleSetupFailure(error)
                }
            }
        }
    }

    private func handleSetupFailure(_ error: Error) {
        Self.failureCount += 1

        Logger.log(level: .error, category: .signup, message: "🎯 FINISH: Setup failed (attempt \(Self.failureCount)): \(error.localizedDescription)")

        activityIndicator.animateState(success: false)

        if let onboardingError = error as? OnboardingError,
           let failureInfo = onboardingError.failureInfo {
            handleStructuredFailure(failureInfo: failureInfo)
        } else {
            handleGenericFailure(error)
        }
    }

    private func handleStructuredFailure(failureInfo: (underlyingError: Error, completedSteps: [String], failedAtStep: String)) {
        let (underlyingError, completedSteps, failedAtStep) = failureInfo

        Logger.log(level: .error, category: .signup, message: "🎯 FINISH: Structured failure - Failed at: \(failedAtStep), Completed: \(completedSteps.joined(separator: ", "))")

        switch failedAtStep {
        case "profile_creation":
            lastSetupError = underlyingError
            let presentation = OnboardingSetupErrorPresentation.presentation(for: underlyingError)
            showCriticalError(
                title: presentation.alertTitle,
                message: presentation.alertMessage,
                canRetry: true,
                error: underlyingError
            )

        case "referral_recording":
            showWarningAndContinue(
                title: "Referral Issue",
                message: "We couldn't process your referral code, but your account was created successfully.",
                continueAction: { [weak self] in
                    self?.playSuccessTransition()
                }
            )

        case "survey_submission":
            showWarningAndContinue(
                title: "Survey Submission Failed",
                message: "Your account was created, but we couldn't save your survey responses. You can complete them later in settings.",
                continueAction: { [weak self] in
                    self?.playSuccessTransition()
                }
            )

        case "onboarding_completion", "delegate_notification":
            lastSetupError = underlyingError
            showCriticalError(
                title: "Setup Incomplete",
                message: "Your account was created but setup couldn't be completed. Please restart the app.",
                canRetry: false,
                error: underlyingError
            )

        default:
            handleGenericFailure(underlyingError)
        }
    }

    private func handleGenericFailure(_ error: Error) {
        lastSetupError = error
        Tracker.shared.track(.onboardingCompletionFailed, error: error.localizedDescription)

        if Self.failureCount >= 2 {
            showSupportButton()
            showCriticalError(
                title: "Setup Failed",
                message: "We're having trouble completing your setup. Please contact support for assistance.",
                canRetry: false,
                error: error
            )
        } else {
            let presentation = OnboardingSetupErrorPresentation.presentation(for: error)
            showCriticalError(
                title: presentation.alertTitle,
                message: presentation.alertMessage,
                canRetry: true,
                error: error
            )
        }
    }

    private func showCriticalError(title: String, message: String, canRetry: Bool, error: Error) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        if canRetry {
            alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
                self?.beginFinishFlow()
            })
        }

        alert.addAction(UIAlertAction(title: "Back", style: .cancel) { [weak self] _ in
            let navigationError = self?.lastSetupError ?? error
            (self?.coordinator as? OnboardingCoordinator)?.handleErrorNavigation(navigationError)
        })

        present(alert, animated: true)
    }

    private func showWarningAndContinue(title: String, message: String, continueAction: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            continueAction()
        })

        present(alert, animated: true)
    }
    
    override func setupContent() {
        view.addSubview(activityIndicator)

        if isSitterFinish {
            view.addSubview(glowView3)
            view.addSubview(glowView2)
            view.addSubview(glowView)
            addChild(inviteCarouselHostingController)
            view.addSubview(inviteCarouselHostingController.view)
            inviteCarouselHostingController.didMove(toParent: self)
        } else {
            // Glow views go behind the card
            view.addSubview(glowView3)
            view.addSubview(glowView2)
            view.addSubview(glowView)
            view.addSubview(nestCreationCardView)
        }

        view.addSubview(slideToEnterView)
        view.addSubview(supportButton)

        if isSitterFinish {
            carouselCenterYConstraint = inviteCarouselHostingController.view.centerYAnchor.constraint(
                equalTo: view.bottomAnchor,
                constant: 200
            )

            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                activityIndicator.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 44),
                activityIndicator.heightAnchor.constraint(equalToConstant: 100),
                activityIndicator.widthAnchor.constraint(equalToConstant: 100),

                inviteCarouselHostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                inviteCarouselHostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                inviteCarouselHostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                carouselCenterYConstraint!,
                inviteCarouselHostingController.view.heightAnchor.constraint(equalToConstant: 302),

                glowView.centerXAnchor.constraint(equalTo: inviteCarouselHostingController.view.centerXAnchor),
                glowView.centerYAnchor.constraint(equalTo: inviteCarouselHostingController.view.centerYAnchor),
                glowView.widthAnchor.constraint(equalToConstant: 280 * 1.05),
                glowView.heightAnchor.constraint(equalToConstant: 290 * 0.6),

                glowView2.centerXAnchor.constraint(equalTo: inviteCarouselHostingController.view.centerXAnchor),
                glowView2.centerYAnchor.constraint(equalTo: inviteCarouselHostingController.view.centerYAnchor),
                glowView2.widthAnchor.constraint(equalToConstant: 280 * 1.1),
                glowView2.heightAnchor.constraint(equalToConstant: 290 * 0.7),

                glowView3.centerXAnchor.constraint(equalTo: inviteCarouselHostingController.view.centerXAnchor),
                glowView3.centerYAnchor.constraint(equalTo: inviteCarouselHostingController.view.centerYAnchor),
                glowView3.widthAnchor.constraint(equalToConstant: 280 * 1.15),
                glowView3.heightAnchor.constraint(equalToConstant: 290 * 0.8),

                slideToEnterView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
                slideToEnterView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
                slideToEnterView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

                supportButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                supportButton.topAnchor.constraint(equalTo: inviteCarouselHostingController.view.bottomAnchor, constant: 60),
                supportButton.heightAnchor.constraint(equalToConstant: 44),
                supportButton.widthAnchor.constraint(equalToConstant: 200),
            ])
        } else {
            // Start card off-screen at the bottom
            cardBottomConstraint = nestCreationCardView.centerYAnchor.constraint(equalTo: view.bottomAnchor, constant: 200)

            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                activityIndicator.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 44),
                activityIndicator.heightAnchor.constraint(equalToConstant: 100),
                activityIndicator.widthAnchor.constraint(equalToConstant: 100),

                nestCreationCardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                cardBottomConstraint!,
                nestCreationCardView.widthAnchor.constraint(equalToConstant: 280),
                nestCreationCardView.heightAnchor.constraint(equalToConstant: 350),

                // Inner glow view
                glowView.centerXAnchor.constraint(equalTo: nestCreationCardView.centerXAnchor),
                glowView.centerYAnchor.constraint(equalTo: nestCreationCardView.centerYAnchor),
                glowView.widthAnchor.constraint(equalTo: nestCreationCardView.widthAnchor, multiplier: 1.05),
                glowView.heightAnchor.constraint(equalTo: nestCreationCardView.heightAnchor, multiplier: 0.6),

                glowView2.centerXAnchor.constraint(equalTo: nestCreationCardView.centerXAnchor),
                glowView2.centerYAnchor.constraint(equalTo: nestCreationCardView.centerYAnchor),
                glowView2.widthAnchor.constraint(equalTo: nestCreationCardView.widthAnchor, multiplier: 1.1),
                glowView2.heightAnchor.constraint(equalTo: nestCreationCardView.heightAnchor, multiplier: 0.7),

                glowView3.centerXAnchor.constraint(equalTo: nestCreationCardView.centerXAnchor),
                glowView3.centerYAnchor.constraint(equalTo: nestCreationCardView.centerYAnchor),
                glowView3.widthAnchor.constraint(equalTo: nestCreationCardView.widthAnchor, multiplier: 1.15),
                glowView3.heightAnchor.constraint(equalTo: nestCreationCardView.heightAnchor, multiplier: 0.8),

                slideToEnterView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
                slideToEnterView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
                slideToEnterView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

                supportButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                supportButton.topAnchor.constraint(equalTo: nestCreationCardView.bottomAnchor, constant: 60),
                supportButton.heightAnchor.constraint(equalToConstant: 44),
                supportButton.widthAnchor.constraint(equalToConstant: 200),
            ])
        }

        // Override slider's internal alpha (HorizontalSliderView sets alpha = 1.0 in resetPosition)
        slideToEnterView.alpha = 0
    }
    
    private func configureGlowShadowPaths(cardWidth: CGFloat, cardHeight: CGFloat) {
        let glowLayers: [(UIView, CGFloat, CGFloat)] = [
            (glowView, 1.05, 0.6),
            (glowView2, 1.1, 0.7),
            (glowView3, 1.15, 0.8)
        ]

        for (view, widthMultiplier, heightMultiplier) in glowLayers {
            let width = cardWidth * widthMultiplier
            let height = cardHeight * heightMultiplier
            view.layer.shadowPath = UIBezierPath(
                ovalIn: CGRect(x: 0, y: 0, width: width, height: height)
            ).cgPath
        }
    }

    private func updateGlowTint(_ color: UIColor) {
        [glowView, glowView2, glowView3].forEach { view in
            view.layer.removeAnimation(forKey: "shadowColor")
            view.layer.shadowColor = color.cgColor
        }
    }

    private func playSuccessTransition() {
        Self.resetFailureCount()

        if !isSitterFinish {
            let nestName = "Your Nest"
            nestCreationCardView.configure(nestName: nestName, createdDate: Date())
        }

        animateSuccessSequence()
    }

    private func animateSuccessSequence() {
        UIView.animate(withDuration: 0.3) {
            self.activityIndicator.alpha = 0
        }
        
        UIView.animate(withDuration: 0.3) {
            self.titleLabel.alpha = 0.0
            self.subtitleLabel.alpha = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.animateCardEntrance()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            self.animateSlideToEnterEntrance()
        }
    }

    private func animateCardEntrance() {
        guard !hasStartedCardAnimation else { return }
        hasStartedCardAnimation = true

        if isSitterFinish {
            configureGlowShadowPaths(cardWidth: 280, cardHeight: 290)
            if let initialTint = SitterFinishCarouselMockData.items.first?.bannerTintColor {
                updateGlowTint(initialTint)
            }
            inviteCarouselHostingController.view.alpha = 1
            glowView.alpha = 1.0
            glowView2.alpha = 1.0
            glowView3.alpha = 1.0

            carouselCenterYConstraint?.isActive = false
            carouselCenterYConstraint = inviteCarouselHostingController.view.centerYAnchor.constraint(
                equalTo: view.centerYAnchor,
                constant: 20
            )
            carouselCenterYConstraint?.isActive = true

            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                self.view.layoutIfNeeded()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
                guard let self else { return }
                ExplosionManager.trigger(.atomic, at: CGPoint(x: view.center.x, y: view.frame.maxY))
                HapticsHelper.lightHaptic()
            }
            return
        }

        configureGlowShadowPaths(cardWidth: 280, cardHeight: 350)
        nestCreationCardView.alpha = 1
        nestCreationCardView.transform = CGAffineTransform(rotationAngle: 2 * .pi / 180)
        glowView.alpha = 1.0
        glowView2.alpha = 1.0
        glowView3.alpha = 1.0

        cardBottomConstraint?.isActive = false
        cardBottomConstraint = nestCreationCardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 0)
        cardBottomConstraint?.isActive = true

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.view.layoutIfNeeded()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            guard let self else { return }
            ExplosionManager.trigger(.atomic, at: CGPoint(x: view.center.x, y: view.frame.maxY))
            HapticsHelper.lightHaptic()
        }
    }

    private func animateSlideToEnterEntrance() {
        guard !hasStartedSlideAnimation else { return }
        hasStartedSlideAnimation = true

        if isSitterFinish {
            self.titleLabel.text = "You're ready to sit!"
            self.subtitleLabel.text = "Join sessions with an invite code—or send a session request to a family."
            self.slideToEnterView.slideTitle = "Slide to Get Started"
        } else {
            self.titleLabel.text = "Your nest has been created!"
            self.subtitleLabel.text = "Swipe below to enter your nest."
            self.slideToEnterView.slideTitle = "Slide to Enter"
        }

        self.slideToEnterView.isHidden = false
        self.slideToEnterView.alpha = 0.0

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2) {
            self.titleLabel.alpha = 1
            self.subtitleLabel.alpha = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.slideToEnterView.alpha = 0.0

            UIView.animate(withDuration: 0.4) {
                self.slideToEnterView.alpha = 1.0
            }
        }
    }

    private func handleSlideComplete() {
        glowView.layer.removeAllAnimations()
        glowView2.layer.removeAllAnimations()
        glowView3.layer.removeAllAnimations()

        UIView.animate(withDuration: 0.5) {
            if self.isSitterFinish {
                self.inviteCarouselHostingController.view.alpha = 0
                self.glowView.alpha = 0
                self.glowView2.alpha = 0
                self.glowView3.alpha = 0
            } else {
                self.nestCreationCardView.alpha = 0
                self.glowView.alpha = 0
                self.glowView2.alpha = 0
                self.glowView3.alpha = 0
            }
            self.slideToEnterView.alpha = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.isDebugMode {
                self.dismiss(animated: true)
            } else {
                (self.coordinator as? OnboardingCoordinator)?.completeOnboarding()
                RatingManager.shared.trackOnboardingComplete()
            }
        }
    }

    func enableDebugMode() {
        isDebugMode = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.playSuccessTransition()
        }
    }

    func enableSitterDebugMode() {
        isDebugMode = true
        debugForceSitterFinish = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.playSuccessTransition()
        }
    }

    private func showSupportButton() {
        supportButton.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.supportButton.alpha = 1.0
        }
    }

    @objc private func supportButtonTapped() {
        guard MFMailComposeViewController.canSendMail() else {
            showMailNotAvailableAlert()
            return
        }

        let filteredLogs = getFilteredLogs()
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        mailComposer.setToRecipients(["support@nestnoteapp.com"])
        mailComposer.setSubject("Nest Setup Issue - User ID: \(UserService.shared.currentUser?.id ?? "Unknown")")

        let messageBody = """
        NestNote Support,

        I'm experiencing issues completing my nest setup. The process has failed \(Self.failureCount) times.

        Please find the relevant logs below:

        \(filteredLogs)
        """

        mailComposer.setMessageBody(messageBody, isHTML: false)

        present(mailComposer, animated: true)
    }

    private func getFilteredLogs() -> String {
        let relevantCategories: Set<String> = [
            Logger.Category.launcher.rawValue,
            Logger.Category.auth.rawValue,
            Logger.Category.signup.rawValue,
            Logger.Category.userService.rawValue,
            Logger.Category.nestService.rawValue
        ]

        let filteredLines = Logger.shared.lines.filter { logLine in
            relevantCategories.contains(logLine.category) ||
            logLine.content.contains("🎯") ||
            logLine.content.contains("🏗️") ||
            logLine.content.contains("🏠") ||
            logLine.content.contains("💾") ||
            logLine.content.contains("error") ||
            logLine.content.contains("Error") ||
            logLine.content.contains("failed") ||
            logLine.content.contains("Failed")
        }

        let last50Lines = Array(filteredLines.suffix(50))

        return last50Lines.map { "\($0.timestamp) [\($0.level.rawValue.uppercased())] \($0.description)" }.joined(separator: "\n")
    }

    private func showMailNotAvailableAlert() {
        let alert = UIAlertController(
            title: "Mail Not Available",
            message: "Please configure a mail account in Settings to send support emails.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}


// MARK: - MFMailComposeViewControllerDelegate
extension OBFinishViewController {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
        
        switch result {
        case .sent:
            Logger.log(level: .info, category: .signup, message: "🎯 FINISH: Support email sent successfully")
        case .cancelled:
            Logger.log(level: .info, category: .signup, message: "🎯 FINISH: Support email cancelled")
        case .failed:
            Logger.log(level: .error, category: .signup, message: "🎯 FINISH: Support email failed to send")
        default:
            break
        }
    }
}
