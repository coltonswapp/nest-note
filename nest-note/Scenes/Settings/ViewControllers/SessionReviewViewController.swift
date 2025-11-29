//
//  SessionReviewViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 11/28/25.
//

import UIKit

/// Contains session information for providing context to the user
struct SessionContextInfo {
    let sessionTitle: String?
    let nestName: String?
    let sessionDate: Date
}

final class SessionReviewViewController: NNViewController {
    
    // MARK: - Properties
    private var selectedSessionRating: SessionReview.SessionRating?
    private var selectedEaseOfUse: SessionReview.EaseOfUse?
    private var selectedFutureUse: SessionReview.FutureUse?
    
    private var sessionRatingButtons: [SessionReviewOptionButton] = []
    private var easeOfUseButtons: [SessionReviewOptionButton] = []
    private var futureUseButtons: [SessionReviewOptionButton] = []
    
    private let sessionId: String?
    private let nestId: String?
    private var isDebugMode: Bool = false

    /// Optional session information for providing context to the user
    private let sessionInfo: SessionContextInfo?
    
    /// Tracks whether the user successfully submitted a review
    private var didSubmitReview: Bool = false
    
    /// Called when the review is completed or dismissed
    var onDismiss: (() -> Void)?
    
    /// The role determines which questions are shown
    private var userRole: SessionReview.UserRole {
        return ModeManager.shared.isSitterMode ? .sitter : .owner
    }
    
