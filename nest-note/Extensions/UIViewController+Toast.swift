//
//  UIViewController+Toast.swift
//  nest-note
//
//  Created by Colton Swapp on 11/7/24.
//

import UIKit
import Toast

/// Tunable spring values for toast enter / exit. Adjust from Toast Test, then paste into defaults.
struct ToastAnimationTuning {
    /// Enter spring
    var duration: TimeInterval = 0.26
    var damping: CGFloat = 0.61
    var velocity: CGFloat = 0.91
    /// Light scale so the slide reads as the primary motion.
    var initialScale: CGFloat = 0.94
    /// Distance to travel on enter (sign flipped for top vs bottom).
    var translateY: CGFloat = 56
    /// Dismiss slide-off
    var dismissDuration: TimeInterval = 0.15
    /// Distance to travel on dismiss (sign flipped for top vs bottom).
    var dismissTranslateY: CGFloat = 80
}

enum ToastPresentationEdge: String, CaseIterable {
    case top
    case bottom

    private static let defaultsKey = "ToastManager.presentationEdge"

    static var current: ToastPresentationEdge {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? ToastPresentationEdge.bottom.rawValue
            return ToastPresentationEdge(rawValue: raw) ?? .bottom
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    var toastDirection: Toast.Direction {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        }
    }

    /// +1 slides toward the bottom of the screen, -1 toward the top.
    var dismissSign: CGFloat {
        switch self {
        case .top: return -1
        case .bottom: return 1
        }
    }

    var menuTitle: String {
        switch self {
        case .top: return "Top"
        case .bottom: return "Bottom"
        }
    }
}

final class ToastManager {
    static let shared = ToastManager()

    private static let overlayLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
    private static let stackScale: CGFloat = 0.92
    private static let stackOffsetY: CGFloat = -14
    private static let dismissScale: CGFloat = 0.92

    var animationTuning = ToastAnimationTuning()

    var presentationEdge: ToastPresentationEdge {
        get { ToastPresentationEdge.current }
        set { ToastPresentationEdge.current = newValue }
    }

    private var toastWindow: PassthroughWindow?
    private var suppressWindow = false

    /// Oldest → newest. Each entry keeps its own dismiss schedule.
    private var entries: [ToastEntry] = []
    private var swipeHandler: ToastSwipeHandler?

    private init() {}

    private func setupToastWindow() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = Self.overlayLevel
        window.backgroundColor = .clear
        window.isHidden = true

        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .clear
        window.rootViewController = rootVC

