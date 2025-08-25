import UIKit
import RevenueCat

final class SubscriptionStatusViewController: NNViewController {
    
    // MARK: - Properties
    private let topImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .rectanglePatternSmall, with: NNColors.primary)
        view.alpha = 0.4
        return view
    }()
    
    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "You're Subscribed!"
        label.font = .h1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Thank you for subscribing to NestNote Pro. Your support helps us continue improving the app."
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subscriptionInfoStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.distribution = .fill
        return stack
    }()
    
    private let productLabel: UILabel = {
        let label = UILabel()
        label.font = .h4
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let expirationLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var doneButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Done")
        button.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        loadSubscriptionInfo()
    }
    
    // MARK: - Setup
    private func setupView() {
        view.backgroundColor = .systemBackground
        
        // Setup scroll view
        view.addSubview(topImageView)
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(subscriptionInfoStackView)
        
        // Add subscription info to stack view
        subscriptionInfoStackView.addArrangedSubview(createInfoCard())
        
        // Pin the Done button to the bottom
        doneButton.pinToBottom(of: view, addBlurEffect: true)
        topImageView.pinToTop(of: view)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topImageView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: doneButton.topAnchor),
            
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            subscriptionInfoStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            subscriptionInfoStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            subscriptionInfoStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            subscriptionInfoStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }
    
    private func createInfoCard() -> UIView {
        let cardView = UIView()
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = NNColors.NNSystemBackground6
        cardView.layer.cornerRadius = 12
        cardView.layer.cornerCurve = .continuous
        
        let appIconImageView = UIImageView()
        appIconImageView.translatesAutoresizingMaskIntoConstraints = false
        appIconImageView.image = UIImage(named: "icon_pattern-preview")
        appIconImageView.contentMode = .scaleAspectFit
        appIconImageView.layer.cornerRadius = 6
        appIconImageView.layer.cornerCurve = .continuous
        appIconImageView.clipsToBounds = true
        
        let checkmarkImageView = UIImageView()
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill")?
            .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
        checkmarkImageView.contentMode = .scaleAspectFit
        
        let labelStackView = UIStackView()
        labelStackView.translatesAutoresizingMaskIntoConstraints = false
        labelStackView.axis = .vertical
        labelStackView.spacing = 4
        labelStackView.alignment = .leading
        
        labelStackView.addArrangedSubview(productLabel)
        labelStackView.addArrangedSubview(expirationLabel)
        
        cardView.addSubview(appIconImageView)
        cardView.addSubview(labelStackView)
        cardView.addSubview(checkmarkImageView)
        
        NSLayoutConstraint.activate([
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            appIconImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            appIconImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            appIconImageView.widthAnchor.constraint(equalToConstant: 40),
            appIconImageView.heightAnchor.constraint(equalToConstant: 40),
            
            labelStackView.leadingAnchor.constraint(equalTo: appIconImageView.trailingAnchor, constant: 12),
            labelStackView.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -12),
            labelStackView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            
            checkmarkImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            checkmarkImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return cardView
    }
    
    private func loadSubscriptionInfo() {
        Task {
            let customerInfo = await SubscriptionService.shared.getCustomerInfo()
            await MainActor.run {
                updateSubscriptionInfo(with: customerInfo)
            }
        }
    }
    
    private func updateSubscriptionInfo(with customerInfo: CustomerInfo?) {
        guard let customerInfo = customerInfo else {
            productLabel.text = "NestNote Pro"
            expirationLabel.text = "Status: Active"
            return
        }
        
        // Get active subscription info
        if let activeSubscription = customerInfo.activeSubscriptions.first {
            let productId = activeSubscription
            
            // Format product name
            let productName = formatProductName(productId)
            productLabel.text = productName
            
            // Get expiration date
            if let expirationDate = customerInfo.expirationDate(forProductIdentifier: productId) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                
                if expirationDate.timeIntervalSinceNow > 0 {
                    expirationLabel.text = "Expires: \(formatter.string(from: expirationDate))"
                } else {
                    expirationLabel.text = "Status: Expired"
                }
            } else {
                expirationLabel.text = "Status: Active"
            }
        } else {
            productLabel.text = "NestNote Pro"
            expirationLabel.text = "Status: Active"
        }
    }
    
    private func formatProductName(_ productId: String) -> String {
        // Convert product ID to user-friendly name
        if productId.contains("monthly") {
            return "NestNote Pro (Monthly)"
        } else if productId.contains("annual") || productId.contains("yearly") {
            return "NestNote Pro (Annual)"
        } else {
            return "NestNote Pro"
        }
    }
    
    // MARK: - Actions
    @objc private func doneTapped() {
        dismiss(animated: true)
    }
}
