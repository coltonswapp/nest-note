//
//  NestItem.swift
//  nest-note
//

import Foundation

struct NestItem: Codable {
    let id: String
    let ownerId: String
    let name: String
    let address: String
    var entries: [BaseEntry]?
    var categories: [NestCategory]?
    
    init(id: String = UUID().uuidString, ownerId: String, name: String, address: String) {
        self.id = id
        self.ownerId = ownerId
        self.name = name
        self.address = address
        self.entries = nil
        self.categories = nil
    }
}

extension NestItem: CustomStringConvertible {
    var description: String {
        """
        NestItem(
            id: \(id),
            ownerId: \(ownerId),
            name: \(name),
            address: \(address)
        )
        """
    }
} 