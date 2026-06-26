import UIKit
import UserNotifications

enum SessionNotificationPrompt {
    /// Presents the enable-notifications education screen when the user has not authorized push,
    /// or silently refreshes prefs + FCM token when already authorized.
    static func presentIfNeeded(from viewController: UIViewController, completion: @escaping () -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    Task {
                        _ = await UserService.shared.ensureNotificationsRegisteredForSessionAlerts()
                        await MainActor.run {
                            completion()
                        }
                    }
                } else {
                    let enableVC = EnableNotificationsViewController()
                    enableVC.onFinished = completion
                    let nav = UINavigationController(rootViewController: enableVC)
                    nav.modalPresentationStyle = .pageSheet
                    viewController.present(nav, animated: true)
                }
            }
        }
    }
}

final class EnableNotificationsViewController: NNViewController {

    var onFinished: (() -> Void)?

    private let topImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .rectanglePatternSmall, with: NNColors.primary)
        view.alpha = 0.4
        return view
    }()

    private let infoView: NNBulletStack

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Enable Notifications"
        label.font = .h1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Get notified when your session starts, runs long, or ends — so you're never caught off guard."
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var enableButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Enable Notifications")
        button.addTarget(self, action: #selector(enableTapped), for: .touchUpInside)
        return button
    }()

    init() {
        let items = [
            NNBulletItem(
                title: "Session Starting",
                description: "Know the moment care begins",
                iconName: "calendar.badge.clock"
            ),
            NNBulletItem(
                title: "Session Extended",
                description: "Get alerted when a session runs past its scheduled end",
                iconName: "timer.circle.fill"
            ),
            NNBulletItem(
                title: "Session Completed",
                description: "See when wrapping up is done",
                iconName: "checkmark.circle.fill"
            ),
        ]
        self.infoView = NNBulletStack(items: items)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupNavigationBar()
    }

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
    }

    private func setupView() {
        view.backgroundColor = .systemBackground

        view.addSubview(topImageView)
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)

        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(infoView)

        infoView.translatesAutoresizingMaskIntoConstraints = false

        enableButton.pinToBottom(of: view, addBlurEffect: true)
        topImageView.pinToTop(of: view)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topImageView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: enableButton.topAnchor),

            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            infoView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            infoView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 36),
            infoView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -36),
            infoView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
        ])
    }

    @objc private func closeTapped() {
        finish()
    }

    @objc private func enableTapped() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()

            if settings.authorizationStatus == .denied {
                await MainActor.run {
                    showSettingsAlert()
                }
                return
            }

            let granted = await requestAuthorization()
            if granted {
                _ = await UserService.shared.ensureNotificationsRegisteredForSessionAlerts()
            }

            await MainActor.run {
                finish()
            }
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error {
                    Logger.log(level: .error, category: .userService, message: "Notification authorization failed: \(error.localizedDescription)")
                }
                continuation.resume(returning: granted)
            }
        }
    }

    private func showSettingsAlert() {
        let alert = UIAlertController(
            title: "Notifications Disabled",
            message: "To enable notifications, go to Settings > Notifications > NestNote and turn on Allow Notifications.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.finish()
        })
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { [weak self] _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
            self?.finish()
        })
        present(alert, animated: true)
    }

    private func finish() {
        dismiss(animated: true) { [onFinished] in
            onFinished?()
        }
    }
}
