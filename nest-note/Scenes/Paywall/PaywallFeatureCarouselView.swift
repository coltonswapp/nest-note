//
//  PaywallFeatureCarouselView.swift
//  nest-note
//

import UIKit

final class PaywallFeatureCarouselView: UIView {

    static let cardAspectRatio: CGFloat = 1.77
    static let carouselSpacing: CGFloat = 30
    private static let pageControlAreaHeight: CGFloat = 28

    var onPageChanged: ((Int, PaywallFeatureCarouselCard) -> Void)?

    var cardHeight: CGFloat {
        get { carouselScrollViewHeightConstraint.constant }
        set {
            carouselScrollViewHeightConstraint.constant = newValue
            cardWidth = newValue / Self.cardAspectRatio
            totalHeightConstraint.constant = newValue + Self.pageControlAreaHeight
            setNeedsLayout()
            layoutIfNeeded()
            rebuildCardLayout()
            updateCardTransforms()
        }
    }

    var isInteractionEnabledForCarousel: Bool = true {
        didSet {
            carouselScrollView.isScrollEnabled = isInteractionEnabledForCarousel
        }
    }

    private var cards: [PaywallFeatureCarouselCard] = paywallFeatureCarouselCards
    private var cardViews: [PaywallFeatureCarouselCardView] = []
    private var cardWidth: CGFloat = 0
    private var sideInset: CGFloat = 0
    private var currentPage = 0

    private var carouselScrollViewHeightConstraint: NSLayoutConstraint!
    private var totalHeightConstraint: NSLayoutConstraint!

    private let carouselScrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.decelerationRate = .fast
        scroll.clipsToBounds = false
        scroll.backgroundColor = .clear
        scroll.contentInsetAdjustmentBehavior = .never
        return scroll
    }()

    private let cardsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private let pageControl: UIPageControl = {
        let control = UIPageControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        control.currentPageIndicatorTintColor = .white
        control.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.35)
        control.isUserInteractionEnabled = false
        return control
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setCards(paywallFeatureCarouselCards)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildCardLayout()
        updateCardTransforms()
    }

    func setCards(_ cards: [PaywallFeatureCarouselCard]) {
        self.cards = cards
        pageControl.numberOfPages = cards.count

        cardViews.forEach { $0.removeFromSuperview() }
        cardViews.removeAll()

        cards.forEach { card in
            let cardView = PaywallFeatureCarouselCardView()
            cardView.configure(with: card)
            cardsContainer.addSubview(cardView)
            cardViews.append(cardView)
        }

        currentPage = 0
        setNeedsLayout()
        layoutIfNeeded()
        scrollToPage(0, animated: false)
        notifyPageChanged()
    }

    private func setup() {
        clipsToBounds = false
        addSubview(carouselScrollView)
        addSubview(pageControl)
        carouselScrollView.addSubview(cardsContainer)
        carouselScrollView.delegate = self

        carouselScrollViewHeightConstraint = carouselScrollView.heightAnchor.constraint(equalToConstant: 220)
        totalHeightConstraint = heightAnchor.constraint(equalToConstant: 220 + Self.pageControlAreaHeight)

        NSLayoutConstraint.activate([
            totalHeightConstraint,

            carouselScrollView.topAnchor.constraint(equalTo: topAnchor),
            carouselScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            carouselScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            carouselScrollViewHeightConstraint,

            pageControl.topAnchor.constraint(equalTo: carouselScrollView.bottomAnchor, constant: 8),
            pageControl.centerXAnchor.constraint(equalTo: centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func rebuildCardLayout() {
        guard bounds.width > 0, carouselScrollViewHeightConstraint.constant > 0, !cardViews.isEmpty else { return }

        let cardHeight = carouselScrollViewHeightConstraint.constant
        cardWidth = cardHeight / Self.cardAspectRatio
        sideInset = max(0, (bounds.width - cardWidth) / 2)
        let pageStep = cardWidth + Self.carouselSpacing
        let cardsWidth = pageStep * CGFloat(cards.count - 1) + cardWidth
        let contentWidth = cardsWidth + sideInset

        carouselScrollView.contentInset = UIEdgeInsets(top: 0, left: sideInset, bottom: 0, right: sideInset)

        cardsContainer.frame = CGRect(x: 0, y: 0, width: contentWidth, height: cardHeight)

        for (index, cardView) in cardViews.enumerated() {
            cardView.frame = CGRect(
                x: pageStep * CGFloat(index),
                y: 0,
                width: cardWidth,
                height: cardHeight
            )
        }

        carouselScrollView.contentSize = CGSize(width: contentWidth, height: cardHeight)

        scrollToPage(currentPage, animated: false)
    }

    private func pageStep() -> CGFloat {
        cardWidth + Self.carouselSpacing
    }

    private func cardCenterX(for page: Int) -> CGFloat {
        pageStep() * CGFloat(page) + cardWidth / 2
    }

    private func pageIndex(for offsetX: CGFloat) -> Int {
        guard !cards.isEmpty else { return 0 }
        let step = pageStep()
        guard step > 0 else { return 0 }

        let visibleCenterX = offsetX + carouselScrollView.bounds.width / 2
        let rawIndex = Int(((visibleCenterX - cardWidth / 2) / step).rounded())
        return max(0, min(rawIndex, cards.count - 1))
    }

    private func targetOffset(for page: Int) -> CGFloat {
        cardCenterX(for: page) - carouselScrollView.bounds.width / 2
    }

    private func scrollToPage(_ page: Int, animated: Bool) {
        let clampedPage = max(0, min(page, cards.count - 1))
        currentPage = clampedPage
        pageControl.currentPage = clampedPage
        carouselScrollView.setContentOffset(
            CGPoint(x: targetOffset(for: clampedPage), y: 0),
            animated: animated
        )
    }

    private func snapToNearestPage() {
        let page = pageIndex(for: carouselScrollView.contentOffset.x)
        scrollToPage(page, animated: true)
        notifyPageChanged()
    }

    private func notifyPageChanged() {
        guard cards.indices.contains(currentPage) else { return }
        onPageChanged?(currentPage, cards[currentPage])
    }

    private func updateCardTransforms() {
        guard cardWidth > 0 else { return }

        let visibleCenterX = carouselScrollView.contentOffset.x + carouselScrollView.bounds.width / 2

        for (index, cardView) in cardViews.enumerated() {
            let distance = abs(visibleCenterX - cardCenterX(for: index))
            let normalized = min(distance / pageStep(), 1)
            let scale = 1 - (normalized * 0.05)
            let yOffset = normalized * 10

            cardView.transform = CGAffineTransform(translationX: 0, y: yOffset)
                .scaledBy(x: scale, y: scale)
        }
    }
}

extension PaywallFeatureCarouselView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCardTransforms()
        let page = pageIndex(for: scrollView.contentOffset.x)
        if page != currentPage {
            currentPage = page
            pageControl.currentPage = page
            notifyPageChanged()
        }
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        let page = pageIndex(for: targetContentOffset.pointee.x)
        targetContentOffset.pointee.x = targetOffset(for: page)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        snapToNearestPage()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            snapToNearestPage()
        }
    }
}
