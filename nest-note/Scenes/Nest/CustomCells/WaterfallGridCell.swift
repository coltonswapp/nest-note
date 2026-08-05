//
//  WaterfallGridCell.swift
//  nest-note
//

import UIKit

final class WaterfallGridCell: UICollectionViewCell {
    enum LayoutStyle {
        case standard
        case place
    }

    static let reuseIdentifier = String(describing: WaterfallGridCell.self)
    static let entryContentLineLimit = 8
    static let cornerRadius: CGFloat = 20
    private static let contentInset: CGFloat = 16

    private let cardView = UIView()
    private let thumbnailImageView = UIImageView()
    private let titleLabel = UILabel()
    private let contentLabel = UILabel()
    private let checkmarkImageView = UIImageView()
    private let stackView = UIStackView()

    private var thumbnailHeightConstraint: NSLayoutConstraint?
    private var stackBottomToCardConstraint: NSLayoutConstraint?
    private var stackBottomToThumbnailConstraint: NSLayoutConstraint?
    private var standardConstraints: [NSLayoutConstraint] = []
    private var placeConstraints: [NSLayoutConstraint] = []

    private var cardBackgroundColor: UIColor = WaterfallGridCell.cardSurfaceBackground()
    private var layoutStyle: LayoutStyle = .standard
    private var isInEditMode = false
    private var isItemSelected = false
    private var showsThumbnail = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureViews() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = cardBackgroundColor
        cardView.layer.cornerRadius = Self.cornerRadius
        cardView.layer.cornerCurve = .continuous
        cardView.clipsToBounds = true

        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 12
        thumbnailImageView.layer.cornerCurve = .continuous
        thumbnailImageView.backgroundColor = .tertiarySystemFill
        thumbnailImageView.isHidden = true

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        // Prefer shrinking/truncating body copy over collapsing the title when a
        // stale waterfall frame is temporarily shorter than the content needs.
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        contentLabel.font = .preferredFont(forTextStyle: .subheadline)
        contentLabel.textColor = .secondaryLabel
        contentLabel.numberOfLines = 0
        contentLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.tintColor = NNColors.primary
        checkmarkImageView.isHidden = true

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .fill
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(contentLabel)

        cardView.addSubview(thumbnailImageView)
        cardView.addSubview(stackView)
        cardView.addSubview(checkmarkImageView)
        contentView.addSubview(cardView)

        thumbnailHeightConstraint = thumbnailImageView.heightAnchor.constraint(equalToConstant: 0)
        stackBottomToCardConstraint = stackView.bottomAnchor.constraint(
            equalTo: cardView.bottomAnchor,
            constant: -Self.contentInset
        )
        stackBottomToThumbnailConstraint = stackView.bottomAnchor.constraint(
            equalTo: thumbnailImageView.topAnchor,
            constant: -12
        )

