//
//  OnboardingCoordinator.swift
//  nest-note
//
//  Created by Colton Swapp on 11/4/24.
//

import UIKit
import Combine
import AuthenticationServices

protocol OnboardingCoordinatorDelegate: AnyObject {
    func onboardingDidComplete()
}

final class OnboardingCoordinator: NSObject, UINavigationControllerDelegate, OnboardingContainerDelegate {
    
    // MARK: - Properties
    private let navigationController: UINavigationController
    private weak var delegate: OnboardingCoordinatorDelegate?
    weak var authenticationDelegate: AuthenticationDelegate?
    private var containerViewController: OnboardingContainerViewController!
    
    private var currentStepIndex: Int = 0
    private lazy var steps: [NNOnboardingViewController] = {
        // Start with the new image-based onboarding screens
        var baseSteps: [NNOnboardingViewController] = [
            NNImageOnboardingViewController(content: .aboutNestNote),
            NNImageOnboardingViewController(content: .createSessions),
            NNImageOnboardingViewController(content: .pickAndChoose),
            NNImageOnboardingViewController(content: .inviteWithEase)
        ]
        
        // Add the original onboarding steps
        baseSteps.append(contentsOf: [
            OBNameViewController(),
            OBRoleViewController(),
            OBReferralViewController()  // Add referral step after role selection
        ])
        
        // Add remaining steps
        baseSteps.append(contentsOf: [
            OBEmailViewController(),
            OBPasswordViewController()
        ])
        
        return baseSteps
    }()
    
    private var allSteps: [NNOnboardingViewController] {
        return steps
    }
    
    // MARK: - User Information
    private var userInfo = UserOnboardingInfo()
    private var appleCredential: ASAuthorizationAppleIDCredential?
    private var isStartingWithApple = false
    
    struct UserOnboardingInfo {
        var fullName: String = ""
        var email: String = ""
        var password: String = ""
        var role: NestUser.UserType = .nestOwner
        var nestInfo: NestInfo?
        var surveyResponses: [String: [String]] = [:]
        var isAppleSignIn: Bool = false
        var referralCode: String?
        
        struct NestInfo {
            var name: String?
            var address: String?
        }
    }
    
    // Public accessor for role
    var currentRole: NestUser.UserType {
        return userInfo.role
    }
    
    // MARK: - Validation Publishers
    private let nameValidationSubject = CurrentValueSubject<Bool, Never>(false)
    private let emailValidationSubject = CurrentValueSubject<Bool, Never>(false)
    private let passwordValidationSubject = PassthroughSubject<PasswordValidation, Never>()
    private let roleValidationSubject = CurrentValueSubject<Bool, Never>(false)
    private let nestValidationSubject = CurrentValueSubject<Bool, Never>(false)
    
    // Expose publishers for views to subscribe to
    var nameValidation: AnyPublisher<Bool, Never> {
        nameValidationSubject.eraseToAnyPublisher()
    }
    
    var emailValidation: AnyPublisher<Bool, Never> {
        emailValidationSubject.eraseToAnyPublisher()
    }
    
    struct PasswordValidation {
        let isValid: Bool
        let hasMinLength: Bool
        let hasCapital: Bool
        let hasNumber: Bool
        let hasSymbol: Bool
        let passwordsMatch: Bool
    }
    
    var passwordValidation: AnyPublisher<PasswordValidation, Never> {
        passwordValidationSubject.eraseToAnyPublisher()
    }
    
    var roleValidation: AnyPublisher<Bool, Never> {
        roleValidationSubject.eraseToAnyPublisher()
    }
    
