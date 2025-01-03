import UIKit

protocol EntryDetailViewControllerDelegate: AnyObject {
    func entryDetailViewController(_ controller: EntryDetailViewController, didSaveEntry entry: BaseEntry?)
}

final class EntryDetailViewController: NNSheetViewController {
    
    // MARK: - Properties
    weak var entryDelegate: EntryDetailViewControllerDelegate?
    
    private let contentTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 18, weight: .medium)
        textView.backgroundColor = .clear
        let placeholder = NSAttributedString(string: "Content")
        textView.perform(NSSelectorFromString("setAttributedPlaceholder:"), with: placeholder)
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    private lazy var saveButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(title: entry == nil ? "Save" : "Update")
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
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
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
    init(category: String, entry: BaseEntry? = nil, sourceFrame: CGRect? = nil) {
        self.category = category
        self.entry = entry
        self.visibilityLevel = entry?.visibility ?? .standard
        super.init(sourceFrame: sourceFrame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = entry == nil ? "New Entry" : "Edit Entry"
        titleField.text = entry?.title
        titleField.placeholder = "Title"
        contentTextView.text = entry?.content
        
        setupVisibilityMenu()
        setupInfoMenu()
        
        itemsHiddenDuringTransition = [buttonStackView, infoButton]
        
        if entry == nil {
            titleField.becomeFirstResponder()
        }
    }
    
    // MARK: - Setup Methods
    override func addContentToContainer() {
        super.addContentToContainer()
        
        buttonStackView.addArrangedSubview(visibilityButton)
        buttonStackView.addArrangedSubview(saveButton)
        
        containerView.addSubview(contentTextView)
        containerView.addSubview(buttonStackView)
        containerView.addSubview(infoButton)
        
        NSLayoutConstraint.activate([
            contentTextView.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 8),
            contentTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            contentTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            contentTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            contentTextView.bottomAnchor.constraint(lessThanOrEqualTo: buttonStackView.topAnchor, constant: -16),
            
            infoButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            infoButton.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -8),
            infoButton.widthAnchor.constraint(equalToConstant: 44),
            infoButton.heightAnchor.constraint(equalToConstant: 44),
            
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            buttonStackView.heightAnchor.constraint(equalToConstant: 46),
            
            visibilityButton.widthAnchor.constraint(lessThanOrEqualTo: buttonStackView.widthAnchor, multiplier: 0.6),
            saveButton.widthAnchor.constraint(lessThanOrEqualTo: buttonStackView.widthAnchor, multiplier: 0.4)
        ])
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
        container.font = UIFont.boldSystemFont(ofSize: 16)
        visibilityButton.configuration?.attributedTitle = AttributedString(visibilityLevel.title, attributes: container)
//        visibilityButton.setTitle(visibilityLevel.title, for: .normal)
//        visibilityButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        
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
        let alert = UIAlertController(
            title: "Visibility Levels",
            message: "Essential: Basic information\nStandard: Normal visibility\nExtended: More details\nComprehensive: Full information",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
                    entryDelegate?.entryDetailViewController(self, didSaveEntry: nil)
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
    
    // MARK: - Actions
    @objc private func saveButtonTapped() {
        guard let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty,
              let content = contentTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            shakeContainerView()
            return
        }
        
        Task {
            do {
                var savedEntry: BaseEntry
                
                if let existingEntry = entry {
                    existingEntry.title = title
                    existingEntry.content = content
                    existingEntry.visibility = visibilityLevel
                    existingEntry.updatedAt = Date()
                    
                    Task.detached {
                        do {
                            try await NestService.shared.updateEntry(existingEntry)
                        } catch {
                            Logger.log(level: .error, category: .nestService, message: "Background update failed: \(error.localizedDescription)")
                        }
                    }
                    savedEntry = existingEntry
                } else {
                    let newEntry = BaseEntry(
                        title: title,
                        content: content,
                        visibilityLevel: visibilityLevel,
                        category: category
                    )
                    
                    Task.detached {
                        do {
                            try await NestService.shared.createEntry(newEntry)
                        } catch {
                            Logger.log(level: .error, category: .nestService, message: "Background creation failed: \(error.localizedDescription)")
                        }
                    }
                    savedEntry = newEntry
                }
                
                HapticsHelper.lightHaptic()
                entryDelegate?.entryDetailViewController(self, didSaveEntry: savedEntry)
                dismiss(animated: true)
            }
        }
    }
} 
