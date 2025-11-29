import UIKit

final class MiniPlaceReviewView: UIView {
    private let container = UIView()
    let thumbnailImageView = UIImageView()
    private let aliasLabel = UILabel()
    private let addressLabel = UILabel()
    private let timestampLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 4, height: 8)
        layer.shadowRadius = 8
        
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 12
        
        aliasLabel.translatesAutoresizingMaskIntoConstraints = false
        aliasLabel.font = .h3
        aliasLabel.textColor = .label
        
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        addressLabel.font = .bodyM
        addressLabel.textColor = .secondaryLabel
        addressLabel.numberOfLines = 2
        
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.font = .bodyL
        timestampLabel.textColor = .secondaryLabel
        
        [thumbnailImageView, aliasLabel, addressLabel, timestampLabel].forEach { container.addSubview($0) }
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            
            thumbnailImageView.topAnchor.constraint(equalTo: container.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            thumbnailImageView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.55),
            
            aliasLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 12),
            aliasLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            aliasLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            addressLabel.topAnchor.constraint(equalTo: aliasLabel.bottomAnchor, constant: 4),
            addressLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            addressLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            timestampLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            timestampLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            timestampLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
    
    func configure(with place: PlaceItem) {
        aliasLabel.text = place.alias ?? place.title
        addressLabel.text = place.address
        timestampLabel.text = "Last modified: \(place.updatedAt.formatted(date: .abbreviated, time: .omitted))"
        
        Task {
            do {
                let image: UIImage
                if let img = try? await NestService.shared.loadImages(for: place) {
                    image = img
                } else {
                    image = UIImage(systemName: "mappin.circle") ?? UIImage()
                }
                await MainActor.run { self.thumbnailImageView.image = image }
            }
        }
    }
}
