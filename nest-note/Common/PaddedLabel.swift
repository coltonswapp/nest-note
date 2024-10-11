//
//  StatusLabel.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//

import UIKit

class PaddedLabel: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLabel()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLabel()
    }
    
    private func setupLabel() {
        backgroundColor = NNColors.primaryOpaque
        textColor = NNColors.primary
        font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        textAlignment = .center
        layer.cornerRadius = 4
        clipsToBounds = true
        
        // Allow multiple lines if needed
        numberOfLines = 0
        
        let vertical: CGFloat = 2
        let horizontal: CGFloat = 6

        // Add padding using layout margins
        layoutMargins = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        
        // Ensure the label respects layout margins
        insetsLayoutMarginsFromSafeArea = false
    }
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: layoutMargins))
    }
    
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        let width = size.width + layoutMargins.left + layoutMargins.right
        let height = size.height + layoutMargins.top + layoutMargins.bottom
        return CGSize(width: width, height: height)
    }
}
