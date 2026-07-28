import UIKit

final class SessionPaymentValueCollectionViewLayout: UICollectionViewFlowLayout {
    private let cellWidth: CGFloat = SessionPaymentValueSelectorView.tickSpacing
    private let cellHeight: CGFloat = 58

    override init() {
        super.init()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }

    private func setupLayout() {
        scrollDirection = .horizontal
        minimumLineSpacing = 0
        minimumInteritemSpacing = 0
        itemSize = CGSize(width: cellWidth, height: cellHeight)
    }

    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        let halfWidth = collectionView.bounds.width / 2 - cellWidth / 2
        sectionInset = UIEdgeInsets(top: 0, left: halfWidth, bottom: 0, right: halfWidth)
    }

    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
        guard let collectionView else { return proposedContentOffset }

        let targetRect = CGRect(
            x: proposedContentOffset.x,
            y: 0,
            width: collectionView.bounds.width,
            height: collectionView.bounds.height
        )

        guard let layoutAttributes = layoutAttributesForElements(in: targetRect) else {
            return proposedContentOffset
        }

        var offsetAdjustment = CGFloat.greatestFiniteMagnitude
        let horizontalCenter = proposedContentOffset.x + collectionView.bounds.width / 2

        for attributes in layoutAttributes {
            let itemCenter = attributes.center.x
            let adjustment = itemCenter - horizontalCenter
            if abs(adjustment) < abs(offsetAdjustment) {
                offsetAdjustment = adjustment
            }
        }

        return CGPoint(x: proposedContentOffset.x + offsetAdjustment, y: 0)
    }
}
