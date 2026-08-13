//
//  RoutineItem.swift
//  nest-note
//
//  Created by Claude on 2/4/25.
//

import Foundation

class RoutineItem: BaseItem, Codable, Hashable {
    static let maxAttachmentCount = 3

    let id: String
    let type: ItemType = .routine
    var title: String
    var category: String
    let createdAt: Date
    var updatedAt: Date
    var routineActions: [String]
    var frequency: String?
    /// Ordered IDs of attached nest items (any type). Soft references; max 3.
    var attachmentIds: [String]

    enum CodingKeys: String, CodingKey {
        case id, type, title, category, createdAt, updatedAt, routineActions, frequency, attachmentIds
    }

    init(
        title: String,
        category: String,
        routineActions: [String] = [],
        frequency: String? = "Daily",
        attachmentIds: [String] = []
    ) {
        self.id = UUID().uuidString
        self.title = title
        self.category = category
        self.routineActions = routineActions
        self.frequency = frequency
        self.attachmentIds = Self.normalizedAttachmentIds(attachmentIds, excluding: nil)
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    init(
        id: String,
        title: String,
        category: String,
        routineActions: [String],
        frequency: String?,
        createdAt: Date,
        updatedAt: Date,
        attachmentIds: [String] = []
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.routineActions = routineActions
        self.frequency = frequency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.attachmentIds = Self.normalizedAttachmentIds(attachmentIds, excluding: id)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(String.self, forKey: .category)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        routineActions = try container.decodeIfPresent([String].self, forKey: .routineActions) ?? []
        frequency = try container.decodeIfPresent(String.self, forKey: .frequency)
        let decodedIds = try container.decodeIfPresent([String].self, forKey: .attachmentIds) ?? []
        attachmentIds = Self.normalizedAttachmentIds(decodedIds, excluding: id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(category, forKey: .category)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(routineActions, forKey: .routineActions)
        try container.encodeIfPresent(frequency, forKey: .frequency)
        try container.encode(attachmentIds, forKey: .attachmentIds)
    }

    var canAddAction: Bool {
        return routineActions.count < 10
    }

    var canAddAttachment: Bool {
        return attachmentIds.count < Self.maxAttachmentCount
    }

    /// Dedupes, drops empty/self IDs, and caps at `maxAttachmentCount`.
    static func normalizedAttachmentIds(_ ids: [String], excluding hostId: String?) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for id in ids {
            guard !id.isEmpty, id != hostId, !seen.contains(id) else { continue }
            seen.insert(id)
            result.append(id)
            if result.count >= maxAttachmentCount { break }
        }
        return result
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RoutineItem, rhs: RoutineItem) -> Bool {
        return lhs.id == rhs.id
    }
}