    var nestValidation: AnyPublisher<Bool, Never> {
        nestValidationSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init(delegate: OnboardingCoordinatorDelegate? = nil) {
        self.navigationController = UINavigationController()
        self.delegate = delegate
        
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        
        navigationController.navigationBar.isHidden = true
        
        super.init()
        
        // Create container with base steps initially
        self.containerViewController = OnboardingContainerViewController(
            navigationController: navigationController,
            totalSteps: steps.count + 1  // +1 for finish step
        )
        
        // Set container delegate
        self.containerViewController.delegate = self
        
        // Add navigation controller delegate
        navigationController.delegate = self
    }
    
    // MARK: - Coordination
    func start() -> UIViewController {
        configureInitialStep()
        #if DEBUG
        setupDebugMode()
        #endif
        return containerViewController
    }
    
    private func configureInitialStep() {
        // If we're starting with Apple Sign In, don't configure initial step yet
        // The Apple credential handler will configure the appropriate step
        if isStartingWithApple {
            return
        }
        
        guard let initialStep = steps.first else { return }
        currentStepIndex = 0
        configureStep(initialStep)
        navigationController.setViewControllers([initialStep], animated: false)
    }
    
    private func configureStep(_ viewController: NNOnboardingViewController) {
        viewController.coordinator = self
        
        // Update container's survey status based on current step
        let isSurveyStep = viewController is NNOnboardingSurveyViewController
        containerViewController.updateSurveyStatus(isSurveyStep)
    }
    
    // MARK: - Navigation
    func next() {
        guard let currentVC = navigationController.topViewController as? NNOnboardingViewController,
              validateStep(currentVC) else {
            return
        }
        
        currentStepIndex += 1
        
        if currentStepIndex < allSteps.count {
            let nextStep = allSteps[currentStepIndex]
            configureStep(nextStep)
            navigationController.pushViewController(nextStep, animated: true)
            // Update progress after the push animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.containerViewController.updateProgress(step: self.currentStepIndex)
            }
        } else {
            completeOnboarding()
        }
    }
    
    @objc private func handleBackTapped() {
        currentStepIndex -= 1
        navigationController.popViewController(animated: true)
        containerViewController.updateProgress(step: currentStepIndex)
    }
    
    func updateProgressTo(_ progress: Float) {
        containerViewController.setProgessTo(progress: progress)
    }
    
    func completeOnboarding() {
        navigationController.dismiss(animated: true)
    }
    
    // MARK: - Validation
    private func validateStep(_ viewController: NNOnboardingViewController) -> Bool {
        // Override this method to add validation logic for each step
        // For example:
        switch viewController {
        case is NNImageOnboardingViewController:
            return true // Image onboarding screens don't need validation
        case is OBNameViewController:
            return validateNameStep(viewController as! OBNameViewController)
        default:
            return true
        }
    }
    
    private func validateNameStep(_ viewController: OBNameViewController) -> Bool {
        // Add validation logic here
        return true
    }
    
    // Add UINavigationControllerDelegate method
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        // Update currentStepIndex based on the visible view controller
        if let index = steps.firstIndex(where: { $0 === viewController }) {
            currentStepIndex = index
            containerViewController.updateProgress(step: currentStepIndex)
        }
        
