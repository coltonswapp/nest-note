//
//  NNSmallLabel.swift
//  nest-note
//
//  Created by Colton Swapp on 7/26/25.
//

import UIKit

class NNSmallLabel: UILabel {
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLabel()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLabel()
    }
    
    // MARK: - Setup
    private func setupLabel() {
        // Styling similar to NNSmallPrimaryButton but smaller
        font = .h4 // Same font as NNSmallPrimaryButton
        textColor = NNColors.primary
        backgroundColor = NNColors.primary.withAlphaComponent(0.15)
        textAlignment = .center
        layer.cornerRadius = 12
        layer.masksToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
        
        // Add padding similar to button content insets
        // This will be handled by intrinsic content size
    }
    
    // MARK: - Layout
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        // Add horizontal padding (16 points on each side like NNSmallPrimaryButton)
        // Add vertical padding to achieve 30pt height
        let horizontalPadding: CGFloat = 32 // 16 leading + 16 trailing
        let verticalPadding: CGFloat = 8 // Adjust to get close to 30pt height
        return CGSize(
            width: size.width + horizontalPadding,
            height: max(30, size.height + verticalPadding)
        )
    }
    
    override func drawText(in rect: CGRect) {
        // Apply padding by inset
        let insets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
        super.drawText(in: rect.inset(by: insets))
    }
}