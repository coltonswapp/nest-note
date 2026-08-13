//
//  ContactItem.swift
//  nest-note
//

import Foundation

struct ContactItem: BaseItem, Codable {
    let id: String
    let type: ItemType = .contact
    var category: String
    var title: String
    /// Freeform body (phone numbers, notes, etc.). Phone numbers are extracted at call-time.
    var content: String
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, category, title, content, phoneNumber, createdAt, updatedAt
    }

    init(
        id: String = UUID().uuidString,
        category: String,
        title: String,
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(String.self, forKey: .category)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        let decodedContent = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        let legacyPhone = try container.decodeIfPresent(String.self, forKey: .phoneNumber) ?? ""
        if decodedContent.isEmpty, !legacyPhone.isEmpty {
            content = legacyPhone
        } else {
            content = decodedContent
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(category, forKey: .category)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        // Keep writing phoneNumber for older clients / readiness that still read it.
        try container.encode(primaryPhoneNumber ?? "", forKey: .phoneNumber)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    /// Phone numbers detected in `content` (display form from the detector).
    var extractedPhoneNumbers: [String] {
        PhoneNumberExtractor.phoneNumbers(in: content)
    }

    /// First detected phone, if any.
    var primaryPhoneNumber: String? {
        extractedPhoneNumbers.first
    }
}
