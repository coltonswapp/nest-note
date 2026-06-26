import Foundation
import UserNotifications

final class NestReadinessService {
    static let shared = NestReadinessService()

    private let nestService: NestService
    private var cachedResult: NestReadinessResult?
    private var cachedNestId: String?

    init(nestService: NestService = .shared) {
        self.nestService = nestService
    }

    func invalidateCache() {
        cachedResult = nil
        cachedNestId = nil
    }

    private func notificationsAreAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    func calculateReadiness(forceRefresh: Bool = false) async throws -> NestReadinessResult {
        if !forceRefresh,
           let cachedResult,
           cachedNestId == nestService.currentNest?.id {
            return cachedResult
        }

        let items = try await nestService.fetchAllItems()
        let categories = try await nestService.fetchCategories()
        let hasProSubscription = await SubscriptionService.shared.hasProSubscription()
        let hasNotificationsEnabled = await notificationsAreAuthorized()
        let result = buildResult(
            items: items,
            categories: categories,
            hasProSubscription: hasProSubscription,
            hasNotificationsEnabled: hasNotificationsEnabled
        )

        cachedResult = result
        cachedNestId = nestService.currentNest?.id
        return result
    }

    // MARK: - Scoring

    private func buildResult(
        items: [BaseItem],
        categories: [NestCategory],
        hasProSubscription: Bool,
        hasNotificationsEnabled: Bool
    ) -> NestReadinessResult {
        let qualifyingItems = items.filter(isQualifyingItem)
        let itemPoints = scoreItemCount(qualifyingItems.count)
        let typePoints = scoreItemTypes(from: qualifyingItems)
        let categoryData = scoreCategories(items: qualifyingItems, categories: categories)
        let essentialData = scoreEssentials(from: qualifyingItems, categories: categories)

        let itemMaxPoints = NestReadinessComponent.itemsDocumented.maxPoints
        let proMaxPoints = NestReadinessComponent.proSubscription.maxPoints
        let notificationsMaxPoints = NestReadinessComponent.notificationsEnabled.maxPoints

        let components: [NestReadinessComponentScore] = [
            NestReadinessComponentScore(
                component: .itemsDocumented,
                earnedPoints: itemPoints,
                detailText: "\(qualifyingItems.count) items",
                statusSubtitle: itemPoints < Int(Double(itemMaxPoints) * 0.75) ? "Add more entries and places" : nil
            ),
            NestReadinessComponentScore(
                component: .itemTypes,
                earnedPoints: typePoints.earned,
                detailText: typePoints.detail,
                statusSubtitle: typePoints.statusSubtitle
            ),
            NestReadinessComponentScore(
                component: .categoriesFilled,
                earnedPoints: categoryData.earned,
                detailText: categoryData.detail,
                statusSubtitle: categoryData.statusSubtitle
            ),
            NestReadinessComponentScore(
                component: .essentialsCovered,
                earnedPoints: essentialData.earned,
                detailText: essentialData.detail,
                statusSubtitle: essentialData.statusSubtitle
            ),
            NestReadinessComponentScore(
                component: .proSubscription,
                earnedPoints: hasProSubscription ? proMaxPoints : 0,
                detailText: hasProSubscription ? "Active" : "Not subscribed",
                statusSubtitle: hasProSubscription ? nil : "Upgrade for +\(proMaxPoints) points"
            ),
            NestReadinessComponentScore(
                component: .notificationsEnabled,
                earnedPoints: hasNotificationsEnabled ? notificationsMaxPoints : 0,
                detailText: hasNotificationsEnabled ? "Enabled" : "Not enabled",
                statusSubtitle: hasNotificationsEnabled ? nil : "Enable for +\(notificationsMaxPoints) points"
            )
        ]

        let totalScore = components.reduce(0) { $0 + $1.earnedPoints }
        let tier = NestReadinessTier.tier(for: totalScore)
        let boosts = buildBoostSuggestions(
            items: qualifyingItems,
            categories: categories,
            typePoints: typePoints,
            categoryData: categoryData,
            coveredEssentials: essentialData.covered,
            missingEssentials: essentialData.missing,
            hasProSubscription: hasProSubscription,
            hasNotificationsEnabled: hasNotificationsEnabled
        )

        return NestReadinessResult(
            totalScore: totalScore,
            tier: tier,
            components: components,
            boostSuggestions: boosts,
            qualifyingItemCount: qualifyingItems.count
        )
    }

    private func scoreItemCount(_ count: Int) -> Int {
        let maxPoints = NestReadinessComponent.itemsDocumented.maxPoints
        let raw = Double(maxPoints) * (1.0 - exp(-Double(count) / 15.0))
        return min(maxPoints, Int(raw.rounded()))
    }

