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

    /// Visual treatment for the card surface.
    /// - `onboardingPreview`: full-size cards on white backgrounds
    /// - `onboardingCompact`: dense 4-up chaos grid (smaller type + chrome)
    enum CardAppearance {
        case standard
        case onboardingPreview
        case onboardingCompact
    }

    private struct Metrics {
        let contentInset: CGFloat
        let stackSpacing: CGFloat
        let cornerRadius: CGFloat
        let thumbnailCornerRadius: CGFloat
        let titleFont: UIFont
        let contentFont: UIFont
        let attachmentIconPointSize: CGFloat
        let attachmentCountFont: UIFont
        let minThumbnailHeight: CGFloat
        let thumbnailHeightRatio: CGFloat
        let stackToThumbnailSpacing: CGFloat
    }

    static let reuseIdentifier = String(describing: WaterfallGridCell.self)
    static let entryContentLineLimit = 8
    static let cornerRadius: CGFloat = 20
    private static let contentInset: CGFloat = 16
    private static let onboardingPreviewBackground = UIColor(red: 248 / 255, green: 248 / 255, blue: 248 / 255, alpha: 1)
    private static let onboardingPreviewBorder = UIColor(red: 241 / 255, green: 241 / 255, blue: 241 / 255, alpha: 1)

    private let cardView = UIView()
    private let thumbnailImageView = UIImageView()
    private let titleLabel = UILabel()
    private let contentLabel = UILabel()
    private let attachmentFooterView = UIStackView()
    private let attachmentIconView = UIImageView()
    private let attachmentCountLabel = UILabel()
    private let checkmarkImageView = UIImageView()
    private let stackView = UIStackView()

    private var thumbnailHeightConstraint: NSLayoutConstraint?
    private var stackTopConstraint: NSLayoutConstraint?
    private var stackLeadingConstraint: NSLayoutConstraint?
    private var stackTrailingConstraint: NSLayoutConstraint?
    private var stackBottomToCardConstraint: NSLayoutConstraint?
    private var stackBottomToThumbnailConstraint: NSLayoutConstraint?
    private var thumbnailLeadingConstraint: NSLayoutConstraint?
    private var thumbnailTrailingConstraint: NSLayoutConstraint?
    private var thumbnailBottomConstraint: NSLayoutConstraint?
    private var placeStackTopConstraint: NSLayoutConstraint?
    private var placeStackLeadingConstraint: NSLayoutConstraint?
    private var placeStackTrailingConstraint: NSLayoutConstraint?
    private var standardConstraints: [NSLayoutConstraint] = []
    private var placeConstraints: [NSLayoutConstraint] = []

    private var cardBackgroundColor: UIColor = WaterfallGridCell.cardSurfaceBackground()
    private var cardAppearance: CardAppearance = .standard
    private var layoutStyle: LayoutStyle = .standard
    private var isInEditMode = false
    private var isItemSelected = false
    private var showsThumbnail = false
    private var activeMetrics = WaterfallGridCell.metrics(for: .standard)

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
        cardView.layer.cornerCurve = .continuous
        cardView.clipsToBounds = true

        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerCurve = .continuous
        thumbnailImageView.backgroundColor = .tertiarySystemFill
        thumbnailImageView.isHidden = true

        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        // Prefer shrinking/truncating body copy over collapsing the title when a
        // stale waterfall frame is temporarily shorter than the content needs.
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        contentLabel.textColor = .secondaryLabel
        contentLabel.numberOfLines = 0
        contentLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        attachmentIconView.contentMode = .scaleAspectFit
        attachmentIconView.tintColor = .tertiaryLabel
        attachmentIconView.setContentHuggingPriority(.required, for: .horizontal)
        attachmentIconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        attachmentCountLabel.textColor = .tertiaryLabel
        attachmentCountLabel.isHidden = true
        attachmentCountLabel.setContentHuggingPriority(.required, for: .horizontal)
        attachmentCountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        attachmentFooterView.axis = .horizontal
        attachmentFooterView.alignment = .center
        attachmentFooterView.spacing = 4
        attachmentFooterView.isHidden = true
        attachmentFooterView.isAccessibilityElement = true
        attachmentFooterView.addArrangedSubview(attachmentIconView)
        attachmentFooterView.addArrangedSubview(attachmentCountLabel)
        // Keep the icon leading without stretching the count across the card.
        attachmentFooterView.addArrangedSubview(UIView())

        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.tintColor = NNColors.primary
        checkmarkImageView.isHidden = true

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(contentLabel)
        stackView.addArrangedSubview(attachmentFooterView)

        cardView.addSubview(thumbnailImageView)
        cardView.addSubview(stackView)
        cardView.addSubview(checkmarkImageView)
        contentView.addSubview(cardView)

        let inset = activeMetrics.contentInset
        thumbnailHeightConstraint = thumbnailImageView.heightAnchor.constraint(equalToConstant: 0)
        stackTopConstraint = stackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: inset)
        stackLeadingConstraint = stackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: inset)
        stackTrailingConstraint = stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -inset)
        stackBottomToCardConstraint = stackView.bottomAnchor.constraint(
            equalTo: cardView.bottomAnchor,
            constant: -inset
        )
        placeStackTopConstraint = stackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: inset)
        placeStackLeadingConstraint = stackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: inset)
        placeStackTrailingConstraint = stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -inset)
        stackBottomToThumbnailConstraint = stackView.bottomAnchor.constraint(
            equalTo: thumbnailImageView.topAnchor,
            constant: -activeMetrics.stackToThumbnailSpacing
        )
        thumbnailLeadingConstraint = thumbnailImageView.leadingAnchor.constraint(
            equalTo: cardView.leadingAnchor,
            constant: inset
        )
        thumbnailTrailingConstraint = thumbnailImageView.trailingAnchor.constraint(
            equalTo: cardView.trailingAnchor,
            constant: -inset
        )
        thumbnailBottomConstraint = thumbnailImageView.bottomAnchor.constraint(
            equalTo: cardView.bottomAnchor,
            constant: -inset
        )

        standardConstraints = [
            stackTopConstraint!,
            stackLeadingConstraint!,
            stackTrailingConstraint!,
            stackBottomToCardConstraint!
        ]

        placeConstraints = [
            placeStackTopConstraint!,
            placeStackLeadingConstraint!,
            placeStackTrailingConstraint!,
            stackBottomToThumbnailConstraint!,
            thumbnailLeadingConstraint!,
            thumbnailTrailingConstraint!,
            thumbnailBottomConstraint!,
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

        applyMetrics(activeMetrics)
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
        cardAppearance = .standard
        isInEditMode = false
        isItemSelected = false
        checkmarkImageView.isHidden = true
        contentLabel.numberOfLines = 0
        updateAttachmentFooter(count: 0)
        applyMetrics(Self.metrics(for: .standard))
        applyLayoutStyle(.standard)
    }

    func configure(
        title: String,
        content: String,
        thumbnail: UIImage? = nil,
        layoutStyle: LayoutStyle = .standard,
        appearance: CardAppearance = .standard,
        showsPlaceThumbnail: Bool = false,
        contentLineLimit: Int = 0,
        attachmentCount: Int = 0,
        isEditMode: Bool = false,
        isSelected: Bool = false
    ) {
        titleLabel.text = title
        contentLabel.text = content
        contentLabel.numberOfLines = contentLineLimit > 0 ? contentLineLimit : 0
        isInEditMode = isEditMode
        isItemSelected = isSelected
        cardAppearance = appearance

        applyMetrics(Self.metrics(for: appearance))
        cardBackgroundColor = Self.cardSurfaceBackground(for: appearance)
        applyLayoutStyle(layoutStyle)
        applyCardBorder()
        updateAttachmentFooter(count: attachmentCount)

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
        cardBackgroundColor = Self.cardSurfaceBackground(for: cardAppearance)
        applyCardBorder()
        updateSelectionAppearance()
    }

    private static func metrics(for appearance: CardAppearance) -> Metrics {
        switch appearance {
        case .standard, .onboardingPreview:
            return Metrics(
                contentInset: 16,
                stackSpacing: 8,
                cornerRadius: 20,
                thumbnailCornerRadius: 12,
                titleFont: .preferredFont(forTextStyle: .headline),
                contentFont: .preferredFont(forTextStyle: .subheadline),
                attachmentIconPointSize: 12,
                attachmentCountFont: .preferredFont(forTextStyle: .caption1),
                minThumbnailHeight: 72,
                thumbnailHeightRatio: 0.55,
                stackToThumbnailSpacing: 12
            )
        case .onboardingCompact:
            return Metrics(
                contentInset: 10,
                stackSpacing: 4,
                cornerRadius: 14,
                thumbnailCornerRadius: 9,
                titleFont: .systemFont(ofSize: 12, weight: .semibold),
                contentFont: .systemFont(ofSize: 11, weight: .regular),
                attachmentIconPointSize: 10,
                attachmentCountFont: .systemFont(ofSize: 10, weight: .regular),
                minThumbnailHeight: 44,
                thumbnailHeightRatio: 0.52,
                stackToThumbnailSpacing: 8
            )
        }
    }

    private static func cardSurfaceBackground(for appearance: CardAppearance = .standard) -> UIColor {
        switch appearance {
        case .standard:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : .white
            }
        case .onboardingPreview, .onboardingCompact:
            // Custom light fill for white backgrounds; share standard dark surface.
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? .secondarySystemGroupedBackground
                    : onboardingPreviewBackground
            }
        }
    }

    private static func cardBorderColor(for appearance: CardAppearance = .standard) -> UIColor {
        switch appearance {
        case .standard:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.white.withAlphaComponent(0.1)
                    : UIColor.black.withAlphaComponent(0.07)
            }
        case .onboardingPreview, .onboardingCompact:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.white.withAlphaComponent(0.1)
                    : onboardingPreviewBorder
            }
        }
    }

    private func applyMetrics(_ metrics: Metrics) {
        activeMetrics = metrics
        titleLabel.font = metrics.titleFont
        contentLabel.font = metrics.contentFont
        attachmentCountLabel.font = metrics.attachmentCountFont
        let symbolConfig = UIImage.SymbolConfiguration(
            pointSize: metrics.attachmentIconPointSize,
            weight: .medium
        )
        attachmentIconView.image = UIImage(systemName: "paperclip", withConfiguration: symbolConfig)
        stackView.spacing = metrics.stackSpacing
        cardView.layer.cornerRadius = metrics.cornerRadius
        thumbnailImageView.layer.cornerRadius = metrics.thumbnailCornerRadius

        let inset = metrics.contentInset
        stackTopConstraint?.constant = inset
        stackLeadingConstraint?.constant = inset
        stackTrailingConstraint?.constant = -inset
        stackBottomToCardConstraint?.constant = -inset
        placeStackTopConstraint?.constant = inset
        placeStackLeadingConstraint?.constant = inset
        placeStackTrailingConstraint?.constant = -inset
        stackBottomToThumbnailConstraint?.constant = -metrics.stackToThumbnailSpacing
        thumbnailLeadingConstraint?.constant = inset
        thumbnailTrailingConstraint?.constant = -inset
        thumbnailBottomConstraint?.constant = -inset
    }

    private func updateAttachmentFooter(count: Int) {
        let shows = count > 0
        attachmentFooterView.isHidden = !shows
        attachmentCountLabel.isHidden = count <= 1
        attachmentCountLabel.text = count > 1 ? "\(count)" : nil
        guard shows else {
            attachmentFooterView.accessibilityLabel = nil
            return
        }
        attachmentFooterView.accessibilityLabel = count == 1
            ? "Has attachment"
            : "Has \(count) attachments"
    }

    private func applyCardBorder() {
        cardView.layer.borderColor = Self.cardBorderColor(for: cardAppearance)
            .resolvedColor(with: traitCollection).cgColor
        switch cardAppearance {
        case .onboardingPreview, .onboardingCompact:
            cardView.layer.borderWidth = 1
        case .standard:
            cardView.layer.borderWidth = 1 / traitCollection.displayScale
        }
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

        let thumbnailWidth = columnWidth - (activeMetrics.contentInset * 2)
        thumbnailHeightConstraint?.constant = max(
            activeMetrics.minThumbnailHeight,
            thumbnailWidth * activeMetrics.thumbnailHeightRatio
        )
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

    func flash() {
        let previous = cardView.backgroundColor
        UIView.animate(withDuration: 0.3, animations: {
            self.cardView.backgroundColor = NNColors.primary.withAlphaComponent(0.3)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.cardView.backgroundColor = previous ?? self.cardBackgroundColor
            }
        }
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
