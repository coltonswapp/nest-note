import UIKit

final class NestReadinessCompactCell: UICollectionViewListCell {
    private static let symbolName = "checkmark.seal.fill"

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        backgroundConfiguration = .listGroupedCell()
    }

    func configure(score: Int) {
        var content = defaultContentConfiguration()
        content.text = "Nest Score"

        let symbolConfiguration = UIImage.SymbolConfiguration(weight: .bold)
        let image = UIImage(systemName: Self.symbolName, withConfiguration: symbolConfiguration)?
            .withTintColor(NNColors.primary, renderingMode: .alwaysOriginal)
        content.image = image
        content.imageProperties.tintColor = NNColors.primary
        content.imageProperties.maximumSize = CGSize(width: 24, height: 24)
        content.imageToTextPadding = 16
        content.directionalLayoutMargins.top = 16
        content.directionalLayoutMargins.bottom = 16

        content.secondaryAttributedText = Self.makeScoreAttributedText(score: score)
        content.prefersSideBySideTextAndSecondaryText = true

        contentConfiguration = content
        accessories = []
    }

    private static func makeScoreAttributedText(score: Int) -> NSAttributedString {
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let scoreFont = UIFont.systemFont(ofSize: baseFont.pointSize, weight: .bold)
        let suffixFont = UIFont.preferredFont(forTextStyle: .callout)

        let attributed = NSMutableAttributedString(
            string: "\(score)",
            attributes: [
                .font: scoreFont,
                .foregroundColor: NestReadinessColors.midGreen
            ]
        )
        attributed.append(NSAttributedString(
            string: "/100",
            attributes: [
                .font: suffixFont,
                .foregroundColor: UIColor.secondaryLabel
            ]
        ))
        return attributed
    }
}
