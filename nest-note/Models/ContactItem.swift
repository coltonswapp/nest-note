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
    var phoneNumber: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        category: String,
        title: String,
        phoneNumber: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.phoneNumber = phoneNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
