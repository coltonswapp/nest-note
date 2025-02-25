import UIKit

final class PlaceListCell: UICollectionViewCell {
    static let reuseIdentifier = "PlaceListCell"
    
    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 6
        imageView.backgroundColor = .secondarySystemBackground
        return imageView
    }()
    
    private let labelStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }()
    
    private let aliasLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        return label
    }()
    
    private let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.backgroundColor = .systemBackground
        
        labelStack.addArrangedSubview(aliasLabel)
        labelStack.addArrangedSubview(addressLabel)
        
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(labelStack)
        
        NSLayoutConstraint.activate([
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            thumbnailImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 75),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 75),
            
            labelStack.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            labelStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            labelStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4)
        ])
    }
    
    func configure(with place: Place) {
        aliasLabel.text = place.alias
        addressLabel.text = place.address
        
        Task {
            do {
                let image = try await PlacesService.shared.loadImages(for: place)
                if aliasLabel.text == place.alias {  // Ensure cell hasn't been reused
                    thumbnailImageView.image = image
                }
            } catch {
                thumbnailImageView.image = UIImage(systemName: "photo.fill")
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        aliasLabel.text = nil
        addressLabel.text = nil
    }
} 
