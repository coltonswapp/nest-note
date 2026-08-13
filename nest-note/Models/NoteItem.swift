//
//  NoteItem.swift
//  nest-note
//
//  Created by Colton Swapp on 10/26/24.
//

import Foundation

class NoteItem: BaseItem, Codable, Hashable {
    static let maxAttachmentCount = 3

    let id: String
    let type: ItemType = .entry
    var title: String
    var content: String
    var category: String
    let createdAt: Date
    var updatedAt: Date
    /// Ordered IDs of attached nest items (any type). Soft references; max 3.
    var attachmentIds: [String]

    enum CodingKeys: String, CodingKey {
        case id, type, title, content, category, createdAt, updatedAt, attachmentIds
    }

    init(title: String, content: String, category: String, attachmentIds: [String] = []) {
        self.id = UUID().uuidString
        self.title = title
        self.content = content
        self.category = category
        self.attachmentIds = Self.normalizedAttachmentIds(attachmentIds, excluding: nil)
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    init(
        id: String,
        title: String,
        content: String,
        category: String,
        createdAt: Date,
        updatedAt: Date,
        attachmentIds: [String] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.attachmentIds = Self.normalizedAttachmentIds(attachmentIds, excluding: id)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        category = try container.decode(String.self, forKey: .category)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        let decodedIds = try container.decodeIfPresent([String].self, forKey: .attachmentIds) ?? []
        attachmentIds = Self.normalizedAttachmentIds(decodedIds, excluding: id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(category, forKey: .category)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(attachmentIds, forKey: .attachmentIds)
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

    static func == (lhs: NoteItem, rhs: NoteItem) -> Bool {
        return lhs.id == rhs.id
    }
}
