//
//  ContactDetailViewController.swift
//  nest-note
//

import UIKit
import Contacts
import ContactsUI

protocol ContactDetailViewControllerDelegate: AnyObject {
    func contactDetailViewController(_ controller: ContactDetailViewController, didSave contact: ContactItem)
    func contactDetailViewController(_ controller: ContactDetailViewController, didDelete contact: ContactItem)
}

final class ContactDetailViewController: NNSheetViewController {

    weak var contactDelegate: ContactDetailViewControllerDelegate?

    private let category: String
    private let existingContact: ContactItem?
    private let isReadOnly: Bool

    private enum ContactNameField {
        case fullName
        case givenName
        case familyName
        case organization
    }

    private let phoneTextView: UITextView = {
        let textView = UITextView()
        textView.font = .bodyXL
        textView.backgroundColor = .clear
        let placeholder = NSAttributedString(string: "Phone")
        textView.perform(NSSelectorFromString("setAttributedPlaceholder:"), with: placeholder)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.keyboardType = .phonePad
        textView.textContentType = .telephoneNumber
        textView.autocorrectionType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.dataDetectorTypes = .phoneNumber
        textView.isEditable = true
        textView.isSelectable = true
        return textView
    }()

    private lazy var importButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(
            title: "Import",
            image: UIImage(systemName: "person.crop.circle.badge.plus"),
            imagePlacement: .left,
            backgroundColor: NNColors.offBlack,
            foregroundColor: .white
        )
        button.addTarget(self, action: #selector(importButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var saveButton: NNLoadingButton = {
        let button = NNLoadingButton(
            title: existingContact == nil ? "Save" : "Update",
            titleColor: .white,
            fillStyle: .fill(NNColors.primary)
        )
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var ctaStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [importButton, saveButton])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fill
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var callButton: NNSmallPrimaryButton = {
        let button = NNSmallPrimaryButton(
            title: "Call",
            image: UIImage(systemName: "phone.fill"),
            imagePlacement: .left,
            backgroundColor: NNColors.primary,
            foregroundColor: .white
        )
        button.addTarget(self, action: #selector(callButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var folderLabel: NNSmallLabel = {
        let label = NNSmallLabel()
        return label
    }()

    private var pendingImportFromContacts = false

    init(category: String, contact: ContactItem? = nil, sourceFrame: CGRect? = nil, isReadOnly: Bool = false) {
        self.category = category
        self.existingContact = contact
        self.isReadOnly = isReadOnly
        super.init(sourceFrame: sourceFrame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.text = existingContact == nil ? "New Contact" : isReadOnly ? "View Contact" : "Edit Contact"
        titleField.placeholder = "Name"
        titleField.text = existingContact?.title
        titleField.delegate = self
        titleField.addTarget(self, action: #selector(titleFieldChanged), for: .editingChanged)

        phoneTextView.text = existingContact?.phoneNumber
        phoneTextView.delegate = self

        configureFolderLabel()

        if isReadOnly {
            titleField.isEnabled = false
            phoneTextView.isEditable = false
            phoneTextView.isUserInteractionEnabled = true
            itemsHiddenDuringTransition = []
            configureReadOnlyInfoMenu()
            updateCallButtonEnabled()
        } else {
            itemsHiddenDuringTransition = [ctaStack]
            let bottomInset: CGFloat = 104
            phoneTextView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
            phoneTextView.scrollIndicatorInsets = phoneTextView.contentInset
            setupInfoButton()
        }

        updateSaveButtonState()

        if existingContact == nil && !isReadOnly {
            titleField.becomeFirstResponder()
        }
    }

    override func addContentToContainer() {
        super.addContentToContainer()
        containerView.addSubview(phoneTextView)
        containerView.addSubview(folderLabel)
        if isReadOnly {
            containerView.addSubview(callButton)
        } else {
            containerView.addSubview(ctaStack)
        }

        var constraints: [NSLayoutConstraint] = [
            phoneTextView.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 8),
            phoneTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            phoneTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            folderLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            folderLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16),
            folderLabel.heightAnchor.constraint(equalToConstant: 30),
        ]

        if !isReadOnly {
            constraints.append(contentsOf: [
                phoneTextView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
                folderLabel.bottomAnchor.constraint(equalTo: ctaStack.topAnchor, constant: -16),
                ctaStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                ctaStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                ctaStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16).with(priority: .defaultHigh),
                ctaStack.heightAnchor.constraint(equalToConstant: 46),
                importButton.widthAnchor.constraint(lessThanOrEqualTo: ctaStack.widthAnchor, multiplier: 0.45),
                saveButton.widthAnchor.constraint(lessThanOrEqualTo: ctaStack.widthAnchor, multiplier: 0.55),
            ])
        } else {
            constraints.append(contentsOf: [
                phoneTextView.bottomAnchor.constraint(equalTo: folderLabel.topAnchor, constant: -16),
                folderLabel.bottomAnchor.constraint(equalTo: callButton.topAnchor, constant: -16),
                callButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                callButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                callButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16).with(priority: .defaultHigh),
                callButton.heightAnchor.constraint(equalToConstant: 46),
            ])
        }

