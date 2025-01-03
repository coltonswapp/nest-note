import UIKit

class NNSheetTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let isPresenting: Bool
    private let sourceFrame: CGRect?
    
    private let presentationDuration: TimeInterval = 0.4
    private let dismissalDuration: TimeInterval = 0.7
    
    init(isPresenting: Bool, sourceFrame: CGRect? = nil) {
        self.isPresenting = isPresenting
        self.sourceFrame = sourceFrame
        super.init()
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return isPresenting ? presentationDuration : dismissalDuration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresentation(using: transitionContext)
        } else {
            animateDismissal(using: transitionContext)
        }
    }
    
    private func animatePresentation(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        guard let toVC = transitionContext.viewController(forKey: .to),
              let toView = toVC.view,
              let sheetVC = toVC as? NNSheetViewController else { return }
        
        // Use sourceFrame if available, otherwise use Dynamic Island position
        let startFrame: CGRect
        if let sourceFrame = sourceFrame {
            startFrame = sourceFrame
        } else {
            startFrame = CGRect(x: containerView.bounds.width / 2 - 60,
                              y: 0,
                              width: 120,
                              height: 37)
        }
        
        HapticsHelper.mediumHaptic()
        
        let transitionView = UIView()
        transitionView.translatesAutoresizingMaskIntoConstraints = false
        transitionView.frame = containerView.bounds
        transitionView.layer.cornerRadius = startFrame.height / 2
        transitionView.backgroundColor = .tertiarySystemBackground
        
        let clippingView = UIView()
        clippingView.frame = startFrame
        clippingView.clipsToBounds = true
        clippingView.layer.cornerCurve = .continuous
        clippingView.layer.cornerRadius = startFrame.height / 2
        clippingView.addSubview(toView)
        
        containerView.addSubview(clippingView)
        
        toView.frame = clippingView.bounds
        toView.layoutIfNeeded()
        
        // Hide transition items
        sheetVC.itemsHiddenDuringTransition.forEach { $0.alpha = 0.0 }
        
        let animator = UIViewPropertyAnimator(duration: transitionDuration(using: transitionContext), dampingRatio: 0.8) {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.6) {
                transitionView.frame = containerView.bounds
                clippingView.frame = containerView.bounds
            }
            
            UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.3) {
                sheetVC.titleLabel.alpha = 1.0
                sheetVC.titleField.alpha = 1.0
            }
            
            UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.4) {
                transitionView.layer.cornerRadius = 24
                clippingView.layer.cornerRadius = 24
                toView.frame = containerView.bounds
                sheetVC.itemsHiddenDuringTransition.forEach { $0.alpha = 1.0 }
            }
        }
        
        animator.addCompletion { _ in
            containerView.addSubview(toView)
            clippingView.removeFromSuperview()
            transitionView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        
        animator.startAnimation()
    }
    
    private func animateDismissal(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        guard let fromVC = transitionContext.viewController(forKey: .from),
              let fromView = fromVC.view,
              let sheetVC = fromVC as? NNSheetViewController else { return }
        
        let endFrame = CGRect(x: containerView.bounds.width / 4,
                            y: transitionContext.containerView.bounds.height + 200,
                            width: containerView.bounds.width / 2,
                            height: 20)
        
        HapticsHelper.mediumHaptic()
        
        let clippingView = UIView()
        clippingView.frame = sheetVC.containerView.frame
        clippingView.clipsToBounds = true
        clippingView.layer.cornerCurve = .continuous
        clippingView.layer.cornerRadius = 24
        clippingView.addSubview(sheetVC.containerView)
        clippingView.backgroundColor = .tertiarySystemBackground
        clippingView.layer.shadowColor = UIColor.black.cgColor
        clippingView.layer.shadowOpacity = 0.75
        
        containerView.addSubview(clippingView)
        
        let animator = UIViewPropertyAnimator(duration: dismissalDuration, dampingRatio: 0.8) {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.3) {
                sheetVC.itemsHiddenDuringTransition.forEach { $0.alpha = 0.0 }
            }
            
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: self.dismissalDuration) {
                clippingView.layer.cornerRadius = endFrame.height / 2
                clippingView.frame = endFrame
                clippingView.alpha = 1.0
            }
            
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.65) {
                fromView.alpha = 0.0
            }
        }
        
        animator.addCompletion { _ in
            fromView.removeFromSuperview()
            clippingView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        
        animator.startAnimation()
    }
}

class NNSheetTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    private let sourceFrame: CGRect?
    
    init(sourceFrame: CGRect? = nil) {
        self.sourceFrame = sourceFrame
        super.init()
    }
    
    func presentationController(forPresented presented: UIViewController,
                              presenting: UIViewController?,
                              source: UIViewController) -> UIPresentationController? {
        return NNSheetPresentationController(presentedViewController: presented,
                                           presenting: presenting)
    }
    
    func animationController(forPresented presented: UIViewController,
                           presenting: UIViewController,
                           source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return NNSheetTransitionAnimator(isPresenting: true, sourceFrame: sourceFrame)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return NNSheetTransitionAnimator(isPresenting: false, sourceFrame: sourceFrame)
    }
}

class NNSheetPresentationController: UIPresentationController {
    override var shouldRemovePresentersView: Bool {
        return false
    }
} 