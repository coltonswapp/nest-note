import UIKit

/// Onboarding-style banner shown to sitters who don't have an active session yet.
/// Tapping the cell opens the "Getting families on NestNote" article; tapping the
/// close button dismisses the banner (persisted via `UserDefaults`).
final class SitterInfoBannerCell: UICollectionViewListCell {

    // MARK: - Callbacks

    var onClose: (() -> Void)?

    // MARK: - UI

    private let logoView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "icon_dark-preview")
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 8
        imageView.layer.cornerCurve = .continuous
        imageView.layer.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = NNColors.offBlack
        label.font = .h4
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = NNColors.offBlack.withAlphaComponent(0.75)
        label.font = .bodyM
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let labelStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var closeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        config.baseForegroundColor = NNColors.offBlack.withAlphaComponent(0.6)
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

        let button = UIButton(configuration: config)
        button.accessibilityLabel = String(localized: "Dismiss")
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
        configureSelectionBehavior()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onClose = nil
    }

    // MARK: - Setup

    private func setupCell() {
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(subtitleLabel)

        contentView.addSubview(logoView)
        contentView.addSubview(labelStack)
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            logoView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            logoView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            logoView.widthAnchor.constraint(equalToConstant: 36),
            logoView.heightAnchor.constraint(equalToConstant: 36),

            labelStack.leadingAnchor.constraint(equalTo: logoView.trailingAnchor, constant: 12),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -4),
            labelStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            labelStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            closeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
        ])
    }

    private func configureSelectionBehavior() {
        let selectedBgView = UIView()
        selectedBgView.backgroundColor = NNColors.EventColors.green.border.withAlphaComponent(0.6)
        selectedBgView.layer.cornerRadius = 12
        selectedBgView.layer.masksToBounds = true
        selectedBackgroundView = selectedBgView
        isUserInteractionEnabled = true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        selectedBackgroundView?.layer.cornerRadius = 12
    }

    // MARK: - Configuration

    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    // MARK: - Actions

    @objc private func handleClose() {
        HapticsHelper.lightHaptic()
        onClose?()
    }
}
