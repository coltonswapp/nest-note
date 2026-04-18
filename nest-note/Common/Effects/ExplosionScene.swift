//
//  ExplosionScene.swift
//  nest-note
//
//  Created by Claude on 11/18/25.
//

import SpriteKit

class ExplosionScene: SKScene {

    // Explosion parameters
    private var gravity: Float = 1.8
    private var particleCount: Int = 15
    private var spread: Float = 1.9
    private var power: Float = 26
    private var explosionOrigin: CGPoint = CGPoint.zero

    // Array of emoji options
    private let emojiOptions = ["✅", "🌲", "💚", "♻️", "🥬", "🐲", "⚡", "❇️", "🐉", "💚", "🈯", "🍃", "🎾", "🪴", "🍀", "☘️", "🌿", "🌱", "🌲", "🌳", "🌴", "🎄", "🫛", "🍏", "🥝"]
                            

    override func didMove(to view: SKView) {
        // SpriteKit's default gravity is -9.8, we'll scale from that
        physicsWorld.gravity = CGVector(dx: 0, dy: CGFloat(-gravity) * 9.8)
    }

    func updateParameters(gravity: Float, particleCount: Int, spread: Float, power: Float) {
        self.gravity = gravity
        self.particleCount = particleCount
        self.spread = spread
        self.power = power

        // Update physics world gravity - maintain proper Float precision
        physicsWorld.gravity = CGVector(dx: 0, dy: CGFloat(-gravity) * 9.8)
    }

    func setExplosionOrigin(_ origin: CGPoint) {
        self.explosionOrigin = origin
    }

    func createExplosion(at point: CGPoint) {
        for _ in 0..<particleCount {
            createEmojiParticle(at: point)
        }
    }

    private func createEmojiParticle(at point: CGPoint) {
        // Create emoji label
        let emoji = emojiOptions.randomElement() ?? "💥"
        let emojiLabel = SKLabelNode(text: emoji)
        emojiLabel.fontSize = CGFloat.random(in: 20...40)

        // Convert UIKit coordinates to SpriteKit coordinates
        let spriteKitPoint = CGPoint(x: explosionOrigin.x, y: size.height - explosionOrigin.y)
        emojiLabel.position = spriteKitPoint

        // Add physics body
        emojiLabel.physicsBody = SKPhysicsBody(circleOfRadius: emojiLabel.fontSize / 2)
        emojiLabel.physicsBody?.isDynamic = true
        emojiLabel.physicsBody?.restitution = 0.3
        emojiLabel.physicsBody?.friction = 0.2

        // Confetti-like explosion: shoot upward in a spread pattern
        // Base direction: straight up (90 degrees)
        let baseAngle: Float = .pi / 2 // 90 degrees (straight up)

        // Map spread (0.5-3.0) to cone angle (20-180 degrees)
        // 20 degrees = π/9, 180 degrees = π
        let minConeAngle: Float = .pi / 9 // 20 degrees
        let maxConeAngle: Float = .pi // 180 degrees
        let normalizedSpread = (spread - 0.5) / (3.0 - 0.5) // Normalize to 0-1
        let coneAngle = minConeAngle + (maxConeAngle - minConeAngle) * normalizedSpread
        let halfCone = coneAngle / 2

        let angle = baseAngle + Float.random(in: -halfCone...halfCone)

        let magnitude = Float.random(in: power * 0.7...power)
        let impulse = CGVector(
            dx: CGFloat(cos(angle) * magnitude),
            dy: CGFloat(sin(angle) * magnitude)
        )

        addChild(emojiLabel)
        emojiLabel.physicsBody?.applyImpulse(impulse)

        // Add rotation
        let rotateAction = SKAction.rotate(byAngle: CGFloat.random(in: -3...3), duration: 1.0)
        let repeatRotate = SKAction.repeatForever(rotateAction)
        emojiLabel.run(repeatRotate)

        // Fade out and remove after delay
        let fadeDelay = SKAction.wait(forDuration: Double.random(in: 2.0...4.0))
        let fadeOut = SKAction.fadeOut(withDuration: 1.0)
        let remove = SKAction.removeFromParent()
        let sequence = SKAction.sequence([fadeDelay, fadeOut, remove])
        emojiLabel.run(sequence)
    }
}
