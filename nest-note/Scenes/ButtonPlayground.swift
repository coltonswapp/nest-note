import UIKit

class ButtonPlayground: UIViewController {

    private lazy var loadingButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Login", titleColor: .white, fillStyle: .fill(NNColors.primary))
        button.addTarget(self, action: #selector(handleLoadingButtonTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var secondaryLoadingButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Create Account", titleColor: .white, fillStyle: .fill(.systemBlue), transitionStyle: .rightHide)
        button.addTarget(self, action: #selector(handleSecondaryButtonTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var tertiaryLoadingButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Send Invite", titleColor: .white, fillStyle: .fill(NNColors.offBlack), transitionStyle: .rightHide)
        button.addTarget(self, action: #selector(handleTertiaryButtonTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var regularButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Regular Button", image: UIImage(systemName: "star.fill"))
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var transitionLabelButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "608-123", backgroundColor: NNColors.primary.withAlphaComponent(0.15), foregroundColor: NNColors.primary)
        button.addTarget(self, action: #selector(handleRegularButtonTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var slowSpinner: NNLoadingSpinner = {
        let spinner = NNLoadingSpinner()
        spinner.setSpeed(duration: 0.9)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    private lazy var mediumSpinner: NNLoadingSpinner = {
        let spinner = NNLoadingSpinner()
        spinner.setSpeed(duration: 0.6)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    private lazy var fastSpinner: NNLoadingSpinner = {
        let spinner = NNLoadingSpinner()
        spinner.setSpeed(duration: 0.3)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Button Playground"

        view.addSubview(loadingButton)
        view.addSubview(secondaryLoadingButton)
        view.addSubview(tertiaryLoadingButton)
        view.addSubview(regularButton)
        view.addSubview(transitionLabelButton)
        view.addSubview(slowSpinner)
        view.addSubview(mediumSpinner)
        view.addSubview(fastSpinner)

        NSLayoutConstraint.activate([
            loadingButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            loadingButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            loadingButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            loadingButton.heightAnchor.constraint(equalToConstant: 55),

            secondaryLoadingButton.topAnchor.constraint(equalTo: loadingButton.bottomAnchor, constant: 20),
            secondaryLoadingButton.leadingAnchor.constraint(equalTo: loadingButton.leadingAnchor),
            secondaryLoadingButton.trailingAnchor.constraint(equalTo: loadingButton.trailingAnchor),
            secondaryLoadingButton.heightAnchor.constraint(equalToConstant: 55),

            tertiaryLoadingButton.topAnchor.constraint(equalTo: secondaryLoadingButton.bottomAnchor, constant: 20),
            tertiaryLoadingButton.leadingAnchor.constraint(equalTo: loadingButton.leadingAnchor),
            tertiaryLoadingButton.trailingAnchor.constraint(equalTo: loadingButton.trailingAnchor),
            tertiaryLoadingButton.heightAnchor.constraint(equalToConstant: 55),

            regularButton.topAnchor.constraint(equalTo: tertiaryLoadingButton.bottomAnchor, constant: 20),
            regularButton.leadingAnchor.constraint(equalTo: loadingButton.leadingAnchor),
            regularButton.trailingAnchor.constraint(equalTo: loadingButton.trailingAnchor),
            regularButton.heightAnchor.constraint(equalToConstant: 55),

            transitionLabelButton.topAnchor.constraint(equalTo: regularButton.bottomAnchor, constant: 20),
            transitionLabelButton.heightAnchor.constraint(equalToConstant: 46.0),
            transitionLabelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            slowSpinner.topAnchor.constraint(equalTo: transitionLabelButton.bottomAnchor, constant: 40),
            slowSpinner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            slowSpinner.widthAnchor.constraint(equalToConstant: 25),
            slowSpinner.heightAnchor.constraint(equalToConstant: 25),

            mediumSpinner.topAnchor.constraint(equalTo: slowSpinner.topAnchor),
            mediumSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mediumSpinner.widthAnchor.constraint(equalToConstant: 25),
            mediumSpinner.heightAnchor.constraint(equalToConstant: 25),

            fastSpinner.topAnchor.constraint(equalTo: slowSpinner.topAnchor),
            fastSpinner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            fastSpinner.widthAnchor.constraint(equalToConstant: 25),
            fastSpinner.heightAnchor.constraint(equalToConstant: 25)
        ])
    }

    @objc private func handleLoadingButtonTap() {
        loadingButton.startLoading()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.loadingButton.stopLoading()
        }
    }

    @objc private func handleSecondaryButtonTap() {
        secondaryLoadingButton.startLoading()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.secondaryLoadingButton.stopLoading(withSuccess: false)
        }
    }

    @objc private func handleTertiaryButtonTap() {
        tertiaryLoadingButton.startLoading()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.tertiaryLoadingButton.stopLoading(withSuccess: true)
        }
    }

    @objc private func handleRegularButtonTap() {
        transitionLabelButton.showCopiedFeedback()
    }
}
