import UIKit

final class PlaceCell: UICollectionViewCell {
    static let reuseIdentifier = "PlaceCell"
    
    // MARK: - UI Elements
    let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .secondarySystemBackground
        return imageView
    }()
    
    private let labelStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 0
        return stack
    }()
    
    private let aliasLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .h4
        label.textColor = .label
        return label
    }()
    
    private let addressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .bodyS
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        return label
    }()
    
    private let blurEffectView: UIVisualEffectView = {
        let view = UIVisualEffectView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Add overlay view for highlighting
    private let highlightOverlay: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black.withAlphaComponent(0.1)
        view.isHidden = true
        view.layer.cornerRadius = 12
        return view
    }()
    
    private var gridConstraints: [NSLayoutConstraint] = []
    private var listConstraints: [NSLayoutConstraint] = []
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        
        // Add highlighting behavior
        self.isUserInteractionEnabled = true
        self.contentView.isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        
        labelStack.addArrangedSubview(aliasLabel)
        labelStack.addArrangedSubview(addressLabel)
        
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(blurEffectView)
        contentView.addSubview(labelStack)
        contentView.addSubview(highlightOverlay)  // Add overlay
        
        // Add overlay constraints
        NSLayoutConstraint.activate([
            highlightOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            highlightOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            highlightOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            highlightOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        // Apply the blur effect
        blurEffectView.effect = UIBlurEffect.variableBlurEffect(
            radius: 16,
            maskImage: UIImage(named: "testBG3")!
        )
    }
    
    private func setupConstraints() {
        // Grid Layout Constraints
        gridConstraints = [
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            blurEffectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            blurEffectView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.35),
            
            labelStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            labelStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            labelStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ]
        
        // List Layout Constraints
        listConstraints = [
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 75),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 75),
            
            labelStack.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            labelStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            labelStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8)
        ]
    }
    
    func configure(with place: Place, isGridLayout: Bool) {
        // Update labels immediately
        aliasLabel.text = place.alias
        addressLabel.text = place.address
        
        // Load thumbnail
        Task {
            do {
                let image = try await PlacesService.shared.loadImages(for: place)
                await MainActor.run {
                    thumbnailImageView.image = image
                }
            } catch {
                Logger.log(level: .error, category: .placesService, 
                    message: "Failed to load image for place: \(error.localizedDescription)")
            }
        }
        
        // Update layout
        NSLayoutConstraint.deactivate(gridConstraints + listConstraints)
        NSLayoutConstraint.activate(isGridLayout ? gridConstraints : listConstraints)
        blurEffectView.isHidden = !isGridLayout
        
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        aliasLabel.text = nil
        addressLabel.text = nil
    }
    
    // Update highlighting behavior
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                // Scale effect
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
                
                // Show/hide overlay
                self.highlightOverlay.isHidden = !self.isHighlighted
                self.highlightOverlay.backgroundColor = self.isHighlighted ?
                    .black.withAlphaComponent(0.15) : .black.withAlphaComponent(0.1)
            }
        }
    }
    
    // Add a flash method for visual feedback
    func flash() {
        UIView.animate(withDuration: 0.3, animations: {
            self.contentView.backgroundColor = NNColors.primary.withAlphaComponent(0.3)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.contentView.backgroundColor = .systemBackground
            }
        }
    }
}

private extension UIImageView {
    func setImage(from asset: UIImageAsset, for traitCollection: UITraitCollection) {
        let style = traitCollection.userInterfaceStyle
        let specificTraits = UITraitCollection(userInterfaceStyle: style)
        self.image = asset.image(with: specificTraits)
    }
} 