        self.toastWindow = window
    }

    func setWindowHidden(_ hidden: Bool) {
        suppressWindow = hidden
        if hidden {
            toastWindow?.isHidden = true
        }
    }

    func showToast(
        delay: CGFloat = 0,
        text: String,
        subtitle: String? = nil,
        sentiment: Sentiment = .positive,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        if toastWindow == nil {
            setupToastWindow()
        }

        let present: () -> Void = { [weak self] in
            guard let self else { return }
            guard !self.suppressWindow else { return }

            self.toastWindow?.isHidden = false

            let tuning = self.animationTuning
            let edge = self.presentationEdge
            let hasAction = actionTitle != nil && onAction != nil
            let visibleDuration: TimeInterval = hasAction ? 4.5 : 3.0

            var dismissBy: [Toast.Dismissable] = [.longPress]
            if !hasAction {
                dismissBy.append(.tap)
            }

            let enterY = tuning.translateY * edge.dismissSign
            let exitTransform = Self.dismissTransform(
                travel: tuning.dismissTranslateY,
                sign: edge.dismissSign
            )

            let config = ToastConfiguration(
                direction: edge.toastDirection,
                dismissBy: dismissBy,
                animationTime: tuning.dismissDuration,
                enteringAnimation: .custom(transformation: .identity),
                exitingAnimation: .custom(transformation: exitTransform),
                attachTo: self.toastWindow?.rootViewController?.view,
                allowToastOverlap: true
            )

            let entryID = UUID()
            let toastView = NNToastView(
                title: text,
                subtitle: subtitle,
                sentiment: sentiment,
                actionTitle: actionTitle,
                onAction: { [weak self] in
                    guard let self else { return }
                    self.dismissEntry(id: entryID, animated: true)
                    // Defer the consumer action so a follow-up toast can't relayout
                    // this one mid slide-off.
                    DispatchQueue.main.async {
                        onAction?()
                    }
                }
            )

            let toast = Toast.custom(view: toastView, config: config)
            let entry = ToastEntry(
                id: entryID,
                toast: toast,
                view: toastView,
                dismissDeadline: Date().addingTimeInterval(visibleDuration)
            )

            let coordinator = ToastDismissalCoordinator { [weak self] in
                // Library-driven close (tap / long-press) finished — drop from queue.
                self?.removeEntry(id: entryID, viewAlreadyRemoved: true)
            }
            entry.coordinator = coordinator
            toast.addDelegate(delegate: coordinator)

            self.entries.append(entry)

            let startTransform = CGAffineTransform(translationX: 0, y: enterY)
                .scaledBy(x: tuning.initialScale, y: tuning.initialScale)

            toast.show()

            toastView.layer.removeAllAnimations()
            toastView.alpha = 0
            toastView.transform = startTransform

            HapticsHelper.superLightHaptic()

            UIView.animate(
                withDuration: tuning.duration,
                delay: 0,
                usingSpringWithDamping: tuning.damping,
                initialSpringVelocity: tuning.velocity,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                toastView.alpha = 1
                toastView.transform = .identity
            } completion: { [weak self] _ in
                self?.relayoutStack(animated: true)
            }

            self.relayoutStack(animated: true)
            self.attachSwipeHandlerToPrimary()
            self.scheduleDismiss(for: entry, after: visibleDuration)
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: present)
        } else {
            DispatchQueue.main.async(execute: present)
        }
    }

    // MARK: - Queue / stack

    private func scheduleDismiss(for entry: ToastEntry, after delay: TimeInterval) {
        entry.dismissTimer?.invalidate()
        let id = entry.id
        let clampedDelay = max(0, delay)
        let timer = Timer(timeInterval: clampedDelay, repeats: false) { [weak self] _ in
            self?.dismissEntry(id: id, animated: true)
        }
        entry.dismissTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func dismissEntry(id: UUID, animated: Bool) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        guard !entry.isDismissing else { return }
        entry.isDismissing = true
        entry.dismissTimer?.invalidate()
        entry.dismissTimer = nil

        let view = entry.view
        let isPrimary = entries.last?.id == id

        if isPrimary {
            swipeHandler = nil
            view.gestureRecognizers?.forEach { view.removeGestureRecognizer($0) }
        }
        view.isUserInteractionEnabled = false

        let finish = { [weak self] in
            self?.removeEntry(id: id, viewAlreadyRemoved: false)
        }

        guard animated else {
            finish()
            return
        }

        // Tall action toasts need enough travel to fully clear the edge.
        view.layoutIfNeeded()
        let travel = max(animationTuning.dismissTranslateY, view.bounds.height + 28)
        let exitTransform = Self.dismissTransform(
            travel: travel,
            sign: presentationEdge.dismissSign
        )

        // Continue from the current (possibly stacked) transform — no fade.
        UIView.animate(
            withDuration: animationTuning.dismissDuration,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction]
        ) {
            view.transform = exitTransform
            view.alpha = 1
        } completion: { _ in
            finish()
        }
    }

    private func removeEntry(id: UUID, viewAlreadyRemoved: Bool) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let entry = entries.remove(at: index)
        entry.dismissTimer?.invalidate()
        entry.isDismissing = true

        if !viewAlreadyRemoved {
            entry.view.layer.removeAllAnimations()
            entry.view.removeFromSuperview()
            // Close without re-entering our dismiss animation; coordinator is a no-op once removed.
            entry.toast.close(animated: false)
        }

        relayoutStack(animated: true)
        attachSwipeHandlerToPrimary()

        if entries.isEmpty {
            swipeHandler = nil
            toastWindow?.isHidden = true
        }
    }

    private func relayoutStack(animated: Bool) {
        let changes = {
            // Only lay out toasts that are still settled — never fight a slide-off.
            let activeEntries = self.entries.filter { !$0.isDismissing }
            for (index, entry) in activeEntries.enumerated() {
                let depth = activeEntries.count - 1 - index
                entry.view.layer.zPosition = CGFloat(1000 - depth)

                if depth == 0 {
                    entry.view.transform = .identity
                    entry.view.isUserInteractionEnabled = true
                } else {
                    let scale = pow(Self.stackScale, CGFloat(depth))
                    let offset = Self.stackOffsetY * CGFloat(depth)
                    entry.view.transform = CGAffineTransform(translationX: 0, y: offset)
                        .scaledBy(x: scale, y: scale)
                    entry.view.isUserInteractionEnabled = false
                }
                entry.view.alpha = 1
            }
        }

        if animated {
            UIView.animate(
                withDuration: 0.28,
                delay: 0,
                usingSpringWithDamping: 0.86,
                initialSpringVelocity: 0.5,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: changes
            )
        } else {
            changes()
        }
    }

    private func attachSwipeHandlerToPrimary() {
        swipeHandler = nil
        guard let primary = entries.last else { return }

        // Ensure only the primary has a pan recognizer.
        for entry in entries {
            entry.view.gestureRecognizers?.forEach { entry.view.removeGestureRecognizer($0) }
        }

        let edge = presentationEdge
        let tuning = animationTuning
        let primaryID = primary.id

        let handler = ToastSwipeHandler(
            toast: primary.toast,
            dismissSign: edge.dismissSign,
            dismissTravel: tuning.dismissTranslateY,
            dismissScale: Self.dismissScale,
            dismissDuration: tuning.dismissDuration,
            onPanBegan: { [weak primary] in
                primary?.dismissTimer?.invalidate()
                primary?.dismissTimer = nil
            },
            onSnapBack: { [weak self, weak primary] in
                guard let self, let primary, self.entries.contains(where: { $0.id == primary.id }) else { return }
                let remaining = max(0.75, primary.dismissDeadline.timeIntervalSinceNow)
                self.scheduleDismiss(for: primary, after: remaining)
            },
            onInteractiveDismissFinished: { [weak self] in
                // View already removed by toast.close; drop from queue.
                self?.removeEntry(id: primaryID, viewAlreadyRemoved: true)
            }
        )
        swipeHandler = handler
        primary.view.addGestureRecognizer(handler.panRecognizer)
        primary.view.isUserInteractionEnabled = true
    }

    private static func dismissTransform(travel: CGFloat, sign: CGFloat) -> CGAffineTransform {
        CGAffineTransform(translationX: 0, y: travel * sign)
            .scaledBy(x: dismissScale, y: dismissScale)
    }
}

