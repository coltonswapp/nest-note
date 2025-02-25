import UIKit

final class CurrentSessionCell: UICollectionViewListCell {
    
    // MARK: - UI Elements
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.textColor = NNColors.primaryLighter
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let birdImageView: UIImageView = {    
        let imageView = UIImageView()
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        imageView.image = UIImage(systemName: "bird", withConfiguration: imageConfig)
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
            
            // Bird image constraints
            birdImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            birdImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            birdImageView.widthAnchor.constraint(equalToConstant: 35),
            birdImageView.heightAnchor.constraint(equalToConstant: 35)
        ])
    }
    
    func configure(title: String, duration: String) {
        titleLabel.text = title
        durationLabel.text = duration
    }
} 
