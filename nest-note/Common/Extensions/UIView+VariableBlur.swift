//
//  UIView+VariableBlur.swift
//  nest-note
//
//  Created by Claude on 2/4/25.
//

import UIKit

extension UIView {
    
    enum BlurDirection {
        case top
        case bottom
        case left
        case right
        
        var gradientStartPoint: CGPoint {
            switch self {
            case .top:
                return CGPoint(x: 0.5, y: 0.0)
            case .bottom:
                return CGPoint(x: 0.5, y: 1.0)
            case .left:
                return CGPoint(x: 0.0, y: 0.5)
            case .right:
                return CGPoint(x: 1.0, y: 0.5)
            }
        }
        
        var gradientEndPoint: CGPoint {
            switch self {
            case .top:
                return CGPoint(x: 0.5, y: 1.0)
            case .bottom:
                return CGPoint(x: 0.5, y: 0.0)
            case .left:
                return CGPoint(x: 1.0, y: 0.5)
            case .right:
                return CGPoint(x: 0.0, y: 0.5)
            }
        }
    }
    
    /// Pins a variable blur effect to the specified direction of the view
    /// - Parameters:
    ///   - view: The view to pin the blur to (usually the superview)
    ///   - direction: The direction to pin the blur (.top, .bottom, .left, .right)
    ///   - useSafeArea: Whether to use the safe area layout guide (default is true)
    ///   - blurRadius: The radius of the blur effect (default is 16)
    ///   - height: The height/width of the blur area (default is 80)
    ///   - blurMaskImage: Optional custom mask image for the blur effect
    /// - Returns: The visual effect view that was created
    @discardableResult
    func pinVariableBlur(to view: UIView,
                        direction: BlurDirection,
                        useSafeArea: Bool = true,
                        blurRadius: Double = 16,
                        height: CGFloat = 80) -> UIVisualEffectView {
        
        let maskImage = UIImage(named: "testBG3") ?? createGradientMaskImage(direction: direction, height: height)
        
        let visualEffectView = UIVisualEffectView()
        visualEffectView.effect = UIBlurEffect.variableBlurEffect(radius: blurRadius, maskImage: maskImage)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        view.insertSubview(visualEffectView, belowSubview: self)
        
        setupBlurConstraints(for: visualEffectView, in: view, direction: direction, height: height, useSafeArea: useSafeArea)
        
        return visualEffectView
    }
    
    private func createGradientMaskImage(direction: BlurDirection, height: CGFloat) -> UIImage {
        // Use appropriate size based on direction
        let size: CGSize
        switch direction {
        case .top, .bottom:
            size = CGSize(width: 100, height: height)
        case .left, .right:
            size = CGSize(width: height, height: 100)
        }
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Create gradient
            let colorSpace = CGColorSpaceCreateDeviceGray()
            let colors = [UIColor.black.cgColor, UIColor.clear.cgColor]
            let locations: [CGFloat] = [0.0, 1.0]
            
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
                return
            }
            
            // Calculate gradient points based on direction
            let startPoint = CGPoint(
                x: direction.gradientStartPoint.x * size.width,
                y: direction.gradientStartPoint.y * size.height
            )
            let endPoint = CGPoint(
                x: direction.gradientEndPoint.x * size.width,
                y: direction.gradientEndPoint.y * size.height
            )
            
            // Draw the gradient
            cgContext.drawLinearGradient(gradient, 
                                       start: startPoint, 
                                       end: endPoint, 
                                       options: [])
        }
    }
    
    private func setupBlurConstraints(for visualEffectView: UIVisualEffectView,
                                    in view: UIView,
                                    direction: BlurDirection,
                                    height: CGFloat,
                                    useSafeArea: Bool) {
        
        let leadingAnchor = useSafeArea ? view.safeAreaLayoutGuide.leadingAnchor : view.leadingAnchor
        let trailingAnchor = useSafeArea ? view.safeAreaLayoutGuide.trailingAnchor : view.trailingAnchor
        let topAnchor = useSafeArea ? view.safeAreaLayoutGuide.topAnchor : view.topAnchor
        let bottomAnchor = useSafeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor
        
        switch direction {
        case .bottom:
            NSLayoutConstraint.activate([
                visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                visualEffectView.heightAnchor.constraint(equalToConstant: height)
            ])
            
        case .top:
            NSLayoutConstraint.activate([
                visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                visualEffectView.topAnchor.constraint(equalTo: topAnchor),
                visualEffectView.heightAnchor.constraint(equalToConstant: height)
            ])
            
        case .left:
            NSLayoutConstraint.activate([
                visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                visualEffectView.topAnchor.constraint(equalTo: topAnchor),
                visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
                visualEffectView.widthAnchor.constraint(equalToConstant: height)
            ])
            
        case .right:
            NSLayoutConstraint.activate([
                visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                visualEffectView.topAnchor.constraint(equalTo: topAnchor),
                visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
                visualEffectView.widthAnchor.constraint(equalToConstant: height)
            ])
        }
    }
}
