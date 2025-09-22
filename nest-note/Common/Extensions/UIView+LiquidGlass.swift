//
//  UIView+LiquidGlass.swift
//  nest-note
//
//  Created by Claude on 9/22/25.
//

import UIKit

extension UIView {

    /// Applies a liquid glass effect to the view with animation
    /// - Parameters:
    ///   - animated: Whether to animate the effect application (default: true)
    ///   - duration: Animation duration (default: 0.3)
    ///   - completion: Optional completion handler
    /// - Returns: The visual effect view that was created
    @discardableResult
    func applyLiquidGlass(animated: Bool = true,
                         duration: TimeInterval = 0.3,
                         completion: (() -> Void)? = nil) -> UIVisualEffectView {

        let effectView = UIVisualEffectView()
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.layer.cornerRadius = layer.cornerRadius
        effectView.clipsToBounds = true

        // Insert at the bottom of the view hierarchy
        insertSubview(effectView, at: 0)

        // Pin to all edges
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Create the glass effect
        let glassEffect = UIBlurEffect(style: .systemMaterial)

        if animated {
            // Animate the effect for a materialize animation
            UIView.animate(withDuration: duration,
                          delay: 0,
                          options: [.curveEaseOut],
                          animations: {
                effectView.effect = glassEffect
            }, completion: { _ in
                completion?()
            })
        } else {
            effectView.effect = glassEffect
            completion?()
        }

        return effectView
    }

    /// Applies a liquid glass effect with custom blur style
    /// - Parameters:
    ///   - style: The blur effect style to use
    ///   - animated: Whether to animate the effect application (default: true)
    ///   - duration: Animation duration (default: 0.3)
    ///   - completion: Optional completion handler
    /// - Returns: The visual effect view that was created
    @discardableResult
    func applyLiquidGlass(style: UIBlurEffect.Style,
                         animated: Bool = true,
                         duration: TimeInterval = 0.3,
                         completion: (() -> Void)? = nil) -> UIVisualEffectView {

        let effectView = UIVisualEffectView()
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.layer.cornerRadius = layer.cornerRadius
        effectView.clipsToBounds = true

        insertSubview(effectView, at: 0)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let glassEffect = UIBlurEffect(style: style)

        if animated {
            UIView.animate(withDuration: duration,
                          delay: 0,
                          options: [.curveEaseOut],
                          animations: {
                effectView.effect = glassEffect
            }, completion: { _ in
                completion?()
            })
        } else {
            effectView.effect = glassEffect
            completion?()
        }

        return effectView
    }

    /// Removes all liquid glass effects from the view
    /// - Parameters:
    ///   - animated: Whether to animate the removal (default: true)
    ///   - duration: Animation duration (default: 0.3)
    ///   - completion: Optional completion handler
    func removeLiquidGlass(animated: Bool = true,
                          duration: TimeInterval = 0.3,
                          completion: (() -> Void)? = nil) {

        let effectViews = subviews.compactMap { $0 as? UIVisualEffectView }

        if animated {
            UIView.animate(withDuration: duration,
                          delay: 0,
                          options: [.curveEaseIn],
                          animations: {
                effectViews.forEach { $0.effect = nil }
            }, completion: { _ in
                effectViews.forEach { $0.removeFromSuperview() }
                completion?()
            })
        } else {
            effectViews.forEach { $0.removeFromSuperview() }
            completion?()
        }
    }
}