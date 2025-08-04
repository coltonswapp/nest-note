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
    
    
    private let buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    
    private lazy var folderLabel: NNSmallLabel = {
        let label = NNSmallLabel()
        return label
    }()
    
    let entry: BaseEntry?
    private let category: String
    
    // MARK: - Initialization
    init(category: String, entry: BaseEntry? = nil, sourceFrame: CGRect? = nil, isReadOnly: Bool = false) {
        self.category = category
        self.entry = entry
        self.isReadOnly = isReadOnly
        super.init(sourceFrame: sourceFrame)
    }
    
    init(category: String, title: String, content: String, sourceFrame: CGRect? = nil) {
        self.category = category
        self.entry = nil
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
        
        // Configure folder label with last 2 components
        configureFolderLabel()
        
        // Remove automatic tip dismissal - let user dismiss manually
        
        if isReadOnly {
            configureReadOnlyMode()
        }
        
        itemsHiddenDuringTransition = [saveButton, infoButton]
        
        if entry == nil && !isReadOnly {
            titleField.becomeFirstResponder()
        }
    }
    
    
    
    // MARK: - Setup Methods
    override func addContentToContainer() {
        super.addContentToContainer()
        
        containerView.addSubview(contentTextView)
        containerView.addSubview(folderLabel)
        if !isReadOnly {
            containerView.addSubview(saveButton)
        }
        
        var constraints: [NSLayoutConstraint] = [
            // Content text view
            contentTextView.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 8),
            contentTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            contentTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Folder label - positioned where details button was
            folderLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            folderLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16),
            folderLabel.heightAnchor.constraint(equalToConstant: 30),
        ]
        
        if !isReadOnly {
            // Full width save button
            constraints.append(contentsOf: [
                contentTextView.bottomAnchor.constraint(equalTo: folderLabel.topAnchor, constant: -16),
                folderLabel.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -16),
                
                saveButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                saveButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                saveButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16).with(priority: .defaultHigh),
                saveButton.heightAnchor.constraint(equalToConstant: 46),
            ])
        } else {
            // Read-only mode - no save button
            constraints.append(contentsOf: [
                contentTextView.bottomAnchor.constraint(equalTo: folderLabel.topAnchor, constant: -16),
                folderLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16).with(priority: .defaultHigh),
            ])
        }
        
        NSLayoutConstraint.activate(constraints)
    }
    
    // MARK: - NNSheetViewController Override
    
    override func setupInfoButton() {
        infoButton.isHidden = false
        
        if isReadOnly {
            setupReadOnlyInfoMenu()
        } else {
            setupEditableInfoMenu()
        }
    }
    
    // MARK: - Private Methods
    
    private func configureFolderLabel() {
        let components = category.components(separatedBy: "/")
        if components.count >= 2 {
            folderLabel.text = components.joined(separator: " / ")
        } else if components.count == 1 {
            // Show single component
            folderLabel.text = components.first
        } else {
            // Fallback
            folderLabel.text = category
        }
    }
    
    
    private func setupEditableInfoMenu() {
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
    
    private func setupReadOnlyInfoMenu() {
        let createdAt = entry?.createdAt ?? Date()
        let modifiedAt = entry?.updatedAt ?? Date()
        
        let createdAtAction = UIAction(title: "Created at: \(formattedDate(createdAt))", handler: { _ in })
        let modifiedAtAction = UIAction(title: "Modified at: \(formattedDate(modifiedAt))", handler: { _ in })
        
        infoButton.menu = UIMenu(title: "", children: [createdAtAction, modifiedAtAction])
        infoButton.showsMenuAsPrimaryAction = true
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
        
        Task {
            
            do {
                var savedEntry: BaseEntry
                
                if let existingEntry = entry {
                    existingEntry.title = title
                    existingEntry.content = content
                    existingEntry.updatedAt = Date()
                    
                    try await NestService.shared.updateEntry(existingEntry)
                    savedEntry = existingEntry
                } else {
                    let newEntry = BaseEntry(
                        title: title,
                        content: content,
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
        
        
        // Priority 2: Entry details tip (after 10 visits)
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