// MARK: - Entry

private final class ToastEntry {
    let id: UUID
    let toast: Toast
    let view: NNToastView
    let dismissDeadline: Date
    var dismissTimer: Timer?
    var coordinator: ToastDismissalCoordinator?
    var isDismissing = false

    init(id: UUID, toast: Toast, view: NNToastView, dismissDeadline: Date) {
        self.id = id
        self.toast = toast
        self.view = view
        self.dismissDeadline = dismissDeadline
    }
}

/// Observes library-driven close (tap / long-press) so we can drop the entry from the queue.
private final class ToastDismissalCoordinator: ToastDelegate {
    private let onDidClose: () -> Void
    private var didHandle = false

    init(onDidClose: @escaping () -> Void) {
        self.onDidClose = onDidClose
    }

    func willShowToast(_ toast: Toast) {}
    func didShowToast(_ toast: Toast) {}
    func willCloseToast(_ toast: Toast) {}

    func didCloseToast(_ toast: Toast) {
        guard !didHandle else { return }
        didHandle = true
        onDidClose()
    }
}

/// Interactive swipe-to-dismiss that continues from the drag (no position reset, no fade).
private final class ToastSwipeHandler: NSObject, UIGestureRecognizerDelegate {
    let panRecognizer = UIPanGestureRecognizer()

    private weak var toast: Toast?
    private let dismissSign: CGFloat
    private let dismissTravel: CGFloat
    private let dismissScale: CGFloat
    private let dismissDuration: TimeInterval
    private let onPanBegan: () -> Void
    private let onSnapBack: () -> Void
    private let onInteractiveDismissFinished: () -> Void

