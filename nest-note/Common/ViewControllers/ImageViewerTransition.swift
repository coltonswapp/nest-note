import UIKit

class ImageViewerTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    private let sourceImageView: UIImageView
    
    init(sourceImageView: UIImageView) {
        self.sourceImageView = sourceImageView
        super.init()
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ImageViewerAnimator(isPresenting: true, sourceImageView: sourceImageView)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ImageViewerAnimator(isPresenting: false, sourceImageView: sourceImageView)
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return nil // We'll add this later for interactive dismissal
    }
}

class ImageViewerAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let isPresenting: Bool
    private let sourceImageView: UIImageView
    
    init(isPresenting: Bool, sourceImageView: UIImageView) {
        self.isPresenting = isPresenting
        self.sourceImageView = sourceImageView
        super.init()
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresentation(using: transitionContext)
        } else {
            animateDismissal(using: transitionContext)
        }
    }
    
    private func animatePresentation(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toVC = transitionContext.viewController(forKey: .to) as? ImageViewerController else { return }
        
        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toVC)
        
        // Convert source frame to container view coordinates
        let sourceFrame = sourceImageView.convert(sourceImageView.bounds, to: containerView)
        
        // Setup initial state
        toVC.view.frame = finalFrame
        toVC.imageView.frame = sourceFrame
        toVC.view.backgroundColor = .clear
        
        containerView.addSubview(toVC.view)
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext),
                      delay: 0,
                      usingSpringWithDamping: 0.8,
                      initialSpringVelocity: 0,
                      options: .curveEaseOut) {
            toVC.imageView.frame = finalFrame
            toVC.view.backgroundColor = .black
        } completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
    
    private func animateDismissal(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromVC = transitionContext.viewController(forKey: .from) as? ImageViewerController else { return }
        
        let containerView = transitionContext.containerView
        let sourceFrame = sourceImageView.convert(sourceImageView.bounds, to: containerView)
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext),
                      delay: 0,
                      usingSpringWithDamping: 0.8,
                      initialSpringVelocity: 0,
                      options: .curveEaseOut) {
            fromVC.imageView.frame = sourceFrame
            fromVC.view.backgroundColor = .clear
        } completion: { _ in
            fromVC.view.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
} 