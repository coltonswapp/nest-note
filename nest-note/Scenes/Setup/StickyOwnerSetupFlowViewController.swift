import UIKit
import UserNotifications
import RevenueCat
import RevenueCatUI

final class StickyOwnerSetupFlowViewController: NNViewController, PaywallPresentable, PaywallViewControllerDelegate {
    
    // MARK: - Properties
    weak var delegate: SetupFlowDelegate?
    
    private let setupService = SetupService.shared
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    // Use the steps from the SetupStepType enum
    private var setupSteps: [SetupStepType] {
        return SetupStepType.allCases
    }
    
    // Store observation tokens
    private var entryObserver: NSObjectProtocol?
    
    private let topImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(imageView, for: .rectanglePatternSmall, with: NNColors.primary)
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h1
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var finishButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Finish")
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(finishButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        view.backgroundColor = .systemGroupedBackground
        
        titleLabel.text = "Finish Setting Up"
        descriptionLabel.text = "Set yourself (& your sitters) up for success by finishing your Nest setup & getting to know NestNote."
        
        // Check and refresh step completion status from app state
        setupService.refreshStepCompletionStatus()
        
        // Add observer for setup step completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setupStepDidComplete(_:)),
            name: .setupStepDidComplete,
            object: nil
        )
    }
    
    deinit {
        // Remove observers if they exist
        if let entryObserver = entryObserver {
            NotificationCenter.default.removeObserver(entryObserver)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh UI in case anything changed while away
        setupService.refreshStepCompletionStatus()
        tableView.reloadData()
        updateFinishButtonState()
    }
    
    override func addSubviews() {
        view.addSubview(topImageView)
        topImageView.pinToTop(of: view)

        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(tableView)
        view.addSubview(finishButton)
    }
    
    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        
        // Add tableView constraints manually
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        finishButton.pinToBottom(of: view, addBlurEffect: true, blurMaskImage: UIImage(named: "testBG3"))
    }
    
    private func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "StepCell")
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = true
        tableView.allowsSelection = true
        
        // Add content insets for smaller devices
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
    }
    
    private func updateFinishButtonState() {
        // Enable the finish button if all steps are complete
        let allStepsComplete = setupSteps.allSatisfy { setupService.isStepComplete($0) }
        finishButton.isEnabled = allStepsComplete
        finishButton.alpha = allStepsComplete ? 1.0 : 0.6
    }
    
    // MARK: - Actions
    @objc private func finishButtonTapped() {
        // Mark as complete and dismiss
        delegate?.setupFlowDidComplete()
        dismiss(animated: true)
    }
    
    @objc private func setupStepDidComplete(_ notification: Notification) {
        // Reload the table view to show updated checkmarks
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
            self?.updateFinishButtonState()
        }
    }
    
    // Handle tapping on a step
    private func didSelectStep(_ step: SetupStepType) {
        // Navigate to the appropriate view controller based on the step
        switch step {
        case .createAccount:
            // Account creation is already done, nothing to do
            break
            
        case .setupNest:
            // Navigate to nest setup if needed
            presentNestSetup()
            
        case .addFirstEntry:
            // Navigate to create an entry
            presentAddFirstEntry()
            
        case .exploreVisibilityLevels:
            // Navigate to explore visibility levels
            presentExploreVisibility()
            
        case .enableNotifications:
            // Request notification permissions
            requestNotifications()
            
        case .feedback:
            presentHowToFeedback()
            
        case .finalStep:
            // Navigate to final step
            presentFinalStep()
        }
    }
    
    // Placeholder navigation methods - implement these based on your app's architecture
    private func presentNestSetup() {
        // Example implementation
        // let nestSetupVC = NestSetupViewController()
        // navigationController?.pushViewController(nestSetupVC, animated: true)
    }
    
    private func presentAddFirstEntry() {
        // Create a NestCategoryViewController for the Household category
        let nestCategoryVC = NestCategoryViewController(
            category: "Household",
            entryRepository: NestService.shared,
            sessionVisibilityLevel: .comprehensive
        )
        
        // Wrap in a navigation controller for proper presentation
        let navController = UINavigationController(rootViewController: nestCategoryVC)
        
        // Present the view controller
        present(navController, animated: true)
        
        // Add observer to mark step as complete when an entry is saved
        entryObserver = NotificationCenter.default.addObserver(
            forName: .entryDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setupService.markStepComplete(.addFirstEntry)
            self?.delegate?.setupFlowDidUpdateStepStatus()
            
            // Remove the observer after the step is completed
            if let entryObserver = self?.entryObserver {
                NotificationCenter.default.removeObserver(entryObserver)
                self?.entryObserver = nil
            }
        }
    }
    
    private func presentExploreVisibility() {
        // Example implementation
        let view = VisibilityLevelInfoViewController()
        present(view, animated: true, completion: { 
            self.setupService.markStepComplete(.exploreVisibilityLevels)
        })
    }
    
    private func presentHowToFeedback() {
        let view = FeedbackHowToViewController()
        present(view, animated: true)
    }
    
    private func presentFinalStep() {
        // Show the paywall for the final step
        showUpgradeFlow()
    }
    
    // MARK: - PaywallPresentable
    var proFeature: ProFeature {
        return .unlimitedEntries // or whichever feature represents the "Pro" upgrade
    }
    
    // MARK: - PaywallViewControllerDelegate
    func paywallViewControllerDidComplete(_ controller: PaywallViewController) {
        // Mark final step as complete when paywall is dismissed (regardless of purchase)
        setupService.markStepComplete(.finalStep)
        delegate?.setupFlowDidUpdateStepStatus()
        
        // Reload UI
        tableView.reloadData()
        updateFinishButtonState()
        
        controller.dismiss(animated: true)
    }
    
    func paywallViewControllerDidCancel(_ controller: PaywallViewController) {
        // Still mark as complete - the user has seen the paywall
        setupService.markStepComplete(.finalStep)
        delegate?.setupFlowDidUpdateStepStatus()
        
        // Reload UI
        tableView.reloadData()
        updateFinishButtonState()
        
        controller.dismiss(animated: true)
    }
    
    // Request notification permissions
    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    // Mark step as complete if permissions granted
                    self.setupService.markStepComplete(.enableNotifications)
                    self.tableView.reloadData()
                    self.updateFinishButtonState()
                    
                    // Notify delegate
                    self.delegate?.setupFlowDidUpdateStepStatus()
                    
                    // Show success message
                    let alert = UIAlertController(
                        title: "Notifications Enabled",
                        message: "You'll now receive notifications for important events in your Nest.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "Great!", style: .default))
                    self.present(alert, animated: true)
                } else {
                    // Show instructions for enabling manually
                    let alert = UIAlertController(
                        title: "Notifications Disabled",
                        message: "To enable notifications, go to Settings > Notifications > NestNote and turn on Allow Notifications.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    })
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension StickyOwnerSetupFlowViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return setupSteps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StepCell", for: indexPath)
        let step = setupSteps[indexPath.row]
        
        // Clear any existing accessory view first to avoid reuse issues
        cell.accessoryView = nil
        cell.accessoryType = .none
        
        // Configure cell
        var content = cell.defaultContentConfiguration()
        content.text = step.title
        content.textProperties.font = .h4
        
        content.secondaryText = step.subtitle
        content.secondaryTextProperties.font = .bodyM
        content.secondaryTextProperties.color = .secondaryLabel
        
        // Add some padding
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        cell.contentConfiguration = content
        
        // Always check completion status directly from the service, never rely on cell state
        let isCompleted = setupService.isStepComplete(step)
        
        // Configure accessory view based on completion status
        if isCompleted {
            let checkmarkImage = UIImage(systemName: "checkmark.circle.fill")
            let checkmarkView = UIImageView(image: checkmarkImage)
            checkmarkView.tintColor = NNColors.primary
            cell.accessoryView = checkmarkView
            
            // Gray out completed steps
            content.textProperties.color = .secondaryLabel
            cell.contentConfiguration = content
        } else {
            cell.accessoryType = .disclosureIndicator
            
            // Reset text color for non-completed steps
            content.textProperties.color = .label
            cell.contentConfiguration = content
        }
        
        // Style cell
        cell.backgroundColor = .secondarySystemGroupedBackground
        cell.layer.cornerRadius = 12
        cell.layer.masksToBounds = true
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Get the selected step
        let step = setupSteps[indexPath.row]
        
        // Navigate to the selected step
        didSelectStep(step)
    }
    
    #if DEBUG
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let step = setupSteps[indexPath.row]
        let isCompleted = setupService.isStepComplete(step)
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let markCompleteAction = UIAction(
                title: "Mark as Complete",
                image: UIImage(systemName: "checkmark.circle"),
                state: isCompleted ? .on : .off
            ) { [weak self] _ in
                self?.setupService.markStepComplete(step)
                self?.tableView.reloadData()
                self?.updateFinishButtonState()
            }
            
            let markIncompleteAction = UIAction(
                title: "Mark as Incomplete",
                image: UIImage(systemName: "xmark.circle"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.setupService.markStepIncomplete(step)
                self?.tableView.reloadData()
                self?.updateFinishButtonState()
            }
            
            let debugMenu = UIMenu(title: "Debug: \(step.title)", children: [
                markCompleteAction,
                markIncompleteAction
            ])
            
            return debugMenu
        }
    }
    #endif
}

// MARK: - Setup Step Model
struct SetupStep {
    let title: String
    let subtitle: String
    let isCompleted: Bool
} 
