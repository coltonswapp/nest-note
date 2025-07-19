//
//  UINavigationItem+NavigationBarVisibility.swift
//  nest-note
//
//  Created by Colton Swapp on 1/18/25.
//

import UIKit

extension UINavigationItem {
    /// Hides the navigation bar using obfuscated method calls
    enum NavigationBarVisibility: Int {
        case visible = 0
        case hidden = 1
    }
    
    var preferredNavigationBarVisibility: NavigationBarVisibility {
        get {
            let key = "_preferredNavigationBarVisibility"
            let rawValue = value(forKey: key) as? Int ?? 0
            return NavigationBarVisibility(rawValue: rawValue)!
        } set {
            let string = "_setPreferredNavigationBarVisibility:"
            let selector = NSSelectorFromString (string)
            perform(selector, with: newValue.rawValue)
        }
    }
    
}
