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

    private var explosionWindow: PassthroughWindow?
    private var explosionScene: ExplosionScene?
    private var isWindowReady = false

    private init() {
        // Setup window immediately on init to avoid first-explosion delay
        DispatchQueue.main.async {
            self.setupExplosionWindow()
        }
    }

    private func setupExplosionWindow() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .alert + 2 // Higher than toast window
        window.backgroundColor = .clear
        window.isHidden = false

        // Create root view controller with clear background (like ToastManager)
        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .clear

        // Create PassthroughSKView as a subview
        let skView = PassthroughSKView()
        skView.backgroundColor = .clear
        skView.allowsTransparency = true
        skView.translatesAutoresizingMaskIntoConstraints = false

        // Temporarily make background visible for debugging
        #if DEBUG
        skView.backgroundColor = UIColor.red.withAlphaComponent(0.1)
        #endif

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
        self.isWindowReady = true
    }

    func triggerExplosion(preset: ExplosionPreset, at point: CGPoint) {
        // Ensure window is ready before triggering explosion
        guard isWindowReady, let scene = explosionScene else {
            // If not ready, setup immediately and retry with small delay
            if explosionWindow == nil {
                setupExplosionWindow()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.triggerExplosion(preset: preset, at: point)
            }
            return
        }

        scene.updateParameters(
            gravity: preset.gravity,
            particleCount: preset.particleCount,
            spread: preset.spread,
            power: preset.power
        )

        scene.setExplosionOrigin(point)
        scene.createExplosion(at: point)
    }

    // MARK: - Static API
    static func prepareForExplosions() {
        // Force initialization of shared instance which will setup window
        _ = shared
    }

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
