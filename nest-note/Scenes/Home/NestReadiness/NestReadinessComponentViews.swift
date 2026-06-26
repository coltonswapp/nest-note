import UIKit

final class NestReadinessComponentRowView: UIControl {
    var onTap: (() -> Void)?

    private let colorDot: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyS
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let pointsLabel: UILabel = {
        let label = UILabel()
        label.font = .h4
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let expansionLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyS
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var isExpanded = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(detailLabel)
        textStack.addArrangedSubview(statusLabel)
        textStack.addArrangedSubview(expansionLabel)

        addSubview(colorDot)
        addSubview(textStack)
        addSubview(pointsLabel)

        NSLayoutConstraint.activate([
            colorDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            colorDot.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            colorDot.widthAnchor.constraint(equalToConstant: 8),
            colorDot.heightAnchor.constraint(equalToConstant: 8),

            textStack.leadingAnchor.constraint(equalTo: colorDot.trailingAnchor, constant: 12),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: pointsLabel.leadingAnchor, constant: -12),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            pointsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            pointsLabel.centerYAnchor.constraint(equalTo: textStack.centerYAnchor)
        ])

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    func configure(with score: NestReadinessComponentScore) {
        titleLabel.text = score.component.title
        detailLabel.text = score.detailText
        statusLabel.text = score.statusSubtitle
        statusLabel.isHidden = score.statusSubtitle == nil
        pointsLabel.text = "\(score.earnedPoints)/\(score.maxPoints)"
        colorDot.backgroundColor = score.component.accentColor
        expansionLabel.text = score.component.expansionText
        isExpanded = false
        expansionLabel.isHidden = true
    }

    @objc private func handleTap() {
        isExpanded.toggle()
        expansionLabel.isHidden = !isExpanded
        onTap?()
    }
}

final class NestReadinessBoostCardView: UIControl {
    var onTap: (() -> Void)?

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = NestReadinessColors.deepGreen
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let pointsLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyS
        label.textColor = NestReadinessColors.deepGreen
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = NestReadinessColors.paleGreen.withAlphaComponent(0.45)
        layer.cornerRadius = 14
        layer.masksToBounds = true

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(pointsLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            pointsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            pointsLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            pointsLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with suggestion: NestReadinessBoostSuggestion) {
        iconView.image = UIImage(systemName: suggestion.iconName)
        titleLabel.text = suggestion.title
        pointsLabel.text = "+\(suggestion.pointsAvailable) pt"
    }

    @objc private func handleTap() {
        onTap?()
    }
}

final class NestReadinessBoostListRowView: UIControl {
    var onTap: (() -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let pointsLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        iconView.tintColor = NNColors.primaryAlt
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .bodyL
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .bodyS
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        pointsLabel.font = .bodyM
        pointsLabel.textColor = NNColors.primaryAlt
        pointsLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(pointsLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: pointsLabel.leadingAnchor, constant: -8),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            pointsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            pointsLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with suggestion: NestReadinessBoostSuggestion) {
        iconView.image = UIImage(systemName: suggestion.iconName)
        titleLabel.text = suggestion.title
        subtitleLabel.text = suggestion.subtitle
        pointsLabel.text = "+\(suggestion.pointsAvailable)"
    }

    @objc private func handleTap() {
        onTap?()
    }
}
