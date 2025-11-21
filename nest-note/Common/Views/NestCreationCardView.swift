import UIKit

class NestCreationCardView: UIView {

    // Add content view to manage hierarchy
    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.layer.cornerRadius = 12
        return view
    }()

    // Top pattern image (uses NNAssetType.rectanglePattern)
    private let topPatternView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        return imageView
    }()

    // Perforation dashed separator
    private let perforationView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let perforationLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.lineWidth = 2
        layer.lineDashPattern = [6, 6]
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.systemGray5.cgColor
        return layer
    }()

    private let nestNameLabel: UILabel = {
        let label = UILabel()
        label.font = .h2
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.text = "Anderson Nest"
        return label
    }()

    // Badge styled like NNCategoryFilterView's enabled chip
    private let newNestBadgeView: UIView = {
        let view = UIView()
        view.layer.borderWidth = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let newNestBadgeLabel: UILabel = {
        let label = UILabel()
        label.font = .h4
        label.text = "NEW NEST"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let creationDateLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        return label
    }()

    // App icon with shadow: use a container for shadow, inner image for rounded mask
    private let appIconContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        // Shadow on container (not clipped)
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.2
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.masksToBounds = false
        return view
    }()

    private let appIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "icon_pattern-preview")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    func updatePattern(size: CGFloat, spacing: CGFloat, alpha: CGFloat) {
        // Update alpha for the pattern view
        topPatternView.alpha = alpha
    }

    private func setupView() {
        backgroundColor = .clear
        layer.cornerRadius = 12
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 4, height: 8)
        layer.shadowRadius = 8

        // Configure top pattern image using NNAssetType.rectanglePattern
        if let image = UIImage(named: NNAssetType.rectanglePattern.rawValue) {
            topPatternView.image = image
            topPatternView.contentMode = .scaleAspectFill
            topPatternView.alpha = NNAssetType.rectanglePattern.defaultAlpha
        }

        // Add content view (clipping container)
        addSubview(contentView)

        // Background pattern and perforation inside contentView so they clip
        contentView.addSubview(topPatternView)
        contentView.addSubview(perforationView)
        perforationView.layer.addSublayer(perforationLayer)

        // Badge setup
        newNestBadgeView.addSubview(newNestBadgeLabel)
        newNestBadgeView.backgroundColor = NNColors.primaryOpaque
        newNestBadgeView.layer.borderColor = NNColors.primary.cgColor
        newNestBadgeLabel.textColor = NNColors.primary

        // Add content elements
        [newNestBadgeView, appIconContainer, nestNameLabel, creationDateLabel].forEach { view in
            view.isUserInteractionEnabled = false
            contentView.addSubview(view)
        }
        // Place the icon image inside the shadow container
        appIconContainer.addSubview(appIconView)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Content view constraints
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Top pattern view (only top section)
            topPatternView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -12),
            topPatternView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topPatternView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            topPatternView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.4),

            // Perforation directly under the pattern
            perforationView.topAnchor.constraint(equalTo: topPatternView.bottomAnchor),
            perforationView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            perforationView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            perforationView.heightAnchor.constraint(equalToConstant: 1),

            // Badge over the perforation (centered)
            newNestBadgeView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            newNestBadgeView.centerYAnchor.constraint(equalTo: perforationView.centerYAnchor),

            // Badge label padding
            newNestBadgeLabel.topAnchor.constraint(equalTo: newNestBadgeView.topAnchor, constant: 6),
            newNestBadgeLabel.leadingAnchor.constraint(equalTo: newNestBadgeView.leadingAnchor, constant: 14),
            newNestBadgeLabel.trailingAnchor.constraint(equalTo: newNestBadgeView.trailingAnchor, constant: -14),
            newNestBadgeLabel.bottomAnchor.constraint(equalTo: newNestBadgeView.bottomAnchor, constant: -6),

            // App icon container below perforation
            appIconContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            appIconContainer.topAnchor.constraint(equalTo: perforationView.bottomAnchor, constant: 48),
            appIconContainer.widthAnchor.constraint(equalToConstant: 100),
            appIconContainer.heightAnchor.constraint(equalTo: appIconContainer.widthAnchor),

            // Icon fills its container
            appIconView.topAnchor.constraint(equalTo: appIconContainer.topAnchor),
            appIconView.leadingAnchor.constraint(equalTo: appIconContainer.leadingAnchor),
            appIconView.trailingAnchor.constraint(equalTo: appIconContainer.trailingAnchor),
            appIconView.bottomAnchor.constraint(equalTo: appIconContainer.bottomAnchor),

            // Title and dates centered under icon
            nestNameLabel.topAnchor.constraint(equalTo: appIconContainer.bottomAnchor, constant: 24),
            nestNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nestNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            creationDateLabel.topAnchor.constraint(equalTo: nestNameLabel.bottomAnchor, constant: 8),
            creationDateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            creationDateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    func configure(nestName: String, createdDate: Date) {
        nestNameLabel.text = nestName

        // Configure creation date with clean format
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        creationDateLabel.text = dateFormatter.string(from: createdDate)

        // Force layout update
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Update dashed line path
        perforationLayer.frame = perforationView.bounds
        let path = UIBezierPath()
        let midY: CGFloat = perforationView.bounds.height / 2
        path.move(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: perforationView.bounds.width, y: midY))
        perforationLayer.path = path.cgPath
        // Update colors on trait changes dynamically
        perforationLayer.strokeColor = UIColor.systemGray3.withAlphaComponent(0.3).cgColor

        newNestBadgeView.layer.cornerRadius = newNestBadgeView.frame.size.height / 2
    }
}
