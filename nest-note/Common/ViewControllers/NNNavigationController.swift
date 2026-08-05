import UIKit

/// Root navigation controller that blocks pops when a minimized draft sheet is waiting.
final class NNNavigationController: UINavigationController {

    /// Intentionally not `override` — UIKit doesn't expose `shouldPop` as overridable in Swift.
    /// Returning `false` and popping ourselves avoids needing `super`.
    @objc func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool {
        // During an interactive pop, the stack is already shorter than the bar's items.
        let isInteractivePopCompletion = (navigationBar.items?.count ?? 0) > viewControllers.count
        if isInteractivePopCompletion {
            return true
        }

        if let sheet = draftSheetBlockingPop() {
            sheet.confirmDiscardForNavigationPop { [weak self] in
                self?.dismissDraftAndPop(sheet)
            }
            restoreNavigationBarAfterCancelledPop(navigationBar)
            return false
        }

        DispatchQueue.main.async { [weak self] in
            _ = self?.popViewController(animated: true)
        }
        return false
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        if let sheet = draftSheetBlockingPop() {
            sheet.confirmDiscardForNavigationPop { [weak self] in
                self?.dismissDraftAndPop(sheet)
            }
            // If the system already began a bar transition, snap it back.
            restoreNavigationBarAfterCancelledPop(navigationBar)
            return nil
        }
        return super.popViewController(animated: animated)
    }

    private func draftSheetBlockingPop() -> NNSheetViewController? {
        guard let top = topViewController else { return nil }
        if let sheet = top.presentedViewController as? NNSheetViewController, sheet.isDraftWaiting {
            return sheet
        }
        return nil
    }

    private func dismissDraftAndPop(_ sheet: NNSheetViewController) {
        sheet.dismissForNavigationPop { [weak self] in
            _ = self?.popViewController(animated: true)
        }
    }

    /// Cancelling `shouldPop` can leave bar button alphas mid-transition; restore them.
    private func restoreNavigationBarAfterCancelledPop(_ navigationBar: UINavigationBar) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.25) {
                for subview in navigationBar.subviews where subview.alpha < 1 {
                    subview.alpha = 1
                }
            }
        }
    }
}