        standardConstraints = [
            stackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: Self.contentInset),
            stackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: Self.contentInset),
            stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -Self.contentInset),
            stackBottomToCardConstraint!
        ]

        placeConstraints = [
            stackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: Self.contentInset),
            stackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: Self.contentInset),
            stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -Self.contentInset),
            stackBottomToThumbnailConstraint!,

            thumbnailImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: Self.contentInset),
            thumbnailImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -Self.contentInset),
            thumbnailImageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -Self.contentInset),

            thumbnailHeightConstraint!
        ]

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            checkmarkImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            checkmarkImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 22),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 22)
        ])

        applyLayoutStyle(.standard)
        applyCardBorder()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        thumbnailImageView.isHidden = true
        showsThumbnail = false
        thumbnailHeightConstraint?.constant = 0
        layoutStyle = .standard
        isInEditMode = false
        isItemSelected = false
        checkmarkImageView.isHidden = true
        contentLabel.numberOfLines = 0
        applyLayoutStyle(.standard)
    }

    func configure(
        title: String,
        content: String,
        thumbnail: UIImage? = nil,
        layoutStyle: LayoutStyle = .standard,
        showsPlaceThumbnail: Bool = false,
        contentLineLimit: Int = 0,
        isEditMode: Bool = false,
        isSelected: Bool = false
    ) {
        titleLabel.text = title
        contentLabel.text = content
        contentLabel.numberOfLines = contentLineLimit > 0 ? contentLineLimit : 0
        isInEditMode = isEditMode
        isItemSelected = isSelected

        cardBackgroundColor = Self.cardSurfaceBackground()
        applyLayoutStyle(layoutStyle)
        applyCardBorder()

        if layoutStyle == .place {
            showsThumbnail = showsPlaceThumbnail || thumbnail != nil
            thumbnailImageView.isHidden = !showsThumbnail
            thumbnailImageView.image = thumbnail
        } else if let thumbnail {
            showsThumbnail = true
            thumbnailImageView.isHidden = false
            thumbnailImageView.image = thumbnail
        } else {
            showsThumbnail = false
            thumbnailImageView.isHidden = true
            thumbnailImageView.image = nil
        }

        updateSelectionAppearance()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        cardBackgroundColor = Self.cardSurfaceBackground()
        applyCardBorder()
        updateSelectionAppearance()
    }

    private static func cardSurfaceBackground() -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : .white
        }
    }

    private static func cardBorderColor() -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.1)
                : UIColor.black.withAlphaComponent(0.07)
        }
    }

    private func applyCardBorder() {
        cardView.layer.borderColor = Self.cardBorderColor().resolvedColor(with: traitCollection).cgColor
        cardView.layer.borderWidth = 1 / traitCollection.displayScale
    }

    private func applyLayoutStyle(_ style: LayoutStyle) {
        layoutStyle = style
        NSLayoutConstraint.deactivate(standardConstraints + placeConstraints)
        NSLayoutConstraint.activate(style == .place ? placeConstraints : standardConstraints)
    }

    static func routinePreviewText(for actions: [String], emptyFallback: String = "Routine") -> String {
        guard !actions.isEmpty else { return emptyFallback }

        let previewCount = 3
        var lines = actions.prefix(previewCount).map { "• \($0)" }
        let remaining = actions.count - previewCount
        if remaining > 0 {
            lines.append("+\(remaining) item\(remaining == 1 ? "" : "s")")
        }
        return lines.joined(separator: "\n")
    }

    func updateThumbnailHeight(forColumnWidth columnWidth: CGFloat) {
        guard showsThumbnail else {
            thumbnailHeightConstraint?.constant = 0
            return
        }

        let thumbnailWidth = columnWidth - (Self.contentInset * 2)
        thumbnailHeightConstraint?.constant = max(72, thumbnailWidth * 0.55)
    }

    /// Preview only the rounded card face — matches the cell's corner radius and
    /// excludes the system platter shadow from the context-menu lift mask.
    func contextMenuTargetedPreview() -> UITargetedPreview {
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(
            roundedRect: cardView.bounds,
            cornerRadius: cardView.layer.cornerRadius
        )
        // Empty path suppresses the default soft platter shadow that otherwise
        // follows a larger/mismatched bounds mask.
        parameters.shadowPath = UIBezierPath()
        return UITargetedPreview(view: cardView, parameters: parameters)
    }

    private func updateSelectionAppearance() {
        if isInEditMode {
            checkmarkImageView.isHidden = false
            checkmarkImageView.image = UIImage(systemName: isItemSelected ? "checkmark.circle.fill" : "circle")
            checkmarkImageView.tintColor = isItemSelected ? NNColors.primary : .tertiaryLabel

            if isItemSelected {
                cardView.backgroundColor = NNColors.primary.withAlphaComponent(0.15)
                cardView.layer.borderColor = NNColors.primary.cgColor
                cardView.layer.borderWidth = 1.5
            } else {
                cardView.backgroundColor = cardBackgroundColor
                applyCardBorder()
            }
        } else {
            checkmarkImageView.isHidden = true
            applyCardBorder()
            updateBrowseHighlightAppearance(animated: false)
        }
    }

    /// Browse-mode press + sticky selection share the same gray card treatment.
    private func updateBrowseHighlightAppearance(animated: Bool = true) {
        guard !isInEditMode else { return }
        let highlighted = isHighlighted || isSelected
        let updates = {
            self.cardView.backgroundColor = highlighted ? .systemGray4 : self.cardBackgroundColor
        }
        if animated {
            UIView.animate(withDuration: highlighted ? 0.1 : 0.05, animations: updates)
        } else {
            updates()
        }
    }

    override var isHighlighted: Bool {
        didSet { updateBrowseHighlightAppearance() }
    }

    override var isSelected: Bool {
        didSet { updateBrowseHighlightAppearance() }
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let attributes = layoutAttributes.copy() as! UICollectionViewLayoutAttributes
        updateThumbnailHeight(forColumnWidth: layoutAttributes.size.width)
        let targetWidth = layoutAttributes.size.width
        let fittingSize = CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height)
        let measured = contentView.systemLayoutSizeFitting(
            fittingSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        attributes.size = CGSize(width: targetWidth, height: ceil(measured.height))
        return attributes
    }
}
