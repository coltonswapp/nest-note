import UIKit
import RevenueCat
import RevenueCatUI
import TipKit

protocol EntryDetailViewControllerDelegate: AnyObject {
    func entryDetailViewController(didSaveEntry entry: BaseEntry?)
    func entryDetailViewController(didDeleteEntry entry: BaseEntry)
}

final class EntryDetailViewController: NNSheetViewController, NNTippable {
    
    // MARK: - Properties
    weak var entryDelegate: EntryDetailViewControllerDelegate?
    private let isReadOnly: Bool
    
    private let contentTextView: UITextView = {
        let textView = UITextView()
        textView.font = .bodyXL
        textView.backgroundColor = .clear
        let placeholder = NSAttributedString(string: "Content")
        textView.perform(NSSelectorFromString("setAttributedPlaceholder:"), with: placeholder)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.dataDetectorTypes = [.address, .phoneNumber, .link]
        textView.isEditable = true
        textView.isSelectable = true
        return textView
    }()
    
    private lazy var saveButton: NNLoadingButton = {
        let button = NNLoadingButton(
            title: entry == nil ? "Save" : "Update",
            titleColor: .white,
            fillStyle: .fill(NNColors.primary)
        )
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var visibilityButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(
            title: "Test",
            image: UIImage(systemName: "chevron.up.chevron.down"),
            imagePlacement: .right,
            backgroundColor: NNColors.offBlack
        )
        button.titleLabel?.font = .h4
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
    
    private lazy var infoButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let image = UIImage(systemName: "ellipsis.circle.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .tertiaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var visibilityLevel: VisibilityLevel
    let entry: BaseEntry?
    private let category: String
    
    // MARK: - Initialization
    init(category: String, entry: BaseEntry? = nil, sourceFrame: CGRect? = nil, isReadOnly: Bool = false) {
        self.category = category
        self.entry = entry
        self.visibilityLevel = entry?.visibility ?? .halfDay
        self.isReadOnly = isReadOnly
        super.init(sourceFrame: sourceFrame)
    }
    
    init(category: String, title: String, content: String, sourceFrame: CGRect? = nil) {
        self.category = category
        self.entry = nil
        self.visibilityLevel = .halfDay
        self.isReadOnly = false
        super.init(sourceFrame: sourceFrame)
        
        titleField.text = title
        contentTextView.text = content
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = entry == nil ? "New Entry" : isReadOnly ? "View Entry" : "Edit Entry"
        titleField.text = entry?.title
        titleField.placeholder = "Title"
        titleField.delegate = self
        contentTextView.text = entry?.content
        contentTextView.delegate = self
        
        // Remove automatic tip dismissal - let user dismiss manually
        
        if isReadOnly {
            configureReadOnlyMode()
        } else {
            setupVisibilityMenu()
            setupInfoMenu()
        }
        
        itemsHiddenDuringTransition = [buttonStackView, infoButton]
        
        if entry == nil && !isReadOnly {
            titleField.becomeFirstResponder()
        }
    }
    
    
    
    // MARK: - Setup Methods
    override func addContentToContainer() {
        super.addContentToContainer()
        
        buttonStackView.addArrangedSubview(visibilityButton)
        if !isReadOnly {
            buttonStackView.addArrangedSubview(saveButton)
        }
        
        containerView.addSubview(contentTextView)
        containerView.addSubview(buttonStackView)
        containerView.addSubview(infoButton)
        
        NSLayoutConstraint.activate([
            contentTextView.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 8),
            contentTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            contentTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            contentTextView.bottomAnchor.constraint(equalTo: infoButton.topAnchor, constant: -16),
            
            infoButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            infoButton.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -8),
            infoButton.widthAnchor.constraint(equalToConstant: 44),
            infoButton.heightAnchor.constraint(equalToConstant: 44),
            
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16).with(priority: .defaultHigh),
            buttonStackView.heightAnchor.constraint(equalToConstant: 46),
            
            visibilityButton.widthAnchor.constraint(lessThanOrEqualTo: buttonStackView.widthAnchor, multiplier: isReadOnly ? 1.0 : 0.6),
            
        ])
        
