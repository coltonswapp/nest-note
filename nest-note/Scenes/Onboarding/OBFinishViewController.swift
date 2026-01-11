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
        indicator.configure(with: NNColors.primaryAlt)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private lazy var successImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(systemName: "checkmark")
        imageView.tintColor = .systemGreen
        imageView.isHidden = true
        imageView.alpha = 0
        return imageView
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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Get user role to customize loading text
        let userRole = (coordinator as? OnboardingCoordinator)?.currentRole ?? .nestOwner

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
        beginFinishFlow()
    }
    
    private func beginFinishFlow() {
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
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 44),
            activityIndicator.heightAnchor.constraint(equalToConstant: 100),
            activityIndicator.widthAnchor.constraint(equalToConstant: 100),
        ])

        view.addSubview(successImageView)
        
        NSLayoutConstraint.activate([
            successImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            successImageView.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 44),
            successImageView.heightAnchor.constraint(equalToConstant: 100),
            successImageView.widthAnchor.constraint(equalToConstant: 100),
        ])

        view.addSubview(supportButton)

        NSLayoutConstraint.activate([
            supportButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            supportButton.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 160),
            supportButton.heightAnchor.constraint(equalToConstant: 44),
            supportButton.widthAnchor.constraint(equalToConstant: 200),
        ])
    }
    
    private func playSuccessTransition() {
        // Reset failure count on success
        Self.resetFailureCount()

        // Get user role to determine which success screen to show
        let userRole = (coordinator as? OnboardingCoordinator)?.currentRole ?? .nestOwner

        // Configure the card based on user role
        if userRole == .sitter {
            // For sitters, use the sitter-specific configuration
            nestCreationCardView.configureForNewSitter()
        } else {
            // For nest owners, show their nest name
            let nestName = (coordinator as? OnboardingCoordinator)?.currentNestName ?? "Your Nest"
            nestCreationCardView.configure(nestName: nestName, createdDate: Date())
        }

        // Start the beautiful animation sequence
        animateSuccessSequence()
    }

    private func animateSuccessSequence() {
        // Phase 1: Hide loading indicator (0.3s)
        UIView.animate(withDuration: 0.3) {
            self.activityIndicator.alpha = 0
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

        // Get user role to customize the text
        let userRole = (coordinator as? OnboardingCoordinator)?.currentRole ?? .nestOwner

        if userRole == .sitter {
            self.titleLabel.text = "Welcome to NestNote!"
            self.subtitleLabel.text = "Swipe below to start exploring."
        } else {
            self.titleLabel.text = "Your nest has been created!"
            self.subtitleLabel.text = "Swipe below to enter your nest."
        }

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
