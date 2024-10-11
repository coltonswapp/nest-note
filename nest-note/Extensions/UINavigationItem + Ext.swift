//
//  UINavigationItem + Ext.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//

import UIKit.UINavigationItem

extension UINavigationItem {

    var weeTitle: String? {
        get {
            return value(forKey: "weeTitle") as? String
        } set {
            perform(Selector(("_setWeeTitle:")), with: newValue)
        }
    }
}
