import UIKit

final class FakePDFThumbnailView: UIView {
    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "PDF"
        label.font = .systemFont(ofSize: 7, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = .systemRed
        label.layer.cornerRadius = 3
        label.layer.masksToBounds = true
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAppearance()
        setupContentLines()
        setupBadge()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupAppearance() {
        backgroundColor = .white
        layer.cornerRadius = 4
        layer.cornerCurve = .continuous
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.separator.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2
    }

    private func setupContentLines() {
        let lineHeights: [CGFloat] = [2, 2, 2, 1.5]
        let lineWidths: [CGFloat] = [0.85, 0.7, 0.78, 0.5]
        var previousLine: UIView?

        for (index, height) in lineHeights.enumerated() {
            let line = UIView()
            line.translatesAutoresizingMaskIntoConstraints = false
            line.backgroundColor = UIColor.systemGray4
            line.layer.cornerRadius = height / 2
            addSubview(line)

            NSLayoutConstraint.activate([
                line.heightAnchor.constraint(equalToConstant: height),
                line.widthAnchor.constraint(equalTo: widthAnchor, multiplier: lineWidths[index]),
                line.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5)
            ])

            if let previousLine {
                line.topAnchor.constraint(equalTo: previousLine.bottomAnchor, constant: 3).isActive = true
            } else {
                line.topAnchor.constraint(equalTo: topAnchor, constant: 6).isActive = true
            }

            if index == lineHeights.count - 1 {
                line.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8).isActive = true
            }

            previousLine = line
        }
    }

    private func setupBadge() {
        addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            badgeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            badgeLabel.widthAnchor.constraint(equalToConstant: 22),
            badgeLabel.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
}

final class SessionPDFExportCell: UICollectionViewListCell {
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = NNColors.primary

        let symbolConfig = UIImage.SymbolConfiguration(weight: .semibold)
        imageView.image = UIImage(systemName: "document.badge.arrow.up.fill", withConfiguration: symbolConfig)
        return imageView
    }()

    private let thumbnailView: FakePDFThumbnailView = {
        let view = FakePDFThumbnailView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Export Session Info"
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private var titleTrailingToThumbnailConstraint: NSLayoutConstraint!
    private var titleTrailingToLoadingConstraint: NSLayoutConstraint!
    private var titleTrailingToContentConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCell() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(thumbnailView)
        contentView.addSubview(loadingIndicator)

        titleTrailingToThumbnailConstraint = titleLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: thumbnailView.leadingAnchor,
            constant: -12
        )
        titleTrailingToLoadingConstraint = titleLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: loadingIndicator.leadingAnchor,
            constant: -8
        )
        titleTrailingToContentConstraint = titleLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: contentView.trailingAnchor,
            constant: -16
        )

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            thumbnailView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            thumbnailView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 34),
            thumbnailView.heightAnchor.constraint(equalToConstant: 46),

            loadingIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 62)
        ])

        titleTrailingToContentConstraint.isActive = true
    }

    func configure(hasGeneratedPDF: Bool, isGenerating: Bool) {
        thumbnailView.isHidden = !hasGeneratedPDF || isGenerating

        titleTrailingToThumbnailConstraint.isActive = hasGeneratedPDF && !isGenerating
        titleTrailingToLoadingConstraint.isActive = isGenerating
        titleTrailingToContentConstraint.isActive = !hasGeneratedPDF && !isGenerating

        if isGenerating {
            loadingIndicator.startAnimating()
            accessories = []
        } else {
            loadingIndicator.stopAnimating()
            accessories = [.disclosureIndicator()]
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadingIndicator.stopAnimating()
        thumbnailView.isHidden = true
        titleTrailingToThumbnailConstraint.isActive = false
        titleTrailingToLoadingConstraint.isActive = false
        titleTrailingToContentConstraint.isActive = true
    }
}
