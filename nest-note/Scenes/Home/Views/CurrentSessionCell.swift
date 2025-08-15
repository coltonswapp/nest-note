import UIKit

final class CurrentSessionCell: UICollectionViewListCell {
    
    // MARK: - UI Elements
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .h4
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.textColor = NNColors.primaryLighter
        label.font = .bodyM
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let birdImageView: UIImageView = {    
        let imageView = UIImageView()
        imageView.image = NNImage.primaryLogo
        imageView.tintColor = NNColors.primaryLighter
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
        labelStack.addArrangedSubview(durationLabel)
        contentView.addSubview(labelStack)
        contentView.addSubview(birdImageView)
        
        NSLayoutConstraint.activate([
            // Label stack constraints
            labelStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            labelStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labelStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            labelStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            // Bird image constraints
            birdImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            birdImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            birdImageView.widthAnchor.constraint(equalToConstant: 35),
            birdImageView.heightAnchor.constraint(equalToConstant: 35)
        ])
    }
    
    private func configureSelectionBehavior() {
        // Create a view for the selected state
        let selectedBgView = UIView()
        selectedBgView.backgroundColor = NNColors.primary.darker()  // Darker version of primary color
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
    
    func configure(title: String, duration: String) {
        titleLabel.text = title
        durationLabel.text = duration
    }
    
    func configureForEarlyAccess(title: String, sessionStartTime: String) {
        titleLabel.text = title
        durationLabel.text = "Session starts \(sessionStartTime)"
    }
} 
