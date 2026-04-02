//
//  BaseItem.swift
//  nest-note
//
//  Created by Claude on 1/30/25.
//

import Foundation

// MARK: - ItemType Enumeration
enum ItemType: String, CaseIterable, Codable {
    case entry = "entry"
    case place = "place"
    case routine = "routine"
    /// Placeholder for documents whose `type` string is not recognized by this app version.
    case unknownDocument = "unknown_document"
    /// Pilot extensibility type (see `PilotCardItem`); register new kinds in `ItemDecoderRegistry`.
    case pilotCard = "pilot_card"
    /// Phone contact (see `ContactItem`).
    case contact = "contact"
}

// MARK: - BaseItem Protocol
protocol BaseItem: Codable, Hashable, Identifiable {
    var id: String { get }
    var type: ItemType { get }
    var category: String { get set }
    var title: String { get set }
    var createdAt: Date { get }
    var updatedAt: Date { get set }
}

// MARK: - Default Implementations
extension BaseItem {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
}
