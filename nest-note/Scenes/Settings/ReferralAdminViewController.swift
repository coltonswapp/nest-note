//
//  ReferralAdminViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 9/9/25.
//

import UIKit

final class ReferralAdminViewController: NNViewController {
    
    // MARK: - UI Elements
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Referral Code Admin"
        label.font = .h1
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Create new referral code section
    private let createSectionLabel: UILabel = {
        let label = UILabel()
        label.text = "Create New Referral Code"
        label.font = .h2
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let codeTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Code (e.g., HEIDI, SYDNEY)"
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .allCharacters
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let creatorNameTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Creator Name"
        textField.autocorrectionType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let creatorEmailTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Creator Email (Optional)"
        textField.keyboardType = .emailAddress
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let notesTextField: NNTextField = {
        let textField = NNTextField()
        textField.placeholder = "Notes (Optional)"
        textField.autocorrectionType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let createButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Create Referral Code")
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Existing codes section
    private let existingCodesLabel: UILabel = {
        let label = UILabel()
        label.text = "Existing Referral Codes"
        label.font = .h2
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private var referralCodes: [(code: String, creatorName: String, creatorEmail: String, isActive: Bool, createdAt: Date)] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupConstraints()
        setupActions()
        setupTableView()
        loadExistingCodes()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "Referral Admin"
        view.backgroundColor = .systemGroupedBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        // Add components to stack
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(createSectionLabel)
        contentStackView.addArrangedSubview(codeTextField)
        contentStackView.addArrangedSubview(creatorNameTextField)
        contentStackView.addArrangedSubview(creatorEmailTextField)
        contentStackView.addArrangedSubview(notesTextField)
        contentStackView.addArrangedSubview(createButton)
        contentStackView.addArrangedSubview(existingCodesLabel)
        contentStackView.addArrangedSubview(tableView)
        contentStackView.addArrangedSubview(loadingIndicator)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content stack view
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48),
            
            // Text field heights
            codeTextField.heightAnchor.constraint(equalToConstant: 50),
            creatorNameTextField.heightAnchor.constraint(equalToConstant: 50),
            creatorEmailTextField.heightAnchor.constraint(equalToConstant: 50),
            notesTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Button height
            createButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Table view height
            tableView.heightAnchor.constraint(equalToConstant: 400)
        ])
    }
    
    private func setupActions() {
        createButton.addTarget(self, action: #selector(createButtonTapped), for: .touchUpInside)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ReferralCodeCell")
    }
    
    // MARK: - Actions
    @objc private func createButtonTapped() {
        guard let code = codeTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty,
              let creatorName = creatorNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !creatorName.isEmpty else {
            showAlert(title: "Error", message: "Please enter both code and creator name")
            return
        }
        
        let creatorEmail = creatorEmailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = notesTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        createButton.isEnabled = false
        loadingIndicator.startAnimating()
        
        Task {
            do {
                try await ReferralService.shared.createReferralCode(
                    code,
                    creatorName: creatorName,
                    creatorEmail: creatorEmail?.isEmpty == true ? nil : creatorEmail,
                    notes: notes?.isEmpty == true ? nil : notes
                )
                
                await MainActor.run {
                    self.showAlert(title: "Success", message: "Referral code '\(code.uppercased())' created successfully") {
                        self.clearForm()
                        self.loadExistingCodes()
                    }
                    self.createButton.isEnabled = true
                    self.loadingIndicator.stopAnimating()
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "Error", message: "Failed to create referral code: \(error.localizedDescription)")
                    self.createButton.isEnabled = true
                    self.loadingIndicator.stopAnimating()
                }
            }
        }
    }
    
    private func clearForm() {
        codeTextField.text = ""
        creatorNameTextField.text = ""
        creatorEmailTextField.text = ""
        notesTextField.text = ""
    }
    
    private func loadExistingCodes() {
        Task {
            do {
                let codes = try await ReferralService.shared.getAllReferralCodes()
                await MainActor.run {
                    self.referralCodes = codes.sorted { $0.createdAt > $1.createdAt }
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    Logger.log(level: .error, category: .referral, message: "Failed to load referral codes: \(error)")
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension ReferralAdminViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return referralCodes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ReferralCodeCell", for: indexPath)
        let codeInfo = referralCodes[indexPath.row]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        let statusText = codeInfo.isActive ? "Active" : "Inactive"
        let statusEmoji = codeInfo.isActive ? "🟢" : "🔴"
        
        cell.textLabel?.text = "\(codeInfo.code) - \(codeInfo.creatorName)"
        cell.detailTextLabel?.text = "\(statusEmoji) \(statusText) | Created: \(dateFormatter.string(from: codeInfo.createdAt))"
        
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        cell.detailTextLabel?.font = .systemFont(ofSize: 14)
        cell.detailTextLabel?.textColor = .secondaryLabel
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ReferralAdminViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let codeInfo = referralCodes[indexPath.row]
        
        let alert = UIAlertController(title: codeInfo.code, message: """
            Creator: \(codeInfo.creatorName)
            Email: \(codeInfo.creatorEmail.isEmpty ? "None" : codeInfo.creatorEmail)
            Status: \(codeInfo.isActive ? "Active" : "Inactive")
            Created: \(DateFormatter.localizedString(from: codeInfo.createdAt, dateStyle: .medium, timeStyle: .short))
            """, preferredStyle: .alert)
        
        if codeInfo.isActive {
            alert.addAction(UIAlertAction(title: "Deactivate", style: .destructive) { _ in
                self.deactivateCode(codeInfo.code)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func deactivateCode(_ code: String) {
        Task {
            do {
                try await ReferralService.shared.deactivateReferralCode(code)
                await MainActor.run {
                    self.showAlert(title: "Success", message: "Referral code '\(code)' has been deactivated") {
                        self.loadExistingCodes()
                    }
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "Error", message: "Failed to deactivate referral code: \(error.localizedDescription)")
                }
            }
        }
    }
}