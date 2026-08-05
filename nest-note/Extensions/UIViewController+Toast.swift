//
//  UIViewController+Toast.swift
//  nest-note
//
//  Created by Colton Swapp on 11/7/24.
//

import UIKit
import Toast

final class ToastManager {
    static let shared = ToastManager()

    /// Above the main app window, but always below `.alert`.
    /// Using `.alert` / `.alert + 1` traps system UI (notifications permission,
    /// Save Password, App Store review, etc.) under an untappable overlay.
    private static let overlayLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)

    private var toastWindow: PassthroughWindow?
    private var suppressWindow = false
    private var hideWindowWorkItem: DispatchWorkItem?
    private var presentationID = 0

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

    /// Temporarily hide the toast overlay window (e.g. while QuickLook is presented).
    func setWindowHidden(_ hidden: Bool) {
        suppressWindow = hidden
        if hidden {
            hideWindowWorkItem?.cancel()
            toastWindow?.isHidden = true
        }
    }

    func showToast(delay: CGFloat = 0.75, text: String, subtitle: String? = nil, sentiment: Sentiment = .positive) {
        if toastWindow == nil {
            setupToastWindow()
        }

        presentationID += 1
        let currentID = presentationID

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard !self.suppressWindow else { return }
            guard currentID == self.presentationID else { return }

            self.toastWindow?.isHidden = false

            let visibleDuration: TimeInterval = 3.0
            let config = ToastConfiguration(
                direction: .bottom,
                dismissBy: [.time(time: visibleDuration), .swipe(direction: .natural), .longPress],
                animationTime: 0.2,
                attachTo: self.toastWindow?.rootViewController?.view
            )

            let toast = Toast.default(
                image: sentiment == .positive ? UIImage(systemName: "checkmark")! : UIImage(systemName: "xmark")!,
                title: text,
                subtitle: subtitle,
                config: config
            )
            toast.show()

            // Put the overlay away after the toast finishes so it can't cover system alerts.
            self.hideWindowWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, currentID == self.presentationID else { return }
                self.toastWindow?.isHidden = true
                self.hideWindowWorkItem = nil
            }
            self.hideWindowWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + visibleDuration + 0.4,
                execute: workItem
            )
        }
    }
}

extension UIViewController {
    func showToast(delay: CGFloat = 0.75, text: String, subtitle: String? = nil, sentiment: Sentiment = .positive) {
        ToastManager.shared.showToast(delay: delay, text: text, subtitle: subtitle, sentiment: sentiment)
    }
}

enum Sentiment {
    case positive
    case negative
}
