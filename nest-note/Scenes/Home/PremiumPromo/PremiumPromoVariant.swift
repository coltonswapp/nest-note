import UIKit

extension Notification.Name {
    static let premiumPromoVariantDidChange = Notification.Name("PremiumPromoVariantDidChange")
}

/// Visual presets for the owner-home premium promo banner.
enum PremiumPromoVariant: String, CaseIterable, Identifiable {
    case stackedIconsLabel
    case centeredLaurels
    case landingAssetCarousel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stackedIconsLabel:
            return "Stacked Icons · Label Title"
        case .centeredLaurels:
            return "Centered · Laurel Accents"
        case .landingAssetCarousel:
            return "Landing Asset Carousel"
        }
    }

    var detail: String {
        switch self {
        case .stackedIconsLabel:
            return "Left-aligned copy with stacked app icons and a background pattern."
        case .centeredLaurels:
            return "Centered headline, subtitle, and CTA with subtle laurel accents on each side."
        case .landingAssetCarousel:
            return "Landing-style NN assets in an auto-scrolling vertical carousel."
        }
    }

    var preferredHeight: CGFloat {
        switch self {
        case .stackedIconsLabel:
            return 120
        case .centeredLaurels:
            return 148
        case .landingAssetCarousel:
            return 120
        }
    }

    var layoutStyle: PremiumPromoLayoutStyle {
        switch self {
        case .stackedIconsLabel:
            return .horizontalIcons
        case .centeredLaurels:
            return .centeredLaurels
        case .landingAssetCarousel:
            return .landingCarousel
        }
    }

    var titleColor: UIColor {
        .label
    }

    var showsSubtitle: Bool {
        true
    }

    var showsPattern: Bool {
        self == .stackedIconsLabel
    }

    var cardBackgroundColor: UIColor {
        .secondarySystemGroupedBackground
    }

    var cardCornerRadius: CGFloat {
        16
    }

    var titleFont: UIFont {
        switch self {
        case .centeredLaurels:
            return .h4
        default:
            return .h3
        }
    }

    var cardBorderWidth: CGFloat { 0 }

    var cardBorderColor: UIColor? { nil }

    static var active: PremiumPromoVariant {
        get {
            #if DEBUG
            guard let rawValue = UserDefaults.standard.string(forKey: storageKey),
                  let variant = PremiumPromoVariant(rawValue: rawValue) else {
                return .stackedIconsLabel
            }
            return variant
            #else
            return .stackedIconsLabel
            #endif
        }
        set {
            #if DEBUG
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
            NotificationCenter.default.post(name: .premiumPromoVariantDidChange, object: nil)
            #endif
        }
    }

    private static let storageKey = "debug_premium_promo_variant"
}

enum PremiumPromoLayoutStyle {
    case horizontalIcons
    case centeredLaurels
    case landingCarousel
}

enum PremiumPromoIconLayout {
    case stacked
    case none
}

enum PremiumPromoCopy {
    static let homeTitle = "Get more with Premium"
    static let homeSubtitle = "More tools for scheduling, planning, and keeping your sitters in the loop."
    static let settingsTitle = "Unlock NestNote Premium"
    static let settingsSubtitle = "Schedule sessions, share more with sitters, and manage your nest with ease."
    static let tryForFreeCTA = "Try for $0"
    static let learnMoreCTA = "Learn More"

    static func ctaTitle(isFreeTrialEligible: Bool) -> String {
        isFreeTrialEligible ? tryForFreeCTA : learnMoreCTA
    }
}
