//
//  EntryItem.swift
//  nest-note
//
//  Created by Claude on 1/30/25.
//

import Foundation

struct EntryItem: BaseItem {
    let id: String
    let type: ItemType = .entry
    var category: String
    var title: String
    var content: String
    var visibility: VisibilityLevel
    let createdAt: Date
    var updatedAt: Date
    
    init(id: String = UUID().uuidString,
         title: String,
         content: String,
         category: String,
         visibility: VisibilityLevel = .always,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.visibility = visibility
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Conversion from BaseEntry
    init(from baseEntry: BaseEntry) {
        self.id = baseEntry.id
        self.title = baseEntry.title
        self.content = baseEntry.content
        self.category = baseEntry.category
        self.visibility = baseEntry.visibility
        self.createdAt = baseEntry.createdAt
        self.updatedAt = baseEntry.updatedAt
    }
    
    // MARK: - Conversion to BaseEntry
    func toBaseEntry() -> BaseEntry {
        return BaseEntry(
            id: id,
            title: title,
            content: content,
            visibilityLevel: visibility,
            category: category,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
