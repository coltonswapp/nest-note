//
//  NNEmptyStateView+Animations.swift
//  nest-note
//
//  Created by Claude on 8/24/25.
//

import UIKit

extension NNEmptyStateView {
    
    /// Animates the empty state view into view with a slide-in and fade effect
    /// - Parameters:
    ///   - duration: Animation duration (default: 0.3 seconds)
    ///   - slideDistance: Distance to slide in from (default: 50 points)
    ///   - delay: Delay before starting animation (default: 0)
    ///   - completion: Optional completion handler
    func animateIn(duration: TimeInterval = 0.3,
                   slideDistance: CGFloat = 50,
                   delay: TimeInterval = 0,
                   completion: (() -> Void)? = nil) {
        
        // Prepare the view for animation
        self.isHidden = false
        self.alpha = 0.0
        self.transform = CGAffineTransform(translationX: 0, y: slideDistance)
        
        // Bring to front if it has a superview
        if let superview = self.superview {
            superview.bringSubviewToFront(self)
        }
        
        // Ensure user interaction is enabled
        self.isUserInteractionEnabled = true
        
        // Create custom property animator with the same cubic-bezier curve from SitterHomeViewController
        let animator = UIViewPropertyAnimator(
            duration: duration,
            controlPoint1: CGPoint(x: 0.34, y: 1.56),
            controlPoint2: CGPoint(x: 0.64, y: 1)
        ) {
            // Fade in
            self.alpha = 1.0
            // Slide into place
            self.transform = .identity
        }
        
        // Add completion if provided
        if let completion = completion {
            animator.addCompletion { _ in
                completion()
            }
        }
        
        // Start animation with delay
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                animator.startAnimation()
            }
        } else {
            animator.startAnimation()
        }
    }
    
    /// Animates the empty state view out of view with a fade effect
    /// - Parameters:
    ///   - duration: Animation duration (default: 0.2 seconds)
    ///   - slideDistance: Distance to slide out to (default: 20 points)
    ///   - completion: Optional completion handler
    func animateOut(duration: TimeInterval = 0.2,
                    slideDistance: CGFloat = 20,
                    completion: (() -> Void)? = nil) {
        
        // Create animator for fade out
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeInOut) {
            self.alpha = 0.0
            self.transform = CGAffineTransform(translationX: 0, y: slideDistance)
        }
        
        animator.addCompletion { _ in
            // Reset state after animation
            self.isHidden = true
            self.alpha = 1.0
            self.transform = .identity
            completion?()
        }
        
        animator.startAnimation()
    }
    
    /// Shows the empty state immediately without animation
    func showImmediately() {
        self.isHidden = false
        self.alpha = 1.0
        self.transform = .identity
        self.isUserInteractionEnabled = true
        
        if let superview = self.superview {
            superview.bringSubviewToFront(self)
        }
    }
    
    /// Hides the empty state immediately without animation
    func hideImmediately() {
        self.isHidden = true
        self.alpha = 1.0
        self.transform = .identity
    }
    
    /// Crossfades between showing and hiding the empty state based on a condition
    /// - Parameters:
    ///   - shouldShow: Whether to show the empty state
    ///   - duration: Animation duration (default: 0.3 seconds)
    ///   - completion: Optional completion handler
    func crossFade(shouldShow: Bool,
                   duration: TimeInterval = 0.3,
                   completion: (() -> Void)? = nil) {
        
        if shouldShow && self.isHidden {
            animateIn(duration: duration, completion: completion)
        } else if !shouldShow && !self.isHidden {
            animateOut(duration: duration, completion: completion)
        } else {
            completion?()
        }
    }
}