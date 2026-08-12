//
//  DemoNestSeed.swift
//  nest-note
//
//  Shared fictional household used by onboarding folder preview and the demo-nest seeder.
//

import CoreLocation
import Foundation
import UIKit

enum DemoNestSeed {
    static let nestName = "The Hart Nest"
    static let nestAddress = "414 Maple Street, Austin, TX"

    struct FolderSpec {
        let name: String
        let symbolName: String
        let isPinned: Bool
        let items: [ItemSpec]
    }

    enum ItemSpec {
        case note(title: String, content: String)
        case routine(title: String, actions: [String])
        case place(title: String, address: String, coordinate: CLLocationCoordinate2D, previewContent: String, mapPlaceholderName: String?)
    }

    static let folders: [FolderSpec] = [
        FolderSpec(name: "Household", symbolName: "house.fill", isPinned: true, items: householdItems),
        FolderSpec(name: "Children", symbolName: "figure.child", isPinned: true, items: childrenItems),
        FolderSpec(name: "Pets", symbolName: "pawprint.fill", isPinned: true, items: petsItems),
        FolderSpec(name: "Plants", symbolName: "leaf.fill", isPinned: false, items: plantsItems)
    ]

    static func folder(named name: String) -> FolderSpec? {
        folders.first { $0.name == name }
    }

    static func items(forFolderName name: String) -> [ItemSpec] {
        switch name {
        case "Children", "Kids":
            return childrenItems
        case "Pets":
            return petsItems
        case "Plants":
            return plantsItems
        default:
            return householdItems
        }
    }

    private static let householdItems: [ItemSpec] = [
        .note(title: "WiFi Password", content: "SuperStrongPassword"),
        .note(title: "Garage Code", content: "8005"),
        .routine(title: "Leaving House", actions: [
            "Check all doors", "Turn off lights", "Dog in kennel", "Arm security system"
        ]),
        .note(title: "Trash Day", content: "Bins out Tuesday night. Recycling only when above halfway full (blue bin)."),
        .note(title: "Alarm Code", content: "4321 — disarm within 30 seconds of opening the door."),
        .routine(title: "Coming Home", actions: [
            "Disarm alarm", "Hang keys by door", "Unpack bags", "Wash hands"
        ]),
        .note(title: "Thermostat", content: "Keep around 68°F. Away mode is fine overnight."),
        .note(title: "Water Shutoff", content: "Basement, north wall — red valve."),
        .place(
            title: "Neighbor Help",
            address: "418 Maple Street, Austin, TX",
            coordinate: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
            previewContent: "Mrs. Wilson — (555) 234-5678",
            mapPlaceholderName: "map-placeholder2"
        )
    ]

    private static let childrenItems: [ItemSpec] = [
        .note(title: "Allergies", content: "Peanuts and penicillin. EpiPen on the top shelf in the pantry."),
        .routine(title: "Bedtime Routine", actions: [
            "Brush teeth", "Put on pajamas", "Read a story", "Turn on nightlight", "Close door halfway"
        ]),
        .note(title: "School Office", content: "(555) 111-2222 — ask for the front desk."),
        .routine(title: "After School", actions: [
            "Hang up backpack", "Wash hands", "Have a snack", "Start homework"
        ]),
        .note(title: "Pediatrician", content: "Dr. Smith — (555) 987-6543"),
        .routine(title: "Bath Time", actions: [
            "Fill tub to marked line", "Wash hair", "Rinse thoroughly", "Dry off and lotion"
        ]),
        .note(title: "Screen Time", content: "45 minutes max after homework. Keep volume reasonable."),
        .place(
            title: "School",
            address: "Lincoln Elementary, Austin, TX",
            coordinate: CLLocationCoordinate2D(latitude: 30.2849, longitude: -97.7341),
            previewContent: "Lincoln Elementary — drop-off at the main loop.",
            mapPlaceholderName: "map-placeholder1"
        ),
        .place(
            title: "Soccer Practice",
            address: "Rec Center Field 2, Austin, TX",
            coordinate: CLLocationCoordinate2D(latitude: 30.2600, longitude: -97.7530),
            previewContent: "Thursday 4:30pm at Rec Center Field 2.",
            mapPlaceholderName: "map-placeholder4"
        )
    ]

    private static let petsItems: [ItemSpec] = [
        .note(title: "Pet Names", content: "Dog: Max · Cat: Luna · Fish: Bubbles"),
        .routine(title: "Pet Care", actions: [
            "Fill water bowl", "Give food", "Let outside / litter check", "Play for 10 minutes"
        ]),
        .note(title: "Dog Food", content: "1 cup morning and evening. Food is in the pantry bin."),
        .note(title: "Treat Rules", content: "Max 2 treats per day — no chocolate, ever."),
        .note(title: "Leash Location", content: "Hanging by the front door with the poop bags."),
        .note(title: "No-Go Areas", content: "Keep pets out of the formal dining room and guest bedroom."),
        .note(title: "Veterinarian", content: "Animal Hospital — (555) 789-4561"),
        .note(title: "Pet Sitter", content: "Emily — (555) 222-3333"),
        .place(
            title: "Favorite Park",
            address: "Zilker Park, Austin, TX",
            coordinate: CLLocationCoordinate2D(latitude: 30.2669, longitude: -97.7729),
            previewContent: "Sunrise Meadow Park — Max's usual walk loop.",
            mapPlaceholderName: "map-placeholder3"
        )
    ]

    private static let plantsItems: [ItemSpec] = [
        .note(title: "Watering Schedule", content: "Most houseplants: every 7–10 days. Check soil first — if damp, wait."),
        .routine(title: "Plant Care", actions: [
            "Check soil moisture", "Water until it drains", "Empty saucers", "Rotate pots a quarter turn"
        ]),
        .note(title: "Fiddle Leaf Fig", content: "Bright indirect light by the living room window. Water sparingly."),
        .note(title: "Herbs on Sill", content: "Basil & mint — water when the top inch is dry. Snip often."),
        .note(title: "Succulents", content: "Kitchen shelf. Water lightly every 2–3 weeks. No misting."),
        .note(title: "Plant Food", content: "Liquid fertilizer under the sink. Use half-strength monthly in summer."),
        .note(title: "Yard Service", content: "Every Monday, 11am–2pm. Leave the side gate unlocked."),
        .note(title: "Outdoor Hose", content: "Spigot on the east side. Timer is set for early mornings."),
        .place(
            title: "Garden Bed",
            address: "414 Maple Street backyard, Austin, TX",
            coordinate: CLLocationCoordinate2D(latitude: 30.2650, longitude: -97.7500),
            previewContent: "Backyard raised beds — tomatoes & peppers along the fence.",
            mapPlaceholderName: "map-placeholder5"
        )
    ]

    /// Local map asset used when the demo nest has no Storage thumbnails.
    static func placeholderImage(for place: PlaceItem) -> UIImage? {
        placeholderImage(forPlaceTitle: place.alias ?? place.title)
    }

    static func placeholderImage(forPlaceTitle title: String) -> UIImage? {
        UIImage(named: mapPlaceholderName(forPlaceTitle: title))
    }

    static func usesMapPlaceholder(for place: PlaceItem) -> Bool {
        DemoModeService.shared.isActive && place.thumbnailURLs == nil
    }

    static func mapPlaceholderName(forPlaceTitle title: String) -> String {
        for folder in folders {
            for item in folder.items {
                if case .place(let placeTitle, _, _, _, let name) = item,
                   placeTitle.compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame,
                   let name {
                    return name
                }
            }
        }
        let index = (abs(title.hashValue) % 5) + 1
        return "map-placeholder\(index)"
    }
}
