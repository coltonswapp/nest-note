import UIKit

/// Dashed placeholder cell prompting the owner to pin another folder.
final class AddPinnedFolderCell: UICollectionViewCell {
    static let reuseIdentifier = "AddPinnedFolderCell"

    private let dashedBorder = CAShapeLayer()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let cornerRadius = FolderShape.scaledCornerRadius(for: contentView.bounds.height)
        let rect = contentView.bounds.insetBy(dx: 0.5, dy: 0.5)
        dashedBorder.path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        dashedBorder.frame = contentView.bounds
        contentView.layer.cornerRadius = cornerRadius
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        updateColors()
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.alpha = self.isHighlighted ? 0.7 : 1
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.96, y: 0.96)
                    : .identity
            }
        }
    }

    private func setup() {
        contentView.backgroundColor = .clear
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        dashedBorder.fillColor = nil
        dashedBorder.lineWidth = 1.5
        dashedBorder.lineDashPattern = [6, 4]
        contentView.layer.addSublayer(dashedBorder)

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image = UIImage(systemName: "plus", withConfiguration: config)
        iconView.contentMode = .scaleAspectFit

        titleLabel.text = "Pin a folder"
        titleLabel.font = .bodyS
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20)
        ])

        updateColors()
    }

    private func updateColors() {
        let stroke = UIColor.tertiaryLabel.resolvedColor(with: traitCollection)
        dashedBorder.strokeColor = stroke.withAlphaComponent(0.22).cgColor
        iconView.tintColor = .tertiaryLabel
        titleLabel.textColor = .tertiaryLabel
    }
}
