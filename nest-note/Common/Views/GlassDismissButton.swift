import UIKit

/// Circular glass dismiss control with an xmark icon. Safe to use on iOS 26+ glass and pre-26 blur fallback.
class GlassDismissButton: GlassIconButton {
    static let size: CGFloat = 30

    init() {
        super.init(
            systemName: "xmark",
            pointSize: 12,
            weight: .semibold,
            tintColor: .secondaryLabel,
            size: Self.size,
            accessibilityLabel: String(localized: "Dismiss")
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
