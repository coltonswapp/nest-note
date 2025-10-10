//
//  ReferralAnalyticsViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 9/9/25.
//

import UIKit

final class ReferralAnalyticsViewController: NNViewController {
    
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
        label.text = "All Referrals Analytics"
        label.font = .h1
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let summaryCard: UIView = {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.label.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 4
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }()
    
    private let summaryStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 20
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let totalReferralsLabel: UILabel = {
        let label = UILabel()
        label.text = "Total Referrals"
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let totalReferralsCountLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let activeCodesCard: UIView = {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.label.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 4
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }()

    private let thisMonthCard: UIView = {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.label.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 4
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }()
    
    private let activeCodesLabel: UILabel = {
        let label = UILabel()
        label.text = "Active Codes"
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let activeCodesCountLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .systemGreen
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let thisMonthLabel: UILabel = {
        let label = UILabel()
        label.text = "This Month"
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let thisMonthCountLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .systemBlue
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let topCodesLabel: UILabel = {
        let label = UILabel()
        label.text = "Top Performing Codes"
        label.font = .h2
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let topCodesTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let recentReferralsLabel: UILabel = {
        let label = UILabel()
        label.text = "Recent Referrals"
        label.font = .h2
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let recentReferralsTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private var analytics: ReferralAnalytics?
    private var topCodes: [(code: String, count: Int)] = []
    private var recentReferrals: [RecentReferral] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupConstraints()
        setupActions()
        loadReferralData()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "Referral Analytics"
        view.backgroundColor = .systemGroupedBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        // Setup summary card with stack view
        summaryCard.addSubview(summaryStackView)

        // Create summary sections
        let totalSection = createSummarySection(titleLabel: totalReferralsLabel, countLabel: totalReferralsCountLabel)
        let activeSection = createSummarySection(titleLabel: activeCodesLabel, countLabel: activeCodesCountLabel)
        let monthSection = createSummarySection(titleLabel: thisMonthLabel, countLabel: thisMonthCountLabel)

        summaryStackView.addArrangedSubview(totalSection)
        summaryStackView.addArrangedSubview(activeSection)
        summaryStackView.addArrangedSubview(monthSection)

        // Setup table views
        topCodesTableView.delegate = self
        topCodesTableView.dataSource = self

        recentReferralsTableView.delegate = self
        recentReferralsTableView.dataSource = self
        
        // Add components to stack
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(summaryCard)
        contentStackView.addArrangedSubview(topCodesLabel)
        contentStackView.addArrangedSubview(topCodesTableView)
        contentStackView.addArrangedSubview(recentReferralsLabel)
        contentStackView.addArrangedSubview(recentReferralsTableView)
        contentStackView.addArrangedSubview(loadingIndicator)
        
        // Start loading
        loadingIndicator.startAnimating()
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
            
            // Summary card
            summaryCard.heightAnchor.constraint(equalToConstant: 100),
            summaryStackView.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: 16),
            summaryStackView.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 16),
            summaryStackView.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -16),
            summaryStackView.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -16),

            // Table views
            topCodesTableView.heightAnchor.constraint(equalToConstant: 250),
            recentReferralsTableView.heightAnchor.constraint(equalToConstant: 300)
        ])
    }
    
    private func setupActions() {
        // No actions needed for analytics view
    }

    private func createSummarySection(titleLabel: UILabel, countLabel: UILabel) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, countLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .center
        return stackView
    }
    
    // MARK: - Data Loading
    private func loadReferralData() {
        loadAllReferralsAnalytics()
    }
    
    private func loadAllReferralsAnalytics() {
        Task {
            do {
                let analytics = try await ReferralService.shared.getAllReferralsAnalytics()

                await MainActor.run {
                    self.analytics = analytics
                    self.topCodes = analytics.topCodes
                    self.recentReferrals = analytics.recentReferrals
                    self.updateUI(with: analytics)
                    self.topCodesTableView.reloadData()
                    self.recentReferralsTableView.reloadData()
                    self.loadingIndicator.stopAnimating()
                    self.loadingIndicator.isHidden = true
                }
            } catch {
                await MainActor.run {
                    Logger.log(level: .error, category: .referral, message: "Failed to load referrals analytics: \(error)")
                    self.loadingIndicator.stopAnimating()
                    self.loadingIndicator.isHidden = true
                }
            }
        }
    }
    
    private func updateUI(with analytics: ReferralAnalytics) {
        totalReferralsCountLabel.text = "\(analytics.totalReferrals)"
        activeCodesCountLabel.text = "\(analytics.totalActiveCodes)"
        thisMonthCountLabel.text = "\(analytics.thisMonthReferrals)"
    }
    
    private func currentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
}

// MARK: - UITableViewDataSource
extension ReferralAnalyticsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == topCodesTableView {
            return topCodes.count
        } else {
            return recentReferrals.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == topCodesTableView {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "TopCodeCell")
            let codeData = topCodes[indexPath.row]

            let rankEmoji = ["🥇", "🥈", "🥉"]
            let rank = indexPath.row < 3 ? rankEmoji[indexPath.row] : "\(indexPath.row + 1)."

            cell.textLabel?.text = "\(rank) \(codeData.code)"
            cell.detailTextLabel?.text = "\(codeData.count) uses"
            cell.textLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            cell.detailTextLabel?.font = .systemFont(ofSize: 16, weight: .bold)
            cell.detailTextLabel?.textColor = .systemBlue
            cell.backgroundColor = .clear

            return cell
        } else {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "RecentReferralCell")
            let referralData = recentReferrals[indexPath.row]

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short

            cell.textLabel?.text = referralData.referralCode
            cell.detailTextLabel?.text = dateFormatter.string(from: referralData.date)
            cell.textLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            cell.detailTextLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            cell.detailTextLabel?.textColor = .systemGreen
            cell.backgroundColor = .clear

            return cell
        }
    }
}

// MARK: - UITableViewDelegate
extension ReferralAnalyticsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if tableView == topCodesTableView {
            return "Top Performing Codes"
        } else {
            return "Recent Referrals"
        }
    }
}