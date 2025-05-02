//
//  OnboardingCoordinator.swift
//  nest-note
//
//  Created by Colton Swapp on 11/4/24.
//

import UIKit
import Combine

protocol OnboardingCoordinatorDelegate: AnyObject {
    func onboardingDidComplete()
}

final class OnboardingCoordinator: NSObject, UINavigationControllerDelegate {
    
    // MARK: - Properties
    private let navigationController: UINavigationController
    private weak var delegate: OnboardingCoordinatorDelegate?
    weak var authenticationDelegate: AuthenticationDelegate?
    private var containerViewController: OnboardingContainerViewController!
    
    private var currentStepIndex: Int = 0
    private lazy var steps: [NNOnboardingViewController] = {
        // Base steps that are common to all users
        var baseSteps: [NNOnboardingViewController] = [
            OBNameViewController(),
            OBRoleViewController()
        ]
        
        // Add remaining steps
        baseSteps.append(contentsOf: [
            OBEmailViewController(),
            OBPasswordViewController()
        ])
        
        return baseSteps
    }()
    
    private var allSteps: [NNOnboardingViewController] {
        var currentSteps = steps
        
        // Only add nest creation step for parents
        if userInfo.role == .nestOwner {
            currentSteps.append(OBCreateNestViewController())
        }
        
        // Always add finish step last
        currentSteps.append(OBFinishViewController())
        return currentSteps
    }
    
    // MARK: - User Information
    private var userInfo = UserOnboardingInfo()
    
    struct UserOnboardingInfo {
        var fullName: String = ""
        var email: String = ""
        var password: String = ""
        var role: NestUser.UserType = .nestOwner
        var nestInfo: NestInfo?
        var surveyResponses: [String: [String]] = [:]
        
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
        guard let initialStep = steps.first else { return }
        currentStepIndex = 0
        configureStep(initialStep)
        navigationController.setViewControllers([initialStep], animated: false)
    }
    
    private func configureStep(_ viewController: NNOnboardingViewController) {
        
        viewController.coordinator = self
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
    }
    
    func finishSetup() async throws {
        #if DEBUG
        if isDebugMode {
            try await Task.sleep(for: .seconds(2))
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            self.authenticationDelegate?.signUpComplete()
            return
        }
        #endif

        // First handle the signup logic
        let user = try await UserService.shared.signUp(with: userInfo)
        Logger.log(level: .info, category: .signup, message: "Successfully completed signup for user: \(user.personalInfo.name)")
        
        // Save survey responses
        if !userInfo.surveyResponses.isEmpty {
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
                Logger.log(level: .info, category: .survey, message: "Successfully submitted survey responses for user: \(user.personalInfo.name)")
            } catch {
                Logger.log(level: .error, category: .survey, message: "Failed to submit survey responses: \(error)")
                // Continue with onboarding even if submission fails
            }
        }
        
        // Then configure all services
//        Logger.log(level: .info, category: .signup, message: "Moving to configure launcher...")
//        try await Launcher.shared.configure()
        
        // Set onboarding completion flag
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        authenticationDelegate?.signUpComplete()
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
    
    // MARK: - Validation Methods
    func validateName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let isValid = !trimmedName.isEmpty && trimmedName.count >= 2
        nameValidationSubject.send(isValid)
        
        if isValid {
            userInfo.fullName = trimmedName
        }
    }
    
    func validateEmail(email: String, confirmEmail: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirmEmail = confirmEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        
        let isValid = !trimmedEmail.isEmpty && 
                     !trimmedConfirmEmail.isEmpty && 
                     trimmedEmail == trimmedConfirmEmail &&
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

// MARK: - Delegate Example
extension SceneDelegate: OnboardingCoordinatorDelegate {
    func onboardingDidComplete() {
    }
} 
