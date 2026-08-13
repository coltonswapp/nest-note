//
//  SelectedNestItems.swift
//  nest-note
//

import Foundation

/// Unified selection payload for any nest item types (sessions, folder picker, category edit mode).
struct SelectedNestItems: Equatable {
    var notes: Set<NoteItem>
    var places: Set<PlaceItem>
    var routines: Set<RoutineItem>
    var contacts: Set<ContactItem>
    var unknownItems: Set<UnknownItem>

    init(
        notes: Set<NoteItem> = [],
        places: Set<PlaceItem> = [],
        routines: Set<RoutineItem> = [],
        contacts: Set<ContactItem> = [],
        unknownItems: Set<UnknownItem> = []
    ) {
        self.notes = notes
        self.places = places
        self.routines = routines
        self.contacts = contacts
        self.unknownItems = unknownItems
    }

    /// All selected item IDs in stable order (notes, places, routines, contacts, unknown).
    var allIds: [String] {
        notes.map(\.id)
            + places.map(\.id)
            + routines.map(\.id)
            + contacts.map(\.id)
            + unknownItems.map(\.id)
    }

    static func == (lhs: SelectedNestItems, rhs: SelectedNestItems) -> Bool {
        lhs.notes == rhs.notes
            && lhs.places == rhs.places
            && lhs.routines == rhs.routines
            && lhs.contacts == rhs.contacts
            && lhs.unknownItems == rhs.unknownItems
    }
}
