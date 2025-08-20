//
//  SelectEntriesCountView.swift
//  nest-note
//
//  Created by Colton Swapp on 8/7/25
//

import UIKit

class SelectEntriesCountView: UIView {
    
    // MARK: - Properties
    private let icon = UIImageView()
    private let countLabel = UILabel()
    private let iconLabelStack = UIStackView()
    private let continueButton = UIButton(type: .system)
    private let stackView = UIStackView()
    
    var onContinueTapped: (() -> Void)?
    
    var count: Int = 0 {
        didSet {
            updateCountLabel()
            updateVisibility()
        }
    }
    
    var selectionLimit: Int? = nil {
        didSet {
            updateCountLabel()
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    private func setupView() {
        setupAppearance()
        setupIcon()
        setupCountLabel()
        setupIconLabelStack()
        setupContinueButton()
        setupStackView()
        setupConstraints()
    }
    
    private func setupAppearance() {
        backgroundColor = .init(dynamicProvider: { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? NNColors.NNSystemBackground4 : .systemBackground
        })
        layer.cornerRadius = 25
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 8
        translatesAutoresizingMaskIntoConstraints = false
        
        // Start offscreen (translated down by 100 points)
        transform = CGAffineTransform(translationX: 0, y: 100)
    }
    
    private func setupIcon() {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        icon.image = UIImage(systemName: "dot.circle.and.hand.point.up.left.fill", withConfiguration: config)
        icon.tintColor = .label
    }
    
    private func setupCountLabel() {
        countLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        countLabel.textColor = .label
    }
    
    private func setupIconLabelStack() {
        iconLabelStack.axis = .horizontal
        iconLabelStack.spacing = 4
        iconLabelStack.alignment = .center
        iconLabelStack.distribution = .fill
        
        iconLabelStack.addArrangedSubview(icon)
        iconLabelStack.addArrangedSubview(countLabel)
    }
    
    private func setupContinueButton() {
        var configuration = UIButton.Configuration.filled()
        
        var container = AttributeContainer()
        container.font = .h4
        configuration.attributedTitle = AttributedString("Continue", attributes: container)

        configuration.baseBackgroundColor = .systemBlue
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        
        continueButton.configuration = configuration
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        continueButton.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupStackView() {
        stackView.axis = .horizontal
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.addArrangedSubview(iconLabelStack)
        stackView.addArrangedSubview(continueButton)
        addSubview(stackView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            
            heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }
    
    private func updateCountLabel() {
        let itemText = count == 1 ? "item" : "items"
        
        if let limit = selectionLimit {
            countLabel.text = "\(count)/\(limit) \(itemText) selected"
        } else {
            countLabel.text = "\(count) \(itemText) selected"
        }
    }
    
    private func updateVisibility() {
        let shouldShow = count > 0
        let targetTransform = shouldShow ? .identity : CGAffineTransform(translationX: 0, y: 100)
        
        let animator = UIViewPropertyAnimator(duration: 0.4, controlPoint1: CGPoint(x: 0.34, y: 1.56), controlPoint2: CGPoint(x: 0.28, y: 0.94), animations: {
            self.transform = targetTransform
        })
        
        animator.startAnimation()
    }
    
    @objc private func continueButtonTapped() {
        onContinueTapped?()
    }
}
