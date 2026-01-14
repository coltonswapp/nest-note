import UIKit

protocol SessionRequestCodeCellDelegate: AnyObject {
    func sessionRequestCodeCellDidTap(inviteCode: String, sessionID: String)
}

class SessionRequestCodeCell: UICollectionViewListCell {
    static let reuseIdentifier = "SessionRequestCodeCell"

    weak var delegate: SessionRequestCodeCellDelegate?
    private var currentInviteCode: String?
    private var sessionID: String?

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = NNColors.primary

        let symbolConfig = UIImage.SymbolConfiguration(weight: .semibold)
        imageView.image = UIImage(systemName: "rectangle.fill.badge.plus", withConfiguration: symbolConfig)
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Session Request"
        return label
    }()

    private lazy var codeLabel: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(
            title: "000-000",
            image: nil,
            backgroundColor: NNColors.primary.withAlphaComponent(0.15),
            foregroundColor: NNColors.primary
        )
        button.isUserInteractionEnabled = true
        button.addTarget(self, action: #selector(codeButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var cellTapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(cellTapped))
        return gesture
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(codeLabel)

        // Add tap gesture to the entire cell (excluding the code button)
        contentView.addGestureRecognizer(cellTapGesture)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: codeLabel.leadingAnchor, constant: -8),

            codeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            codeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            codeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            codeLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    func configure(inviteCode: String, sessionID: String) {
        self.currentInviteCode = inviteCode
        self.sessionID = sessionID

        // Format code as 123-456
        let formattedCode = String(inviteCode.prefix(3)) + "-" + String(inviteCode.suffix(3))
        codeLabel.setTitle(formattedCode)

        // Add shimmer effect to the code button
        codeLabel.titleLabel.addShimmerEffect()
        codeLabel.titleLabel.startShimmer()
    }

    @objc private func cellTapped(_ gesture: UITapGestureRecognizer) {
        // Check if tap is not on the code button
        let location = gesture.location(in: contentView)
        let codeLabelFrame = codeLabel.frame

        if !codeLabelFrame.contains(location) {
            // Tap is on the cell but not on the code button
            guard let code = currentInviteCode, let sessionID = sessionID else { return }
            delegate?.sessionRequestCodeCellDidTap(inviteCode: code, sessionID: sessionID)
        }
    }

    @objc private func codeButtonTapped() {
        guard let code = currentInviteCode else { return }

        // Copy code to clipboard
        UIPasteboard.general.string = code

        // Show "Copied" animation (same as SessionInviteSitterCell)
        codeLabel.showCopiedFeedback()

        // Haptic feedback
        HapticsHelper.lightHaptic()
    }
}
