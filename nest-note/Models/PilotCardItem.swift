//
//  PilotCardItem.swift
//  nest-note
//
//  Pilot type for the extensible item pipeline. Feature-gated in UI via `FeatureFlag.pilotCardItemsEnabled`.
//

import Foundation

struct PilotCardItem: BaseItem, Codable {
    let id: String
    let type: ItemType = .pilotCard
    var category: String
    var title: String
    var body: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        category: String,
        title: String,
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
