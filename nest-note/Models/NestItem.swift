//
//  NestItem.swift
//  nest-note
//

import Foundation

struct NestItem: Codable {
    let id: String
    let ownerId: String
    var name: String
    var address: String
    var entries: [BaseEntry]?
    var categories: [NestCategory]?
    var pinnedCategories: [String]?
    var nestReviewCadence: Int? // In months: 1, 3, 6, or 12. Default: 3
    
    init(id: String = UUID().uuidString, ownerId: String, name: String, address: String) {
        self.id = id
        self.ownerId = ownerId
        self.name = name
        self.address = address
        self.entries = nil
        self.categories = nil
        self.pinnedCategories = nil
        self.nestReviewCadence = 3 // Default to 3 months
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

extension NestItem {
    /// Returns the review cadence in months, with a default of 3 months if not set
    var reviewCadenceInMonths: Int {
        return nestReviewCadence ?? 3
    }
    
    /// Returns the review cadence in days for threshold calculations
    var reviewCadenceInDays: Int {
        return reviewCadenceInMonths * 30 // Approximate days per month
    }
} 
