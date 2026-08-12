import UIKit
import RevenueCat
import RevenueCatUI
import TipKit

protocol NoteDetailViewControllerDelegate: AnyObject {
    func noteDetailViewController(didSaveNote entry: NoteItem?)
    func noteDetailViewController(didDeleteNote entry: NoteItem)
}

final class NoteDetailViewController: NNSheetViewController, NNTippable {
    
    // MARK: - Properties
    weak var noteDelegate: NoteDetailViewControllerDelegate?
    private let isReadOnly: Bool
    
    override var hasDiscardableContent: Bool {
        guard !isReadOnly else { return false }
        if entry == nil {
            let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let content = contentTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !title.isEmpty || !content.isEmpty || !pendingAttachmentIds.isEmpty
        }
        return hasUnsavedChanges
    }
    
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
    
    let entry: NoteItem?
    private let category: String
    private let initialTitle: String?
    private let initialContent: String?

    private lazy var attachmentStackView: AttachmentStackView = {
        // Expand left (horizontal accordion) across the footer row.
        let stack = AttachmentStackView(stackSize: 80, expansionDirection: .left)
        stack.delegate = self
        return stack
    }()

    /// Working attachment IDs (pending until save).
    private var pendingAttachmentIds: [String] = []
    private var resolvedAttachments: [any BaseItem] = []
    private var originalAttachmentIds: [String] = []
    private var hasCompletedInitialAttachmentLoad = false
    
    // Track original values for change detection
    private var originalTitle: String?
    private var originalContent: String?
    
    // Track changes
    private var hasUnsavedChanges: Bool = false {
        didSet {
            updateSaveButtonState()
        }
    }
    
    // MARK: - Initialization
    init(category: String, entry: NoteItem? = nil, sourceFrame: CGRect? = nil, isReadOnly: Bool = false) {
        self.category = category
        self.entry = entry
        self.isReadOnly = isReadOnly
        self.initialTitle = nil
        self.initialContent = nil
        super.init(sourceFrame: sourceFrame)
    }
    
