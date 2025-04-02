//
//  UIViewController+Toast.swift
//  nest-note
//
//  Created by Colton Swapp on 11/7/24.
//

import UIKit
import Toast

final class ToastManager {
    static let shared = ToastManager()
    
    private var toastWindow: PassthroughWindow?
    
    private init() {}
    
    private func setupToastWindow() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isHidden = false
        
        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .clear
        window.rootViewController = rootVC
        
        self.toastWindow = window
    }
    
    func showToast(delay: CGFloat = 0.75, text: String, subtitle: String? = nil, sentiment: Sentiment = .positive) {
        if toastWindow == nil {
            setupToastWindow()
        }
        
        var toast: Toast?
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let config = ToastConfiguration(
                direction: .bottom,
                dismissBy: [.time(time: 3.0), .swipe(direction: .natural), .longPress],
                animationTime: 0.2,
                attachTo: self.toastWindow?.rootViewController?.view
            )
            
            toast = Toast.default(
                image: sentiment == .positive ? UIImage(systemName: "checkmark")! : UIImage(systemName: "xmark")!,
                title: text,
                subtitle: subtitle,
                config: config
            )
            toast!.show()
        }
    }
}

extension UIViewController {
    func showToast(delay: CGFloat = 0.75, text: String, subtitle: String? = nil, sentiment: Sentiment = .positive) {
        ToastManager.shared.showToast(delay: delay, text: text, subtitle: subtitle, sentiment: sentiment)
    }
}

enum Sentiment {
    case positive
    case negative
}