    private var startTranslationY: CGFloat = 0
    private var startScale: CGFloat = 1
    private var didFinish = false

    init(
        toast: Toast,
        dismissSign: CGFloat,
        dismissTravel: CGFloat,
        dismissScale: CGFloat,
        dismissDuration: TimeInterval,
        onPanBegan: @escaping () -> Void,
        onSnapBack: @escaping () -> Void,
        onInteractiveDismissFinished: @escaping () -> Void
    ) {
        self.toast = toast
        self.dismissSign = dismissSign
        self.dismissTravel = dismissTravel
        self.dismissScale = dismissScale
        self.dismissDuration = dismissDuration
        self.onPanBegan = onPanBegan
        self.onSnapBack = onSnapBack
        self.onInteractiveDismissFinished = onInteractiveDismissFinished
        super.init()

        panRecognizer.addTarget(self, action: #selector(handlePan(_:)))
        panRecognizer.delegate = self
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = toast?.view, !didFinish else { return }

        switch gesture.state {
        case .began:
            startTranslationY = view.transform.ty
            startScale = hypot(view.transform.a, view.transform.c)
            if startScale == 0 { startScale = 1 }
            onPanBegan()

        case .changed:
            let delta = gesture.translation(in: view.superview).y
            var translationY = startTranslationY + delta
            if dismissSign > 0 {
                translationY = translationY < 0 ? translationY * 0.2 : translationY
            } else {
                translationY = translationY > 0 ? translationY * 0.2 : translationY
            }

            let progress = min(1, abs(translationY) / max(dismissTravel, 1))
            let scale = startScale + (dismissScale - startScale) * progress
            view.transform = CGAffineTransform(translationX: 0, y: translationY)
                .scaledBy(x: scale, y: scale)
            view.alpha = 1

        case .ended, .cancelled:
            let translationY = view.transform.ty
            let velocityY = gesture.velocity(in: view.superview).y
            let distance = abs(translationY)
            let projectedTravel = distance + abs(velocityY) * 0.12
            let movingInDismissDirection = velocityY * dismissSign > 0
            let shouldDismiss =
                distance > 20
                || (movingInDismissDirection && abs(velocityY) > 450)
                || projectedTravel > dismissTravel * 0.55

            if shouldDismiss, gesture.state == .ended {
                finishInteractiveDismiss(
                    from: translationY,
                    velocityY: velocityY,
                    view: view
                )
            } else {
                UIView.animate(
                    withDuration: 0.35,
                    delay: 0,
                    usingSpringWithDamping: 0.82,
                    initialSpringVelocity: 0.4,
                    options: [.allowUserInteraction, .beginFromCurrentState]
                ) {
                    view.transform = .identity
                    view.alpha = 1
                } completion: { [weak self] _ in
                    self?.onSnapBack()
                }
            }

        default:
            break
        }
    }

    private func finishInteractiveDismiss(from currentY: CGFloat, velocityY: CGFloat, view: UIView) {
        didFinish = true

        let targetY = dismissSign * max(dismissTravel, abs(currentY) + 36)
        let distance = abs(targetY - currentY)
        let velocity = max(abs(velocityY), 1)
        let velocityDuration = distance / velocity
        let duration = min(dismissDuration, max(0.12, velocityDuration))

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
            view.transform = CGAffineTransform(translationX: 0, y: targetY)
                .scaledBy(x: self.dismissScale, y: self.dismissScale)
            view.alpha = 1
        } completion: { [weak self] _ in
            guard let self else { return }
            self.toast?.close(animated: false)
            self.onInteractiveDismissFinished()
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        if touch.view is UIControl { return false }
        return true
    }
}

extension UIViewController {
    func showToast(
        delay: CGFloat = 0,
        text: String,
        subtitle: String? = nil,
        sentiment: Sentiment = .positive,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        ToastManager.shared.showToast(
            delay: delay,
            text: text,
            subtitle: subtitle,
            sentiment: sentiment,
            actionTitle: actionTitle,
            onAction: onAction
        )
    }
}

enum Sentiment {
    case positive
    case negative
}
