import UIKit

final class SetupProgressCell: UICollectionViewListCell {
    
    // MARK: - UI Elements
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .h4
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.text = "Get to know NestNote"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let progressLabel: UILabel = {
        let label = UILabel()
        label.textColor = NNColors.primaryLighter
        label.font = .h3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let labelStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
        configureSelectionBehavior()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        
        // Add subviews
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(subtitleLabel)
        contentView.addSubview(labelStack)
        contentView.addSubview(progressLabel)
        
        NSLayoutConstraint.activate([
            // Label stack constraints
            labelStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            labelStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labelStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            labelStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            progressLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            progressLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
//            progressLabel.widthAnchor.constraint(equalToConstant: 35),
//            progressLabel.heightAnchor.constraint(equalToConstant: 35),
        ])
    }
    
    private func configureSelectionBehavior() {
        // Create a view for the selected state
        let selectedBgView = UIView()
        selectedBgView.backgroundColor = NNColors.EventColors.blue.border
        selectedBgView.layer.cornerRadius = 12
        selectedBgView.layer.masksToBounds = true
        
        // Set the selected background view
        selectedBackgroundView = selectedBgView
        
        // Enable user interaction
        isUserInteractionEnabled = true
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        selectedBackgroundView?.layer.cornerRadius = 12
    }
    
    func configure(title: String, current: Int, total: Int) {
        titleLabel.text = title
        progressLabel.text = "\(current)/\(total)"
        subtitleLabel.text = "Get to know NestNote"
    }
} 
