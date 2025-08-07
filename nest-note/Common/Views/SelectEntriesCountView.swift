//
//  SelectEntriesCountView.swift
//  nest-note
//
//  Created by Colton Swapp on 8/7/25
//

import UIKit

class SelectEntriesCountView: UIView {
    
    // MARK: - Properties
    private let countLabel = UILabel()
    private let continueButton = UIButton(type: .system)
    private let stackView = UIStackView()
    
    var onContinueTapped: (() -> Void)?
    
    var count: Int = 0 {
        didSet {
            updateCountLabel()
            isHidden = count == 0
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
        setupCountLabel()
        setupContinueButton()
        setupStackView()
        setupConstraints()
    }
    
    private func setupAppearance() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 25
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 8
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupCountLabel() {
        countLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        countLabel.textColor = .label
        countLabel.translatesAutoresizingMaskIntoConstraints = false
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
        
        stackView.addArrangedSubview(countLabel)
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
        countLabel.text = "\(count) \(itemText) selected"
    }
    
    @objc private func continueButtonTapped() {
        onContinueTapped?()
    }
}
