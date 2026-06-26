import UIKit

final class NestReadinessBannerCell: UICollectionViewListCell {
    static let preferredHeight: CGFloat = 88

    var onDismiss: (() -> Void)?

    private let cardBackgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = NestReadinessColors.bannerBackground
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }()

    private let patternImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        NNAssetHelper.configureImageView(imageView, for: .rectanglePattern, with: NNColors.primary)
        imageView.alpha = 0.11
        imageView.clipsToBounds = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4
        label.textColor = .label
        label.text = "Nest Readiness Score"
        label.numberOfLines = 1
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.text = "Based on breadth, depth, and variety in your nest."
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 40, weight: .bold).rounded()
        label.textColor = NestReadinessColors.midGreen
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let scoreSuffixLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .medium).rounded()
        label.textColor = .tertiaryLabel
        label.text = "/100"
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private lazy var textStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var scoreStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [scoreLabel, scoreSuffixLabel])
        stack.axis = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
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
        onDismiss = nil
    }

    private func setupCell() {
        clipsToBounds = false
        contentView.clipsToBounds = false
        contentView.backgroundColor = .clear
        patternImageView.transform = CGAffineTransform(rotationAngle: 30 * .pi / 180)

        cardBackgroundView.addSubview(patternImageView)
        contentView.addSubview(cardBackgroundView)
        contentView.addSubview(textStack)
        contentView.addSubview(scoreStack)
        contentView.addSubview(dismissButton)
        cardBackgroundView.sendSubviewToBack(patternImageView)

        dismissButton.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)

        NSLayoutConstraint.activate([
            cardBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            patternImageView.trailingAnchor.constraint(equalTo: cardBackgroundView.trailingAnchor, constant: 32),
            patternImageView.topAnchor.constraint(equalTo: cardBackgroundView.topAnchor, constant: -24),
            patternImageView.bottomAnchor.constraint(equalTo: cardBackgroundView.bottomAnchor, constant: 24),
            patternImageView.widthAnchor.constraint(equalToConstant: 140),

            dismissButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            dismissButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            dismissButton.widthAnchor.constraint(equalToConstant: GlassDismissButton.size),
            dismissButton.heightAnchor.constraint(equalToConstant: GlassDismissButton.size),

            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -14),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: scoreStack.leadingAnchor, constant: -12),

            scoreStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scoreStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        var backgroundConfig = UIBackgroundConfiguration.listCell()
        backgroundConfig.backgroundColor = .clear
        backgroundConfiguration = backgroundConfig

        let selectedBgView = UIView()
        selectedBgView.backgroundColor = NNColors.primary.withAlphaComponent(0.08)
        selectedBgView.layer.cornerRadius = 16
        selectedBgView.layer.cornerCurve = .continuous
        selectedBgView.layer.masksToBounds = true
        selectedBackgroundView = selectedBgView
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        cardBackgroundView.backgroundColor = NestReadinessColors.bannerBackground
    }

    func configure(result: NestReadinessResult, animated: Bool) {
        scoreLabel.text = "\(result.totalScore)"
    }

    @objc private func handleDismiss() {
        HapticsHelper.lightHaptic()
        onDismiss?()
    }
}
