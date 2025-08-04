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
    case routine = "routine" // Future implementation
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
