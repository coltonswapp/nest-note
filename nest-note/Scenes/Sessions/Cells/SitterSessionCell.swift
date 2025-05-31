import UIKit

class SitterSessionCell: UICollectionViewListCell {
    static let reuseIdentifier = "SitterSessionCell"
    
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
        label.font = .bodyS
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
        var bgConfig = UIBackgroundConfiguration.listCell()
        bgConfig.backgroundColor = .secondarySystemGroupedBackground
        backgroundConfiguration = bgConfig
        
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
    
    func configureEmptyState(for section: SitterSessionsViewController.Section) {
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
        contentView.backgroundColor = nil
    }
    
    private func emptyStateConfig(for section: SitterSessionsViewController.Section) -> (message: String, iconName: String) {
        switch section {
        case .inProgress:
            return ("No in-progress sessions", "person.badge.clock")
        case .upcoming:
            return ("No upcoming sessions", "calendar.and.person")
        case .past:
            return (
                "No past sessions",
                "calendar.badge.checkmark"
            )
        }
    }
    
    func configure(with session: SessionItem, nestName: String) {
        // Hide empty state stack
        emptyStateStack.isHidden = true
        
        var content = defaultContentConfiguration()
        
        // Configure text style
        content.text = session.title
        content.textProperties.font = .bodyL
        
        // Configure date and nest name display
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
        
        // Add nest name to secondary text
        content.secondaryText = "\(nestName) • \(dateString)"
        content.secondaryTextProperties.font = .bodyM
        content.secondaryTextProperties.color = .secondaryLabel
        
        // Apply standard system margins
        content.directionalLayoutMargins = .init(top: 12, leading: 16, bottom: 12, trailing: 16)
        
        contentConfiguration = content
        accessories = [.disclosureIndicator()]
    }
    
    /// Configures the cell to display an archived sitter session
    /// - Parameters:
    ///   - title: The title to display
    ///   - date: The date to display (usually the date when the session occurred)
    ///   - isArchived: Whether this is an archived session (adds visual indicators)
    func configureArchived(title: String, date: Date, isArchived: Bool = true) {
        // Hide empty state stack
        emptyStateStack.isHidden = true
        
        var content = defaultContentConfiguration()
        
        // Configure text style
        content.text = title
        content.textProperties.font = .bodyL
        
        // Format date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let dateString = dateFormatter.string(from: date)
        
        // Add archived indicator to secondary text
        content.secondaryText = isArchived ? "Completed • \(dateString)" : dateString
        content.secondaryTextProperties.font = .bodyM
        content.secondaryTextProperties.color = .secondaryLabel
        
        // Apply standard system margins
        content.directionalLayoutMargins = .init(top: 12, leading: 16, bottom: 12, trailing: 16)
        
        // Add a faded appearance for archived items
        var bgConfig = backgroundConfiguration ?? UIBackgroundConfiguration.listCell()
        bgConfig.backgroundColor = isArchived ? 
            .secondarySystemGroupedBackground.withAlphaComponent(0.8) : 
            .secondarySystemGroupedBackground
        backgroundConfiguration = bgConfig
        
        contentConfiguration = content
        accessories = [.disclosureIndicator()]
    }
} 