        // Update survey status when navigating
        if let onboardingVC = viewController as? NNOnboardingViewController {
            let isSurveyStep = onboardingVC is NNOnboardingSurveyViewController
            containerViewController.updateSurveyStatus(isSurveyStep)
        }
    }
    
    func finishSetup() async throws {
        Logger.log(level: .info, category: .signup, message: "🎯 FINISH SETUP: Starting finish setup process")
        Logger.log(level: .info, category: .signup, message: "🎯 FINISH SETUP: User role: \(userInfo.role), Apple sign in: \(userInfo.isAppleSignIn)")

        #if DEBUG
        if isDebugMode {
            Logger.log(level: .info, category: .signup, message: "🎯 FINISH SETUP: Debug mode enabled - using mock flow")
            try await Task.sleep(for: .seconds(2))
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            self.authenticationDelegate?.signUpComplete()
            return
        }
        #endif

        do {
            // First handle the signup logic
            Logger.log(level: .info, category: .signup, message: "🎯 STEP 1: Starting user signup/profile creation...")
            let user: NestUser
            if userInfo.isAppleSignIn {
                // User is already authenticated, just need to complete profile setup
                Logger.log(level: .info, category: .signup, message: "🎯 STEP 1: Using Apple Sign In profile completion")
                user = try await UserService.shared.completeAppleSignUp(with: userInfo)
            } else {
                Logger.log(level: .info, category: .signup, message: "🎯 STEP 1: Using regular email signup")
                user = try await UserService.shared.signUp(with: userInfo)
            }
            Logger.log(level: .info, category: .signup, message: "🎯 STEP 1: ✅ Successfully completed signup for user: \(user.personalInfo.name)")

            // Record referral if one was provided
            if let referralCode = userInfo.referralCode, !referralCode.isEmpty {
                Logger.log(level: .info, category: .signup, message: "🎯 STEP 2: Recording referral code: \(referralCode)")
                do {
                    try await ReferralService.shared.recordReferral(
                        referralCode: referralCode,
                        for: user.id,
                        email: user.personalInfo.email,
                        role: userInfo.role.rawValue
                    )
                    Logger.log(level: .info, category: .signup, message: "🎯 STEP 2: ✅ Successfully recorded referral for code: \(referralCode)")
                    Tracker.shared.track(.referralRecorded)
                } catch {
                    Logger.log(level: .error, category: .signup, message: "🎯 STEP 2: ⚠️ Failed to record referral: \(error)")
                    Tracker.shared.track(.referralRecorded, result: false, error: error.localizedDescription)
                    // Continue with onboarding even if referral fails
                }
            } else {
                Logger.log(level: .info, category: .signup, message: "🎯 STEP 2: No referral code provided, skipping")
            }

            // Save survey responses
            if !userInfo.surveyResponses.isEmpty {
                Logger.log(level: .info, category: .signup, message: "🎯 STEP 3: Submitting survey responses...")
                let response = SurveyResponse(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    surveyType: userInfo.role == .nestOwner ? .parentSurvey : .sitterSurvey,
                    version: "1.0", // TODO: Get from config
                    responses: userInfo.surveyResponses.map { SurveyResponse.QuestionResponse(questionId: $0.key, answers: $0.value) },
                    metadata: [
                        "userId": user.id,
                        "role": userInfo.role.rawValue
                    ]
                )

                do {
                    try await SurveyService.shared.submitSurveyResponse(response)
                    Logger.log(level: .info, category: .signup, message: "🎯 STEP 3: ✅ Successfully submitted survey responses for user: \(user.personalInfo.name)")
                } catch {
                    Logger.log(level: .error, category: .signup, message: "🎯 STEP 3: ⚠️ Failed to submit survey responses: \(error)")
                    // Continue with onboarding even if submission fails
                }
            } else {
                Logger.log(level: .info, category: .signup, message: "🎯 STEP 3: No survey responses to submit, skipping")
            }

            // Set onboarding completion flag
            Logger.log(level: .info, category: .signup, message: "🎯 STEP 4: Setting onboarding completion flag...")
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            Logger.log(level: .info, category: .signup, message: "🎯 STEP 4: ✅ Onboarding completion flag set")

            Logger.log(level: .info, category: .signup, message: "🎯 STEP 5: Notifying authentication delegate...")
            authenticationDelegate?.signUpComplete()
            Logger.log(level: .info, category: .signup, message: "🎯 STEP 5: ✅ Authentication delegate notified")

            Logger.log(level: .info, category: .signup, message: "🎯 ✅ FINISH SETUP COMPLETE: All steps completed successfully!")

        } catch {
            Logger.log(level: .error, category: .signup, message: "🎯 ❌ FINISH SETUP FAILED: \(error.localizedDescription)")
            Logger.log(level: .error, category: .signup, message: "🎯 ❌ Error type: \(type(of: error))")
            Logger.log(level: .error, category: .signup, message: "🎯 ❌ Full error: \(error)")
            Logger.log(level: .error, category: .signup, message: "🎯 ❌ User info - Role: \(userInfo.role), Apple: \(userInfo.isAppleSignIn), Email: \(userInfo.email)")

            // Track the overall finish setup failure
            if userInfo.isAppleSignIn {
                Tracker.shared.track(.appleSignUpAttempted, result: false, error: error.localizedDescription)
            } else {
                Tracker.shared.track(.regularSignUpAttempted, result: false, error: error.localizedDescription)
            }

            throw error
        }
    }
    
    func handleErrorNavigation(_ error: Error) {
        // Handle only the navigation aspect of errors
        // Convert the error to your custom error type if needed
        let authError = error as? AuthError // Assuming you have an AuthError type
        
        // Determine which step to return to based on the error
        let targetStep = steps.first(where: { $0 is OBEmailViewController })
        
        if let targetStep = targetStep,
           let targetIndex = steps.firstIndex(where: { $0 === targetStep }) {
            // Reset subsequent steps
            for index in (targetIndex + 1)..<steps.count {
                steps[index].reset()
            }
            
            currentStepIndex = targetIndex
            navigationController.popToViewController(targetStep, animated: true)
            containerViewController.updateProgress(step: currentStepIndex)
            
            // Show error message on the target view controller
            targetStep.reset()
            targetStep.showToast(delay: 1.5, text: "Whoops!", subtitle: error.localizedDescription, sentiment: .negative)
        }
    }
    
    // MARK: - Update Methods
    func updateUserName(_ name: String) {
        userInfo.fullName = name
    }
    
    func updateEmail(_ email: String) {
        userInfo.email = email
    }
    
    func updatePassword(_ password: String) {
        userInfo.password = password
    }
    
    func updateRole(_ role: NestUser.UserType) {
        userInfo.role = role
        
        // Remove any existing survey steps
        steps.removeAll { $0 is NNOnboardingSurveyViewController }
        
        // Add survey questions based on role
        if let surveyConfig = loadSurveyConfig(for: role) {
            let surveySteps = surveyConfig.questions.map { question -> NNOnboardingSurveyViewController in
                let vc = NNOnboardingSurveyViewController()
                vc.configure(with: question)
                return vc
            }
            
            // Insert survey steps after role selection
            let roleIndex = steps.firstIndex(where: { $0 is OBRoleViewController }) ?? 0
            steps.insert(contentsOf: surveySteps, at: roleIndex + 1)
        }
        
        // Update container's total steps count based on new role
        containerViewController.updateTotalSteps(allSteps.count)
    }
    
    func updateNestInfo(name: String, address: String) {
        userInfo.nestInfo = UserOnboardingInfo.NestInfo(name: name, address: address)
    }
    
    func updateSurveyResponses(_ responses: [String: [String]]) {
        // Merge new responses with existing ones
        userInfo.surveyResponses.merge(responses) { _, new in new }
    }
    
    func updateReferralCode(_ referralCode: String?) {
        userInfo.referralCode = referralCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : referralCode?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Validation Methods
    func validateName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let isValid = !trimmedName.isEmpty && trimmedName.count >= 2
        nameValidationSubject.send(isValid)
        
        if isValid {
            userInfo.fullName = trimmedName
        }
    }
    
    func validateEmail(email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        
        let isValid = !trimmedEmail.isEmpty &&
                     emailPredicate.evaluate(with: trimmedEmail)
        
        emailValidationSubject.send(isValid)
        
        if isValid {
            userInfo.email = trimmedEmail
        }
    }
    
    func validatePassword(password: String, confirmPassword: String) {
        let validation = PasswordValidation(
            isValid: isPasswordValid(password, confirmPassword),
            hasMinLength: password.count >= 6,
            hasCapital: password.range(of: ".*[A-Z]+.*", options: .regularExpression) != nil,
            hasNumber: password.range(of: ".*[0-9]+.*", options: .regularExpression) != nil,
            hasSymbol: password.range(of: ".*[!&^%$#@()/]+.*", options: .regularExpression) != nil,
            passwordsMatch: password == confirmPassword
        )
        
        passwordValidationSubject.send(validation)
        
        if validation.isValid {
            userInfo.password = password
        }
    }
    
    private func isPasswordValid(_ password: String, _ confirmPassword: String) -> Bool {
        return password.count >= 6 &&
               password.range(of: ".*[A-Z]+.*", options: .regularExpression) != nil &&
               password.range(of: ".*[0-9]+.*", options: .regularExpression) != nil &&
               password.range(of: ".*[!&^%$#@()/]+.*", options: .regularExpression) != nil &&
               password == confirmPassword
    }
    
    func validateRole(_ role: NestUser.UserType) {
        roleValidationSubject.send(true)
        updateRole(role)
        
        // Add required steps to the flow when role is selected
        ensureRequiredStepsExist()
    }
    
    private func ensureRequiredStepsExist() {
        // Add nest creation step for owners if it doesn't exist
        if userInfo.role == .nestOwner && !steps.contains(where: { $0 is OBCreateNestViewController }) {
            steps.append(OBCreateNestViewController())
        }
        
        // Add paywall step for nest owners only if it doesn't exist
        if userInfo.role == .nestOwner && !steps.contains(where: { $0 is OBPaywallViewController }) {
            steps.append(OBPaywallViewController())
        }
        
        // Add finish step if it doesn't exist
        if !steps.contains(where: { $0 is OBFinishViewController }) {
            steps.append(OBFinishViewController())
        }
        
        // Update container's step count
        containerViewController.updateTotalSteps(steps.count)
    }
    
    func validateNest(name: String, address: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let isValid = !trimmedName.isEmpty && !trimmedAddress.isEmpty
        nestValidationSubject.send(isValid)
        
        if isValid {
            userInfo.nestInfo = UserOnboardingInfo.NestInfo(name: trimmedName, address: trimmedAddress)
        }
    }
    
    // MARK: - Apple Sign In
    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) {
        // Store the credential for later use
        self.appleCredential = credential
        self.isStartingWithApple = true
        
        // Extract user info from Apple credential
        if let email = credential.email {
            userInfo.email = email
        }
        
        if let fullName = credential.fullName {
            let nameComponents = [fullName.givenName, fullName.familyName].compactMap { $0 }
            userInfo.fullName = nameComponents.joined(separator: " ")
        }
        
        // Mark as Apple sign in
        userInfo.isAppleSignIn = true
        
        // Ensure required steps exist for the default role
        ensureRequiredStepsExist()
        
        // Skip to role selection since we have the user's basic info
        skipToRoleSelection()
    }
    
    func handleAppleSignInMidFlow(credential: ASAuthorizationAppleIDCredential) {
        // Store the credential for later use
        self.appleCredential = credential
        
        // Extract user info from Apple credential
        if let email = credential.email {
            userInfo.email = email
        }
        
        if let fullName = credential.fullName {
            let nameComponents = [fullName.givenName, fullName.familyName].compactMap { $0 }
            userInfo.fullName = nameComponents.joined(separator: " ")
        }
        
        // Mark as Apple sign in
        userInfo.isAppleSignIn = true
        
        // Remove password step since we don't need it for Apple users
        // Keep referral step since they can still use referral codes
        steps.removeAll { $0 is OBPasswordViewController }
        
        // Update container's total steps count
        containerViewController.updateTotalSteps(allSteps.count)
        
        // Continue to next step in the flow
        next()
    }
    
    private func skipToRoleSelection() {
        // For Apple users, remove the email and password steps from the flow
        // Keep the referral step since they can still use referral codes
        steps.removeAll { $0 is OBEmailViewController || $0 is OBPasswordViewController }
        
        // Update container's total steps count
        containerViewController.updateTotalSteps(allSteps.count)
        
        // Find the role selection step
        guard let roleStep = allSteps.first(where: { $0 is OBRoleViewController }),
              let roleIndex = allSteps.firstIndex(where: { $0 === roleStep }) else {
            return
        }
        
        // Clear the navigation stack and set role selection as the root
        currentStepIndex = roleIndex
        configureStep(roleStep)
        
        // Use a small delay to ensure the container is fully presented
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.navigationController.setViewControllers([roleStep], animated: false)
            self.containerViewController.updateProgress(step: self.currentStepIndex)
        }
    }
    
    // MARK: - Survey Configuration
    private func loadSurveyConfig(for role: NestUser.UserType) -> SurveyConfiguration? {
        let configFileName = role == .nestOwner ? "parent_survey_config" : "sitter_survey_config"
        return SurveyConfiguration.loadLocal(named: configFileName)
    }
    
    #if DEBUG
    private var isDebugMode = false
    private var debugTapCount = 0
    private let debugTapThreshold = 3
    private var debugTimer: Timer?
    
    private func setupDebugMode() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDebugTap))
        containerViewController.progressBar.isUserInteractionEnabled = true
        containerViewController.progressBar.addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleDebugTap() {
        debugTapCount += 1
        debugTimer?.invalidate()
        
        if debugTapCount >= debugTapThreshold {
            debugTapCount = 0
            presentDebugOptions()
        } else {
            debugTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                self?.debugTapCount = 0
            }
        }
    }
    
    private func presentDebugOptions() {
        let alert = UIAlertController(title: "Debug Mode", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Enable Debug Mode", style: .default) { [weak self] _ in
            self?.isDebugMode = true
            Logger.log(level: .debug, category: .general, message: "Debug mode enabled for Onboarding")
        })
        
        alert.addAction(UIAlertAction(title: "Skip to Email", style: .default) { [weak self] _ in
            self?.skipToViewController(OBEmailViewController.self)
        })
        
        alert.addAction(UIAlertAction(title: "Skip to Password", style: .default) { [weak self] _ in
            self?.skipToViewController(OBPasswordViewController.self)
        })
        
        alert.addAction(UIAlertAction(title: "Skip to Role", style: .default) { [weak self] _ in
            self?.skipToViewController(OBRoleViewController.self)
        })
        
        alert.addAction(UIAlertAction(title: "Skip to Nest Creation", style: .default) { [weak self] _ in
            self?.userInfo.role = .nestOwner
            self?.skipToViewController(OBCreateNestViewController.self)
        })
        
        alert.addAction(UIAlertAction(title: "Skip to Paywall", style: .default) { [weak self] _ in
            self?.skipToViewController(OBPaywallViewController.self)
        })
        
        alert.addAction(UIAlertAction(title: "Skip to Finalizing", style: .default) { [weak self] _ in
            self?.skipToViewController(OBFinishViewController.self)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        navigationController.present(alert, animated: true)
    }
    
    private func skipToViewController<T: NNOnboardingViewController>(_ viewControllerType: T.Type) {
        isDebugMode = true
        
        // Find the target view controller in allSteps
        guard let targetVC = allSteps.first(where: { $0 is T }) else {
            return
        }
        
        // Configure and show the target step
        configureStep(targetVC)
        navigationController.pushViewController(targetVC, animated: true)
        containerViewController.updateProgress(step: currentStepIndex)
    }
    
    // Modify validateStep to bypass validation in debug mode
    private func ifDebugMode() -> Bool {
        #if DEBUG
        if isDebugMode { return true }
        #endif
        
        return false
    }
    #endif
}

