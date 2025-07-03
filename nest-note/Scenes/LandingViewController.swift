//
//  LandingViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 11/2/24.
//

import UIKit
import AuthenticationServices
import CryptoKit


final class LandingViewController: NNViewController {
    
    // MARK: - UI Elements
    private let topImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .rectanglePattern)
        return view
    }()
    
    private let mainStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 40
        return stack
    }()
    
    private let titleStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()
    
    private let titleImage: UIImageView = {
        let imageView = UIImageView()
        imageView.image = NNImage.primaryLogo
        imageView.tintColor = .label
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome to NestNote"
        label.font = .h1
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "All Your Caregiving Needs, One Secure App"
        label.font = .bodyL
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    // MARK: Carousel & Page Control
    private var pageViewController: UIPageViewController!
    private let pageControl = UIPageControl()
    private let welcomePages: [WelcomePageType] = [.slide4, .slide1, .slide2, .slide3]
    private var currentPageIndex = 0
    
    private lazy var getStartedButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Get Started", image: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(getStartedTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var bottomStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [getStartedButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Keep delegate and keyboard constraint
    weak var delegate: AuthenticationDelegate?
    private var mainStackTopConstraint: NSLayoutConstraint?
    
    override func loadView() {
        setupCarousel()
        super.loadView()
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        #if DEBUG
        setupDebugMode()
        #endif
    }
    
    override func addSubviews() {
        view.addSubview(topImageView)
        // Remove loginStack and email/password fields
//        titleStack.addArrangedSubview(titleLabel)
//        titleStack.addArrangedSubview(subtitleLabel)
//        mainStack.addArrangedSubview(titleStack)
//        view.addSubview(mainStack)
        view.addSubview(getStartedButton)
        // Add carousel and page control
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)
        view.addSubview(pageControl)
        // Add bottom stack
        view.addSubview(bottomStack)
    }
    
    override func constrainSubviews() {
        topImageView.pinToTop(of: view)
        
        // Carousel edge-to-edge
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: topImageView.bottomAnchor, constant: -20),
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        // Page control directly beneath carousel
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageControl.bottomAnchor.constraint(equalTo: bottomStack.topAnchor, constant: -24),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        // Bottom stack pinned to bottom
        NSLayoutConstraint.activate([
            bottomStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            bottomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -0)
        ])
        // Set heights for buttons
        getStartedButton.heightAnchor.constraint(equalToConstant: 55).isActive = true;
    }
    
    @objc private func getStartedTapped() {
        let loginVC = LoginViewController()
        loginVC.delegate = self.delegate
        self.navigationController?.pushViewController(loginVC, animated: true)
    }
    
    // MARK: - Debug Mode
    private var debugTapCount = 0
    private let debugTapThreshold = 3
    private var debugTimer: Timer?
    
    private func setupDebugMode() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDebugTap))
        titleImage.isUserInteractionEnabled = true
        titleImage.addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleDebugTap() {
        debugTapCount += 1
        debugTimer?.invalidate()
        
        if debugTapCount >= debugTapThreshold {
            debugTapCount = 0
//            presentDebugOptions()
        } else {
            debugTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                self?.debugTapCount = 0
            }
        }
    }
    
//    private func presentDebugOptions() {
//        let alert = UIAlertController(title: "Debug Mode", message: nil, preferredStyle: .actionSheet)
//        
//        alert.addAction(UIAlertAction(title: "Default Account", style: .default) { [weak self] _ in
//            self?.emailField.text = "coltonbswapp@gmail.com"
//            self?.passwordField.text = "Test123!"
//        })
//        
//        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
//        
//        present(alert, animated: true)
//    }
}

