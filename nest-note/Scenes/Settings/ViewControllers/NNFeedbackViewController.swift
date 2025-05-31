//
//  NNFeedbackViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 5/29/25.
//

import UIKit

final class NNFeedbackViewController: NNSheetViewController {
    
    // MARK: - Properties
    private let feedback: Feedback?
    private let isReadOnly: Bool
    
    // MARK: - Initialization
    init() {
        self.feedback = nil
        self.isReadOnly = false
        super.init()
    }
    
    init(feedback: Feedback) {
        self.feedback = feedback
        self.isReadOnly = true
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let contentTextView: UITextView = {
        let textView = UITextView()
        textView.font = .bodyXL
        textView.backgroundColor = .clear
        textView.setPlaceHolder("You should change x, y, & z...")
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.dataDetectorTypes = [.address, .phoneNumber, .link]
        textView.isEditable = true
        textView.isSelectable = true
        return textView
    }()
    
    private lazy var saveButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(title: "Submit", backgroundColor: .systemBlue, foregroundColor: .white)
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var doneButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(image: UIImage(systemName: "keyboard.chevron.compact.down")!, backgroundColor: NNColors.offBlack, foregroundColor: .white)
        button.addTarget(self, action: #selector(hideKeyboard), for: .touchUpInside)
        return button
    }()
    
    private lazy var infoButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(title: "Feedback Info", image: UIImage(systemName: "info")!, backgroundColor: .systemBlue, foregroundColor: .white)
        button.addTarget(self, action: #selector(hideKeyboard), for: .touchUpInside)
        return button
    }()
    
    private lazy var deleteButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(image: UIImage(systemName: "trash.fill")!, backgroundColor: .systemRed, foregroundColor: .white)
        button.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // MARK: - Private Properties
    private var textViewBottomConstraint: NSLayoutConstraint?
    private let buttonStackHeight: CGFloat = 46
    private let buttonStackBottomPadding: CGFloat = 16
    private let blurHeight: CGFloat = 72
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if isReadOnly {
            titleLabel.text = "Feedback Details"
            configureForReadOnly()
        } else {
            titleLabel.text = "Give Feedback"
            titleField.placeholder = "Make Cooler Features..."
            titleField.returnKeyType = .next
            titleField.delegate = self
            titleField.becomeFirstResponder()
        }
        
        contentTextView.delegate = self
        itemsHiddenDuringTransition = isReadOnly ? [] : [buttonStackView]
        
        containerView.clipsToBounds = true
    }
    
    private func configureForReadOnly() {
        guard let feedback = feedback else { return }
        
        // Populate fields with feedback data
        titleField.text = feedback.title
        contentTextView.text = feedback.body
        
        // Make fields non-interactive
        titleField.isUserInteractionEnabled = false
        contentTextView.isEditable = false
        contentTextView.isSelectable = true
        
        // Remove submit and keyboard buttons for read-only mode
        buttonStackView.isHidden = false
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let formattedTimestamp = dateFormatter.string(from: feedback.timestamp)
        
        let createdAtAction = UIAction(title: "Created: \(formattedTimestamp)", handler: { _ in 
            UIPasteboard.general.string = formattedTimestamp
        })
        let userId = UIAction(title: "userID: \(feedback.userId)", handler: { _ in 
            UIPasteboard.general.string = feedback.userId
        })
        let userEmail = UIAction(title: "\(feedback.email)", handler: { _ in 
            UIPasteboard.general.string = feedback.email
        })
        let nestId = UIAction(title: "nestId: \(feedback.nestId)", handler: { _ in 
            UIPasteboard.general.string = feedback.nestId
        })
        
        infoButton.menu = UIMenu(title: "", children: [createdAtAction, userId, userEmail, nestId])
        infoButton.showsMenuAsPrimaryAction = true
    }
    
    override func addContentToContainer() {
        super.addContentToContainer()
        
        if let feedback {
            buttonStackView.addArrangedSubview(infoButton)
            buttonStackView.addArrangedSubview(deleteButton)
        } else {
            buttonStackView.addArrangedSubview(saveButton)
            buttonStackView.addArrangedSubview(doneButton)
        }
        
        containerView.addSubview(contentTextView)
        
        addBottomBlur()
        
        containerView.addSubview(buttonStackView)
        
        // Create the bottom constraint for the text view
        textViewBottomConstraint = contentTextView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 0)
        
