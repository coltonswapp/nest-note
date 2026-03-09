import UIKit

final class NNOnboardingBulletViewController: NNOnboardingViewController {

    private var bulletStack: NNBulletStack?
    private var bulletItems: [NNBulletItem] = []
    private var configuredTitle: String = ""
    private var configuredSubtitle: String?
    private var ctaText: String = "Continue"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupOnboarding(title: configuredTitle, subtitle: configuredSubtitle)
        setupContent()
        addCTAButton(title: ctaText)
        ctaButton?.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
    }

    func configure(title: String, subtitle: String?, bullets: [NNBulletItem], ctaText: String? = nil) {
        self.configuredTitle = title
        self.configuredSubtitle = subtitle
        self.bulletItems = bullets
        if let ctaText = ctaText {
            self.ctaText = ctaText
        }
    }

    override func setupContent() {
        let stack = NNBulletStack(items: bulletItems)
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.bulletStack = stack

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36)
        ])
    }

    @objc private func continueButtonTapped() {
        (coordinator as? OnboardingCoordinator)?.next()
    }
}
