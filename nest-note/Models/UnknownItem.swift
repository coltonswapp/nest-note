//
//  UnknownItem.swift
//  nest-note
//

import Foundation
import FirebaseFirestore

/// Represents a Firestore nest item whose `type` field is not a known `ItemType` for this app build.
/// Preserves the original `type` string on encode/decode so newer clients do not corrupt data.
final class UnknownItem: BaseItem, Codable, Hashable {
    let id: String
    let type: ItemType = .unknownDocument
    var category: String
    var title: String
    let createdAt: Date
    var updatedAt: Date
    let originalTypeString: String

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case title
        case createdAt
        case updatedAt
        case type
    }

    init(
        id: String,
        category: String,
        title: String,
        createdAt: Date,
        updatedAt: Date,
        originalTypeString: String
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.originalTypeString = originalTypeString
    }

    /// Decode from Firestore when `type` is not in `ItemType` or is `.unknownDocument`.
    static func fromFirestore(document: DocumentSnapshot, originalTypeString: String) throws -> UnknownItem {
        guard let data = document.data() else {
            throw FirebaseItemRepository.ItemRepositoryError.documentHasNoData(document.documentID)
        }
        let id = (data["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? document.documentID
        let title = data["title"] as? String ?? "Unsupported item"
        let category = data["category"] as? String ?? "Other"
        let createdAt = Self.decodeDate(data["createdAt"])
        let updatedAt = Self.decodeDate(data["updatedAt"])
        return UnknownItem(
            id: id,
            category: category,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            originalTypeString: originalTypeString
        )
    }

    private static func decodeDate(_ value: Any?) -> Date {
        if let ts = value as? Timestamp {
            return ts.dateValue()
        }
        if let d = value as? Date {
            return d
        }
        return Date()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Other"
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Unsupported item"
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        originalTypeString = try container.decode(String.self, forKey: .type)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(category, forKey: .category)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(originalTypeString, forKey: .type)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: UnknownItem, rhs: UnknownItem) -> Bool {
        lhs.id == rhs.id
    }
}
