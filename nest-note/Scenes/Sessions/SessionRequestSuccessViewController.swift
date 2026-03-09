import UIKit

class SessionRequestSuccessViewController: NNViewController {

    // MARK: - Properties

    private let inviteCode: String

    private let successImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark.circle.fill")
        imageView.tintColor = NNColors.primary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Request Created!"
        label.font = .h1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Share this code with the parent"
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var codeLabel: UILabel = {
        let label = UILabel()
        label.text = inviteCode
        label.font = UIFont.monospacedSystemFont(ofSize: 48, weight: .bold)
        label.textAlignment = .center
        label.textColor = NNColors.primary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let codeContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 2
        view.layer.borderColor = NNColors.primary.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var copyButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Copy Code", titleColor: .white, fillStyle: .fill(NNColors.primary))
        button.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var shareButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Share Code", titleColor: .white, fillStyle: .fill(NNColors.primary))
        button.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Done", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle

    init(inviteCode: String) {
        self.inviteCode = inviteCode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        navigationItem.hidesBackButton = true

        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        codeContainerView.addSubview(codeLabel)

        view.addSubview(successImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(codeContainerView)
        view.addSubview(copyButton)
        view.addSubview(shareButton)
        view.addSubview(doneButton)

        NSLayoutConstraint.activate([
            successImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            successImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            successImageView.widthAnchor.constraint(equalToConstant: 80),
            successImageView.heightAnchor.constraint(equalToConstant: 80),

            titleLabel.topAnchor.constraint(equalTo: successImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            codeContainerView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            codeContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            codeContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            codeContainerView.heightAnchor.constraint(equalToConstant: 120),

            codeLabel.centerXAnchor.constraint(equalTo: codeContainerView.centerXAnchor),
            codeLabel.centerYAnchor.constraint(equalTo: codeContainerView.centerYAnchor),

            copyButton.topAnchor.constraint(equalTo: codeContainerView.bottomAnchor, constant: 32),
            copyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            copyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            copyButton.heightAnchor.constraint(equalToConstant: 50),

            shareButton.topAnchor.constraint(equalTo: copyButton.bottomAnchor, constant: 12),
            shareButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            shareButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            shareButton.heightAnchor.constraint(equalToConstant: 50),

            doneButton.topAnchor.constraint(equalTo: shareButton.bottomAnchor, constant: 24),
            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            doneButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - Actions

    @objc private func copyButtonTapped() {
        UIPasteboard.general.string = inviteCode

        // Show feedback
        copyButton.setTitle("Copied!")
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.copyButton.setTitle("Copy Code")
        }
    }

    @objc private func shareButtonTapped() {
        let message = "Join my session on NestNote with code: \(inviteCode)"
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }

        present(activityVC, animated: true)
    }

    @objc private func doneButtonTapped() {
        // Dismiss back to sitter home
        dismiss(animated: true)
    }
}