    private func scoreItemTypes(from items: [BaseItem]) -> (earned: Int, detail: String, statusSubtitle: String?) {
        let presentTypes = Set(items.map(\.type))
        let scoredTypes: [ItemType] = [.entry, .place, .routine, .contact]
        let presentCount = scoredTypes.filter { presentTypes.contains($0) }.count
        let maxPoints = NestReadinessComponent.itemTypes.maxPoints
        let earned = Int((Double(presentCount) / Double(scoredTypes.count) * Double(maxPoints)).rounded())
        let detail = "\(presentCount) of 4 types"
        let missing = scoredTypes.filter { !presentTypes.contains($0) }
        let statusSubtitle: String? = missing.isEmpty ? nil : "Missing: \(missing.map(displayName(for:)).joined(separator: ", "))"
        return (earned, detail, statusSubtitle)
    }

    private func scoreCategories(items: [BaseItem], categories: [NestCategory]) -> (earned: Int, detail: String, statusSubtitle: String?, emptyCategories: [String], applicableCount: Int) {
        var expectedNames = Set(categories.map(\.name))
        expectedNames.insert("Household")
        expectedNames.insert("Emergency")

        let applicable = expectedNames.sorted()
        guard !applicable.isEmpty else {
            return (0, "0 folders", "Add nest folders", applicable, applicable.count)
        }

        let filled = applicable.filter { categoryHasItems($0, in: items) }
        let empty = applicable.filter { !categoryHasItems($0, in: items) }
        let ratio = Double(filled.count) / Double(applicable.count)
        let maxPoints = NestReadinessComponent.categoriesFilled.maxPoints
        let earned = Int((ratio * Double(maxPoints)).rounded())
        let detail = "\(filled.count) of \(applicable.count) folders"
        let statusSubtitle: String? = empty.first.map { "\($0) folder is empty" }
        return (earned, detail, statusSubtitle, empty, applicable.count)
    }

    private func scoreEssentials(from items: [BaseItem], categories: [NestCategory]) -> (earned: Int, detail: String, statusSubtitle: String?, covered: Set<NestReadinessEssential>, missing: [NestReadinessEssential]) {
        let applicableEssentials = applicableEssentials(for: categories)
        let covered = Set(applicableEssentials.filter { essential in
            items.contains { matchesEssential(essential, item: $0) }
        })
        let missing = applicableEssentials.filter { !covered.contains($0) }
        let maxPoints = NestReadinessComponent.essentialsCovered.maxPoints
        let earned = min(maxPoints, covered.count)
        let detail = "\(covered.count) of \(applicableEssentials.count) essentials"
        let statusSubtitle: String? = missing.isEmpty ? nil : "\(missing.count) essentials still missing"
        return (earned, detail, statusSubtitle, covered, missing)
    }

    private func applicableEssentials(for categories: [NestCategory]) -> [NestReadinessEssential] {
        let categoryNames = Set(categories.map(\.name))
        let hasPets = categoryNames.contains("Pets")
        return NestReadinessEssential.catalog.filter { essential in
            if essential.categoryName == "Pets" {
                return hasPets
            }
            return true
        }
    }

