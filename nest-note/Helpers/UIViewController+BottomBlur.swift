import UIKit

extension UIViewController {
    /// Adds a blur effect view pinned to the bottom of the view controller's view.
    /// - Parameters:
    ///   - useSafeArea: Whether to use the safe area layout guide (default is true)
    ///   - height: The height of the blur area (default is 55)
    ///   - blurRadius: The radius of the blur effect (default is 16)
    ///   - blurMaskImage: The mask image for the blur effect (default is nil)
    /// - Returns: The created UIVisualEffectView for further customization if needed
    @discardableResult
    func pinBottomBlur(useSafeArea: Bool = true, height: CGFloat = 55, blurRadius: Double = 16, blurMaskImage: UIImage? = nil) -> UIVisualEffectView {
        let visualEffectView = UIVisualEffectView()
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        if let maskImage = blurMaskImage {
            visualEffectView.effect = UIBlurEffect.variableBlurEffect(radius: blurRadius, maskImage: maskImage)
        } else {
            visualEffectView.effect = UIBlurEffect(style: .regular)
        }
        
        view.addSubview(visualEffectView)
        
        
        let bottomAnchor = useSafeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor
        
        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            visualEffectView.topAnchor.constraint(equalTo: bottomAnchor, constant: (-height) - 20)
        ])
        
        return visualEffectView
    }
} 
