//
//  NSLayoutConstraint + Ext.swift
//  nest-note
//
//  Created by Colton Swapp on 10/17/24.
//

import UIKit.NSLayoutConstraint

extension NSLayoutConstraint {
    func with(priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
