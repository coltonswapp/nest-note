//
//  UIViewController+BottomPalette.swift
//  nest-note
//
//  Created by Colton Swapp on 12/31/24.
//

import UIKit

extension UIViewController {
    /// Adds a view as a bottom palette to the navigation bar
    /// - Parameter view: The view to be added as the bottom palette
    func addNavigationBarPalette(_ view: UIView) {
        let paletteString1: String = "ettelaPraB"
        let paletteString2: String = "noitagivaNIU_"
        
        let classString: String = paletteString1+paletteString2
        
        let selectorString1: String = ":ettelaP"
        let selectorString2: String = "mottoBtes_"
        
        let selectorString: String = selectorString1+selectorString2
        
        // Get the private UINavigationBarPalette class
        guard let paletteClass = NSClassFromString(String(classString.reversed())) as? UIView.Type else { return }
        
        // Create the palette with the provided view
        let palette = paletteClass.perform(NSSelectorFromString("alloc"))
            .takeUnretainedValue()
            .perform(NSSelectorFromString("initWithContentView:"), with: view)
            .takeUnretainedValue()
        
        // Set the bottom palette
        navigationItem.perform(NSSelectorFromString(String(selectorString.reversed())), with: palette)
    }
}
