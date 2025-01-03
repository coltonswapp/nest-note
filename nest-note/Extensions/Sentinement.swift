//
//  Sentinement.swift
//  nest-note
//
//  Created by Colton Swapp on 11/7/24.
//

import UIKit
import Toast

extension UIViewController {

    func showToast(delay: CGFloat = 0.75, text: String, subtitle: String? = nil, sentiment: Sentinement = .positive) {
        
        var toast: Toast?
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            
            let config = ToastConfiguration(
                direction: .bottom,
                dismissBy: [.time(time: 3.0), .swipe(direction: .natural), .longPress],
                animationTime: 0.2,
                attachTo: self.view
            )
            
            toast = Toast.default(image: sentiment == .positive ? UIImage(systemName: "checkmark")! : UIImage(systemName: "xmark")!, title: (text), subtitle: subtitle, config: config)
            toast!.show()
        }
    }
    
//    func showReachabilityToast() {
//        showToast(text: "No internet connection.", sentiment: .negative)
//    }
    
    enum Sentinement {
        case positive
        case negative
    }
}