    // MARK: - UI Elements
    private let topPatternImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(imageView, for: .rectanglePatternSmall, with: NNColors.primary)
        return imageView
    }()

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .label
        button.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        button.layer.cornerRadius = 20
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.1
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Session Review"
        label.font = .h2
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Just a few quick questions!"
        label.font = .bodyL
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let headerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Question 1: Session Rating
    private let sessionRatingLabel: UILabel = {
        let label = UILabel()
        label.text = "How was your session?"
        label.font = .h4
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()
    
    private let sessionRatingStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillProportionally
        return stack
    }()
    
    // Question 2: Ease of Use
    private let easeOfUseLabel: UILabel = {
        let label = UILabel()
        label.text = "Was NestNote easy to use?"
        label.font = .h4
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()
    
    private let easeOfUseStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillProportionally
        return stack
    }()
    
    // Question 3: Future Use
    private let futureUseLabel: UILabel = {
        let label = UILabel()
        label.font = .h4
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()
    
    private let futureUseStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillProportionally
        return stack
    }()
    
    // Feedback Text View
    private let feedbackLabel: UILabel = {
        let label = UILabel()
        label.text = "Anything you'd like to add? (Optional)"
        label.font = .h4
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()
    
    private let feedbackTextView: UITextView = {
        let textView = UITextView()
        textView.font = .bodyL
        textView.backgroundColor = NNColors.NNSystemBackground6
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isScrollEnabled = false
        textView.setPlaceHolder("Give us your thoughts!")
        return textView
    }()
    
    private let questionsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var submitButton: NNLoadingButton = {
        let button = NNLoadingButton(
            title: "Submit",
            titleColor: .white,
            fillStyle: .fill(NNColors.primary)
        )
        button.addTarget(self, action: #selector(submitButtonTapped), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()
    
    // MARK: - Initialization
    init(sessionId: String? = nil, nestId: String? = nil, sessionInfo: SessionContextInfo? = nil) {
        self.sessionId = sessionId
        self.nestId = nestId
        self.sessionInfo = sessionInfo
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardDismissGesture()
        setupKeyboardObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    override func setup() {
        // Configure sheet presentation
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = false
        }

        // Setup subtitle with session context if available
        updateSubtitleWithSessionContext()

        // Setup the future use question based on role
        updateFutureUseQuestion()

        // Setup option buttons
        setupSessionRatingButtons()
        setupEaseOfUseButtons()
        setupFutureUseButtons()

        // Setup close button
        closeButton.addTarget(self, action: #selector(dismissReview), for: .touchUpInside)
    }
    
    
    @objc private func dismissReview() {
        // If user didn't submit a review, mark this session as skipped
        if !didSubmitReview, let sessionId = sessionId {
            SessionReviewManager.shared.markSessionAsSkipped(sessionId)
        }
        
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }
    
    override func addSubviews() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(topPatternImageView)
        view.addSubview(closeButton)
        
        // Header
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subtitleLabel)
        contentView.addSubview(headerStack)
        
        // Questions stack
        let sessionRatingQuestion = createQuestionView(label: sessionRatingLabel, optionsStack: sessionRatingStack)
        let easeOfUseQuestion = createQuestionView(label: easeOfUseLabel, optionsStack: easeOfUseStack)
        let futureUseQuestion = createQuestionView(label: futureUseLabel, optionsStack: futureUseStack)
        let feedbackQuestion = createQuestionView(label: feedbackLabel, optionsStack: nil, customView: feedbackTextView)
        
        questionsStack.addArrangedSubview(sessionRatingQuestion)
        questionsStack.addArrangedSubview(easeOfUseQuestion)
        questionsStack.addArrangedSubview(futureUseQuestion)
        questionsStack.addArrangedSubview(feedbackQuestion)
        
        contentView.addSubview(questionsStack)
        view.addSubview(submitButton)
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            // Pattern image - manually constrained since pinToTop uses frame.width which is 0 at setup time
            topPatternImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            topPatternImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topPatternImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            topPatternImageView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.15),
            
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: submitButton.topAnchor, constant: -16),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Header
            headerStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 70),
            headerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            headerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            // Questions
            questionsStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 32),
            questionsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            questionsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            questionsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            
            // Feedback text view
            feedbackTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            // Submit button
            submitButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            submitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            submitButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            submitButton.heightAnchor.constraint(equalToConstant: 55),

            // Close button
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // MARK: - Helper Methods
    private func createQuestionView(label: UILabel, optionsStack: UIStackView?, customView: UIView? = nil) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.addArrangedSubview(label)
        
        if let optionsStack = optionsStack {
            stack.addArrangedSubview(optionsStack)
        }
        
        if let customView = customView {
            stack.addArrangedSubview(customView)
        }
        
        return stack
    }
    
    private func updateSubtitleWithSessionContext() {
        guard let sessionInfo = sessionInfo else {
            subtitleLabel.text = "Just a few quick questions!"
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let formattedDate = dateFormatter.string(from: sessionInfo.sessionDate)

        if userRole == .sitter {
            // For sitters, keep it simple with just the date
            subtitleLabel.text = "How was your recent sitting session on \(formattedDate)?"
        } else {
            // For owners, use session title when available, otherwise nest name, then fallback
            if let sessionTitle = sessionInfo.sessionTitle, !sessionTitle.isEmpty {
                subtitleLabel.text = "How was your '\(sessionTitle)' session on \(formattedDate)?"
            } else if let nestName = sessionInfo.nestName {
                subtitleLabel.text = "How was your recent session at \(nestName) on \(formattedDate)?"
            } else {
                subtitleLabel.text = "How was your recent session on \(formattedDate)?"
            }
        }
    }

    private func updateFutureUseQuestion() {
        if userRole == .owner {
            futureUseLabel.text = "Will you use NestNote for future sessions?"
        } else {
            futureUseLabel.text = "Will you recommend NestNote to another family?"
        }
    }
    
    private func setupSessionRatingButtons() {
        let options = SessionReview.SessionRating.allCases
        for (index, option) in options.enumerated() {
            let button = SessionReviewOptionButton(title: option.rawValue)
            button.tag = index
            button.addTarget(self, action: #selector(sessionRatingButtonTapped(_:)), for: .touchUpInside)
            sessionRatingStack.addArrangedSubview(button)
            sessionRatingButtons.append(button)
        }
    }
    
    private func setupEaseOfUseButtons() {
        let options = SessionReview.EaseOfUse.allCases
        for (index, option) in options.enumerated() {
            let button = SessionReviewOptionButton(title: option.rawValue)
            button.tag = index
            button.addTarget(self, action: #selector(easeOfUseButtonTapped(_:)), for: .touchUpInside)
            easeOfUseStack.addArrangedSubview(button)
            easeOfUseButtons.append(button)
        }
    }
    
    private func setupFutureUseButtons() {
        let options = SessionReview.FutureUse.options(for: userRole)
        for (index, option) in options.enumerated() {
            let button = SessionReviewOptionButton(title: option.title)
            button.tag = index
            button.addTarget(self, action: #selector(futureUseButtonTapped(_:)), for: .touchUpInside)
            futureUseStack.addArrangedSubview(button)
            futureUseButtons.append(button)
        }
    }
    
    /// Triggers explosion for positive options (indices 2 and 3)
    private func triggerExplosionIfPositive(for button: UIView, at index: Int) {
        // Indices 2 and 3 are the positive options in each question
        guard index >= 2 else { return }
        
        // Get the button's center in the window coordinate space
        guard let window = view.window else { return }
        let buttonCenter = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: window)
        
        ExplosionManager.trigger(.tiny, at: buttonCenter)
    }
    
    private func setupKeyboardDismissGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        let bottomInset = keyboardHeight - view.safeAreaInsets.bottom
        
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = bottomInset
            self.scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
        
        // Scroll to make the text view visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let textViewFrame = self.feedbackTextView.convert(self.feedbackTextView.bounds, to: self.scrollView)
            self.scrollView.scrollRectToVisible(textViewFrame, animated: true)
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = 0
            self.scrollView.verticalScrollIndicatorInsets.bottom = 0
        }
    }
    
    private func updateSubmitButtonState() {
        let allQuestionsAnswered = selectedSessionRating != nil &&
                                   selectedEaseOfUse != nil &&
                                   selectedFutureUse != nil
        submitButton.isEnabled = allQuestionsAnswered
    }
    
    // MARK: - Button Actions
    @objc private func sessionRatingButtonTapped(_ sender: SessionReviewOptionButton) {
        // Deselect all buttons in this group
        sessionRatingButtons.forEach { $0.setSelected(false) }
        
        // Select the tapped button
        sender.setSelected(true)
        
        // Update the selected value
        if let index = sessionRatingButtons.firstIndex(of: sender) {
            selectedSessionRating = SessionReview.SessionRating.allCases[index]
            triggerExplosionIfPositive(for: sender, at: index)
        }
        
        HapticsHelper.lightHaptic()
        updateSubmitButtonState()
    }
    
    @objc private func easeOfUseButtonTapped(_ sender: SessionReviewOptionButton) {
        // Deselect all buttons in this group
        easeOfUseButtons.forEach { $0.setSelected(false) }
        
        // Select the tapped button
        sender.setSelected(true)
        
        // Update the selected value
        if let index = easeOfUseButtons.firstIndex(of: sender) {
            selectedEaseOfUse = SessionReview.EaseOfUse.allCases[index]
            triggerExplosionIfPositive(for: sender, at: index)
        }
        
        HapticsHelper.lightHaptic()
        updateSubmitButtonState()
    }
    
    @objc private func futureUseButtonTapped(_ sender: SessionReviewOptionButton) {
        // Deselect all buttons in this group
        futureUseButtons.forEach { $0.setSelected(false) }
        
        // Select the tapped button
        sender.setSelected(true)
        
        // Update the selected value
        selectedFutureUse = SessionReview.FutureUse.allCases[sender.tag]
        triggerExplosionIfPositive(for: sender, at: sender.tag)
        
        HapticsHelper.lightHaptic()
        updateSubmitButtonState()
    }
    
    @objc private func submitButtonTapped() {
        guard let sessionRating = selectedSessionRating,
              let easeOfUse = selectedEaseOfUse,
              let futureUse = selectedFutureUse else {
            return
        }
        
        submitButton.startLoading()
        
        // Get user info
        let currentUser = UserService.shared.currentUser
        let userId = currentUser?.id ?? "anonymous"
        let userEmail = currentUser?.personalInfo.email ?? "unknown"
        let userName = currentUser?.personalInfo.name ?? "Unknown"
        
        let review = SessionReview(
            userId: userId,
            userEmail: userEmail,
            userName: userName,
            sessionId: sessionId,
            nestId: nestId ?? NestService.shared.currentNest?.id,
            userRole: userRole,
            sessionRating: sessionRating,
            easeOfUse: easeOfUse,
            futureUse: futureUse,
            additionalFeedback: feedbackTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        Task {
            do {
                if !isDebugMode {
                    try await SessionReviewService.shared.submitReview(review)
                    
                    // Mark the session as reviewed
                    await markSessionAsReviewed()
                } else {
                    // Simulate network delay in debug mode
                    try await Task.sleep(for: .seconds(1))
                }
                
                await MainActor.run {
                    // Mark as submitted so we don't skip this session on dismiss
                    self.didSubmitReview = true

                    submitButton.stopLoading(withSuccess: true)

                    // Dismiss after showing success checkmark
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.dismiss(animated: true) {
                            self.onDismiss?()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    submitButton.stopLoading(withSuccess: false)
                    showToast(text: "Failed to submit review")
                    Logger.log(level: .error, category: .general, message: "Failed to submit session review: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Marks the session as reviewed in Firebase
    private func markSessionAsReviewed() async {
        guard let sessionId = sessionId else { return }
        
        do {
            if userRole == .owner {
                // For owners, update the session's ownerReviewedAt field
                guard let nestId = nestId ?? NestService.shared.currentNest?.id else { return }
                try await SessionReviewService.shared.markSessionReviewedByOwner(sessionId: sessionId, nestId: nestId)
            } else {
                // For sitters, update the sitter session's reviewedAt field
                guard let userId = UserService.shared.currentUser?.id else { return }
                try await SessionReviewService.shared.markSessionReviewedBySitter(sessionId: sessionId, userId: userId)
            }
        } catch {
            Logger.log(level: .error, category: .general, message: "Failed to mark session as reviewed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Debug Mode
    func enableDebugMode() {
        isDebugMode = true
    }
}

// MARK: - SessionReviewOptionButton
private class SessionReviewOptionButton: UIControl {
    
    // MARK: - Properties
    private(set) var isOptionSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    // MARK: - UI Elements
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 18
        clipsToBounds = true
        
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            
            heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
        
        // Add touch handling
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: .touchUpInside)
        addTarget(self, action: #selector(touchCancel), for: [.touchUpOutside, .touchCancel])
        
        updateAppearance()
    }
    
    private func updateAppearance() {
        if isOptionSelected {
            backgroundColor = NNColors.primary.withAlphaComponent(0.15)
            titleLabel.textColor = NNColors.primary
        } else {
            backgroundColor = NNColors.NNSystemBackground6
            titleLabel.textColor = .secondaryLabel
        }
    }
    
    // MARK: - Touch Handling
    @objc private func touchDown() {
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.1) {
            self.transform = .identity
        }
    }
    
    @objc private func touchCancel() {
        UIView.animate(withDuration: 0.1) {
            self.transform = .identity
        }
    }
    
    // MARK: - Public Methods
    func setSelected(_ selected: Bool) {
        isOptionSelected = selected
    }
}
