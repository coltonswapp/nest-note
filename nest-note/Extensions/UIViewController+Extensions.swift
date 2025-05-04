//
//  UIViewController+Extensions.swift
//  nest-note
//
//  Created by Colton Swapp on 5/3/25.
//
import UIKit

extension UIViewController {
    
    // Helper to recursively dismiss all presented view controllers
    func dismissAllViewControllers(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = keyWindow.rootViewController else {
            completion?()
            return
        }
        
        if let presentedVC = rootViewController.presentedViewController {
            // Dismiss all presented view controllers
            rootViewController.dismiss(animated: animated, completion: completion)
        } else {
            completion?()
        }
    }
}
