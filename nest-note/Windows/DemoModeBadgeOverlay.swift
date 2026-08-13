//
//  DemoModeBadgeOverlay.swift
//  nest-note
//
//  Window-level "Demo" pill while demo mode is on. Hidden during screen
//  recording / mirroring (`UIScreen.isCaptured`) and when the user taps it,
//  so influencer footage does not include the chrome.
//

import UIKit

final class DemoModeBadgeOverlay {
    static let shared = DemoModeBadgeOverlay()

    private static let overlayLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 0.5)
    private static let tapHideDuration: TimeInterval = 12

    private var overlayWindow: PassthroughWindow?
    private var badge: DemoModeBadgeView?
    private var windowScene: UIWindowScene?
    private var hideWorkItem: DispatchWorkItem?
    private var isTemporarilyHidden = false
    private var isSuppressed = false
    private var didInstallObservers = false

    private init() {}

    func install(windowScene: UIWindowScene? = nil) {
        if let windowScene {
            self.windowScene = windowScene
        }
        installObserversIfNeeded()
        updateVisibility(animated: false)
    }

    /// Hide while system modals (QuickLook, etc.) are on screen.
    func setSuppressed(_ suppressed: Bool) {
        isSuppressed = suppressed
        updateVisibility(animated: false)
    }

    // MARK: - Observers

    private func installObserversIfNeeded() {
        guard !didInstallObservers else { return }
        didInstallObservers = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDemoModeChange),
            name: .demoModeDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCaptureChange),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleDemoModeChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !DemoModeService.shared.isActive {
                self.isTemporarilyHidden = false
                self.hideWorkItem?.cancel()
            }
            self.updateVisibility(animated: true)
        }
    }

    @objc private func handleCaptureChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if UIScreen.main.isCaptured {
                self.isTemporarilyHidden = false
                self.hideWorkItem?.cancel()
            }
            self.updateVisibility(animated: true)
        }
    }

    // MARK: - Visibility

    private func shouldShowBadge() -> Bool {
        DemoModeService.shared.isActive
            && !UIScreen.main.isCaptured
            && !isTemporarilyHidden
            && !isSuppressed
    }

    private func updateVisibility(animated: Bool) {
        let show = shouldShowBadge()
        if show {
            ensureWindow()
        }

        guard let window = overlayWindow, let badge else {
            return
        }

        let applyVisibleState = {
            badge.alpha = show ? 1 : 0
            badge.transform = CGAffineTransform.identity
            badge.isUserInteractionEnabled = show
        }

        if !animated {
            applyVisibleState()
            window.isHidden = !show
            return
        }

        if show {
            window.isHidden = false
            if badge.alpha < 0.01 {
                badge.transform = CGAffineTransform(scaleX: 0.55, y: 0.55)
            }
            UIView.animate(
                withDuration: 0.5,
                delay: 0.05,
                usingSpringWithDamping: 0.58,
                initialSpringVelocity: 0.9,
                options: [.beginFromCurrentState]
            ) {
                applyVisibleState()
            }
        } else {
            UIView.animate(
                withDuration: 0.22,
                delay: 0,
                options: [.curveEaseInOut, .beginFromCurrentState]
            ) {
                applyVisibleState()
            } completion: { [weak self] _ in
                if self?.shouldShowBadge() == false {
                    window.isHidden = true
                }
            }
        }
    }

    private func ensureWindow() {
        if overlayWindow != nil { return }

        let scene = windowScene
            ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        guard let scene else { return }

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = Self.overlayLevel
        window.backgroundColor = .clear
        window.isHidden = true

        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .clear

        let badge = DemoModeBadgeView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.onTap = { [weak self] in
            self?.hideTemporarily()
        }
        badge.onExit = {
            Task {
                do {
                    try await DemoModeService.shared.exit()
                } catch {
                    Logger.log(
                        level: .error,
                        category: .demoMode,
                        message: "Failed to exit demo from badge: \(error.localizedDescription)"
                    )
                }
            }
        }

        rootVC.view.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.centerXAnchor.constraint(equalTo: rootVC.view.centerXAnchor),
            badge.bottomAnchor.constraint(equalTo: rootVC.view.bottomAnchor, constant: -16)
        ])

        window.rootViewController = rootVC
        overlayWindow = window
        self.badge = badge
    }

    private func hideTemporarily() {
        hideWorkItem?.cancel()
        isTemporarilyHidden = true
        updateVisibility(animated: true)

        let work = DispatchWorkItem { [weak self] in
            self?.isTemporarilyHidden = false
            self?.updateVisibility(animated: true)
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.tapHideDuration, execute: work)
    }
}

// MARK: - Pill

private final class DemoModeBadgeView: UIVisualEffectView {
    var onTap: (() -> Void)?
    var onExit: (() -> Void)?

    private let titleLabel = UILabel()
    private let iconView = UIImageView()

    override init(effect: UIVisualEffect?) {
        super.init(effect: effect)
        setup()
    }

    convenience init() {
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .regular)
            glassEffect.isInteractive = true
            self.init(effect: glassEffect)
        } else {
            self.init(effect: nil)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        clipsToBounds = true

        if #available(iOS 26.0, *) {
            // Glass effect handles the background
        } else {
            backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 2)
            layer.shadowOpacity = 0.12
            layer.shadowRadius = 8
            clipsToBounds = false
            layer.masksToBounds = false
        }

        let symbol = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        iconView.image = UIImage(systemName: "play.rectangle.fill", withConfiguration: symbol)
        iconView.tintColor = NNColors.primary
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.text = "Demo"
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = NNColors.primary

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 5
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)

        var config = UIButton.Configuration.plain()
        config.contentInsets = .zero
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Demo nest"
        button.accessibilityHint = "Hides this badge for a few seconds so it stays out of recordings. Touch and hold to exit the demo nest."
        button.addAction(UIAction { [weak self] _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            self?.onTap?()
        }, for: .primaryActionTriggered)

        let exitAction = UIAction(
            title: "Exit demo nest",
            image: UIImage(systemName: "arrow.uturn.backward"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.onExit?()
        }
        button.menu = UIMenu(children: [exitAction])
        button.showsMenuAsPrimaryAction = false

        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            button.topAnchor.constraint(equalTo: contentView.topAnchor),
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}