        NSLayoutConstraint.activate(constraints)

        if !isReadOnly {
            folderLabel.pinVariableBlur(to: containerView, direction: .bottom, blurRadius: 20, height: 120)
            containerView.clipsToBounds = true
        }
    }

    override func setupInfoButton() {
        guard !isReadOnly else {
            infoButton.isHidden = true
            return
        }
        infoButton.isHidden = false
        infoButton.menu = createInfoMenu()
        infoButton.showsMenuAsPrimaryAction = true
    }

    private func configureFolderLabel() {
        let components = category.components(separatedBy: "/")
        if components.count >= 2 {
            folderLabel.text = components.joined(separator: " / ")
        } else if components.count == 1 {
            folderLabel.text = components.first
        } else {
            folderLabel.text = category
        }
    }

    private func createInfoMenu() -> UIMenu {
        let createdAt = existingContact?.createdAt ?? Date()
        let modifiedAt = existingContact?.updatedAt ?? Date()
        let createdAtAction = UIAction(title: "Created at: \(formattedDate(createdAt))", handler: { _ in })
        let modifiedAtAction = UIAction(title: "Modified at: \(formattedDate(modifiedAt))", handler: { _ in })

        var items: [UIMenuElement] = []
        if existingContact != nil {
            let deleteAction = UIAction(
                title: "Delete Contact",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.confirmDelete()
            }
            items.append(deleteAction)
        }
        items.append(contentsOf: [createdAtAction, modifiedAtAction])
        return UIMenu(title: "", children: items)
    }

    private func configureReadOnlyInfoMenu() {
        infoButton.isHidden = false
        let createdAt = existingContact?.createdAt ?? Date()
        let modifiedAt = existingContact?.updatedAt ?? Date()
        let createdAtAction = UIAction(title: "Created at: \(formattedDate(createdAt))", handler: { _ in })
        let modifiedAtAction = UIAction(title: "Modified at: \(formattedDate(modifiedAt))", handler: { _ in })
        infoButton.menu = UIMenu(title: "", children: [createdAtAction, modifiedAtAction])
        infoButton.showsMenuAsPrimaryAction = true
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func updateCallButtonEnabled() {
        guard isReadOnly else { return }
        let raw = (phoneTextView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        callButton.isEnabled = !sanitizedDialString(from: raw).isEmpty
    }

    /// Keeps leading `+` and decimal digits for `tel:` URLs.
    private func sanitizedDialString(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let hasPlus = trimmed.first == "+"
        let digits = trimmed.filter(\.isNumber)
        if hasPlus, !digits.isEmpty {
            return "+" + digits
        }
        return digits
    }

    @objc private func callButtonTapped() {
        let raw = (phoneTextView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let dial = sanitizedDialString(from: raw)
        guard !dial.isEmpty, let url = URL(string: "tel:\(dial)") else { return }
        UIApplication.shared.open(url)
    }

    @objc private func importButtonTapped() {
        presentContactPicker()
    }

    private func presentContactPicker() {
        let picker = CNContactPickerViewController()
        picker.delegate = self
        present(picker, animated: true)
    }

    private func phones(from contact: CNContact) -> [String] {
        contact.phoneNumbers.map { $0.value.stringValue }.filter { !$0.isEmpty }
    }

    private func displayLabel(for contact: CNContact) -> String {
        CNContactFormatter.string(from: contact, style: .fullName)
            ?? [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            ?? contact.organizationName
    }

    private func string(for contact: CNContact, field: ContactNameField) -> String? {
        let s: String
        switch field {
        case .fullName:
            s = CNContactFormatter.string(from: contact, style: .fullName)
                ?? [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        case .givenName:
            s = contact.givenName
        case .familyName:
            s = contact.familyName
        case .organization:
            s = contact.organizationName
        }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func importSummaryLines(contact: CNContact, phones: [String]) -> String {
        let nameLine = displayLabel(for: contact).trimmingCharacters(in: .whitespacesAndNewlines)
        let namePart = nameLine.isEmpty ? "No name in contact" : nameLine
        if phones.isEmpty {
            return namePart
        }
        let extra = phones.count > 1 ? " (+ \(phones.count - 1) more numbers)" : ""
        return "\(namePart)\n\(phones[0])\(extra)"
    }

    private func presentImportChoices(for contact: CNContact) {
        let phones = phones(from: contact)
        let sheet = UIAlertController(
            title: "Import from contact",
            message: importSummaryLines(contact: contact, phones: phones),
            preferredStyle: .actionSheet
        )

        sheet.addAction(UIAlertAction(title: "Import name & phone", style: .default) { [weak self] _ in
            self?.importNameAndPhone(contact: contact, phones: phones)
        })

        if !phones.isEmpty {
            sheet.addAction(UIAlertAction(title: "Import phone only", style: .default) { [weak self] _ in
                self?.importPhoneOnly(contact: contact, phones: phones)
            })
        }

        sheet.addAction(UIAlertAction(title: "Import name only", style: .default) { [weak self] _ in
            self?.importNameOnly(contact: contact, field: .fullName)
        })

        sheet.addAction(UIAlertAction(title: "Choose name to import…", style: .default) { [weak self] _ in
            self?.presentNameFieldChooser(contact: contact)
        })

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        configurePopover(for: sheet, sourceView: importButton)
        present(sheet, animated: true)
    }

    private func presentNameFieldChooser(contact: CNContact) {
        let alert = UIAlertController(
            title: "Name to import",
            message: "Only the name field will change. You can import the phone separately if needed.",
            preferredStyle: .alert
        )

        let fields: [(String, ContactNameField)] = [
            ("Full name", .fullName),
            ("First name", .givenName),
            ("Last name", .familyName),
            ("Company / organization", .organization),
        ]

        for (label, field) in fields {
            guard string(for: contact, field: field) != nil else { continue }
            alert.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                self?.importNameOnly(contact: contact, field: field)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func importNameOnly(contact: CNContact, field: ContactNameField) {
        guard let name = string(for: contact, field: field) else {
            shakeContainerView()
            return
        }
        titleField.text = name
        markImported()
        updateSaveButtonState()
    }

    private func importPhoneOnly(contact: CNContact, phones: [String]) {
        guard !phones.isEmpty else {
            shakeContainerView()
            return
        }
        if phones.count == 1 {
            phoneTextView.text = phones[0]
        } else {
            presentPhonePicker(phones: phones) { [weak self] chosen in
                self?.phoneTextView.text = chosen
                self?.markImported()
                self?.updateSaveButtonState()
            }
            return
        }
        markImported()
        updateSaveButtonState()
    }

    private func importNameAndPhone(contact: CNContact, phones: [String]) {
        if let name = string(for: contact, field: .fullName) ?? string(for: contact, field: .organization) {
            titleField.text = name
        }

        guard !phones.isEmpty else {
            markImported()
            updateSaveButtonState()
            let hasName = !(titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            if !hasName {
                shakeContainerView()
            }
            return
        }

        if phones.count == 1 {
            phoneTextView.text = phones[0]
            markImported()
            updateSaveButtonState()
        } else {
            presentPhonePicker(phones: phones) { [weak self] chosen in
                self?.phoneTextView.text = chosen
                self?.markImported()
                self?.updateSaveButtonState()
            }
        }
    }

    private func presentPhonePicker(phones: [String], onPick: @escaping (String) -> Void) {
        let sheet = UIAlertController(title: "Choose a phone number", message: nil, preferredStyle: .actionSheet)
        for number in phones {
            sheet.addAction(UIAlertAction(title: number, style: .default) { _ in
                onPick(number)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        configurePopover(for: sheet, sourceView: importButton)
        present(sheet, animated: true)
    }

    private func configurePopover(for alert: UIAlertController, sourceView: UIView) {
        if let pop = alert.popoverPresentationController {
            pop.sourceView = sourceView
            pop.sourceRect = sourceView.bounds
        }
    }

    private func markImported() {
        pendingImportFromContacts = true
    }

    @objc private func titleFieldChanged() {
        updateSaveButtonState()
    }

    private func normalizedPhoneString() -> String {
        let raw = phoneTextView.text ?? ""
        raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return raw
    }

    private func updateSaveButtonState() {
        let nameOk = !(titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let phoneOk = !normalizedPhoneString().isEmpty
        saveButton.isEnabled = nameOk && phoneOk
    }

    @objc private func saveButtonTapped() {
        guard let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            shakeContainerView()
            return
        }
        let phone = normalizedPhoneString()
        guard !phone.isEmpty else {
            shakeContainerView()
            return
        }

        saveButton.startLoading()
        Task {
            do {
                let item: ContactItem
                if let existing = existingContact {
                    var updated = existing
                    updated.title = title
                    updated.phoneNumber = phone
                    updated.updatedAt = Date()
                    item = updated
                    try await NestService.shared.updateItem(item)
                } else {
                    item = ContactItem(category: category, title: title, phoneNumber: phone)
                    try await NestService.shared.createItem(item)
                }
                if pendingImportFromContacts {
                    Tracker.shared.track(.contactImportedFromSystem)
                } else {
                    Tracker.shared.track(.contactCreated)
                }
                await MainActor.run {
                    self.saveButton.stopLoading()
                    self.contactDelegate?.contactDetailViewController(self, didSave: item)
                    self.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.saveButton.stopLoading()
                    self.shakeContainerView()
                }
            }
        }
    }

    private func confirmDelete() {
        guard let contact = existingContact else { return }
        let alert = UIAlertController(
            title: "Delete Contact",
            message: "Are you sure you want to delete '\(contact.title)'? This action cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteContact(contact)
        })
        present(alert, animated: true)
    }

    private func deleteContact(_ contact: ContactItem) {
        Task {
            do {
                try await NestService.shared.deleteItem(id: contact.id)
                await MainActor.run {
                    self.contactDelegate?.contactDetailViewController(self, didDelete: contact)
                    self.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.shakeContainerView()
                }
            }
        }
    }
}

extension ContactDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === titleField {
            phoneTextView.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}

extension ContactDetailViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateSaveButtonState()
    }
}

extension ContactDetailViewController: CNContactPickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        // Dismiss keyboard first to avoid RTI session noise; copy contact data before async dismiss
        // (CNContact is only guaranteed valid during this callback).
        view.endEditing(true)
        guard let contactCopy = contact.mutableCopy() as? CNMutableContact else {
            picker.dismiss(animated: true)
            return
        }
        picker.dismiss(animated: true) { [weak self] in
            self?.presentImportChoices(for: contactCopy)
        }
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        view.endEditing(true)
    }
}
