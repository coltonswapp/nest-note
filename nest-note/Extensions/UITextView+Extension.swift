//
//  UITextView+Extension.swift
//  nest-note
//
//  Created by Colton Swapp on 5/29/25.
//

import UIKit.UITextView

extension UITextView {
    
    /// Easily set a UITextField placeholder
    func setPlaceHolder(_ placeholder: String) {
        let one: String = "set"
        let two: String = "Attributed"
        let three: String = "Placeholder:"
        let final: String = [one, two, three].joined()
        
        self.perform(NSSelectorFromString(final), with: NSAttributedString(string: placeholder))
    }
    
    func scrollToCaretIfNeeded() {
        // First try the private method
        let selector = NSSelectorFromString("_scrollToCaretIfNeeded")
        if self.responds(to: selector) {
            self.perform(selector)
        } else {
            // Fallback implementation
            scrollToCaretManually()
        }
    }
    
    /// Fallback method to manually scroll to the cursor position
    private func scrollToCaretManually() {
        guard let selectedRange = selectedTextRange else { return }
        
        // Get the cursor position rectangle
        let caretRect = self.caretRect(for: selectedRange.end)
        
        // Adjust for content insets
        let adjustedRect = CGRect(
            x: caretRect.origin.x,
            y: caretRect.origin.y - contentInset.top,
            width: caretRect.width,
            height: caretRect.height
        )
        
        // Only scroll if the caret is not visible
        let visibleRect = CGRect(
            x: contentOffset.x,
            y: contentOffset.y,
            width: bounds.width - contentInset.left - contentInset.right,
            height: bounds.height - contentInset.top - contentInset.bottom
        )
        
        if !visibleRect.contains(adjustedRect) {
            scrollRectToVisible(adjustedRect, animated: true)
        }
    }
    
    /// Sets the text container inset using the private method
    /// - Parameter insets: The edge insets to apply to the text container
    func setCustomTextContainerInset(_ insets: UIEdgeInsets) {
        // Use the private method via selector
        let selector = NSSelectorFromString("setTextContainerInset:")
        if self.responds(to: selector) {
            self.perform(selector, with: NSValue(uiEdgeInsets: insets))
        }
    }
}
