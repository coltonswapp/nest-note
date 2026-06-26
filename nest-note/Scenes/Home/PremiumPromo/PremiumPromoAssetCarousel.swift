import SwiftUI

/// Compact vertical asset carousel for the premium promo banner, using landing-page NN cards.
struct PremiumPromoAssetCarousel: View {
    private enum Metrics {
        static let cardWidth: CGFloat = 112
        static let cardHeight: CGFloat = 108
        static let spacing: CGFloat = 10
        static let scrollStep: CGFloat = 0.32
        static let horizontalPadding: CGFloat = 8
    }

    @State private var scrollPosition = ScrollPosition()
    @State private var currentScrollOffset: CGFloat = 0
    /// `.common` keeps firing while the hosting collection view is scrolling (`.default` pauses in tracking mode).
    @State private var timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()

    private var loopHeight: CGFloat {
        let cardCount = CGFloat(cards.count)
        return cardCount * Metrics.cardHeight + max(cardCount - 1, 0) * Metrics.spacing
    }

    var body: some View {
        VerticalInfiniteScrollView(spacing: Metrics.spacing) {
            ForEach(cards) { card in
                carouselCard(card)
            }
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .scrollIndicators(.hidden)
        .scrollPosition($scrollPosition)
        .scrollClipDisabled()
        .mask(fadeMask)
        .onScrollGeometryChange(for: CGFloat.self) {
            $0.contentOffset.y + $0.contentInsets.top
        } action: { _, newValue in
            currentScrollOffset = newValue
        }
        .onReceive(timer) { _ in
            let loop = loopHeight
            guard loop > 0 else { return }

            currentScrollOffset += Metrics.scrollStep
            if currentScrollOffset >= loop {
                currentScrollOffset -= loop
            }
            scrollPosition.scrollTo(y: currentScrollOffset)
        }
    }

    private var fadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.12),
                .init(color: .black, location: 0.88),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private func carouselCard(_ card: Card) -> some View {
        Image(card.image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: Metrics.cardWidth, height: Metrics.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(uiColor: .tertiarySystemBackground), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.14), radius: 5, x: 0, y: 2)
            .scrollTransition(.interactive.threshold(.centered), axis: .vertical) { content, phase in
                content
                    .scaleEffect(phase == .identity ? 1 : 0.94)
                    .rotationEffect(.degrees(phase.value * 4), anchor: .leading)
            }
    }
}
