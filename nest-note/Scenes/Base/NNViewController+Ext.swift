import UIKit

// MARK: - Keyboard Avoidance
extension NNViewController {
    /// Sets up keyboard avoidance for a bottom-anchored view
    /// - Parameters:
    ///   - bottomView: The view that should move up with the keyboard
    ///   - bottomConstraint: The constraint that controls the bottom spacing of the view
    ///   - defaultBottomSpacing: The default bottom spacing when keyboard is hidden
    ///   - additionalOffset: Additional offset to add when keyboard is shown (defaults to 16)
    func setupKeyboardAvoidance(
        for bottomView: UIView,
        bottomConstraint: NSLayoutConstraint,
        defaultBottomSpacing: CGFloat,
        additionalOffset: CGFloat = 8
    ) {
        // Store the constraint and default spacing
        objc_setAssociatedObject(
            bottomView,
            &AssociatedKeys.keyboardBottomConstraint,
            bottomConstraint,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            bottomView,
            &AssociatedKeys.defaultBottomSpacing,
            defaultBottomSpacing,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            bottomView,
            &AssociatedKeys.additionalOffset,
            additionalOffset,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Add keyboard observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(NNkeyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(NNkeyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    /// Removes keyboard avoidance setup for a view
    /// - Parameter bottomView: The view that was previously set up for keyboard avoidance
    func removeKeyboardAvoidance(for bottomView: UIView) {
        // Remove associated objects
        objc_setAssociatedObject(
            bottomView,
            &AssociatedKeys.keyboardBottomConstraint,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            bottomView,
            &AssociatedKeys.defaultBottomSpacing,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            bottomView,
            &AssociatedKeys.additionalOffset,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        // Remove observers if this is the last view using keyboard avoidance
        if !hasAnyKeyboardAvoidanceSetup() {
            NotificationCenter.default.removeObserver(
                self,
                name: UIResponder.keyboardWillShowNotification,
                object: nil
            )
            NotificationCenter.default.removeObserver(
                self,
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
        }
    }
    
    private func hasAnyKeyboardAvoidanceSetup() -> Bool {
        // Check if any view in the hierarchy has keyboard avoidance setup
        return view.subviews.contains { view in
            objc_getAssociatedObject(view, &AssociatedKeys.keyboardBottomConstraint) != nil
        }
    }
    
    @objc private func NNkeyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        
        // Find all views with keyboard avoidance setup
        view.subviews.forEach { subview in
            if let constraint = objc_getAssociatedObject(subview, &AssociatedKeys.keyboardBottomConstraint) as? NSLayoutConstraint,
               let defaultSpacing = objc_getAssociatedObject(subview, &AssociatedKeys.defaultBottomSpacing) as? CGFloat,
               let additionalOffset = objc_getAssociatedObject(subview, &AssociatedKeys.additionalOffset) as? CGFloat {
                
                UIView.animate(withDuration: duration) {
                    constraint.constant = -keyboardHeight + defaultSpacing + additionalOffset
                    self.view.layoutIfNeeded()
                }
            }
        }
    }
    
    @objc private func NNkeyboardWillHide(notification: NSNotification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        // Reset all views with keyboard avoidance setup
        view.subviews.forEach { subview in
            if let constraint = objc_getAssociatedObject(subview, &AssociatedKeys.keyboardBottomConstraint) as? NSLayoutConstraint,
               let defaultSpacing = objc_getAssociatedObject(subview, &AssociatedKeys.defaultBottomSpacing) as? CGFloat {
                
                UIView.animate(withDuration: duration) {
                    constraint.constant = -defaultSpacing
                    self.view.layoutIfNeeded()
                }
            }
        }
    }
}

// MARK: - Associated Keys
private struct AssociatedKeys {
    static var keyboardBottomConstraint: UInt8 = 0
    static var defaultBottomSpacing: UInt8 = 1
    static var additionalOffset: UInt8 = 2
}
