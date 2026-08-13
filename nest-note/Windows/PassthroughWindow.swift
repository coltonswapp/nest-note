//
//  PassthroughWindow.swift
//  NestNote
//
//  Created by Colton Swapp on 1/15/25.
//

import UIKit

final class PassthroughWindow: UIWindow {
    /// Only interactive content attached to the root view (e.g. a toast) should
    /// capture touches. The empty root / system chrome must never steal hits from
    /// windows underneath — including modals like `QLPreviewController`.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let rootView = rootViewController?.view else { return nil }

        let pointInRoot = convert(point, to: rootView)
        guard rootView.bounds.contains(pointInRoot) else { return nil }

        // Walk root subviews only — never return the root view itself.
        for subview in rootView.subviews.reversed() where !subview.isHidden && subview.isUserInteractionEnabled && subview.alpha > 0.01 {
            let pointInSubview = rootView.convert(pointInRoot, to: subview)
            if let hit = subview.hitTest(pointInSubview, with: event) {
                return hit
            }
        }

        return nil
    }
} 