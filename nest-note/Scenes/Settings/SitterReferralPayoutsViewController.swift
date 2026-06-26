//
//  SitterReferralPayoutsViewController.swift
//  nest-note
//

import UIKit

final class SitterReferralPayoutsViewController: NNViewController {

    private enum Tab: Int, CaseIterable {
        case pending
        case paid
        case clawedBack

        var title: String {
            switch self {
            case .pending: return "Pending"
            case .paid: return "Paid"
            case .clawedBack: return "Clawed Back"
            }
        }

        var status: ReferralConversionStatus {
            switch self {
            case .pending: return .pendingPayout
            case .paid: return .paid
            case .clawedBack: return .clawedBack
            }
        }
    }

    private let segmentedControl = UISegmentedControl(items: Tab.allCases.map(\.title))
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let filterMissingVenmoSwitch = UISwitch()
    private let filterLabel = UILabel()
    private let filterStack = UIStackView()
    private let exportButton = UIBarButtonItem(title: "Export", style: .plain, target: nil, action: nil)

    private var conversions: [ReferralConversion] = []
    private var filteredConversions: [ReferralConversion] = []
    private var showMissingVenmoOnly = false
    private var selectedTab: Tab = .pending

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sitter Referral Payouts"
        view.backgroundColor = NNColors.groupedBackground
        setupFilterRow()
        setupSegmentedControl()
        setupTableView()
        navigationItem.rightBarButtonItem = exportButton
        exportButton.target = self
        exportButton.action = #selector(exportTapped)
        loadConversions()
    }

    private func setupFilterRow() {
        filterLabel.text = "Missing Venmo only"
        filterLabel.font = .preferredFont(forTextStyle: .subheadline)
        filterLabel.textColor = .secondaryLabel

        filterMissingVenmoSwitch.addTarget(self, action: #selector(filterChanged), for: .valueChanged)

        filterStack.axis = .horizontal
        filterStack.spacing = 8
        filterStack.alignment = .center
        filterStack.isLayoutMarginsRelativeArrangement = true
        filterStack.layoutMargins = UIEdgeInsets(top: 8, left: 20, bottom: 0, right: 20)
        filterStack.addArrangedSubview(filterLabel)
        filterStack.addArrangedSubview(filterMissingVenmoSwitch)
    }

    private func setupSegmentedControl() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(SitterReferralPayoutCell.self, forCellReuseIdentifier: SitterReferralPayoutCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120

        let stack = UIStackView(arrangedSubviews: [filterStack, segmentedControl, tableView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func loadConversions() {
        Task {
            do {
                let loaded = try await ReferralConversionService.shared.fetchConversions(status: selectedTab.status)
                await MainActor.run {
                    conversions = loaded
                    applyFilter()
                }
            } catch {
                await MainActor.run {
                    showToast(text: "Failed to load payouts")
                }
            }
        }
    }

    private func applyFilter() {
        if showMissingVenmoOnly && selectedTab == .pending {
            filteredConversions = conversions.filter { !$0.hasVenmoOnFile }
        } else {
            filteredConversions = conversions
        }
        tableView.reloadData()
        filterStack.isHidden = selectedTab != .pending
        exportButton.isEnabled = !filteredConversions.isEmpty
    }

    @objc private func tabChanged() {
        selectedTab = Tab(rawValue: segmentedControl.selectedSegmentIndex) ?? .pending
        loadConversions()
    }

    @objc private func filterChanged() {
        showMissingVenmoOnly = filterMissingVenmoSwitch.isOn
        applyFilter()
    }

    @objc private func exportTapped() {
        let csv = ReferralConversionService.shared.exportCSV(conversions: filteredConversions)
        UIPasteboard.general.string = csv
        showToast(text: "CSV copied to clipboard")
    }

    private func copyEmail(_ email: String) {
        UIPasteboard.general.string = email
        showToast(text: "Email copied")
    }

    private func copyVenmo(_ venmo: String) {
        UIPasteboard.general.string = venmo
        showToast(text: "Venmo copied")
    }

    private func openVenmo(for conversion: ReferralConversion) {
        guard let handle = conversion.sitterVenmo?.trimmingCharacters(in: .whitespacesAndNewlines),
              !handle.isEmpty else {
            showToast(text: "No Venmo on file")
            return
        }

        let cleanHandle = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
        let amount = String(format: "%.2f", Double(conversion.rewardAmountCents) / 100.0)
        let note = "NestNote referral"
        var components = URLComponents(string: "venmo://paycharge")!
        components.queryItems = [
            URLQueryItem(name: "txn", value: "pay"),
            URLQueryItem(name: "recipients", value: cleanHandle),
            URLQueryItem(name: "amount", value: amount),
            URLQueryItem(name: "note", value: note),
        ]

        if let url = components.url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let appStoreURL = URL(string: "https://apps.apple.com/app/venmo/id351727428") {
            UIApplication.shared.open(appStoreURL)
        }
    }

    private func markPaid(_ conversion: ReferralConversion) {
        guard let documentID = conversion.documentID else { return }

        let alert = UIAlertController(title: "Mark as Paid", message: "Optional Venmo confirmation note", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = conversion.sitterVenmo.map { "@\($0)" } ?? "Payout note"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Mark Paid", style: .default) { [weak self] _ in
            let notes = alert.textFields?.first?.text
            Task {
                do {
                    try await ReferralConversionService.shared.markAsPaid(conversionId: documentID, notes: notes)
                    await MainActor.run {
                        self?.showToast(text: "Marked as paid")
                        self?.loadConversions()
                    }
                } catch {
                    await MainActor.run {
                        self?.showToast(text: "Update failed")
                    }
                }
            }
        })
        present(alert, animated: true)
    }
}

extension SitterReferralPayoutsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredConversions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SitterReferralPayoutCell.reuseID, for: indexPath) as! SitterReferralPayoutCell
        let conversion = filteredConversions[indexPath.row]
        cell.configure(with: conversion)
        cell.onCopyEmail = { [weak self] in self?.copyEmail(conversion.sitterEmail) }
        cell.onCopyVenmo = { [weak self] in
            if let venmo = conversion.sitterVenmo { self?.copyVenmo(venmo) }
        }
        cell.onOpenVenmo = { [weak self] in self?.openVenmo(for: conversion) }
        cell.onMarkPaid = { [weak self] in self?.markPaid(conversion) }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Cell

private final class SitterReferralPayoutCell: UITableViewCell {
    static let reuseID = "SitterReferralPayoutCell"

    var onCopyEmail: (() -> Void)?
    var onCopyVenmo: (() -> Void)?
    var onOpenVenmo: (() -> Void)?
    var onMarkPaid: (() -> Void)?

    private let nameLabel = UILabel()
    private let amountLabel = UILabel()
    private let emailLabel = UILabel()
    private let venmoLabel = UILabel()
    private let detailLabel = UILabel()
    private let missingBadge = UILabel()
    private let actionStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onCopyEmail = nil
        onCopyVenmo = nil
        onOpenVenmo = nil
        onMarkPaid = nil
    }

    private func setup() {
        selectionStyle = .none

        nameLabel.font = .h2
        amountLabel.font = .h2
        amountLabel.textColor = NNColors.primary
        amountLabel.textAlignment = .right

        emailLabel.font = .preferredFont(forTextStyle: .subheadline)
        emailLabel.textColor = .secondaryLabel
        emailLabel.numberOfLines = 1

        venmoLabel.font = .preferredFont(forTextStyle: .subheadline)
        venmoLabel.textColor = .secondaryLabel

        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.textColor = .tertiaryLabel
        detailLabel.numberOfLines = 0

        missingBadge.font = .captionBoldS
        missingBadge.textColor = .white
        missingBadge.backgroundColor = .systemOrange
        missingBadge.text = " No Venmo on file "
        missingBadge.layer.cornerRadius = 4
        missingBadge.clipsToBounds = true
        missingBadge.isHidden = true

        actionStack.axis = .horizontal
        actionStack.spacing = 8
        actionStack.distribution = .fillEqually

        let topRow = UIStackView(arrangedSubviews: [nameLabel, amountLabel])
        topRow.axis = .horizontal
        topRow.alignment = .firstBaseline

        let contactRow = UIStackView(arrangedSubviews: [emailLabel, venmoLabel])
        contactRow.axis = .vertical
        contactRow.spacing = 2

        let root = UIStackView(arrangedSubviews: [topRow, contactRow, missingBadge, detailLabel, actionStack])
        root.axis = .vertical
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(with conversion: ReferralConversion) {
        nameLabel.text = conversion.sitterName
        amountLabel.text = conversion.rewardAmountDollars
        emailLabel.text = conversion.sitterEmail
        if let venmo = conversion.sitterVenmo, !venmo.isEmpty {
            venmoLabel.text = venmo.hasPrefix("@") ? venmo : "@\(venmo)"
            venmoLabel.isHidden = false
        } else {
            venmoLabel.text = "No Venmo on file"
            venmoLabel.isHidden = false
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        detailLabel.text = "Referred: \(conversion.referredUserEmail) · \(conversion.packageType.capitalized) · \(formatter.string(from: conversion.purchaseDate))"

        missingBadge.isHidden = conversion.hasVenmoOnFile

        actionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        actionStack.addArrangedSubview(makeButton(title: "Copy Email", action: #selector(copyEmailTapped)))
        actionStack.addArrangedSubview(makeButton(title: "Copy Venmo", action: #selector(copyVenmoTapped)))
        actionStack.addArrangedSubview(makeButton(title: "Open Venmo", action: #selector(openVenmoTapped)))
        if conversion.status == .pendingPayout {
            actionStack.addArrangedSubview(makeButton(title: "Mark Paid", action: #selector(markPaidTapped)))
        }
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.baseForegroundColor = NNColors.primary
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func copyEmailTapped() { onCopyEmail?() }
    @objc private func copyVenmoTapped() { onCopyVenmo?() }
    @objc private func openVenmoTapped() { onOpenVenmo?() }
    @objc private func markPaidTapped() { onMarkPaid?() }
}
