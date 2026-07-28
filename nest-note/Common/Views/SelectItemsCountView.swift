//
//  SelectEntriesCountView.swift
//  nest-note
//
//  Created by Colton Swapp on 8/7/25
//

import UIKit

class SelectItemsCountView: UIVisualEffectView {
    
    // MARK: - Properties
    private let icon = UIImageView()
    private let countLabel = UILabel()
    private let iconLabelStack = UIStackView()
    private let continueContainer = UIView()
    private let continueTitleLabel = UILabel()
    private let spinner = NNLoadingSpinner()
    private let continueTapButton = UIButton(type: .system)
    private let stackView = UIStackView()
    private var isLoading = false

    var onContinueTapped: (() -> Void)?
    
    /// When true, the bar stays visible after the user clears a non-empty selection so they can confirm zero items.
    var allowsEmptySelection: Bool = false
    
    /// When true, the bar is always visible (creation wizard step).
    var alwaysShowsContinue: Bool = false
    
    /// Highest selection count seen this session; used with `allowsEmptySelection` to keep Continue available after clearing.
    var peakSelectionCount: Int = 0
    
    var count: Int = 0 {
        didSet {
            peakSelectionCount = max(peakSelectionCount, count)
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
    override init(effect: UIVisualEffect?) {
        super.init(effect: effect)
        setupView()
    }

    convenience init() {
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .regular)
            glassEffect.isInteractive = true
            self.init(effect: glassEffect)
        } else {
            // Fallback: No effect for older iOS versions
            self.init(effect: nil)
        }
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
        layer.cornerRadius = 25
        translatesAutoresizingMaskIntoConstraints = false

        // Add background styling for non-glass versions
        if #available(iOS 26.0, *) {
            // Glass effect handles the background
        } else {
            // Fallback: Add background color and shadow for non-glass
            backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 2)
            layer.shadowOpacity = 0.1
            layer.shadowRadius = 8
        }

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
        continueContainer.translatesAutoresizingMaskIntoConstraints = false
        continueContainer.backgroundColor = .systemBlue
        continueContainer.layer.cornerRadius = 18
        continueContainer.clipsToBounds = true
        
        continueTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        continueTitleLabel.text = "Continue"
        continueTitleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        continueTitleLabel.textColor = .white
        continueTitleLabel.textAlignment = .center
        
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isHidden = true
        spinner.configure(with: .white)
        
        continueTapButton.translatesAutoresizingMaskIntoConstraints = false
        continueTapButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        
        continueContainer.addSubview(continueTitleLabel)
        continueContainer.addSubview(spinner)
        continueContainer.addSubview(continueTapButton)
        
        NSLayoutConstraint.activate([
            continueTitleLabel.centerXAnchor.constraint(equalTo: continueContainer.centerXAnchor),
            continueTitleLabel.centerYAnchor.constraint(equalTo: continueContainer.centerYAnchor),
            continueTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: continueContainer.leadingAnchor, constant: 16),
            continueTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: continueContainer.trailingAnchor, constant: -16),
            
            spinner.centerXAnchor.constraint(equalTo: continueContainer.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: continueContainer.centerYAnchor),
            spinner.heightAnchor.constraint(equalToConstant: 20),
            spinner.widthAnchor.constraint(equalTo: spinner.heightAnchor),
            
            continueTapButton.topAnchor.constraint(equalTo: continueContainer.topAnchor),
            continueTapButton.leadingAnchor.constraint(equalTo: continueContainer.leadingAnchor),
            continueTapButton.trailingAnchor.constraint(equalTo: continueContainer.trailingAnchor),
            continueTapButton.bottomAnchor.constraint(equalTo: continueContainer.bottomAnchor),
            
            continueContainer.heightAnchor.constraint(equalToConstant: 36),
            continueContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 110)
        ])
        
        spinner.transform = CGAffineTransform(translationX: 0, y: 40)
    }
    
    private func setupStackView() {
        stackView.axis = .horizontal
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.addArrangedSubview(iconLabelStack)
        stackView.addArrangedSubview(continueContainer)
        contentView.addSubview(stackView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

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
        guard !isLoading else { return }
        
        let shouldShow = alwaysShowsContinue || count > 0 || (allowsEmptySelection && peakSelectionCount > 0)
        let targetTransform = shouldShow ? .identity : CGAffineTransform(translationX: 0, y: 100)

        let animator = UIViewPropertyAnimator(duration: 0.4, controlPoint1: CGPoint(x: 0.34, y: 1.56), controlPoint2: CGPoint(x: 0.28, y: 0.94), animations: {
            self.transform = targetTransform
            self.alpha = 1
        })

        animator.startAnimation()
    }
    
    // MARK: - Loading
    
    func startLoading() {
        guard !isLoading else { return }
        isLoading = true
        isUserInteractionEnabled = false
        
        spinner.isHidden = false
        spinner.reset()
        spinner.transform = CGAffineTransform(translationX: 0, y: continueContainer.bounds.height > 0 ? continueContainer.bounds.height : 40)
        
        let animator = UIViewPropertyAnimator(
            duration: 0.45,
            controlPoint1: CGPoint(x: 0.76, y: 0.0),
            controlPoint2: CGPoint(x: 0.24, y: 1.0)
        ) {
            self.spinner.transform = .identity
            self.continueTitleLabel.transform = CGAffineTransform(
                translationX: 0,
                y: -(self.continueContainer.bounds.height > 0 ? self.continueContainer.bounds.height : 40)
            )
        }
        animator.startAnimation()
    }
    
    /// - Parameter restoreTitle: When false, leaves the spinner/success state visible (e.g. before sliding the bar off).
    func stopLoading(
        withSuccess success: Bool? = nil,
        restoreTitle: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let finish: () -> Void = { [weak self] in
            guard let self else {
                completion?()
                return
            }
            
            if restoreTitle {
                self.hideSpinner {
                    self.isLoading = false
                    self.isUserInteractionEnabled = true
                    completion?()
                }
            } else {
                self.isLoading = false
                self.isUserInteractionEnabled = true
                completion?()
            }
        }
        
        if let success {
            spinner.animateState(success: success) {
                finish()
            }
        } else {
            finish()
        }
    }
    
    func animateOff(completion: (() -> Void)? = nil) {
        // Avoid animating alpha on UIVisualEffectView — it snaps the glass effect off
        // instead of fading. Match the same spring used when the bar slides in.
        let offscreenY = max(bounds.height + 40, 120)
        let animator = UIViewPropertyAnimator(
            duration: 0.45,
            controlPoint1: CGPoint(x: 0.34, y: 1.56),
            controlPoint2: CGPoint(x: 0.28, y: 0.94)
        ) {
            self.transform = CGAffineTransform(translationX: 0, y: offscreenY)
        }
        animator.addCompletion { _ in
            completion?()
        }
        animator.startAnimation()
    }
    
    private func hideSpinner(completion: (() -> Void)? = nil) {
        let offset = continueContainer.bounds.height > 0 ? continueContainer.bounds.height : 40
        let animator = UIViewPropertyAnimator(
            duration: 0.35,
            controlPoint1: CGPoint(x: 0.76, y: 0.0),
            controlPoint2: CGPoint(x: 0.24, y: 1.0)
        ) {
            self.spinner.transform = CGAffineTransform(translationX: 0, y: offset)
            self.continueTitleLabel.transform = .identity
        }
        animator.addCompletion { _ in
            self.spinner.isHidden = true
            self.spinner.reset()
            completion?()
        }
        animator.startAnimation()
    }
    
    @objc private func continueButtonTapped() {
        guard !isLoading else { return }
        onContinueTapped?()
    }
}
