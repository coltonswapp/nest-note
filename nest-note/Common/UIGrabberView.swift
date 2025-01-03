//
//  UIGrabberView.swift
//  nest-note
//
//  Created by Colton Swapp on 10/22/24.
//
import UIKit

class UIGrabberView: UIControl {
    // MARK: - Private Properties
    private var backgroundView: UIView!
    
    // MARK: - Public Properties
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 36, height: 5)
    }
    
    // MARK: - init(frame:)
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBackgroundView()
    }
    
    // MARK: - init(coder:)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private Methods
    private func setupBackgroundView() {
        backgroundView = UIView()
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerCurve = .circular
        backgroundView.backgroundColor = .tertiaryLabel
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(backgroundView)
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func layoutBackgroundView() {
        backgroundView.layer.cornerRadius = frame.height / 2
    }
    
    // MARK: - layoutSubviews()
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutBackgroundView()
    }
}
