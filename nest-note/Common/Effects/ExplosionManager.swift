//
//  ExplosionManager.swift
//  nest-note
//
//  Created by Claude on 11/18/25.
//

import UIKit
import SpriteKit

// Passthrough SKView that doesn't intercept touches
final class PassthroughSKView: SKView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Always return nil so touches pass through to underlying views
        return nil
    }
}

struct ExplosionPreset {
    let gravity: Float
    let particleCount: Int
    let spread: Float
    let power: Float

    static let tiny = ExplosionPreset(gravity: 1.2, particleCount: 6, spread: 0.8, power: 25)
    static let small = ExplosionPreset(gravity: 1.2, particleCount: 15, spread: 0.8, power: 30)
    static let medium = ExplosionPreset(gravity: 1.5, particleCount: 50, spread: 1.5, power: 35)
    static let large = ExplosionPreset(gravity: 1.0, particleCount: 100, spread: 3.0, power: 40)
    static let atomic = ExplosionPreset(gravity: 1.5, particleCount: 200, spread: 1.0, power: 50)
}

class ExplosionManager {
    static let shared = ExplosionManager()

    /// Matches `ExplosionScene` particle lifetime: fade delay 2–4s + 1s fade-out.
    private static let overlayVisibleDuration: TimeInterval = 5.5

    private var explosionWindow: PassthroughWindow?
    private var explosionScene: ExplosionScene?
    private var hideOverlayWorkItem: DispatchWorkItem?

    private init() {}

    /// Creates the overlay window and SpriteKit scene so the first explosion renders correctly.
    static func prepare(windowScene: UIWindowScene? = nil) {
        shared.prepareExplosionWindow(windowScene: windowScene)
    }

    private func prepareExplosionWindow(windowScene: UIWindowScene?) {
        guard explosionWindow == nil else { return }
        setupExplosionWindow(windowScene: windowScene)
    }

    private func setupExplosionWindow(windowScene: UIWindowScene? = nil) {
        let scene = windowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        guard let scene else { return }

        let window = PassthroughWindow(windowScene: scene)
        // Above the main app / toast (`.normal + 1`), always below `.alert`.
        // Never use `.alert` or higher — that traps notification permission,
        // Save Password, App Store review, etc. under an untappable overlay.
        // Still hide when idle: QuickLook lives in `.normal` and higher windows
        // can steal its gestures even with passthrough hit-testing.
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 2)
        window.backgroundColor = .clear
        window.isHidden = true
        window.isUserInteractionEnabled = false

        // Create root view controller with clear background (like ToastManager)
        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .clear
        rootVC.view.isUserInteractionEnabled = false

        // Create PassthroughSKView as a subview
        let skView = PassthroughSKView()
        skView.backgroundColor = .clear
        skView.allowsTransparency = true
        skView.isUserInteractionEnabled = false
        skView.translatesAutoresizingMaskIntoConstraints = false

        // Add SKView as subview (not replace root view)
        rootVC.view.addSubview(skView)

        // Constraint to fill the entire view
        NSLayoutConstraint.activate([
            skView.topAnchor.constraint(equalTo: rootVC.view.topAnchor),
            skView.leadingAnchor.constraint(equalTo: rootVC.view.leadingAnchor),
            skView.trailingAnchor.constraint(equalTo: rootVC.view.trailingAnchor),
            skView.bottomAnchor.constraint(equalTo: rootVC.view.bottomAnchor)
        ])

        // Setup explosion scene with screen bounds
        let screenSize = UIScreen.main.bounds.size
        explosionScene = ExplosionScene(size: screenSize)
        explosionScene?.scaleMode = .resizeFill
        explosionScene?.backgroundColor = UIColor.clear

        skView.presentScene(explosionScene)
        window.rootViewController = rootVC

        self.explosionWindow = window
    }

    /// Hide app overlay windows that sit above system modals (QuickLook, etc.).
    /// Explosion window stays hidden until the next trigger either way.
    static func setOverlayWindowsHidden(_ hidden: Bool) {
        shared.explosionWindow?.isHidden = true
        ToastManager.shared.setWindowHidden(hidden)
        DemoModeBadgeOverlay.shared.setSuppressed(hidden)
    }

    func triggerExplosion(preset: ExplosionPreset, at point: CGPoint) {
        prepareExplosionWindow(windowScene: nil)

        guard let scene = explosionScene, let window = explosionWindow else {
            return
        }

        window.isHidden = false

        scene.updateParameters(
            gravity: preset.gravity,
            particleCount: preset.particleCount,
            spread: preset.spread,
            power: preset.power
        )

        scene.setExplosionOrigin(point)
        scene.createExplosion(at: point)

        // Keep the overlay up for the full particle lifetime; reset if another burst fires.
        hideOverlayWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.explosionWindow?.isHidden = true
            self?.hideOverlayWorkItem = nil
        }
        hideOverlayWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.overlayVisibleDuration, execute: workItem)
    }

    // MARK: - Static API
    static func trigger(_ preset: ExplosionPreset, at point: CGPoint) {
        shared.triggerExplosion(preset: preset, at: point)
    }

    static func triggerRandom(at point: CGPoint) {
        let presets: [ExplosionPreset] = [.small, .medium, .large, .atomic]
        let randomPreset = presets.randomElement() ?? .medium
        shared.triggerExplosion(preset: randomPreset, at: point)
    }

    // MARK: - Legacy convenience methods (kept for compatibility)
    func triggerSmallExplosion(at point: CGPoint) {
        triggerExplosion(preset: .small, at: point)
    }

    func triggerMediumExplosion(at point: CGPoint) {
        triggerExplosion(preset: .medium, at: point)
    }

    func triggerLargeExplosion(at point: CGPoint) {
        triggerExplosion(preset: .large, at: point)
    }

    func triggerAtomicExplosion(at point: CGPoint) {
        triggerExplosion(preset: .atomic, at: point)
    }

    func triggerRandomExplosion(at point: CGPoint) {
        ExplosionManager.triggerRandom(at: point)
    }
}
