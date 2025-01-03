//
//  UIBlurEffect + Ext.swift
//  nest-note
//
//  Created by Colton Swapp on 10/20/24.
//
import UIKit.UIBlurEffect

extension UIBlurEffect {
    static func variableBlurEffect(radius: Double, maskImage: UIImage) -> UIBlurEffect? {
        let symbol = (@convention(c) (AnyClass, Selector, Double, UIImage) -> UIBlurEffect).self
        let selector = NSSelectorFromString("effectWithVariableBlurRadius:imageMask:")

        guard UIBlurEffect.responds(to: selector) else { return nil }

        let implementation = UIBlurEffect.method(for: selector)
        let method = unsafeBitCast(implementation, to: symbol)

        return method(UIBlurEffect.self, selector, radius, maskImage)
    }
}
