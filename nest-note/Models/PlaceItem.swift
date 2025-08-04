//
//  PlaceItem.swift
//  nest-note
//
//  Created by Claude on 1/30/25.
//

import Foundation
import CoreLocation
import FirebaseFirestore

struct PlaceItem: BaseItem, Codable {
    let id: String
    let type: ItemType = .place
    var category: String
    var title: String
    let createdAt: Date
    var updatedAt: Date
    
    // Place-specific properties
    let nestId: String
    var alias: String?
    var address: String
    var coordinate: GeoPoint
    var thumbnailURLs: ThumbnailURLs?
    var isTemporary: Bool
    
    struct ThumbnailURLs: Codable, Hashable {
        let light: String
        let dark: String
    }
    
    init(id: String = UUID().uuidString,
         nestId: String,
         category: String = "Places", // Default category for places
         title: String? = nil,
         alias: String? = nil,
         address: String,
         coordinate: CLLocationCoordinate2D,
         thumbnailURLs: ThumbnailURLs? = nil,
         isTemporary: Bool = false,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.nestId = nestId
        self.category = category
        self.title = title ?? alias ?? address.components(separatedBy: ",").first ?? address
        self.alias = alias
        self.address = address
        self.coordinate = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        self.thumbnailURLs = thumbnailURLs
        self.isTemporary = isTemporary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    
    // MARK: - Custom Decoding for Legacy Documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        id = try container.decode(String.self, forKey: .id)
        nestId = try container.decode(String.self, forKey: .nestId)
        address = try container.decode(String.self, forKey: .address)
        coordinate = try container.decode(GeoPoint.self, forKey: .coordinate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        
        // Optional fields with defaults
        alias = try container.decodeIfPresent(String.self, forKey: .alias)
        thumbnailURLs = try container.decodeIfPresent(ThumbnailURLs.self, forKey: .thumbnailURLs)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Places"
        
        // Compute title from alias or address
        title = alias ?? address.components(separatedBy: ",").first ?? address
        
        // Backward compatibility for isTemporary
        if let isTemp = try? container.decode(Bool.self, forKey: .isTemporary) {
            isTemporary = isTemp
        } else {
            // If no isTemporary field exists, infer from alias (no alias = temporary)
            isTemporary = alias == nil
        }
    }
    
    // MARK: - Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(category, forKey: .category)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(nestId, forKey: .nestId)
        try container.encode(alias, forKey: .alias)
        try container.encode(address, forKey: .address)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encode(thumbnailURLs, forKey: .thumbnailURLs)
        try container.encode(isTemporary, forKey: .isTemporary)
    }
    
    // MARK: - CodingKeys
    enum CodingKeys: String, CodingKey {
        case id, type, category, title, createdAt, updatedAt
        case nestId, alias, address, coordinate, thumbnailURLs, isTemporary
    }
}

// MARK: - Helpers
extension PlaceItem {
    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    var displayName: String {
        return alias ?? address.components(separatedBy: ",").first ?? address
    }
    
    // Override hash to include place-specific properties
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(alias)
        hasher.combine(address)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(thumbnailURLs)
        hasher.combine(updatedAt)
    }
}
