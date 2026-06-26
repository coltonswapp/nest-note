import UIKit

/// Compact sitter onboarding banner — same structure as `PremiumPromoCell` / `PremiumPromoBannerView`.
final class SitterInfoBannerCell: UICollectionViewCell {

    static let preferredHeight: CGFloat = 88

    var onClose: (() -> Void)?

    private static let contentInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 44)
    private static let iconSize: CGFloat = 44
    private static let iconCornerRadius: CGFloat = 10
    private static let iconRotationDegrees: CGFloat = -6

    private let cardContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let cardBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let patternImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        NNAssetHelper.configureImageView(imageView, for: .rectanglePattern, with: NNColors.primary)
        imageView.alpha = 0.11
        return imageView
    }()

    private let iconCard: UIView = {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.2
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 10
        card.layer.masksToBounds = false
        return card
    }()

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "icon_dark-preview")
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = SitterInfoBannerCell.iconCornerRadius
        imageView.layer.cornerCurve = .continuous
        imageView.layer.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return stack
    }()

    private let contentRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = SitterInfoBannerCell.contentInsets
        return stack
    }()

    private lazy var dismissButton = GlassDismissButton()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onClose = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateIconAppearance()
    }

    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    private func setupCell() {
        clipsToBounds = false
        backgroundColor = .clear
        contentView.clipsToBounds = false
        contentView.backgroundColor = .clear

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        iconCard.addSubview(iconView)
        contentRow.addArrangedSubview(iconCard)
        contentRow.addArrangedSubview(textStack)

        patternImageView.transform = CGAffineTransform(rotationAngle: 30 * .pi / 180)

        contentView.addSubview(cardContainer)
        cardContainer.addSubview(cardBackgroundView)
        cardBackgroundView.addSubview(patternImageView)
        cardContainer.addSubview(contentRow)
        contentView.addSubview(dismissButton)

        dismissButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)

        NSLayoutConstraint.activate([
            cardContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            cardBackgroundView.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            cardBackgroundView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            cardBackgroundView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            cardBackgroundView.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),

            patternImageView.trailingAnchor.constraint(equalTo: cardBackgroundView.trailingAnchor, constant: 32),
            patternImageView.topAnchor.constraint(equalTo: cardBackgroundView.topAnchor, constant: -24),
            patternImageView.bottomAnchor.constraint(equalTo: cardBackgroundView.bottomAnchor, constant: 24),
            patternImageView.widthAnchor.constraint(equalToConstant: 140),

            contentRow.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            contentRow.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            contentRow.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            contentRow.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),

            iconCard.widthAnchor.constraint(equalToConstant: Self.iconSize),
            iconCard.heightAnchor.constraint(equalToConstant: Self.iconSize),

            iconView.topAnchor.constraint(equalTo: iconCard.topAnchor),
            iconView.leadingAnchor.constraint(equalTo: iconCard.leadingAnchor),
            iconView.trailingAnchor.constraint(equalTo: iconCard.trailingAnchor),
            iconView.bottomAnchor.constraint(equalTo: iconCard.bottomAnchor),

            dismissButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            dismissButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            dismissButton.widthAnchor.constraint(equalToConstant: GlassDismissButton.size),
            dismissButton.heightAnchor.constraint(equalToConstant: GlassDismissButton.size),
        ])

        cardBackgroundView.sendSubviewToBack(patternImageView)

        let selectedBgView = UIView()
        selectedBgView.backgroundColor = NNColors.primary.withAlphaComponent(0.08)
        selectedBgView.layer.cornerRadius = 16
        selectedBgView.layer.cornerCurve = .continuous
        selectedBgView.layer.masksToBounds = true
        selectedBackgroundView = selectedBgView
        isUserInteractionEnabled = true
    }

    @objc private func handleClose() {
        HapticsHelper.lightHaptic()
        onClose?()
    }

    private func updateIconAppearance() {
        let radians = Self.iconRotationDegrees * .pi / 180
        iconCard.transform = CGAffineTransform(rotationAngle: radians)

        guard !iconCard.bounds.isEmpty else {
            iconCard.layer.shadowPath = nil
            return
        }

        iconCard.layer.shadowPath = UIBezierPath(
            roundedRect: iconCard.bounds,
            cornerRadius: Self.iconCornerRadius
        ).cgPath
    }
}
