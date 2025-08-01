//
//  BaseEntry.swift
//  nest-note
//
//  Created by Colton Swapp on 10/26/24.
//

import Foundation

class BaseEntry: BaseItem, Codable, Hashable {
    let id: String
    let type: ItemType = .entry
    var title: String
    var content: String
    var category: String
    var visibility: VisibilityLevel
    let createdAt: Date
    var updatedAt: Date
    
    init(title: String, content: String, visibilityLevel: VisibilityLevel = .always, category: String) {
        self.id = UUID().uuidString
        self.title = title
        self.content = content
        self.visibility = visibilityLevel
        self.category = category
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Add hash function for Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Existing Equatable conformance can stay the same
    static func == (lhs: BaseEntry, rhs: BaseEntry) -> Bool {
        return lhs.id == rhs.id
    }
}
