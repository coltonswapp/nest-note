import UIKit

final class NestReadinessAboutViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = "About Nest Score"
        titleLabel.font = .h2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyLabel = UILabel()
        bodyLabel.numberOfLines = 0
        bodyLabel.font = .bodyL
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.text = """
        Your Nest Score reflects how thoroughly you've documented your nest for sitters.

        It combines item count, item types, folder coverage, and common essentials. Scores do not decrease over time — keeping entries current is handled separately by Nest Review.

        Open the Boost section to see the fastest ways to raise your score.
        """
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

final class NestReadinessDetailHeaderCell: UICollectionViewCell {
    let ringView = NestReadinessRingView()

    private let topImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NNAssetHelper.configureImageView(view, for: .rectanglePatternSmall, with: NestReadinessColors.midGreen)
        view.alpha = 0.4
        view.clipsToBounds = true
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Nest Score"
        label.font = .h1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "See how thoroughly your nest is documented and what to add next."
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let aboutTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "About Nest Score"
        label.font = .h3
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let aboutBodyLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = """
        Your Nest Score reflects how thoroughly you've documented your nest for sitters.

        It combines item count, item types, folder coverage, and common essentials. Scores do not decrease over time — keeping entries current is handled separately by Nest Review.
        """
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        ringView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(topImageView)
        [titleLabel, subtitleLabel, ringView, aboutTitleLabel, aboutBodyLabel].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            topImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            topImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            topImageView.heightAnchor.constraint(
                equalTo: contentView.widthAnchor,
                multiplier: NNAssetType.rectanglePatternSmall.heightMultiplier
            ),

            titleLabel.topAnchor.constraint(equalTo: topImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            ringView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            ringView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            ringView.widthAnchor.constraint(equalToConstant: 168),
            ringView.heightAnchor.constraint(equalToConstant: 168),

            aboutTitleLabel.topAnchor.constraint(equalTo: ringView.bottomAnchor, constant: 28),
            aboutTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            aboutTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            aboutBodyLabel.topAnchor.constraint(equalTo: aboutTitleLabel.bottomAnchor, constant: 8),
            aboutBodyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            aboutBodyLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            aboutBodyLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(subtitle: String) {
        subtitleLabel.text = subtitle
    }
}

enum NestReadinessPointsAnimator {
    static func showGain(_ points: Int, in view: UIView) {
        guard points > 0 else { return }

        let label = UILabel()
        label.text = "+\(points)"
        label.font = .systemFont(ofSize: 28, weight: .bold).rounded()
        label.textColor = NestReadinessColors.deepGreen
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40)
        ])

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        UIView.animate(withDuration: 0.35, animations: {
            label.alpha = 1
            label.transform = CGAffineTransform(translationX: 0, y: -24)
        }, completion: { _ in
            UIView.animate(withDuration: 0.35, delay: 0.4, options: [], animations: {
                label.alpha = 0
            }, completion: { _ in
                label.removeFromSuperview()
            })
        })
    }
}
