import Foundation

struct NestReadinessEssential: Hashable {
    let title: String
    let matchTokens: [String]
    let categoryName: String
    let iconName: String
    let preferredItemType: ItemType

    static let catalog: [NestReadinessEssential] = [
        NestReadinessEssential(
            title: "WiFi Password",
            matchTokens: ["wifi", "wi-fi", "internet"],
            categoryName: "Household",
            iconName: "wifi",
            preferredItemType: .entry
        ),
        NestReadinessEssential(
            title: "Garage Code",
            matchTokens: ["garage"],
            categoryName: "Household",
            iconName: "car.garage",
            preferredItemType: .entry
        ),
        NestReadinessEssential(
            title: "Front Door Code",
            matchTokens: ["front door", "door code", "door"],
            categoryName: "Household",
            iconName: "door.left.hand.closed",
            preferredItemType: .entry
        ),
        NestReadinessEssential(
            title: "Alarm Code",
            matchTokens: ["alarm"],
            categoryName: "Household",
            iconName: "bell.fill",
            preferredItemType: .entry
        ),
        NestReadinessEssential(
            title: "Emergency Contact",
            matchTokens: ["emergency contact", "emergency"],
            categoryName: "Emergency",
            iconName: "phone.fill",
            preferredItemType: .contact
        ),
        NestReadinessEssential(
            title: "Allergies",
            matchTokens: ["allerg", "epipen", "epi pen"],
            categoryName: "Emergency",
            iconName: "cross.case.fill",
            preferredItemType: .entry
        ),
        NestReadinessEssential(
            title: "Nearest Hospital",
            matchTokens: ["hospital", "urgent care"],
            categoryName: "Emergency",
            iconName: "cross.fill",
            preferredItemType: .place
        ),
        NestReadinessEssential(
            title: "Poison Control",
            matchTokens: ["poison"],
            categoryName: "Emergency",
            iconName: "exclamationmark.triangle.fill",
            preferredItemType: .entry
        ),
        NestReadinessEssential(
            title: "Bedtime Routine",
            matchTokens: ["bedtime", "bed time"],
            categoryName: "Household",
            iconName: "moon.stars.fill",
            preferredItemType: .routine
        ),
        NestReadinessEssential(
            title: "Morning Wake Up",
            matchTokens: ["morning", "wake up", "wake-up"],
            categoryName: "Household",
            iconName: "sunrise.fill",
            preferredItemType: .routine
        ),
        NestReadinessEssential(
            title: "After School",
            matchTokens: ["after school", "after-school"],
            categoryName: "Household",
            iconName: "backpack.fill",
            preferredItemType: .routine
        ),
        NestReadinessEssential(
            title: "School",
            matchTokens: ["school"],
            categoryName: "Household",
            iconName: "graduationcap.fill",
            preferredItemType: .place
        ),
        NestReadinessEssential(
            title: "Pet Care",
            matchTokens: ["pet care", "dog food", "cat", "leash"],
            categoryName: "Pets",
            iconName: "pawprint.fill",
            preferredItemType: .routine
        ),
        NestReadinessEssential(
            title: "Thermostat",
            matchTokens: ["thermostat", "temperature", "heat", "ac"],
            categoryName: "Household",
            iconName: "thermometer.medium",
            preferredItemType: .entry
        ),
        NestReadinessEssential(
            title: "Trash Day",
            matchTokens: ["trash", "recycling", "garbage"],
            categoryName: "Household",
            iconName: "trash.fill",
            preferredItemType: .entry
        )
    ]
}
