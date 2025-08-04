import UIKit

protocol PlaceAddressCellDelegate: AnyObject {
    func placeAddressCell(didTapThumbnail viewController: ImageViewerController)
    func placeAddressCellAddressTapped(_ view: UIView, place: PlaceItem?)
}

final class PlaceAddressCell: UICollectionViewListCell {
    enum AddressOption {
        case openInMaps
        case openInGoogleMaps
        case copyAddress
    }
    
    weak var delegate: PlaceAddressCellDelegate?
    
    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.isUserInteractionEnabled = true
        return imageView
    }()
    
    let addressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .left
        label.textColor = .label
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(addressLabel)
        
        let addressTapGesture = UITapGestureRecognizer(target: self, action: #selector(addressTapped))
        addressLabel.isUserInteractionEnabled = true
        addressLabel.addGestureRecognizer(addressTapGesture)
        
        let imageTapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        thumbnailImageView.addGestureRecognizer(imageTapGesture)
        
        NSLayoutConstraint.activate([
            // Thumbnail constraints - 35% of cell width
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16.0),
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16.0),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16.0),
            thumbnailImageView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.4),
            thumbnailImageView.heightAnchor.constraint(equalTo: thumbnailImageView.widthAnchor), // Keep square
            
            // Address label constraints
            addressLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            addressLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16.0),
            addressLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16.0)
        ])
    }
    
    func configure(with address: String, thumbnail: UIImage?) {
        // Create underlined attributed string
        let attributedString = NSAttributedString(
            string: address,
            attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: UIFont.bodyL
            ]
        )
        addressLabel.attributedText = attributedString
        thumbnailImageView.image = thumbnail
    }
    
    @objc private func addressTapped() {
        delegate?.placeAddressCellAddressTapped(self, place: nil)
    }
    
    func showCopyFeedback() {
        HapticsHelper.lightHaptic()
        
        let copiedLabel = UILabel()
        copiedLabel.text = "Copied!"
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        copiedLabel.textAlignment = .center
        copiedLabel.layer.cornerRadius = 10
        copiedLabel.clipsToBounds = true
        copiedLabel.alpha = 0
        
        contentView.addSubview(copiedLabel)
        copiedLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            copiedLabel.centerXAnchor.constraint(equalTo: addressLabel.centerXAnchor),
            copiedLabel.centerYAnchor.constraint(equalTo: addressLabel.centerYAnchor),
            copiedLabel.widthAnchor.constraint(equalToConstant: 100),
            copiedLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        UIView.animate(withDuration: 0.2) {
            copiedLabel.alpha = 1
        }
        
        UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
            copiedLabel.alpha = 0
        }) { _ in
            copiedLabel.removeFromSuperview()
        }
    }
    
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
    
    @objc private func imageTapped() {
        guard let image = thumbnailImageView.image else { return }
        let imageViewer = ImageViewerController(sourceImageView: thumbnailImageView)
        delegate?.placeAddressCell(didTapThumbnail: imageViewer)
    }
    
    override var isHighlighted: Bool {
        get { return false }
        set { }
    }
} 