// MARK: - ASAuthorizationControllerDelegate
extension LandingViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            Task {
                do {
                    let result = try await UserService.shared.signInWithApple(credential: appleIDCredential)
                    
                    await MainActor.run {
                        if result.isNewUser {
                            if result.isIncompleteSignup {
                                // This is an incomplete signup - show explanation
                                self.showIncompleteSignupAlert(credential: appleIDCredential)
                            } else {
                                // This is a truly new user - go directly to onboarding
                                self.startAppleOnboardingFlow(credential: appleIDCredential)
                            }
                        } else {
                            // Existing user - sign them in
                            self.handleExistingAppleUser()
                        }
                    }
                } catch {
                    await MainActor.run {
                        let alert = UIAlertController(
                            title: "Sign In Failed",
                            message: error.localizedDescription,
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let alert = UIAlertController(
            title: "Sign In Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func startAppleOnboardingFlow(credential: ASAuthorizationAppleIDCredential) {
        // Dismiss the login screen and start onboarding directly
        self.dismiss(animated: true) {
            if let delegate = self.delegate as? LaunchCoordinator {
                delegate.startAppleSignInOnboarding(with: credential)
            } else {
                self.delegate?.signUpTapped()
            }
        }
    }
    
    private func showIncompleteSignupAlert(credential: ASAuthorizationAppleIDCredential) {
        let alert = UIAlertController(
            title: "Welcome Back!",
            message: "Let's finish setting up your NestNote account.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Complete Setup", style: .default) { _ in
            self.startAppleOnboardingFlow(credential: credential)
        })
        
        present(alert, animated: true)
    }
    
    private func handleExistingAppleUser() {
        // Existing user - sign them in directly
        Task {
            try await Launcher.shared.configure()
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            
            await MainActor.run {
                Logger.log(level: .info, category: .general, message: "Successfully signed in with Apple")
                self.delegate?.authenticationComplete()
                self.dismiss(animated: true)
            }
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension LandingViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}

// MARK: - WelcomePageType Enum

enum WelcomePageType: Int, CaseIterable {
    case slide4, slide1, slide2, slide3
    
    var imageName: String {
        switch self {
        case .slide1: return "WSlide1"
        case .slide2: return "WSlide2"
        case .slide3: return "WSlide3"
        case .slide4: return "WSlide4"
        }
    }
    
    var title: String {
        switch self {
        case .slide1: return "Complete Care Guide"
        case .slide2: return "Works for Every Caregiver"
        case .slide3: return "Print-Friendly Too"
        case .slide4: return "Meet NestNote"
        }
    }
    
    var subtitle: String {
        switch self {
        case .slide1: return "From garage codes to feeding schedules - organize all the details"
        case .slide2: return "Share your family guide instantly with a simple access code"
        case .slide3: return "No smartphone? Export session details as a handy PDF reference"
        case .slide4: return "All your caregiving needs, one secure app"
        }
    }
}

// MARK: - WelcomePage UIView

class WelcomePage: UIView {
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let stackView = UIStackView()
    
    init(type: WelcomePageType) {
        super.init(frame: .zero)
        setup(type: type)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup(type: WelcomePageType) {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: type.imageName)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        titleLabel.text = type.title
        titleLabel.font = .h2
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        
        subtitleLabel.text = type.subtitle
        subtitleLabel.font = .bodyL
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        
        addSubview(imageView)
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.55),
            
            stackView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12)
        ])
    }
}

// MARK: - Carousel Setup
extension LandingViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func setupCarousel() {
        pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        pageViewController.dataSource = self
        pageViewController.delegate = self
        
        let firstVC = viewControllerForPage(index: 0)
        pageViewController.setViewControllers([firstVC], direction: .forward, animated: false, completion: nil)
        
        pageControl.numberOfPages = welcomePages.count
        pageControl.currentPage = 0
        pageControl.currentPageIndicatorTintColor = NNColors.primary
        pageControl.backgroundStyle = .prominent
        pageControl.addTarget(self, action: #selector(pageControlChanged), for: .valueChanged)
        
//        pageViewController.view.backgroundColor = .red.withAlphaComponent(0.2)
    }
    
    func viewControllerForPage(index: Int) -> UIViewController {
        let vc = UIViewController()
        let page = WelcomePage(type: welcomePages[index])
        page.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(page)
        NSLayoutConstraint.activate([
            page.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            page.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
            
            page.topAnchor.constraint(lessThanOrEqualTo: vc.view.topAnchor),
            page.bottomAnchor.constraint(lessThanOrEqualTo: vc.view.bottomAnchor),
            page.leadingAnchor.constraint(lessThanOrEqualTo: vc.view.leadingAnchor),
            page.trailingAnchor.constraint(lessThanOrEqualTo: vc.view.trailingAnchor)
        ])
        return vc
    }
    
    // MARK: UIPageViewControllerDataSource
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let index = currentIndex(for: viewController), index > 0 else { return nil }
        return viewControllerForPage(index: index - 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let index = currentIndex(for: viewController), index < welcomePages.count - 1 else { return nil }
        return viewControllerForPage(index: index + 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed, let currentVC = pageViewController.viewControllers?.first, let index = currentIndex(for: currentVC) {
            currentPageIndex = index
            pageControl.currentPage = index
        }
    }
    
    private func currentIndex(for viewController: UIViewController) -> Int? {
        guard let page = viewController.view.subviews.first(where: { $0 is WelcomePage }) as? WelcomePage else { return nil }
        for (i, type) in welcomePages.enumerated() {
            if let img = (page.subviews.first { $0 is UIImageView }) as? UIImageView, img.image == UIImage(named: type.imageName) {
                return i
            }
        }
        return nil
    }
    
    @objc private func pageControlChanged(_ sender: UIPageControl) {
        let newIndex = sender.currentPage
        let direction: UIPageViewController.NavigationDirection = newIndex > currentPageIndex ? .forward : .reverse
        let vc = viewControllerForPage(index: newIndex)
        pageViewController.setViewControllers([vc], direction: direction, animated: true, completion: nil)
        currentPageIndex = newIndex
    }
}

