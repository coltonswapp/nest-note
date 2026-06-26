import UIKit

struct NestReadinessRingAnimationConfig: Equatable {
    enum CurveStyle: Equatable {
        case basic(controlPoints: BezierControlPoints)
        case twoPhase(
            midProgressFraction: CGFloat,
            midKeyTime: CGFloat,
            firstSegment: BezierControlPoints,
            secondSegment: BezierControlPoints
        )
    }

    struct BezierControlPoints: Equatable {
        var x1: Float
        var y1: Float
        var x2: Float
        var y2: Float

        var timingFunction: CAMediaTimingFunction {
            CAMediaTimingFunction(controlPoints: x1, y1, x2, y2)
        }

        var swiftLiteral: String {
            String(format: "(%.2f, %.2f, %.2f, %.2f)", x1, y1, x2, y2)
        }

        static let linear = BezierControlPoints(x1: 0, y1: 0, x2: 1, y2: 1)
        static let easeOut = BezierControlPoints(x1: 0, y1: 0, x2: 0.2, y2: 1)
        static let easeIn = BezierControlPoints(x1: 0.4, y1: 0, x2: 1, y2: 1)
        static let easeInOut = BezierControlPoints(x1: 0.4, y1: 0, x2: 0.2, y2: 1)
    }

    var startDelay: TimeInterval
    var duration: TimeInterval
    var curveStyle: CurveStyle
    var playsExplosion: Bool

    static let production = NestReadinessRingAnimationConfig(
        startDelay: 0.55,
        duration: 0.44,
        curveStyle: .basic(controlPoints: .easeOut),
        playsExplosion: true
    )

    static let experimentDefault = NestReadinessRingAnimationConfig(
        startDelay: 0.55,
        duration: 0.44,
        curveStyle: .basic(controlPoints: .easeOut),
        playsExplosion: true
    )

    func makeAnimation(from: CGFloat, to progress: CGFloat) -> CAAnimation {
        switch curveStyle {
        case .basic(let controlPoints):
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = from
            animation.toValue = progress
            animation.duration = duration
            animation.timingFunction = controlPoints.timingFunction
            return animation

        case .twoPhase(let midProgressFraction, let midKeyTime, let firstSegment, let secondSegment):
            let clampedMidProgress = min(max(midProgressFraction, 0.05), 0.95)
            let clampedMidKeyTime = min(max(midKeyTime, 0.05), 0.95)
            let midValue = from + (progress - from) * clampedMidProgress

            let animation = CAKeyframeAnimation(keyPath: "strokeEnd")
            animation.values = [from, midValue, progress]
            animation.keyTimes = [0, NSNumber(value: clampedMidKeyTime), 1]
            animation.timingFunctions = [
                firstSegment.timingFunction,
                secondSegment.timingFunction
            ]
            animation.duration = duration
            animation.calculationMode = .linear
            return animation
        }
    }

    var swiftSnippet: String {
        switch curveStyle {
        case .basic(let controlPoints):
            return """
            NestReadinessRingAnimationConfig(
                startDelay: \(String(format: "%.2f", startDelay)),
                duration: \(String(format: "%.2f", duration)),
                curveStyle: .basic(controlPoints: .init\(controlPoints.swiftLiteral)),
                playsExplosion: \(playsExplosion)
            )
            """
        case .twoPhase(let midProgressFraction, let midKeyTime, let firstSegment, let secondSegment):
            return """
            NestReadinessRingAnimationConfig(
                startDelay: \(String(format: "%.2f", startDelay)),
                duration: \(String(format: "%.2f", duration)),
                curveStyle: .twoPhase(
                    midProgressFraction: \(String(format: "%.2f", midProgressFraction)),
                    midKeyTime: \(String(format: "%.2f", midKeyTime)),
                    firstSegment: .init\(firstSegment.swiftLiteral),
                    secondSegment: .init\(secondSegment.swiftLiteral)
                ),
                playsExplosion: \(playsExplosion)
            )
            """
        }
    }
}
