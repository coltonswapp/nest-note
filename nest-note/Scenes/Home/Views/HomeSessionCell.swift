import UIKit

/// Represents the type of session being displayed
enum HomeSessionType {
    case sitterActive    // Sitter's currently active session
    case ownerUpcoming   // Owner's next upcoming session
    case ownerInProgress // Owner's session currently in progress
    
    var backgroundColor: UIColor {
        switch self {
        case .sitterActive, .ownerInProgress:
            return NNColors.primaryAlt
        case .ownerUpcoming:
            return .secondarySystemGroupedBackground
        }
    }
    
    var titleColor: UIColor {
        switch self {
        case .sitterActive, .ownerInProgress:
            return .white
        case .ownerUpcoming:
            return .label
        }
    }
    
    var subtitleColor: UIColor {
        switch self {
        case .sitterActive, .ownerInProgress:
            return NNColors.primaryLighter
        case .ownerUpcoming:
            return .secondaryLabel
        }
    }
    
    var iconName: String {
        switch self {
        case .sitterActive:
            return "bird"
        case .ownerUpcoming:
            return "calendar"
        case .ownerInProgress:
            return "clock.fill"
        }
    }
}

final class HomeSessionCell: UICollectionViewListCell {
    
    // MARK: - Properties
    private var sessionType: HomeSessionType = .sitterActive
    
    // MARK: - UI Elements
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let rightStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .trailing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Add labels to left stack
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        
        // Add status views to right stack
        let statusStack = UIStackView()
        statusStack.axis = .horizontal
        statusStack.spacing = 4
        statusStack.alignment = .center
        
        statusStack.addArrangedSubview(statusLabel)
        statusStack.addArrangedSubview(statusImageView)
        
        rightStackView.addArrangedSubview(statusStack)
        rightStackView.addArrangedSubview(dateLabel)
        
        // Add stacks to content view
        contentView.addSubview(stackView)
        contentView.addSubview(rightStackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: rightStackView.leadingAnchor, constant: -12),
            
            rightStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rightStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            statusImageView.widthAnchor.constraint(equalToConstant: 16),
            statusImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        // Set background color
        backgroundColor = .secondarySystemGroupedBackground
        
        // Set corner radius
        layer.cornerRadius = 10
        layer.masksToBounds = true
    }
    
    func configure(with session: SessionItem, isCurrentSession: Bool) {
        // Configure title and subtitle
        titleLabel.text = session.title
        
        if let sitter = session.assignedSitter {
            subtitleLabel.text = sitter.name
        } else {
            subtitleLabel.text = "No sitter assigned"
        }
        
        // Configure status
        let status = session.status
        statusLabel.text = status.displayName
        
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        statusImageView.image = UIImage(systemName: status.icon, withConfiguration: symbolConfig)
        
        // Set status colors based on session status
        switch status {
        case .upcoming:
            statusLabel.textColor = .secondaryLabel
            statusImageView.tintColor = .secondaryLabel
        case .inProgress:
            statusLabel.textColor = NNColors.primary
            statusImageView.tintColor = NNColors.primary
        case .extended:
            statusLabel.textColor = .systemOrange
            statusImageView.tintColor = .systemOrange
        case .completed:
            statusLabel.textColor = .systemGreen
            statusImageView.tintColor = .systemGreen
        }
        
        // Configure date display
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, MMM d"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        
        if isCurrentSession {
            // For current session, show end time
            dateLabel.text = "Ends " + timeFormatter.string(from: session.endDate)
        } else {
            // For upcoming sessions, show start date and time
            dateLabel.text = "\(dateFormatter.string(from: session.startDate))\n\(timeFormatter.string(from: session.startDate))"
            dateLabel.numberOfLines = 2
        }
        
        // Add accessories
        accessories = [.disclosureIndicator()]
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        titleLabel.text = nil
        subtitleLabel.text = nil
        statusLabel.text = nil
        statusImageView.image = nil
        dateLabel.text = nil
        dateLabel.numberOfLines = 1
        accessories = []
    }
} 