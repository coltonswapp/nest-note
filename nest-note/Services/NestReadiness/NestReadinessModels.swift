import UIKit

enum NestReadinessTier: String, CaseIterable {
    case emptyNest
    case gettingStarted
    case sitterReady
    case wellDocumented
    case overPrepared
    case nestExpert

    static func tier(for score: Int) -> NestReadinessTier {
        switch score {
        case 0..<20: return .emptyNest
        case 20..<40: return .gettingStarted
        case 40..<60: return .sitterReady
        case 60..<80: return .wellDocumented
        case 80..<95: return .overPrepared
        default: return .nestExpert
        }
    }

    var displayName: String {
        switch self {
        case .emptyNest: return "Empty Nest"
        case .gettingStarted: return "Getting Started"
        case .sitterReady: return "Sitter Ready"
        case .wellDocumented: return "Well Documented"
        case .overPrepared: return "Over-Prepared"
        case .nestExpert: return "Nest Expert"
        }
    }
}

enum NestReadinessComponent: String, CaseIterable {
    case itemsDocumented
    case itemTypes
    case categoriesFilled
    case essentialsCovered
    case proSubscription
    case notificationsEnabled

    var title: String {
        switch self {
        case .itemsDocumented: return "Items documented"
        case .itemTypes: return "Item types"
        case .categoriesFilled: return "Categories filled"
        case .essentialsCovered: return "Essentials covered"
        case .proSubscription: return "Pro subscription"
        case .notificationsEnabled: return "Notifications enabled"
        }
    }

    var maxPoints: Int {
        switch self {
        case .itemsDocumented: return 33
        case .itemTypes: return 17
        case .categoriesFilled: return 21
        case .essentialsCovered: return 13
        case .proSubscription: return 8
        case .notificationsEnabled: return 8
        }
    }

    static var totalMaxPoints: Int {
        allCases.reduce(0) { $0 + $1.maxPoints }
    }

    var accentColor: UIColor {
        NestReadinessColors.componentAccent(for: self)
    }

    var expansionText: String {
        switch self {
        case .itemsDocumented:
            return "Add entries, places, routines, and contacts. More items help your score, with the biggest gains in your first ~30 items."
        case .itemTypes:
            return "Use all four item types: text entries, important places, routines, and phone contacts."
        case .categoriesFilled:
            return "Add at least one item to each folder in your nest, including Household and Emergency."
        case .essentialsCovered:
            return "Cover common sitter essentials like WiFi, emergency contacts, and bedtime routines."
        case .proSubscription:
            return "Pro subscribers receive a \(maxPoints)-point boost to their Nest Score."
        case .notificationsEnabled:
            return "Turn on notifications to stay in the loop about sessions and your nest."
        }
    }

    var symbolName: String {
        switch self {
        case .itemsDocumented: return "doc.text.fill"
        case .itemTypes: return "square.grid.2x2.fill"
        case .categoriesFilled: return "folder.fill"
        case .essentialsCovered: return "checkmark.seal.fill"
        case .proSubscription: return "creditcard.fill"
        case .notificationsEnabled: return "bell.fill"
        }
    }
}

struct NestReadinessComponentScore: Hashable {
    let component: NestReadinessComponent
    let earnedPoints: Int
    let detailText: String
    let statusSubtitle: String?

    var maxPoints: Int { component.maxPoints }
    var progress: CGFloat {
        guard maxPoints > 0 else { return 0 }
        return CGFloat(earnedPoints) / CGFloat(maxPoints)
    }
}

enum NestReadinessBoostKind: Hashable {
    case essential(NestReadinessEssential)
    case missingItemType(ItemType)
    case emptyCategory(String)
    case proSubscription
    case notificationsEnabled
}

struct NestReadinessBoostSuggestion: Hashable {
    let id: String
    let title: String
    let subtitle: String
    let pointsAvailable: Int
    let categoryName: String
    let iconName: String
    let kind: NestReadinessBoostKind

    init(
        title: String,
        subtitle: String,
        pointsAvailable: Int,
        categoryName: String,
        iconName: String,
        kind: NestReadinessBoostKind
    ) {
        self.id = "\(title)-\(categoryName)-\(pointsAvailable)"
        self.title = title
        self.subtitle = subtitle
        self.pointsAvailable = pointsAvailable
        self.categoryName = categoryName
        self.iconName = iconName
        self.kind = kind
    }
}

struct NestReadinessResult: Hashable {
    let totalScore: Int
    let tier: NestReadinessTier
    let components: [NestReadinessComponentScore]
    let boostSuggestions: [NestReadinessBoostSuggestion]
    let qualifyingItemCount: Int

    var tierLabel: String { tier.displayName }

    func componentScore(for component: NestReadinessComponent) -> NestReadinessComponentScore? {
        components.first { $0.component == component }
    }

    var componentProgressValues: [CGFloat] {
        NestReadinessComponent.allCases.map { component in
            componentScore(for: component)?.progress ?? 0
        }
    }
}

enum NestReadinessColors {
    static let deepGreen = NNColors.EventColors.green.border
    static let midGreen = NNColors.primary
    static let brightGreen = NNColors.EventColors.green.fill
    static let paleGreen = UIColor(red: 196/255, green: 248/255, blue: 220/255, alpha: 1)

    static func componentAccent(for component: NestReadinessComponent) -> UIColor {
        switch component {
        case .itemsDocumented: return deepGreen
        case .itemTypes: return midGreen
        case .categoriesFilled: return brightGreen
        case .essentialsCovered: return UIColor(red: 72/255, green: 210/255, blue: 140/255, alpha: 1)
        case .proSubscription: return midGreen
        case .notificationsEnabled: return midGreen
        }
    }

    static var bannerBackground: UIColor { .secondarySystemGroupedBackground }
    static var progressTrack: UIColor { UIColor.systemGray5 }
    static var progressFill: UIColor { midGreen }
    static var bannerBorder: UIColor { UIColor.separator.withAlphaComponent(0.35) }
}