    private func buildBoostSuggestions(
        items: [BaseItem],
        categories: [NestCategory],
        typePoints: (earned: Int, detail: String, statusSubtitle: String?),
        categoryData: (earned: Int, detail: String, statusSubtitle: String?, emptyCategories: [String], applicableCount: Int),
        coveredEssentials: Set<NestReadinessEssential>,
        missingEssentials: [NestReadinessEssential],
        hasProSubscription: Bool,
        hasNotificationsEnabled: Bool
    ) -> [NestReadinessBoostSuggestion] {
        var suggestions: [NestReadinessBoostSuggestion] = []

        if !hasProSubscription {
            suggestions.append(
                NestReadinessBoostSuggestion(
                    title: "Upgrade to Nest Note Pro",
                    subtitle: "Unlock premium features and boost your score",
                    pointsAvailable: NestReadinessComponent.proSubscription.maxPoints,
                    categoryName: "Subscription",
                    iconName: "creditcard.fill",
                    kind: .proSubscription
                )
            )
        }

        if !hasNotificationsEnabled {
            suggestions.append(
                NestReadinessBoostSuggestion(
                    title: "Turn on notifications",
                    subtitle: "Stay in the loop about sessions and your nest",
                    pointsAvailable: NestReadinessComponent.notificationsEnabled.maxPoints,
                    categoryName: "Notifications",
                    iconName: "bell.fill",
                    kind: .notificationsEnabled
                )
            )
        }

        for essential in missingEssentials {
            suggestions.append(
                NestReadinessBoostSuggestion(
                    title: "Add \(essential.title)",
                    subtitle: essential.categoryName,
                    pointsAvailable: 1,
                    categoryName: essential.categoryName,
                    iconName: essential.iconName,
                    kind: .essential(essential)
                )
            )
        }

        let scoredTypes: [ItemType] = [.entry, .place, .routine, .contact]
        let itemTypeMaxPoints = NestReadinessComponent.itemTypes.maxPoints
        let pointsPerItemType = max(1, itemTypeMaxPoints / scoredTypes.count)
        let presentTypes = Set(items.map(\.type))
        for type in scoredTypes where !presentTypes.contains(type) {
            suggestions.append(
                NestReadinessBoostSuggestion(
                    title: boostTitle(for: type),
                    subtitle: "Covers all folders",
                    pointsAvailable: pointsPerItemType,
                    categoryName: "Household",
                    iconName: iconName(for: type),
                    kind: .missingItemType(type)
                )
            )
        }

        let categoryMaxPoints = NestReadinessComponent.categoriesFilled.maxPoints
        let pointsPerCategory = max(1, categoryMaxPoints / max(1, categoryData.applicableCount))
        for categoryName in categoryData.emptyCategories {
            let icon = categories.first(where: { $0.name == categoryName })?.symbolName ?? "folder.fill"
            suggestions.append(
                NestReadinessBoostSuggestion(
                    title: "Fill \(categoryName)",
                    subtitle: "Add any item to this folder",
                    pointsAvailable: pointsPerCategory,
                    categoryName: categoryName,
                    iconName: icon,
                    kind: .emptyCategory(categoryName)
                )
            )
        }

        if suggestions.isEmpty, items.count < 30 {
            suggestions.append(
                NestReadinessBoostSuggestion(
                    title: "Add more nest items",
                    subtitle: "Entries, places, routines, and contacts all count",
                    pointsAvailable: 2,
                    categoryName: "Household",
                    iconName: "plus.circle.fill",
                    kind: .emptyCategory("Household")
                )
            )
        }

        return Array(
            suggestions
                .sorted { lhs, rhs in
                    if lhs.pointsAvailable != rhs.pointsAvailable {
                        return lhs.pointsAvailable > rhs.pointsAvailable
                    }
                    return lhs.title < rhs.title
                }
                .prefix(12)
        )
    }

    // MARK: - Item validation

    private func isQualifyingItem(_ item: BaseItem) -> Bool {
        switch item.type {
        case .entry:
            guard let entry = item as? BaseEntry else { return false }
            return entry.content.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
        case .contact:
            guard let contact = item as? ContactItem else { return false }
            let digits = contact.phoneNumber.filter(\.isNumber)
            return digits.count >= 7
        case .routine:
            guard let routine = item as? RoutineItem else { return false }
            return routine.routineActions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count >= 2
        case .place:
            return true
        case .pilotCard, .unknownDocument:
            return false
        }
    }

    private func categoryHasItems(_ categoryName: String, in items: [BaseItem]) -> Bool {
        items.contains { item in
            let topLevel = item.category.components(separatedBy: "/").first ?? item.category
            return topLevel.caseInsensitiveCompare(categoryName) == .orderedSame
        }
    }

    private func matchesEssential(_ essential: NestReadinessEssential, item: BaseItem) -> Bool {
        if item.type != essential.preferredItemType {
            return false
        }

        let normalizedTitle = normalize(item.title)
        let normalizedContent: String = {
            if let entry = item as? BaseEntry { return normalize(entry.content) }
            if let contact = item as? ContactItem { return normalize(contact.phoneNumber) }
            if let routine = item as? RoutineItem { return normalize(routine.routineActions.joined(separator: " ")) }
            return ""
        }()

        return essential.matchTokens.contains { token in
            let normalizedToken = normalize(token)
            return normalizedTitle.contains(normalizedToken)
                || normalizedContent.contains(normalizedToken)
                || normalizedToken.contains(normalizedTitle)
        }
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func displayName(for type: ItemType) -> String {
        switch type {
        case .entry: return "Entries"
        case .place: return "Places"
        case .routine: return "Routines"
        case .contact: return "Contacts"
        case .pilotCard: return "Cards"
        case .unknownDocument: return "Items"
        }
    }

    private func boostTitle(for type: ItemType) -> String {
        switch type {
        case .entry: return "Add an entry"
        case .place: return "Add a place"
        case .routine: return "Add a routine"
        case .contact: return "Add a contact"
        case .pilotCard: return "Add a card"
        case .unknownDocument: return "Add an item"
        }
    }

    private func iconName(for type: ItemType) -> String {
        switch type {
        case .entry: return "doc.text.fill"
        case .place: return "mappin.and.ellipse"
        case .routine: return "checklist"
        case .contact: return "phone.fill"
        case .pilotCard: return "rectangle.on.rectangle"
        case .unknownDocument: return "doc.fill"
        }
    }
}
