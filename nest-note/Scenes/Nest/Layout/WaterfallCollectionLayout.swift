//
//  WaterfallCollectionLayout.swift
//  nest-note
//

import UIKit

protocol WaterfallCollectionLayoutDelegate: AnyObject {
    func collectionView(
        _ collectionView: UICollectionView,
        layout: WaterfallCollectionLayout,
        heightForItemAt indexPath: IndexPath,
        columnWidth: CGFloat
    ) -> CGFloat

    func collectionView(
        _ collectionView: UICollectionView,
        layout: WaterfallCollectionLayout,
        shouldShowHeaderForSection section: Int
    ) -> Bool

    func collectionView(
        _ collectionView: UICollectionView,
        layout: WaterfallCollectionLayout,
        heightForHeaderInSection section: Int
    ) -> CGFloat
}

final class WaterfallCollectionLayout: UICollectionViewLayout {
    weak var delegate: WaterfallCollectionLayoutDelegate?

    var columnCount: Int = 2
    var columnSpacing: CGFloat = 12
    var rowSpacing: CGFloat = 12
    var sectionInset: UIEdgeInsets = UIEdgeInsets(top: 4, left: 16, bottom: 24, right: 16)
    var sectionSpacing: CGFloat = 32

    private var itemCache: [UICollectionViewLayoutAttributes] = []
    private var headerCache: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0

    override var collectionViewContentSize: CGSize {
        guard let collectionView else { return .zero }
        return CGSize(width: collectionView.bounds.width, height: contentHeight)
    }

    override func prepare() {
        guard let collectionView, columnCount > 0 else { return }

        itemCache.removeAll()
        headerCache.removeAll()
        contentHeight = 0

        let availableWidth = collectionView.bounds.width
            - sectionInset.left
            - sectionInset.right
            - CGFloat(columnCount - 1) * columnSpacing
        let columnWidth = floor(availableWidth / CGFloat(columnCount))

        var yOffset = sectionInset.top
        let sectionCount = collectionView.numberOfSections

        for section in 0 ..< sectionCount {
            if delegate?.collectionView(collectionView, layout: self, shouldShowHeaderForSection: section) ?? false {
                let headerHeight = delegate?.collectionView(
                    collectionView,
                    layout: self,
                    heightForHeaderInSection: section
                ) ?? 28

                let headerAttributes = UICollectionViewLayoutAttributes(
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    with: IndexPath(item: 0, section: section)
                )
                headerAttributes.frame = CGRect(
                    x: 0,
                    y: yOffset,
                    width: collectionView.bounds.width,
                    height: headerHeight
                )
                headerCache.append(headerAttributes)
                yOffset += headerHeight
            }

            var columnHeights = Array(repeating: yOffset, count: columnCount)
            let itemCount = collectionView.numberOfItems(inSection: section)

            for item in 0 ..< itemCount {
                let indexPath = IndexPath(item: item, section: section)
                let itemHeight = delegate?.collectionView(
                    collectionView,
                    layout: self,
                    heightForItemAt: indexPath,
                    columnWidth: columnWidth
                ) ?? 120

                let shortestColumn = columnHeights.enumerated().min(by: { $0.element < $1.element })!.offset
                let x = sectionInset.left + CGFloat(shortestColumn) * (columnWidth + columnSpacing)
                let y = columnHeights[shortestColumn]

                let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                attributes.frame = CGRect(x: x, y: y, width: columnWidth, height: itemHeight)
                itemCache.append(attributes)

                columnHeights[shortestColumn] = y + itemHeight + rowSpacing
            }

            if itemCount > 0 {
                yOffset = (columnHeights.max() ?? yOffset) - rowSpacing + sectionSpacing
            }
        }

        contentHeight = max(yOffset, sectionInset.top) + sectionInset.bottom
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let items = itemCache.filter { $0.frame.intersects(rect) }
        let headers = headerCache.filter { $0.frame.intersects(rect) }
        return items + headers
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        itemCache.first { $0.indexPath == indexPath }
    }

    override func layoutAttributesForSupplementaryView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        headerCache.first {
            $0.indexPath == indexPath && $0.representedElementKind == elementKind
        }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }
}
