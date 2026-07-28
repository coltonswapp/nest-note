import UIKit

class LabelShimmerView: UIView {

    private let targetLabel: UILabel
    private var shimmerLayer: CAGradientLayer!
    private let textMaskLayer = CALayer()

    init(targetLabel: UILabel) {
        self.targetLabel = targetLabel
        super.init(frame: .zero)
        setupShimmer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupShimmer() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        clipsToBounds = true
        isUserInteractionEnabled = false

        setupShimmerLayer()
        layer.mask = textMaskLayer
    }

    private func setupShimmerLayer() {
        shimmerLayer = CAGradientLayer()
        shimmerLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.4).cgColor,
            UIColor.white.withAlphaComponent(0.4).cgColor,
            UIColor.clear.cgColor
        ]
        shimmerLayer.locations = [0, 0.3, 0.7, 1]

        let angle = 10 * CGFloat.pi / 180
        let startPoint = CGPoint(x: 0.5 - cos(angle) * 0.5, y: 0.5 - sin(angle) * 0.5)
        let endPoint = CGPoint(x: 0.5 + cos(angle) * 0.5, y: 0.5 + sin(angle) * 0.5)

        shimmerLayer.startPoint = startPoint
        shimmerLayer.endPoint = endPoint

        layer.addSublayer(shimmerLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shimmerLayer.frame = bounds
        updateTextMask()
    }

    private func updateTextMask() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        textMaskLayer.frame = bounds
        textMaskLayer.contentsScale = traitCollection.displayScale

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = targetLabel.textAlignment
        // UILabel always word-wraps when numberOfLines == 0, regardless of its lineBreakMode
        // (which defaults to .byTruncatingTail). NSString.draw honors lineBreakMode literally,
        // where truncating modes are non-wrapping, so mirror UILabel's actual behavior here.
        paragraphStyle.lineBreakMode = targetLabel.numberOfLines == 1 ? targetLabel.lineBreakMode : .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: targetLabel.font as Any,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let text = targetLabel.text ?? ""
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { _ in
            text.draw(
                with: bounds,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
        }

        textMaskLayer.contents = image.cgImage
    }

    func startShimmerAnimation() {
        shimmerLayer.removeAnimation(forKey: "shimmer")

        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-0.8, -0.6, -0.4, -0.2]
        animation.toValue = [1.2, 1.4, 1.6, 1.8]
        animation.duration = 1.8
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shimmerLayer.add(animation, forKey: "shimmer")
    }

    func stopShimmerAnimation() {
        shimmerLayer.removeAnimation(forKey: "shimmer")
    }
}

// MARK: - UILabel Extension
extension UILabel {

    private static var shimmerViewAssociationKey: UInt8 = 0

    private var shimmerView: LabelShimmerView? {
        get {
            return objc_getAssociatedObject(self, &UILabel.shimmerViewAssociationKey) as? LabelShimmerView
        }
        set {
            objc_setAssociatedObject(self, &UILabel.shimmerViewAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func addShimmerEffect() {
        guard shimmerView == nil, let superview = superview else { return }

        let shimmer = LabelShimmerView(targetLabel: self)
        shimmerView = shimmer

        superview.addSubview(shimmer)
        NSLayoutConstraint.activate([
            shimmer.leadingAnchor.constraint(equalTo: leadingAnchor),
            shimmer.trailingAnchor.constraint(equalTo: trailingAnchor),
            shimmer.topAnchor.constraint(equalTo: topAnchor),
            shimmer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        shimmer.layoutIfNeeded()
        shimmer.startShimmerAnimation()
    }

    func removeShimmerEffect() {
        shimmerView?.stopShimmerAnimation()
        shimmerView?.removeFromSuperview()
        shimmerView = nil
    }

    func startShimmer() {
        shimmerView?.startShimmerAnimation()
    }

    func stopShimmer() {
        shimmerView?.stopShimmerAnimation()
    }
}
