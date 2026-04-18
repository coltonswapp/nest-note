//
//  ItemBuckets.swift
//  nest-note
//

import Foundation

/// Groups `[BaseItem]` by `ItemType` for folder math and UI without hard-coded triples.
struct ItemBuckets {
    let allItems: [BaseItem]
    private let grouped: [ItemType: [BaseItem]]

    init(items: [BaseItem]) {
        self.allItems = items
        self.grouped = Dictionary(grouping: items, by: { $0.type })
    }

    var entries: [BaseEntry] {
        grouped[.entry]?.compactMap { $0 as? BaseEntry } ?? []
    }

    var places: [PlaceItem] {
        grouped[.place]?.compactMap { $0 as? PlaceItem } ?? []
    }

    var routines: [RoutineItem] {
        grouped[.routine]?.compactMap { $0 as? RoutineItem } ?? []
    }

    var pilotCards: [PilotCardItem] {
        grouped[.pilotCard]?.compactMap { $0 as? PilotCardItem } ?? []
    }

    var contacts: [ContactItem] {
        grouped[.contact]?.compactMap { $0 as? ContactItem } ?? []
    }

    var unknownItems: [UnknownItem] {
        grouped[.unknownDocument]?.compactMap { $0 as? UnknownItem } ?? []
    }

    func items(inCategory category: String) -> ItemBuckets {
        let filtered = allItems.filter { $0.category == category }
        return ItemBuckets(items: filtered)
    }
}
