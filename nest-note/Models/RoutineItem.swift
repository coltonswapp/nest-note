//
//  RoutineItem.swift
//  nest-note
//
//  Created by Claude on 2/4/25.
//

import Foundation

class RoutineItem: BaseItem, Codable, Hashable {
    let id: String
    let type: ItemType = .routine
    var title: String
    var category: String
    let createdAt: Date
    var updatedAt: Date
    var routineActions: [String]
    var frequency: String?
    
    init(title: String, category: String, routineActions: [String] = [], frequency: String? = "Daily") {
        self.id = UUID().uuidString
        self.title = title
        self.category = category
        self.routineActions = routineActions
        self.frequency = frequency
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    init(id: String, title: String, category: String, routineActions: [String], frequency: String?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.title = title
        self.category = category
        self.routineActions = routineActions
        self.frequency = frequency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var canAddAction: Bool {
        return routineActions.count < 10
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RoutineItem, rhs: RoutineItem) -> Bool {
        return lhs.id == rhs.id
    }
}