        if let feedback {
            NSLayoutConstraint.activate([
                contentTextView.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 8),
                contentTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
                contentTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                textViewBottomConstraint!,
                
                buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -buttonStackBottomPadding).with(priority: .defaultHigh),
                buttonStackView.heightAnchor.constraint(equalToConstant: buttonStackHeight),
                
                deleteButton.widthAnchor.constraint(lessThanOrEqualTo: buttonStackView.widthAnchor, multiplier: 0.2),
            ])
        } else {
            NSLayoutConstraint.activate([
                contentTextView.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 8),
                contentTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
                contentTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                textViewBottomConstraint!,
                
                buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -buttonStackBottomPadding).with(priority: .defaultHigh),
                buttonStackView.heightAnchor.constraint(equalToConstant: buttonStackHeight),
                
                doneButton.widthAnchor.constraint(lessThanOrEqualTo: buttonStackView.widthAnchor, multiplier: 0.2),
            ])
        }
        
        // Calculate the total space needed at the bottom
        let totalBottomSpace = buttonStackHeight + buttonStackBottomPadding + 8 // 8pt gap between text view and buttons
        
        // Update content insets to ensure text is never hidden behind buttons or keyboard
        contentTextView.contentInset.bottom = totalBottomSpace
        contentTextView.scrollIndicatorInsets.bottom = totalBottomSpace
    }
    
    @objc func saveButtonTapped() {
        // Validate input
        guard let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            shakeContainerView()
            return
        }
        
        guard let body = contentTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !body.isEmpty else {
            shakeContainerView()
            return
        }
        
        // Show confirmation dialog
        showFeedbackConfirmation(title: title, body: body)
    }
    
    private func showFeedbackConfirmation(title: String, body: String) {
        let alert = UIAlertController(
            title: "Submit Feedback",
            message: "Your feedback will be submitted along with some of your information (email, user ID, nest ID) to help us improve NestNote. Would you like to continue?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Submit", style: .default) { [weak self] _ in
            self?.submitFeedback(title: title, body: body)
        })
        
        present(alert, animated: true)
    }
    
    private func submitFeedback(title: String, body: String) {
        // Get user and nest information
        guard let currentUser = UserService.shared.currentUser else {
            showErrorAlert(message: "Unable to get user information. Please try again.")
            return
        }
        
        guard let currentNest = NestService.shared.currentNest else {
            showErrorAlert(message: "Unable to get nest information. Please try again.")
            return
        }
        
        // Disable submit button to prevent multiple submissions
        saveButton.isEnabled = false
        saveButton.setTitle("Submitting...", for: .normal)
        
        // Create feedback object
        let feedback = Feedback(
            userId: currentUser.id,
            email: currentUser.personalInfo.email,
            nestId: currentNest.id,
            title: title,
            body: body
        )
        
        // Submit feedback
        Task {
            do {
                try await SurveyService.shared.submitFeedback(feedback)
                
                await MainActor.run {
                    self.dismiss(animated: true) {
                        self.showToast(text: "Thank you!", subtitle: "Your feedback has been recorded", sentiment: .positive)
                    }
                }
            } catch {
                await MainActor.run {
                    self.saveButton.isEnabled = true
                    self.saveButton.setTitle("Submit", for: .normal)
                    self.showErrorAlert(message: "Failed to submit feedback. Please try again.")
                }
            }
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc func hideKeyboard() {
        if titleField.isFirstResponder {
            titleField.resignFirstResponder()
        } else if contentTextView.isFirstResponder {
            contentTextView.resignFirstResponder()
        }
    }
    
    @objc func scrollTest() {
        contentTextView.scrollToCaretIfNeeded()
    }
    
    @objc func deleteButtonTapped() {
        showDeleteConfirmation()
    }
    
    private func showDeleteConfirmation() {
        let alert = UIAlertController(
            title: "Delete Feedback",
            message: "Are you sure you want to delete this feedback? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteFeedback()
        })
        
        present(alert, animated: true)
    }
    
    private func deleteFeedback() {
        guard let feedback = feedback else { return }
        
        // Disable delete button to prevent multiple deletions
        deleteButton.isEnabled = false
        
        Task {
            do {
                try await SurveyService.shared.deleteFeedback(feedback)
                
                await MainActor.run {
                    self.dismiss(animated: true) {
                        self.showToast(text: "Deleted", subtitle: "Feedback has been removed", sentiment: .negative)
                    }
                }
            } catch {
                await MainActor.run {
                    self.deleteButton.isEnabled = true
                    self.showErrorAlert(message: "Failed to delete feedback. Please try again.")
                }
            }
        }
    }
    
    func addBottomBlur() {
        var visualEffectView = UIVisualEffectView()
            
        visualEffectView.effect = UIBlurEffect.variableBlurEffect(radius: 8.0, maskImage: UIImage(named: "testBG3")!)
        
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(visualEffectView)
        
        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            visualEffectView.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -blurHeight)
        ])
    }
}

extension NNFeedbackViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        contentTextView.becomeFirstResponder()
        return true
    }
}

extension NNFeedbackViewController: UITextViewDelegate {
    func textViewDidChangeSelection(_ textView: UITextView) {
        // Ensure the cursor stays visible when selection changes
        if textView.isFirstResponder {
            DispatchQueue.main.async {
                textView.scrollToCaretIfNeeded()
            }
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        // Ensure the cursor stays visible when text changes
        DispatchQueue.main.async {
            textView.scrollToCaretIfNeeded()
        }
    }
}

