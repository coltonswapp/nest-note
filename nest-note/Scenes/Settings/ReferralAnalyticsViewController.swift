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
        label.text = "Referral Analytics"
        label.font = .h1
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let totalReferralsCard: UIView = {
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
    
    private let totalReferralsLabel: UILabel = {
        let label = UILabel()
        label.text = "Total Referrals"
        label.font = .bodyL
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let totalReferralsCountLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
    
    private let thisMonthLabel: UILabel = {
        let label = UILabel()
        label.text = "This Month"
        label.font = .bodyL
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let thisMonthCountLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = .systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let referralCodeLabel: UILabel = {
        let label = UILabel()
        label.text = "Your Referral Code"
        label.font = .bodyL
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let referralCodeValueLabel: UILabel = {
        let label = UILabel()
        label.text = "Contact admin for your referral code"
        label.font = .bodyL
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let copyCodeButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Copy Code")
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true  // Hidden until we have a valid code
        return button
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private var userReferralCode: String?
    
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
        
        // Setup total referrals card
        totalReferralsCard.addSubview(totalReferralsLabel)
        totalReferralsCard.addSubview(totalReferralsCountLabel)
        
        // Setup this month card
        thisMonthCard.addSubview(thisMonthLabel)
        thisMonthCard.addSubview(thisMonthCountLabel)
        
        // Add components to stack
        contentStackView.addArrangedSubview(titleLabel)
        
        let cardsStackView = UIStackView(arrangedSubviews: [totalReferralsCard, thisMonthCard])
        cardsStackView.axis = .horizontal
        cardsStackView.spacing = 16
        cardsStackView.distribution = .fillEqually
        contentStackView.addArrangedSubview(cardsStackView)
        
        contentStackView.addArrangedSubview(referralCodeLabel)
        contentStackView.addArrangedSubview(referralCodeValueLabel)
        contentStackView.addArrangedSubview(copyCodeButton)
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
            
            // Card heights
            totalReferralsCard.heightAnchor.constraint(equalToConstant: 120),
            thisMonthCard.heightAnchor.constraint(equalToConstant: 120),
            
            // Total referrals card content
            totalReferralsLabel.topAnchor.constraint(equalTo: totalReferralsCard.topAnchor, constant: 16),
            totalReferralsLabel.leadingAnchor.constraint(equalTo: totalReferralsCard.leadingAnchor, constant: 16),
            totalReferralsLabel.trailingAnchor.constraint(equalTo: totalReferralsCard.trailingAnchor, constant: -16),
            
            totalReferralsCountLabel.topAnchor.constraint(equalTo: totalReferralsLabel.bottomAnchor, constant: 8),
            totalReferralsCountLabel.leadingAnchor.constraint(equalTo: totalReferralsCard.leadingAnchor, constant: 16),
            totalReferralsCountLabel.trailingAnchor.constraint(equalTo: totalReferralsCard.trailingAnchor, constant: -16),
            
            // This month card content
            thisMonthLabel.topAnchor.constraint(equalTo: thisMonthCard.topAnchor, constant: 16),
            thisMonthLabel.leadingAnchor.constraint(equalTo: thisMonthCard.leadingAnchor, constant: 16),
            thisMonthLabel.trailingAnchor.constraint(equalTo: thisMonthCard.trailingAnchor, constant: -16),
            
            thisMonthCountLabel.topAnchor.constraint(equalTo: thisMonthLabel.bottomAnchor, constant: 8),
            thisMonthCountLabel.leadingAnchor.constraint(equalTo: thisMonthCard.leadingAnchor, constant: 16),
            thisMonthCountLabel.trailingAnchor.constraint(equalTo: thisMonthCard.trailingAnchor, constant: -16),
            
            // Copy button
            copyCodeButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupActions() {
        copyCodeButton.addTarget(self, action: #selector(copyCodeTapped), for: .touchUpInside)
    }
    
    // MARK: - Data Loading
    private func loadReferralData() {
        // Check if user has been assigned a referral code
        checkForAssignedReferralCode()
    }
    
    private func checkForAssignedReferralCode() {
        guard let currentUser = UserService.shared.currentUser else {
            referralCodeValueLabel.text = "ERROR: No User"
            loadingIndicator.stopAnimating()
            loadingIndicator.isHidden = true
            return
        }
        
        Task {
            do {
                // Check all referral codes to see if any are assigned to this user's email
                let allCodes = try await ReferralService.shared.getAllReferralCodes()
                let assignedCode = allCodes.first { codeInfo in
                    codeInfo.creatorEmail.lowercased() == currentUser.personalInfo.email.lowercased() && codeInfo.isActive
                }
                
                await MainActor.run {
                    if let assignedCode = assignedCode {
                        // User has a referral code assigned
                        self.userReferralCode = assignedCode.code
                        self.referralCodeValueLabel.text = assignedCode.code
                        self.referralCodeValueLabel.font = .systemFont(ofSize: 20, weight: .semibold)
                        self.referralCodeValueLabel.textColor = .label
                        self.copyCodeButton.isHidden = false
                        
                        // Load stats for this code
                        self.loadReferralStats(for: assignedCode.code)
                    } else {
                        // No code assigned
                        self.referralCodeValueLabel.text = "Contact admin for your referral code"
                        self.loadingIndicator.stopAnimating()
                        self.loadingIndicator.isHidden = true
                    }
                }
            } catch {
                await MainActor.run {
                    Logger.log(level: .error, category: .referral, message: "Failed to check for assigned referral code: \(error)")
                    self.referralCodeValueLabel.text = "Error loading referral code"
                    self.loadingIndicator.stopAnimating()
                    self.loadingIndicator.isHidden = true
                }
            }
        }
    }
    
    private func loadReferralStats(for referralCode: String) {
        Task {
            do {
                // Load referral summary
                let summary = try await ReferralService.shared.getReferralSummary(for: referralCode)
                let currentMonth = currentMonthKey()
                let thisMonthCount = summary?.monthlyReferrals[currentMonth] ?? 0
                
                await MainActor.run {
                    self.totalReferralsCountLabel.text = "\(summary?.totalReferrals ?? 0)"
                    self.thisMonthCountLabel.text = "\(thisMonthCount)"
                    self.loadingIndicator.stopAnimating()
                    self.loadingIndicator.isHidden = true
                }
            } catch {
                await MainActor.run {
                    Logger.log(level: .error, category: .referral, message: "Failed to load referral stats: \(error)")
                    self.loadingIndicator.stopAnimating()
                    self.loadingIndicator.isHidden = true
                    // Show error state or default to 0
                }
            }
        }
    }
    
    private func currentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    // MARK: - Actions
    @objc private func copyCodeTapped() {
        guard let referralCode = userReferralCode else { return }
        
        UIPasteboard.general.string = referralCode
        
        // Show success feedback
        let alert = UIAlertController(title: "Copied!", message: "Your referral code has been copied to the clipboard.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        
        // Track analytics
        Tracker.shared.track(.referralCodeEntered)
    }
}