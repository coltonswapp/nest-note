//
//  SelectedNestItems.swift
//  nest-note
//

import Foundation

/// Unified selection payload for any nest item types (sessions, folder picker, category edit mode).
struct SelectedNestItems: Equatable {
    var entries: Set<BaseEntry>
    var places: Set<PlaceItem>
    var routines: Set<RoutineItem>
    var pilotCards: Set<PilotCardItem>
    var contacts: Set<ContactItem>
    var unknownItems: Set<UnknownItem>

    init(
        entries: Set<BaseEntry> = [],
        places: Set<PlaceItem> = [],
        routines: Set<RoutineItem> = [],
        pilotCards: Set<PilotCardItem> = [],
        contacts: Set<ContactItem> = [],
        unknownItems: Set<UnknownItem> = []
    ) {
        self.entries = entries
        self.places = places
        self.routines = routines
        self.pilotCards = pilotCards
        self.contacts = contacts
        self.unknownItems = unknownItems
    }

    /// All selected item IDs in stable order (entries, places, routines, pilot, contacts, unknown).
    var allIds: [String] {
        entries.map(\.id)
            + places.map(\.id)
            + routines.map(\.id)
            + pilotCards.map(\.id)
            + contacts.map(\.id)
            + unknownItems.map(\.id)
    }

    static func == (lhs: SelectedNestItems, rhs: SelectedNestItems) -> Bool {
        lhs.entries == rhs.entries
            && lhs.places == rhs.places
            && lhs.routines == rhs.routines
            && lhs.pilotCards == rhs.pilotCards
            && lhs.contacts == rhs.contacts
            && lhs.unknownItems == rhs.unknownItems
    }
}
