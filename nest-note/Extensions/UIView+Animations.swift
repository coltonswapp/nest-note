//
//  UIView+Animations.swift
//  nest-note
//
//  Created by Colton Swapp on 10/6/24.
//

import UIKit

extension UIView {
    func bounce(height: CGFloat = 22, duration: TimeInterval = 0.5, includeScale: Bool = false) {
        // Position animation
        let bounceAnimation = CAKeyframeAnimation(keyPath: "position")
        
        // Initial position
        let initialPosition = self.center
        
        // Bouncing positions
        let bounce1 = CGPoint(x: initialPosition.x, y: initialPosition.y - height)
        let bounce2 = CGPoint(x: initialPosition.x, y: initialPosition.y - 0)
        let bounce3 = CGPoint(x: initialPosition.x, y: initialPosition.y - (height/2))
        let bounce4 = CGPoint(x: initialPosition.x, y: initialPosition.y)
        
        bounceAnimation.values = [
            NSValue(cgPoint: initialPosition),
            NSValue(cgPoint: bounce1),
            NSValue(cgPoint: bounce2),
            NSValue(cgPoint: bounce3),
            NSValue(cgPoint: bounce4)
        ]
        
        bounceAnimation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeIn)
        ]
        
        bounceAnimation.duration = duration
        
        if includeScale {
            // Scale animation
            let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
            
            scaleAnimation.values = [
                0.01,  // Start tiny
                1.1,   // Slightly overshoot
                1.0    // Settle to normal
            ]
            
            scaleAnimation.keyTimes = [
                0,      // Start
                0.2,    // Overshoot at 20% of the animation
                0.4     // Settle by 40% of the animation
            ]
            
            scaleAnimation.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeIn)
            ]
            
            scaleAnimation.duration = duration
            
            // Combine animations
            let animationGroup = CAAnimationGroup()
            animationGroup.animations = [bounceAnimation, scaleAnimation]
            animationGroup.duration = duration
            
            // Add the animation group
            self.layer.add(animationGroup, forKey: "bounceAndScaleAnimation")
        } else {
            // Just add the bounce animation
            self.layer.add(bounceAnimation, forKey: "bounceAnimation")
        }
    }
    
    func scaleAnimation(scaleTo: CGFloat = 1.3, duration: TimeInterval = 0.3) {
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        
        scaleAnimation.values = [
            1.0,     // Start normal
            scaleTo, // Scale up
            1.0      // Back to normal
        ]
        
        scaleAnimation.keyTimes = [
            0,    // Start
            0.5,  // Peak scale at middle
            1.0   // End
        ]
        
        scaleAnimation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeIn)
        ]
        
        scaleAnimation.duration = duration
        
        self.layer.add(scaleAnimation, forKey: "scaleAnimation")
    }
    
    func errorShake(angle: CGFloat = 0.1, duration: TimeInterval = 0.4) {
        let rotationAnimation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        
        // Convert angles to radians
        let angleInRadians = angle * .pi
        
        rotationAnimation.values = [
            0,                  // Start position
            -angleInRadians,    // Rotate counterclockwise
            angleInRadians,     // Rotate clockwise
            -angleInRadians/2,  // Smaller counterclockwise
            angleInRadians/4,   // Smaller clockwise
            0                   // Back to center
        ]
        
        rotationAnimation.keyTimes = [
            0,    // Start
            0.2,  // First rotation
            0.4,  // Second rotation
            0.6,  // Third rotation
            0.8,  // Fourth rotation
            1.0   // End
        ]
        
        rotationAnimation.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        
        rotationAnimation.duration = duration
        
        self.layer.add(rotationAnimation, forKey: "errorShakeAnimation")
    }
} 
