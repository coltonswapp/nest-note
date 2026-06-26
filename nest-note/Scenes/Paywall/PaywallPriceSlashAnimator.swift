//
//  PaywallPriceSlashAnimator.swift
//  nest-note
//

import UIKit

struct PriceAnimationComponent: Equatable {
    let amount: Decimal
    let suffix: String
    let currencyCode: String
}

struct PaywallPriceSnapshot: Equatable {
    let primary: String
    let secondary: String?
    let primaryPrice: PriceAnimationComponent?
    let secondaryPrice: PriceAnimationComponent?
}

final class PaywallPriceSlashAnimator {

    struct AnimatedLabel {
        let label: UILabel
        let fromText: String
        let toText: String
        let fromAmount: Decimal?
        let toAmount: Decimal?
        let suffix: String?
        let currencyCode: String?
    }

    private var displayLink: CADisplayLink?
    private var animatedLabels: [AnimatedLabel] = []
    private var startTime: CFTimeInterval = 0
    private var delay: TimeInterval = 0
    private var duration: TimeInterval = 0.75
    private var completion: (() -> Void)?
    private var currencyFormatters: [String: NumberFormatter] = [:]

    func animate(
        labels: [(label: UILabel, from: String, to: String, fromAmount: Decimal?, toAmount: Decimal?, suffix: String?, currencyCode: String?)],
        delay: TimeInterval = 0,
        duration: TimeInterval = 0.75,
        completion: (() -> Void)? = nil
    ) {
        stop()

        self.delay = delay
        self.duration = duration
        self.completion = completion
        self.startTime = 0

        animatedLabels = labels.map { item in
            item.label.text = item.from
            item.label.alpha = 1
            item.label.transform = .identity

            return AnimatedLabel(
                label: item.label,
                fromText: item.from,
                toText: item.to,
                fromAmount: item.fromAmount,
                toAmount: item.toAmount,
                suffix: item.suffix,
                currencyCode: item.currencyCode
            )
        }

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil

        animatedLabels.forEach { item in
            item.label.transform = .identity
            item.label.alpha = 1
        }
        animatedLabels.removeAll()
        completion = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if startTime == 0 {
            startTime = link.timestamp
        }

        let elapsed = link.timestamp - startTime
        guard elapsed >= delay else { return }

        let progress = min(1, (elapsed - delay) / duration)
        let eased = 1 - pow(1 - progress, 3)

        for item in animatedLabels {
            if let fromAmount = item.fromAmount,
               let toAmount = item.toAmount,
               let suffix = item.suffix,
               let currencyCode = item.currencyCode,
               fromAmount != toAmount {
                let current = interpolate(from: fromAmount, to: toAmount, progress: eased)
                item.label.text = formattedPrice(current, currencyCode: currencyCode) + suffix
                item.label.alpha = 1
            } else {
                animateTextDrop(item, progress: progress)
            }
        }

        if progress >= 1 {
            animatedLabels.forEach { item in
                item.label.text = item.toText
                item.label.alpha = 1
                item.label.transform = .identity
            }

            let done = completion
            stop()
            done?()
        }
    }

    private func animateTextDrop(_ item: AnimatedLabel, progress: CGFloat) {
        let swapPoint: CGFloat = 0.45

        if progress < swapPoint {
            let localProgress = progress / swapPoint
            item.label.text = item.fromText
            item.label.alpha = 1 - localProgress
        } else {
            let localProgress = (progress - swapPoint) / (1 - swapPoint)
            item.label.text = item.toText
            item.label.alpha = localProgress
        }
    }

    private func interpolate(from: Decimal, to: Decimal, progress: Double) -> Decimal {
        let fromValue = (from as NSDecimalNumber).doubleValue
        let toValue = (to as NSDecimalNumber).doubleValue
        return Decimal(fromValue + (toValue - fromValue) * progress)
    }

    private func formattedPrice(_ amount: Decimal, currencyCode: String) -> String {
        if currencyFormatters[currencyCode] == nil {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            currencyFormatters[currencyCode] = formatter
        }

        let formatted = currencyFormatters[currencyCode]?.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        return formatted
    }

    deinit {
        stop()
    }
}