// MARK: - OnboardingContainerDelegate
extension OnboardingCoordinator {
    func onboardingContainerDidRequestAbort(_ container: OnboardingContainerViewController) {
        // Handle abort - go back to login
        navigationController.dismiss(animated: true)
    }
    
    func onboardingContainerDidRequestSkipSurvey(_ container: OnboardingContainerViewController) {
        // Skip all survey steps and move to next non-survey step
        skipSurveySteps()
    }
    
    private func skipSurveySteps() {
        Logger.log(level: .info, category: .general, message: "Skipping survey steps for Apple user: \(userInfo.isAppleSignIn), role: \(userInfo.role)")
        
        // First, remove all survey steps from the current flow
        steps.removeAll { $0 is NNOnboardingSurveyViewController }
        
        // Find the next non-survey step that we should navigate to
        // This should be the first step after the role selection that isn't a survey
        var nextStep: NNOnboardingViewController?
        
        // For Apple Sign In users, email step might not exist, so find the next available step
        if userInfo.isAppleSignIn {
            // Look for the next step after role: could be nest creation (if owner) or finish
            if userInfo.role == .nestOwner {
                nextStep = steps.first { $0 is OBCreateNestViewController }
            } else {
                // For sitters, go directly to finish step since they don't get paywall
                nextStep = steps.first { $0 is OBFinishViewController }
            }
        } else {
            // For regular users, look for the email step (which should be the next step after surveys)
            nextStep = steps.first { $0 is OBEmailViewController }
        }
        
        // Update the container's total steps count after potentially modifying steps
        containerViewController.updateTotalSteps(allSteps.count)
        
        if let targetStep = nextStep {
            Logger.log(level: .info, category: .general, message: "Found target step: \(type(of: targetStep))")
            
            // Check if this step is already in the navigation stack
            let isAlreadyInStack = navigationController.viewControllers.contains { $0 === targetStep }
            
            if !isAlreadyInStack {
                // Find the index of this step in steps for progress tracking
                if let targetIndex = steps.firstIndex(where: { $0 === targetStep }) {
                    currentStepIndex = targetIndex
                    configureStep(targetStep)
                    navigationController.pushViewController(targetStep, animated: true)
                    
                    // Update progress
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.containerViewController.updateProgress(step: self.currentStepIndex)
                    }
                }
            } else {
                // If it's already in the stack, pop back to it
                navigationController.popToViewController(targetStep, animated: true)
                if let targetIndex = steps.firstIndex(where: { $0 === targetStep }) {
                    currentStepIndex = targetIndex
                    containerViewController.updateProgress(step: currentStepIndex)
                }
            }
        } else {
            Logger.log(level: .error, category: .general, message: "No target step found for survey skip")
        }
    }
}

// MARK: - Delegate Example
extension SceneDelegate: OnboardingCoordinatorDelegate {
    func onboardingDidComplete() {
    }
} 