    /// Creates a new note form prefilled from a Common Items suggestion.
    init(category: String, title: String, content: String, sourceFrame: CGRect? = nil) {
        self.category = category
        self.entry = nil
        self.isReadOnly = false
        self.initialTitle = title
        self.initialContent = content
        super.init(sourceFrame: sourceFrame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = entry == nil ? "New Note" : isReadOnly ? "View Note" : "Edit Note"
        titleField.text = entry?.title ?? initialTitle
        titleField.placeholder = "Title"
        titleField.delegate = self
        contentTextView.text = entry?.content ?? initialContent
        contentTextView.delegate = self
        
        // Store original values for change detection
        originalTitle = entry?.title
        originalContent = entry?.content
        pendingAttachmentIds = entry?.attachmentIds ?? []
        originalAttachmentIds = pendingAttachmentIds
        
        // Add target for title field changes
        titleField.addTarget(self, action: #selector(titleFieldChanged), for: .editingChanged)
        
        // Configure folder label with last 2 components
        configureFolderLabel()
        
        // Remove automatic tip dismissal - let user dismiss manually
        
        if isReadOnly {
            configureReadOnlyMode()
        }
        
        itemsHiddenDuringTransition = isReadOnly ? [attachmentStackView] : [saveButton, attachmentStackView]
        
        if entry == nil && !isReadOnly && titleField.text?.isEmpty ?? false {
            titleField.becomeFirstResponder()
        } else if entry == nil && !isReadOnly {
            contentTextView.becomeFirstResponder()
        }
        
        // Initial save button state update
        updateSaveButtonState()
        refreshAttachmentStack()
        loadResolvedAttachments()
    }
    
    // MARK: - Setup Methods
    override func addContentToContainer() {
        super.addContentToContainer()
        
        containerView.addSubview(contentTextView)
        containerView.addSubview(attachmentStackView)
        containerView.addSubview(folderLabel)
        if !isReadOnly {
            containerView.addSubview(saveButton)
        }
        
        folderLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        folderLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        attachmentStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        attachmentStackView.setContentHuggingPriority(.required, for: .horizontal)

        var constraints: [NSLayoutConstraint] = [
            // Content text view
            contentTextView.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 8),
            contentTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            contentTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            // Same row above Save: folder left, attachments right
            folderLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            folderLabel.trailingAnchor.constraint(lessThanOrEqualTo: attachmentStackView.leadingAnchor, constant: -12),
            folderLabel.heightAnchor.constraint(equalToConstant: 30),

            attachmentStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
        ]
        
        if !isReadOnly {
            constraints.append(contentsOf: [
                contentTextView.bottomAnchor.constraint(equalTo: attachmentStackView.topAnchor, constant: -16),
                // Bottoms share the row just above Save so empty stack doesn't misplace the folder.
                folderLabel.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -12),
                attachmentStackView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -12),
                
                saveButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                saveButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                saveButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Self.ctaBottomPadding),
                saveButton.heightAnchor.constraint(equalToConstant: 46),
            ])
        } else {
            constraints.append(contentsOf: [
                contentTextView.bottomAnchor.constraint(equalTo: attachmentStackView.topAnchor, constant: -16),
                folderLabel.bottomAnchor.constraint(
                    equalTo: containerView.bottomAnchor,
                    constant: -Self.ctaBottomPadding
                ).with(priority: .defaultHigh),
                attachmentStackView.bottomAnchor.constraint(
                    equalTo: containerView.bottomAnchor,
                    constant: -Self.ctaBottomPadding
                ).with(priority: .defaultHigh),
            ])
        }
        
        NSLayoutConstraint.activate(constraints)

        // Blur behind folder + attachment stack + save (pin from stack so z-order stays correct).
        attachmentStackView.pinVariableBlur(to: containerView, direction: .bottom, blurRadius: 20, height: 140)
        containerView.bringSubviewToFront(folderLabel)
        containerView.bringSubviewToFront(attachmentStackView)
        if !isReadOnly {
            containerView.bringSubviewToFront(saveButton)
        }
        containerView.clipsToBounds = true
    }
    
    // MARK: - NNSheetViewController Override
    
    override func setupInfoButton() {
        setLeadingBarButtonHidden(false)
        
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
        
        var topActions: [UIAction] = []
        var menuChildren: [UIMenuElement] = []

        let attachTitle = pendingAttachmentIds.isEmpty ? "Add Attachment" : "Manage Attachments"
        let attachAction = UIAction(
            title: attachTitle,
            image: UIImage(systemName: "paperclip")
        ) { [weak self] _ in
            self?.presentAttachmentPicker()
        }
        topActions.append(attachAction)
        topActions.append(contentsOf: [createdAtAction, modifiedAtAction])
        
        let topSection = UIMenu(title: "", options: .displayInline, children: topActions)
        menuChildren.append(topSection)
        
        if entry != nil {
            let deleteAction = UIAction(
                title: "Delete Note",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.handleDeleteTapped()
            }
            menuChildren.append(deleteAction)
        }
        
        setLeadingBarButtonMenu(UIMenu(title: "", children: menuChildren))
    }
    
    private func setupReadOnlyInfoMenu() {
        let createdAt = entry?.createdAt ?? Date()
        let modifiedAt = entry?.updatedAt ?? Date()
        
        let createdAtAction = UIAction(title: "Created at: \(formattedDate(createdAt))", handler: { _ in })
        let modifiedAtAction = UIAction(title: "Modified at: \(formattedDate(modifiedAt))", handler: { _ in })
        
        setLeadingBarButtonMenu(UIMenu(title: "", children: [createdAtAction, modifiedAtAction]))
    }
    
    
    private func handleDeleteTapped() {
        guard let entry = entry else { return }
        
        let alert = UIAlertController(
            title: "Delete Note",
            message: "Are you sure you want to delete '\(entry.title)'? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteNote()
        })
        
        present(alert, animated: true)
    }
    
    private func deleteNote() {
        guard let entry = entry else { return }
        
        Task {
            do {
                try await NestService.shared.deleteNote(entry)
                await MainActor.run {
                    noteDelegate?.noteDetailViewController(didDeleteNote: entry)
                    HapticsHelper.lightHaptic()
                    dismissSheet()
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
        prepareToSaveAndDismiss()
        titleField.isUserInteractionEnabled = false
        contentTextView.isUserInteractionEnabled = false
        
        Task {
            
            do {
                var savedNote: NoteItem
                
                let allItems = try await NestService.shared.fetchAllItems()
                let prunedAttachmentIds = AttachmentResolver.prune(
                    ids: pendingAttachmentIds,
                    against: allItems,
                    excludingHostId: entry?.id
                )

                if let existingEntry = entry {
                    existingEntry.title = title
                    existingEntry.content = content
                    existingEntry.attachmentIds = prunedAttachmentIds
                    existingEntry.updatedAt = Date()
                    
                    try await NestService.shared.updateNote(existingEntry)
                    savedNote = existingEntry
                } else {
                    let newEntry = NoteItem(
                        title: title,
                        content: content,
                        category: category,
                        attachmentIds: prunedAttachmentIds
                    )
                    
                    // Create entry (limit check is done before showing this VC)
                    try await NestService.shared.createNote(newEntry)
                    savedNote = newEntry
                    
                    // Track entry creation for rating prompt
                    RatingManager.shared.trackEntryCreation()
                }
                
                HapticsHelper.lightHaptic()
                
                // Notify delegate
                await MainActor.run {
                    self.noteDelegate?.noteDetailViewController(didSaveNote: savedNote)
                    
                    // Post notification that an entry was saved
                    NotificationCenter.default.post(name: .noteDidSave, object: nil, userInfo: ["note": savedNote])
                    
                    self.dismissSheet()
                }
            } catch {
                await MainActor.run {
                    self.cancelSaveAndDismiss()
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
        guard !isReadOnly else { return }

        trackScreenVisit()

        // New-note tips first (only while creating an empty note)
        let isNewEmptyNote = entry == nil && (titleField.text?.isEmpty ?? true)
        if isNewEmptyNote {
            if NNTipManager.shared.shouldShowTip(NoteDetailTips.noteTitleContentTip) {
                NNTipManager.shared.showTip(
                    NoteDetailTips.noteTitleContentTip,
                    sourceView: titleField,
                    in: self,
                    pinToEdge: .bottom,
                    offset: CGPoint(x: 0, y: 70)
                )
                return
            }

            if NNTipManager.shared.shouldShowTip(NoteDetailTips.noteDetailsTip) {
                NNTipManager.shared.showTip(
                    NoteDetailTips.noteDetailsTip,
                    sourceView: navigationBar,
                    in: self,
                    pinToEdge: .leading,
                    offset: CGPoint(x: 8, y: 0)
                )
                return
            }
        }

        showAttachmentTipIfNeeded()
    }

    private func showAttachmentTipIfNeeded() {
        guard NNTipManager.shared.shouldShowTip(AttachmentTips.attachItemsTip) else { return }
        NNTipManager.shared.showTip(
            AttachmentTips.attachItemsTip,
            sourceView: attachmentStackView,
            in: self,
            pinToEdge: .top,
            offset: CGPoint(x: 0, y: -8)
        )
    }
    
    // MARK: - Change Detection
    
    @objc private func titleFieldChanged() {
        collapseAttachmentsIfNeeded()
        checkForUnsavedChanges()
    }

    override func leadingMenuWillPresent() {
        collapseAttachmentsIfNeeded()
    }

    private func collapseAttachmentsIfNeeded() {
        attachmentStackView.collapseIfNeeded()
    }
    
    private func checkForUnsavedChanges() {
        let currentTitle = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentContent = contentTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let titleChanged = currentTitle != originalTitle
        let contentChanged = currentContent != originalContent
        let attachmentsChanged = pendingAttachmentIds != originalAttachmentIds
        
        hasUnsavedChanges = titleChanged || contentChanged || attachmentsChanged
    }

    // MARK: - Attachments

    private func refreshAttachmentStack() {
        // Empty editable stacks show a dashed paperclip; otherwise the accordion.
        attachmentStackView.configure(
            items: resolvedAttachments,
            showsPlus: !isReadOnly,
            allowsRemoval: !isReadOnly
        )
        loadPlaceThumbnailsForAttachments()
        if !isReadOnly {
            setupEditableInfoMenu()
        }
    }

    private func loadResolvedAttachments() {
        guard !pendingAttachmentIds.isEmpty else {
            hasCompletedInitialAttachmentLoad = true
            resolvedAttachments = []
            refreshAttachmentStack()
            return
        }

        Task {
            do {
                let items = try await fetchItemsForAttachmentResolution()
                let resolved = AttachmentResolver.resolve(
                    ids: pendingAttachmentIds,
                    from: items,
                    excludingHostId: entry?.id
                )
                await MainActor.run {
                    self.resolvedAttachments = resolved
                    // Keep pending IDs in sync with what still exists
                    self.pendingAttachmentIds = resolved.map(\.id)
                    if !self.hasCompletedInitialAttachmentLoad {
                        self.originalAttachmentIds = self.pendingAttachmentIds
                        self.hasCompletedInitialAttachmentLoad = true
                    }
                    self.refreshAttachmentStack()
                    self.checkForUnsavedChanges()
                }
            } catch {
                Logger.log(
                    level: .error,
                    category: .general,
                    message: "Failed to resolve attachments: \(error.localizedDescription)"
                )
            }
        }
    }

    private func fetchItemsForAttachmentResolution() async throws -> [BaseItem] {
        if isReadOnly {
            return try await SitterViewService.shared.itemsForAttachmentResolution()
        }
        return try await NestService.shared.itemsForAttachmentResolution()
    }

    private func loadPlaceThumbnailsForAttachments() {
        for item in resolvedAttachments {
            guard let place = item as? PlaceItem else { continue }
            Task {
                do {
                    let image: UIImage
                    if isReadOnly {
                        image = try await SitterViewService.shared.loadImages(for: place)
                    } else {
                        image = try await NestService.shared.loadImages(for: place)
                    }
                    await MainActor.run {
                        self.attachmentStackView.setPreviewImage(image, forItemId: place.id)
                    }
                } catch {
                    // Keep icon fallback
                }
            }
        }
    }

    private func presentAttachmentPicker() {
        collapseAttachmentsIfNeeded()
        NNTipManager.shared.dismissTip(AttachmentTips.attachItemsTip)
        AttachmentPickerPresenter.present(
            from: self,
            selectedIds: pendingAttachmentIds,
            excludingHostId: entry?.id
        ) { [weak self] ids in
            guard let self else { return }
            self.pendingAttachmentIds = ids
            self.loadResolvedAttachments()
            self.checkForUnsavedChanges()
        }
    }
    
    private func updateSaveButtonState() {
        if isReadOnly {
            saveButton.isHidden = true
            return
        }
        
        // For new entries, enable save button when title and content are not empty
        if entry == nil {
            let titleString = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let contentString = contentTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hasRequiredContent = !titleString.isEmpty && !contentString.isEmpty
            saveButton.isEnabled = hasRequiredContent
            return
        }
        
        // For existing entries, enable save button only when there are changes
        let titleString = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let contentString = contentTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasRequiredContent = !titleString.isEmpty && !contentString.isEmpty
        
        saveButton.isEnabled = hasRequiredContent && hasUnsavedChanges
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
extension NoteDetailViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        collapseAttachmentsIfNeeded()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == titleField {
            contentTextView.becomeFirstResponder()
            return false
        }
        return true
    }
}

// MARK: - UITextViewDelegate
extension NoteDetailViewController: UITextViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        collapseAttachmentsIfNeeded()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        collapseAttachmentsIfNeeded()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        collapseAttachmentsIfNeeded()
        checkForUnsavedChanges()
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        collapseAttachmentsIfNeeded()

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

// MARK: - AttachmentStackViewDelegate
extension NoteDetailViewController: AttachmentStackViewDelegate {
    func attachmentStackView(_ stackView: AttachmentStackView, didTapItem item: any BaseItem) {
        NestItemDetailRouter.presentDetail(
            for: item,
            from: self,
            nestItemRepository: isReadOnly ? SitterViewService.shared : NestService.shared,
            category: item.category,
            sourceFrame: stackView.convert(stackView.bounds, to: nil),
            placeListDelegate: nil,
            noteDelegate: nil,
            routineDelegate: nil,
            contactDelegate: nil
        )
    }

    func attachmentStackViewDidTapPlus(_ stackView: AttachmentStackView) {
        presentAttachmentPicker()
    }

    func attachmentStackView(_ stackView: AttachmentStackView, didChangeExpanded isExpanded: Bool) {
        // Hide folder while the horizontal accordion is open so cards have room.
        UIView.animate(withDuration: 0.2) {
            self.folderLabel.alpha = isExpanded ? 0 : 1
        }
        self.folderLabel.isUserInteractionEnabled = !isExpanded
    }

    func attachmentStackView(_ stackView: AttachmentStackView, didRequestRemoveItem item: any BaseItem) {
        pendingAttachmentIds.removeAll { $0 == item.id }
        resolvedAttachments.removeAll { $0.id == item.id }
        // Stack already animated the drop; keep local state in sync without rebuilding.
        checkForUnsavedChanges()
        if !isReadOnly {
            setupEditableInfoMenu()
        }
    }
}