        if !isReadOnly {
            NSLayoutConstraint.activate([
                saveButton.widthAnchor.constraint(lessThanOrEqualTo: buttonStackView.widthAnchor, multiplier: 0.4)
            ])
        }
    }
    
    // MARK: - Private Methods
    private func setupVisibilityMenu() {
        let infoAction = UIAction(title: "Learn about Levels", image: UIImage(systemName: "info.circle")) { [weak self] _ in
            self?.showVisibilityLevelInfo()
        }
        
        let visibilityActions = VisibilityLevel.allCases.map { level in
            UIAction(title: level.title, state: level == self.visibilityLevel ? .on : .off) { [weak self] action in
                HapticsHelper.lightHaptic()
                self?.visibilityLevel = level
                self?.updateVisibilityButton()
                
                // Mark visibility tip as completed when visibility is changed
                if let self = self,
                   let visibilityTip = EntryDetailTips.tipGroup.tips.first(where: { $0.id == "VisibilityLevelTip" }) {
                    NNTipManager.shared.dismissTip(visibilityTip)
                }
            }
        }
        
        let visibilitySection = UIMenu(title: "Select Visibility", options: .displayInline, children: visibilityActions)
        let infoSection = UIMenu(title: "What level is right for me?", options: .displayInline, children: [infoAction])
        
        visibilityButton.menu = UIMenu(children: [visibilitySection, infoSection])
        visibilityButton.showsMenuAsPrimaryAction = true
        
        updateVisibilityButton()
    }
    
    private func setupInfoMenu() {
        let createdAt = entry?.createdAt ?? Date()
        let modifiedAt = entry?.updatedAt ?? Date()
        
        let createdAtAction = UIAction(title: "Created at: \(formattedDate(createdAt))", handler: { _ in })
        let modifiedAtAction = UIAction(title: "Modified at: \(formattedDate(modifiedAt))", handler: { _ in })
        
        var menuItems: [UIMenuElement] = []
        
        if entry != nil {
            let deleteAction = UIAction(
                title: "Delete Entry",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.handleDeleteTapped()
            }
            menuItems.append(deleteAction)
        }
        
        menuItems.append(contentsOf: [createdAtAction, modifiedAtAction])
        
        let menu = UIMenu(title: "", children: menuItems)
        infoButton.menu = menu
        infoButton.showsMenuAsPrimaryAction = true
    }
    
    private func updateVisibilityButton() {
        
        var container = AttributeContainer()
        container.font = .h4
        visibilityButton.configuration?.attributedTitle = AttributedString(visibilityLevel.title, attributes: container)
        
        if let menu = visibilityButton.menu {
            let updatedActions = menu.children.compactMap { $0 as? UIMenu }.flatMap { $0.children }.map { action in
                guard let action = action as? UIAction else { return action }
                if VisibilityLevel.allCases.map({ $0.title }).contains(action.title) {
                    action.state = action.title == visibilityLevel.title ? .on : .off
                }
                return action
            }
            
            visibilityButton.menu = UIMenu(children: [
                UIMenu(title: "Select Visibility", options: .displayInline, children: updatedActions.filter { VisibilityLevel.allCases.map({ $0.title }).contains($0.title) }),
                UIMenu(title: "", options: .displayInline, children: updatedActions.filter { $0.title == "Learn about Levels" })
            ])
        }
    }
    
    private func showVisibilityLevelInfo() {
        let viewController = VisibilityLevelInfoViewController()
        present(viewController, animated: true)
        HapticsHelper.lightHaptic()
    }
    
    private func handleDeleteTapped() {
        guard let entry = entry else { return }
        
        let alert = UIAlertController(
            title: "Delete Entry",
            message: "Are you sure you want to delete '\(entry.title)'? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteEntry()
        })
        
        present(alert, animated: true)
    }
    
    private func deleteEntry() {
        guard let entry = entry else { return }
        
        Task {
            do {
                try await NestService.shared.deleteEntry(entry)
                await MainActor.run {
                    entryDelegate?.entryDetailViewController(didDeleteEntry: entry)
                    HapticsHelper.lightHaptic()
                    dismiss(animated: true)
                }
            } catch {
                Logger.log(level: .error, category: .nestService, message: "Failed to delete entry: \(error.localizedDescription)")
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func configureReadOnlyMode() {
        // Disable editing
        titleField.isEnabled = false
        contentTextView.isEditable = false
        
        // Hide buttons that modify content
        visibilityButton.isHidden = false
        visibilityButton.isEnabled = false
        updateVisibilityButton()
        saveButton.isHidden = false
        saveButton.isEnabled = false
        
        // Update info button menu to only show metadata
        let createdAt = entry?.createdAt ?? Date()
        let modifiedAt = entry?.updatedAt ?? Date()
        
        let createdAtAction = UIAction(title: "Created at: \(formattedDate(createdAt))", handler: { _ in })
        let modifiedAtAction = UIAction(title: "Modified at: \(formattedDate(modifiedAt))", handler: { _ in })
        
        infoButton.menu = UIMenu(title: "", children: [createdAtAction, modifiedAtAction])
        infoButton.showsMenuAsPrimaryAction = true
    }
    
    // MARK: - Actions
    
    @objc private func saveButtonTapped() {
        guard let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty,
              let content = contentTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            shakeContainerView()
            return
        }
        
        saveButton.startLoading()
        titleField.isUserInteractionEnabled = false
        contentTextView.isUserInteractionEnabled = false
        visibilityButton.isUserInteractionEnabled = false
        
        Task {
            
            do {
                var savedEntry: BaseEntry
                
                if let existingEntry = entry {
                    existingEntry.title = title
                    existingEntry.content = content
                    existingEntry.visibility = visibilityLevel
                    existingEntry.updatedAt = Date()
                    
                    try await NestService.shared.updateEntry(existingEntry)
                    savedEntry = existingEntry
                } else {
                    let newEntry = BaseEntry(
                        title: title,
                        content: content,
                        visibilityLevel: visibilityLevel,
                        category: category
                    )
                    
                    // Create entry (limit check is done before showing this VC)
                    try await NestService.shared.createEntry(newEntry)
                    savedEntry = newEntry
                }
                
                HapticsHelper.lightHaptic()
                
                // Notify delegate
                await MainActor.run {
                    self.entryDelegate?.entryDetailViewController(didSaveEntry: savedEntry)
                    
                    // Post notification that an entry was saved
                    NotificationCenter.default.post(name: .entryDidSave, object: nil, userInfo: ["entry": savedEntry])
                    
                    self.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    saveButton.stopLoading(withSuccess: false)
                    titleField.isUserInteractionEnabled = true
                    contentTextView.isUserInteractionEnabled = true
                    visibilityButton.isUserInteractionEnabled = true
                    // Handle errors (entry limit is checked before showing this VC)
                    self.showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - NNTippable Methods
    
    func showTips() {
        // Show tips in priority order - only show one at a time
        guard entry == nil && !isReadOnly else {
            return
        }
        
        trackScreenVisit()
        
        // Priority 1: Title/content tip (for new users)
        let titleTipShouldShow = NNTipManager.shared.shouldShowTip(EntryDetailTips.entryTitleContentTip)
        if titleTipShouldShow {
            NNTipManager.shared.showTip(
                EntryDetailTips.entryTitleContentTip,
                sourceView: titleField,
                in: self,
                pinToEdge: .bottom,
                offset: CGPoint(x: 0, y: 70)
            )
            return // Don't show other tips
        }
        
        // Priority 2: Visibility tip (after 5 visits)
        let visibilityTipShouldShow = NNTipManager.shared.shouldShowTip(EntryDetailTips.visibilityLevelTip)
        if visibilityTipShouldShow {
            NNTipManager.shared.showTip(
                EntryDetailTips.visibilityLevelTip,
                sourceView: visibilityButton,
                in: self,
                pinToEdge: .top,
                offset: CGPoint(x: 0, y: 8)
            )
            return // Don't show other tips
        }
        
        // Priority 3: Entry details tip (after 10 visits)
        let detailsTipShouldShow = NNTipManager.shared.shouldShowTip(EntryDetailTips.entryDetailsTip)
        if detailsTipShouldShow {
            NNTipManager.shared.showTip(
                EntryDetailTips.entryDetailsTip,
                sourceView: infoButton,
                in: self,
                pinToEdge: .leading,
                offset: CGPoint(x: 8, y: 0)
            )
        }
    }
    
    // MARK: - Error Handling
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension EntryDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == titleField {
            contentTextView.becomeFirstResponder()
            return false
        }
        return true
    }
}

// MARK: - UITextViewDelegate
extension EntryDetailViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        //
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if interaction == .preview {
            return true
        }
        
        if URL.scheme == "tel" {
            UIApplication.shared.open(URL)
        } else if URL.scheme == "mailto" {
            UIApplication.shared.open(URL)
        } else {
            UIApplication.shared.open(URL, options: [:], completionHandler: nil)
        }
        return false
    }
    
    func textView(_ textView: UITextView, shouldInteractWith textAttachment: NSTextAttachment, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        return true
    }
}

 
