import UIKit

class SessionCell: UICollectionViewListCell {
    static let reuseIdentifier = "SessionCell"
    
    private lazy var emptyStateStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private lazy var emptyStateIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .secondaryLabel
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        
        // Setup empty state stack
        emptyStateStack.addArrangedSubview(emptyStateLabel)
        emptyStateStack.addArrangedSubview(emptyStateIcon)
        contentView.addSubview(emptyStateStack)
        
        NSLayoutConstraint.activate([
            emptyStateStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            emptyStateStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            emptyStateStack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 16),
            emptyStateStack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            emptyStateIcon.widthAnchor.constraint(equalToConstant: 12),
            emptyStateIcon.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    func configureEmptyState(for section: NestSessionsViewController.Section) {
        var bgConfig = UIBackgroundConfiguration.listCell()
        bgConfig.backgroundColor = .clear
        backgroundConfiguration = bgConfig
        
        // Hide default content configuration
        contentConfiguration = nil
        accessories = []
        
        // Configure empty state based on section
        let (message, iconName) = emptyStateConfig(for: section)
        emptyStateLabel.text = message
        emptyStateIcon.image = UIImage(systemName: iconName)?
            .withConfiguration(UIImage.SymbolConfiguration(weight: .medium))
        
        // Show empty state stack
        emptyStateStack.isHidden = false
        contentView.backgroundColor = .systemGroupedBackground
    }
    
//    override func updateConfiguration(using state: UICellConfigurationState) {
//        super.updateConfiguration(using: state)
//        
//        // Update background configuration for current state
//        var newBgConfig = backgroundConfiguration
//        newBgConfig?.backgroundColor = state.isSelected ? .systemGray4 : .secondarySystemGroupedBackground
//        backgroundConfiguration = newBgConfig
//    }
    
    private func emptyStateConfig(for section: NestSessionsViewController.Section) -> (message: String, iconName: String) {
        switch section {
        case .inProgress:
            return ("No in-progress sessions", "person.badge.clock")
        case .upcoming:
            return ("No upcoming sessions", "calendar.and.person")
        case .past:
            return ("No past sessions", "clock.arrow.2.circlepath")
        }
    }
    
    func configure(with session: SessionItem) {
        // Hide empty state stack
        emptyStateStack.isHidden = true
        
        // Configure background
        var bgConfig = UIBackgroundConfiguration.listCell()
        bgConfig.backgroundColor = .secondarySystemGroupedBackground
        
        // Set up content configuration
        var content = UIListContentConfiguration.cell()
        
        // Configure text style
        content.text = session.title
        content.textProperties.font = .systemFont(ofSize: 16, weight: .medium)
        
        // Configure date display
        let dateFormatter = DateFormatter()
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        
        let dateString: String
        if session.isMultiDay {
            // For multi-day sessions, show date range without times
            dateFormatter.dateFormat = "MMM d"
            let startString = dateFormatter.string(from: session.startDate)
            let endString = dateFormatter.string(from: session.endDate)
            dateString = "\(startString) - \(endString)"
        } else {
            // For single day sessions, show date with start time
            dateFormatter.dateFormat = "MMM d"
            let dayString = dateFormatter.string(from: session.startDate)
            let timeString = timeFormatter.string(from: session.startDate)
            dateString = "\(dayString), \(timeString)"
        }
        
        content.secondaryText = dateString
        content.secondaryTextProperties.font = .systemFont(ofSize: 14)
        content.secondaryTextProperties.color = .secondaryLabel
        
        // Apply standard system margins
        content.directionalLayoutMargins = .init(top: 12, leading: 16, bottom: 12, trailing: 16)
        
        
        backgroundConfiguration = bgConfig
        contentConfiguration = content
        accessories = [.disclosureIndicator()]
    }
    
    override var isSelected: Bool {
        didSet {
            // Force refresh of background configuration when selection state changes
            var newBgConfig = backgroundConfiguration
            newBgConfig?.backgroundColor = isSelected ? .systemGray4 : .secondarySystemGroupedBackground
            backgroundConfiguration = newBgConfig
        }
    }
}


