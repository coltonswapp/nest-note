import UIKit

final class SetupStepCell: UITableViewCell {
    
    // MARK: - UI Elements
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        imageView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        imageView.tintColor = .systemGreen
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        return imageView
    }()
    
    private let disclosureImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        imageView.image = UIImage(systemName: "chevron.right", withConfiguration: config)
        imageView.tintColor = .tertiaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let labelStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .secondarySystemGroupedBackground
        selectionStyle = .default
        
        contentView.addSubview(labelStack)
        contentView.addSubview(checkmarkImageView)
        contentView.addSubview(disclosureImageView)
        
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            labelStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            labelStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labelStack.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -12),
            
            checkmarkImageView.trailingAnchor.constraint(equalTo: disclosureImageView.leadingAnchor, constant: -12),
            checkmarkImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 22),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 22),
            
            disclosureImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            disclosureImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            disclosureImageView.widthAnchor.constraint(equalToConstant: 18),
            disclosureImageView.heightAnchor.constraint(equalToConstant: 18)
        ])
        
        // Add rounded corners
        layer.cornerRadius = 12
        layer.masksToBounds = true
    }
    
    func configure(with title: String, subtitle: String, isCompleted: Bool) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        
        checkmarkImageView.isHidden = !isCompleted
        
        // If completed, make the text gray to show it's done
        if isCompleted {
            titleLabel.textColor = .secondaryLabel
            disclosureImageView.isHidden = true
        } else {
            titleLabel.textColor = .label
            disclosureImageView.isHidden = false
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        checkmarkImageView.isHidden = true
        disclosureImageView.isHidden = false
        titleLabel.textColor = .label
    }
} 