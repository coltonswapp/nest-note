//
//  SitterInviteCarouselView.swift
//  nest-note
//

import SwiftUI
import UIKit

struct SitterInviteCarouselView: View {
    private enum Metrics {
        static let cardWidth: CGFloat = 280
        static let cardHeight: CGFloat = 290
        static let spacing: CGFloat = 40
        static let scrollStep: CGFloat = 0.45
    }

    var onActiveTintColorChange: (UIColor) -> Void

    @State private var scrollPosition = ScrollPosition()
    @State private var currentScrollOffset: CGFloat = 0
    @State private var timer = Timer.publish(every: 0.01, on: .current, in: .default).autoconnect()

    init(onActiveTintColorChange: @escaping (UIColor) -> Void = { _ in }) {
        self.onActiveTintColorChange = onActiveTintColorChange
    }

    var body: some View {
        InfiniteScrollView(spacing: Metrics.spacing) {
            ForEach(SitterFinishCarouselMockData.items) { item in
                carouselCard(item)
            }
        }
        .frame(height: Metrics.cardHeight + 12)
        .scrollIndicators(.hidden)
        .scrollPosition($scrollPosition)
        .scrollClipDisabled()
        .onScrollGeometryChange(for: CGFloat.self) {
            $0.contentOffset.x + $0.contentInsets.leading
        } action: { _, newValue in
            currentScrollOffset = newValue
            updateGlowTint(for: newValue)
        }
        .onReceive(timer) { _ in
            currentScrollOffset += Metrics.scrollStep
            scrollPosition.scrollTo(x: currentScrollOffset)
            updateGlowTint(for: currentScrollOffset)
        }
        .onAppear {
            updateGlowTint(for: currentScrollOffset)
        }
    }

    private func updateGlowTint(for offset: CGFloat) {
        let items = SitterFinishCarouselMockData.items
        guard !items.isEmpty else { return }

        let stride = Metrics.cardWidth + Metrics.spacing
        guard stride > 0 else { return }

        let fractionalIndex = offset / stride
        let baseIndex = Int(floor(fractionalIndex))
        let progress = fractionalIndex - floor(fractionalIndex)

        // Shift the blend toward the incoming card before it reaches center.
        let earlyShift: CGFloat = 0.32
        let linearBlend = min(max((progress + earlyShift) / (1 + earlyShift), 0), 1)
        let blendProgress = smoothStep(linearBlend)

        let fromIndex = ((baseIndex % items.count) + items.count) % items.count
        let toIndex = (fromIndex + 1) % items.count

        let fromColor = items[fromIndex].bannerTintColor
        let toColor = items[toIndex].bannerTintColor
        let blended = fromColor.interpolated(to: toColor, progress: blendProgress)
        onActiveTintColorChange(blended)
    }

    private func smoothStep(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    @ViewBuilder
    private func carouselCard(_ item: SitterFinishCarouselItem) -> some View {
        SessionInviteCardRepresentable(
            session: item.session,
            invite: item.invite,
            bannerTintColor: item.bannerTintColor
        )
            .frame(width: Metrics.cardWidth, height: Metrics.cardHeight)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(item.bannerTintColor).opacity(0.14))
                    .blur(radius: 18)
                    .padding(-10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color(item.bannerTintColor).opacity(0.22), radius: 14, x: 0, y: 0)
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            .scrollTransition(.interactive.threshold(.centered), axis: .horizontal) { content, phase in
                content
                    .offset(y: phase == .identity ? 0 : 10)
                    .rotationEffect(.degrees(-phase.value * 5), anchor: .center)
            }
    }
}

private extension UIColor {
    func interpolated(to color: UIColor, progress: CGFloat) -> UIColor {
        var fromRed: CGFloat = 0
        var fromGreen: CGFloat = 0
        var fromBlue: CGFloat = 0
        var fromAlpha: CGFloat = 0
        var toRed: CGFloat = 0
        var toGreen: CGFloat = 0
        var toBlue: CGFloat = 0
        var toAlpha: CGFloat = 0

        guard getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha),
              color.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha) else {
            return progress >= 0.5 ? color : self
        }

        let t = min(max(progress, 0), 1)
        return UIColor(
            red: fromRed + (toRed - fromRed) * t,
            green: fromGreen + (toGreen - fromGreen) * t,
            blue: fromBlue + (toBlue - fromBlue) * t,
            alpha: fromAlpha + (toAlpha - fromAlpha) * t
        )
    }
}
