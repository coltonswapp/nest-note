//
//  OBFinishViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 7/8/25.
//

import UIKit
import MessageUI

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

    // Nest Creation Card
    private lazy var nestCreationCardView: NestCreationCardView = {
        let cardView = NestCreationCardView()
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.alpha = 0 // Start hidden
        return cardView
    }()

    // Glow effect behind the card - creates actual glowing effect with shadows
    private lazy var glowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.clear
        view.alpha = 0

        // Create a shadow path for the glow effect
        view.layer.shadowColor = NNColors.primary.cgColor
        view.layer.shadowOffset = CGSize.zero
        view.layer.shadowRadius = 40
        view.layer.shadowOpacity = 0.8
        view.layer.masksToBounds = false

        // Set shadow path to oval following card proportions - remove async to prevent layout conflicts
        let width = 280 * 1.05  // Card width * multiplier
        let height = 350 * 0.6  // Card height * multiplier
        let shadowPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: width, height: height))
        view.layer.shadowPath = shadowPath.cgPath

        return view
    }()

    // Secondary glow layer with larger radius
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

        // Set shadow path to oval following card proportions - remove async to prevent layout conflicts
        let width = 280 * 1.1  // Card width * multiplier
        let height = 350 * 0.7 // Card height * multiplier
        let shadowPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: width, height: height))
        view.layer.shadowPath = shadowPath.cgPath

        return view
    }()

    // Outermost glow layer for maximum effect
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

        // Set shadow path to oval following card proportions - remove async to prevent layout conflicts
        let width = 280 * 1.15  // Card width * multiplier
        let height = 350 * 0.8  // Card height * multiplier
        let shadowPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: width, height: height))
        view.layer.shadowPath = shadowPath.cgPath

        return view
    }()

    // Slide to Enter
    private lazy var slideToEnterView: HorizontalSliderView = {
        let slider = HorizontalSliderView()
        slider.isHidden = true
        slider.onSlideComplete = { [weak self] in
            self?.handleSlideComplete()
        }
        return slider
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

    // State management
    private var isDebugMode = false
    private var cardBottomConstraint: NSLayoutConstraint?
    private var hasStartedSlideAnimation = false
    private var hasStartedCardAnimation = false

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOnboarding(
            title: "Finishing up...",
            subtitle: "Gathering twigs, grass, and leaves for your nest..."
        )
        
        setupContent()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        beginFinishFlow()
    }
    
    private func beginFinishFlow() {
        // Reset spinner if this is a retry after failure
        activityIndicator.reset()
        
        // Hide success image if it was shown
//        successImageView.isHidden = true
//        successImageView.alpha = 0
        
        Task {
            do {
                // Signal to coordinator we're ready to finish
                try await (coordinator as? OnboardingCoordinator)?.finishSetup()

                // If we get here, signup was successful
                activityIndicator.animateState(success: true) {
                    (self.coordinator as? OnboardingCoordinator)?.updateProgressTo(1.0)
                    self.playSuccessTransition()
                }
            } catch {
                await MainActor.run {
                    self.handleSetupFailure(error)
                }
            }
        }
    }

    private func handleSetupFailure(_ error: Error) {
        // Increment failure count
        Self.failureCount += 1

        Logger.log(level: .error, category: .signup, message: "🎯 FINISH: Setup failed (attempt \(Self.failureCount)): \(error.localizedDescription)")

        // Hide loading state
        activityIndicator.animateState(success: false)

        // Handle different types of errors
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

        // Provide specific user feedback based on what failed
        switch failedAtStep {
        case "profile_creation":
            // Critical failure - profile couldn't be created
            showCriticalError(
                title: "Account Creation Failed",
                message: "We couldn't create your account. Please check your connection and try again.",
                canRetry: true
            )
            Tracker.shared.track(.userProfileCreationFailed, error: underlyingError.localizedDescription)

        case "referral_recording":
            // Non-critical - show warning but allow continuation
            showWarningAndContinue(
                title: "Referral Issue",
                message: "We couldn't process your referral code, but your account was created successfully.",
                continueAction: { [weak self] in
                    self?.playSuccessTransition()
                }
            )

        case "survey_submission":
            // Non-critical - show warning but allow continuation
            showWarningAndContinue(
                title: "Survey Submission Failed",
                message: "Your account was created, but we couldn't save your survey responses. You can complete them later in settings.",
                continueAction: { [weak self] in
                    self?.playSuccessTransition()
                }
            )

        case "onboarding_completion", "delegate_notification":
            // Critical but profile exists - this is a state issue
            showCriticalError(
                title: "Setup Incomplete",
                message: "Your account was created but setup couldn't be completed. Please restart the app.",
                canRetry: false
            )

        default:
            handleGenericFailure(underlyingError)
        }
    }

    private func handleGenericFailure(_ error: Error) {
        // Track failure
        Tracker.shared.track(.onboardingCompletionFailed, error: error.localizedDescription)

        // Show support button if failed 2+ times
        if Self.failureCount >= 2 {
            showSupportButton()
            showCriticalError(
                title: "Setup Failed",
                message: "We're having trouble completing your setup. Please contact support for assistance.",
                canRetry: false
            )
        } else {
            showCriticalError(
                title: "Setup Failed",
                message: "Something went wrong during setup. Please try again.",
                canRetry: true
            )
        }
    }

    private func showCriticalError(title: String, message: String, canRetry: Bool) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        if canRetry {
            alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
                self?.beginFinishFlow()
            })
        }

        alert.addAction(UIAlertAction(title: "Back", style: .cancel) { [weak self] _ in
            (self?.coordinator as? OnboardingCoordinator)?.handleErrorNavigation(AuthError.unknown)
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
        // Add glow layers in proper order (back to front)
        view.addSubview(glowView3)          // Outermost glow (largest radius)
        view.addSubview(glowView2)          // Medium glow
        view.addSubview(glowView)           // Core glow (smallest radius)

        // Add nest creation card (on top of glow)
        view.addSubview(nestCreationCardView)

        // Add activity indicator
        view.addSubview(activityIndicator)

        // Add slide to enter
        view.addSubview(slideToEnterView)

        // Add support button
        view.addSubview(supportButton)

        // Add card constraints - start offscreen
        cardBottomConstraint = nestCreationCardView.topAnchor.constraint(equalTo: view.bottomAnchor, constant: 100)

        NSLayoutConstraint.activate([
            // Activity indicator (shown during loading)
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 44),
            activityIndicator.heightAnchor.constraint(equalToConstant: 100),
            activityIndicator.widthAnchor.constraint(equalToConstant: 100),

            // Nest creation card - start offscreen
            nestCreationCardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nestCreationCardView.widthAnchor.constraint(equalToConstant: 280),
            nestCreationCardView.heightAnchor.constraint(equalToConstant: 350),
            cardBottomConstraint!,

            // Core glow view - just slightly larger than card
            glowView.centerXAnchor.constraint(equalTo: nestCreationCardView.centerXAnchor),
            glowView.centerYAnchor.constraint(equalTo: nestCreationCardView.centerYAnchor),
            glowView.widthAnchor.constraint(equalTo: nestCreationCardView.widthAnchor, multiplier: 1.05),
            glowView.heightAnchor.constraint(equalTo: nestCreationCardView.heightAnchor, multiplier: 0.6),

            // Secondary glow view - medium glow
            glowView2.centerXAnchor.constraint(equalTo: nestCreationCardView.centerXAnchor),
            glowView2.centerYAnchor.constraint(equalTo: nestCreationCardView.centerYAnchor),
            glowView2.widthAnchor.constraint(equalTo: nestCreationCardView.widthAnchor, multiplier: 1.1),
            glowView2.heightAnchor.constraint(equalTo: nestCreationCardView.heightAnchor, multiplier: 0.7),

            // Outer glow view - subtle outer glow
            glowView3.centerXAnchor.constraint(equalTo: nestCreationCardView.centerXAnchor),
            glowView3.centerYAnchor.constraint(equalTo: nestCreationCardView.centerYAnchor),
            glowView3.widthAnchor.constraint(equalTo: nestCreationCardView.widthAnchor, multiplier: 1.15),
            glowView3.heightAnchor.constraint(equalTo: nestCreationCardView.heightAnchor, multiplier: 0.8),

            // Slide to enter - pinned to bottom, full width with margins
            slideToEnterView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            slideToEnterView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            slideToEnterView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            // Support button
            supportButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            supportButton.topAnchor.constraint(equalTo: nestCreationCardView.bottomAnchor, constant: 60),
            supportButton.heightAnchor.constraint(equalToConstant: 44),
            supportButton.widthAnchor.constraint(equalToConstant: 200),
        ])

        // Shadow paths are set during view initialization - no additional layout needed

        // IMPORTANT: Override slider's internal alpha setting after all constraints are set
        // The HorizontalSliderView sets self.alpha = 1.0 in resetPosition() during setup
        slideToEnterView.alpha = 0
    }
    
    private func playSuccessTransition() {
        // Reset failure count on success
        Self.resetFailureCount()

        // Configure the card with nest information
        let nestName = (coordinator as? OnboardingCoordinator)?.currentNestName ?? "Your Nest"
        nestCreationCardView.configure(nestName: nestName, createdDate: Date())

        // Start the beautiful animation sequence
        animateSuccessSequence()
    }

    private func animateSuccessSequence() {
        // Phase 1: Hide loading indicator (0.3s)
        UIView.animate(withDuration: 0.3) {
            self.activityIndicator.alpha = 0
        }
        
        UIView.animate(withDuration: 0.3) {
            self.titleLabel.alpha = 0.0
            self.subtitleLabel.alpha = 0.0
        }

        // Phase 2: Show and animate card with glow (starting at 0.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.animateCardEntrance()
        }

        // Phase 3: Show slide to enter (starting at 1.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            self.animateSlideToEnterEntrance()
        }
    }

    private func animateCardEntrance() {
        // Guard against double execution
        guard !hasStartedCardAnimation else {
            return
        }
        hasStartedCardAnimation = true

        // First make it visible and add slight rotation
        nestCreationCardView.alpha = 1
        nestCreationCardView.transform = CGAffineTransform(rotationAngle: 2 * .pi / 180)
        glowView.alpha = 1.0
        glowView2.alpha = 1.0
        glowView3.alpha = 1.0

        // Remove current constraint and add new one (copied from JoinSessionViewController)
        cardBottomConstraint?.isActive = false
        cardBottomConstraint = nestCreationCardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 0)
        cardBottomConstraint?.isActive = true

        // Animate it up from the bottom with spring effect (copied from JoinSessionViewController)
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
        // Guard against double execution
        guard !hasStartedSlideAnimation else {
            return
        }
        hasStartedSlideAnimation = true

        self.titleLabel.text = "Your nest has been created!"
        self.subtitleLabel.text = "Swipe below to enter your nest."

        // Keep it hidden, only use alpha for fade-in control
        self.slideToEnterView.isHidden = false
        self.slideToEnterView.alpha = 0.0
        

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2) {
            self.titleLabel.alpha = 1
            self.subtitleLabel.alpha = 1
        }

        // Simple fade in for slide-to-enter (no transform animation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Ensure alpha is 0 right before animation (override any internal slider logic)
            self.slideToEnterView.alpha = 0.0

            UIView.animate(withDuration: 0.4) {
                self.slideToEnterView.alpha = 1.0
            }
        }
    }

    private func handleSlideComplete() {
        // Stop all animations
        glowView.layer.removeAllAnimations()
        glowView2.layer.removeAllAnimations()
        glowView3.layer.removeAllAnimations()

        // Fade out all elements
        UIView.animate(withDuration: 0.5) {
            self.nestCreationCardView.alpha = 0
            self.glowView.alpha = 0
            self.glowView2.alpha = 0
            self.glowView3.alpha = 0
            self.slideToEnterView.alpha = 0
        }

        // Complete onboarding after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.isDebugMode {
                // In debug mode, just dismiss
                self.dismiss(animated: true)
            } else {
                // Normal flow - complete onboarding
                (self.coordinator as? OnboardingCoordinator)?.completeOnboarding()
            }
        }
    }

    // Add method to enable debug mode
    func enableDebugMode() {
        isDebugMode = true
        // Start directly with success animation for testing
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
