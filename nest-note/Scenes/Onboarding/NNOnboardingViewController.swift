//
// NNOnboardingViewController.swift
// nest-note
//
// Created by Colton Swapp on 11/3/24.
//

import UIKit
import Combine

class NNOnboardingViewController: UIViewController {

    /// Step id from onboarding JSON (e.g. `nest_intro`, `sitter_missing_info`).
    var onboardingStepId: String?

    // MARK: - UI Elements
    /// Container for title/subtitle (plus any header content subclasses insert into `labelStack`).
    /// Hosts the `.top` scroll edge interaction on iOS 26+.
    let headerContainerView: UIView = {
        let view = EdgeElementContainerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Created on iOS 26+ when a CTA is pinned; hosts the `.bottom` scroll edge interaction.
    private(set) var bottomEdgeContainerView: UIView?

    let labelStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h1
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    var ctaButton: NNBaseControl?
    var buttonBottomConstraint: NSLayoutConstraint?
    
    var coordinator: NSObject?
    var cancellables = Set<AnyCancellable>()
    
    var shouldHandleKeyboard: Bool = true
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupBaseUI()
        setupKeyboardObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup Methods
    private func setupBaseUI() {
        view.addSubview(headerContainerView)
        headerContainerView.addSubview(labelStack)
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            headerContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerContainerView.bottomAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 16),

            labelStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            labelStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            labelStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36)
        ])
    }
    
    /// Configure the basic elements of the onboarding screen
    func setupOnboarding(title: String, subtitle: String? = nil) {
        titleLabel.text = title
        if let subtitle {
            subtitleLabel.text = subtitle   
        } else {
            subtitleLabel.isHidden = true
        }
    }
    
    /// Override this method in subclasses to add custom content
    func setupContent() {
        // To be overridden by subclasses
    }
    
    // MARK: - CTA Button
    func addCTAButton(title: String, image: UIImage? = nil) {
        let button = NNLoadingButton(title: title)
        if let image {
            button.setImage(image)
        }

        if #available(iOS 26.0, *) {
            pinButtonToBottomEdgeContainer(button, horizontalPadding: 24, bottomPadding: 12, height: 55)
        } else {
            button.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(button)

            buttonBottomConstraint = button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)

            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
                button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
                button.heightAnchor.constraint(equalToConstant: 55),
                buttonBottomConstraint!
            ])
        }

        self.ctaButton = button
    }

    // MARK: - Scroll Edge Interactions
    /// Pins the button to the bottom inside a passthrough container that hosts the `.bottom`
    /// scroll edge interaction. The button must not already be in the view hierarchy.
    @available(iOS 26.0, *)
    @discardableResult
    func pinButtonToBottomEdgeContainer(_ button: NNBaseControl,
                                        horizontalPadding: CGFloat = 20,
                                        bottomPadding: CGFloat = 10,
                                        height: CGFloat = 55,
                                        effectTopPadding: CGFloat = 16) -> UIView {
        // Interaction is installed later via installScrollEdgeInteractions(for:),
        // once the subclass's scroll view exists.
        let container = button.pinToBottomEdgeContainer(
            of: view,
            horizontalPadding: horizontalPadding,
            bottomPadding: bottomPadding,
            height: height,
            effectTopPadding: effectTopPadding
        )
        buttonBottomConstraint = button.pinnedBottomConstraint
        bottomEdgeContainerView = container
        return container
    }

    /// Installs top/bottom scroll edge element interactions on iOS 26+. No-op pre-26.
    /// Call after the scroll view and any bottom-pinned CTA are in the hierarchy.
    func installScrollEdgeInteractions(for scrollView: UIScrollView) {
        if #available(iOS 26.0, *) {
            let topInteraction = UIScrollEdgeElementContainerInteraction()
            topInteraction.scrollView = scrollView
            topInteraction.edge = .top
            headerContainerView.addInteraction(topInteraction)
            view.bringSubviewToFront(headerContainerView)

            if let bottomContainer = bottomEdgeContainerView {
                let bottomInteraction = UIScrollEdgeElementContainerInteraction()
                bottomInteraction.scrollView = scrollView
                bottomInteraction.edge = .bottom
                bottomContainer.addInteraction(bottomInteraction)
                view.bringSubviewToFront(bottomContainer)
            }
        }
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardObservers() {
        guard shouldHandleKeyboard else { return }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        
        UIView.animate(withDuration: duration) {
            self.buttonBottomConstraint?.constant = -keyboardHeight + 24
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        UIView.animate(withDuration: duration) {
            self.buttonBottomConstraint?.constant = -12
            self.view.layoutIfNeeded()
        }
    }

    func reset() {

    }
}
