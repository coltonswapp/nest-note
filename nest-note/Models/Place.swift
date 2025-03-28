import Foundation
import CoreLocation
import FirebaseFirestore

struct Place: Codable, Identifiable, Hashable {
    var id: String
    let nestId: String
    var alias: String?
    var address: String
    var coordinate: GeoPoint
    var thumbnailURLs: ThumbnailURLs?
    let createdAt: Date
    let updatedAt: Date
    var isTemporary: Bool
    
    struct ThumbnailURLs: Codable, Hashable {
        let light: String
        let dark: String
    }
    
    // Custom CodingKeys to handle optional properties
    enum CodingKeys: String, CodingKey {
        case id, nestId, alias, address, coordinate, thumbnailURLs, createdAt, updatedAt, isTemporary
    }
    
    init(id: String = UUID().uuidString,
         nestId: String,
         alias: String? = nil,
         address: String,
         coordinate: CLLocationCoordinate2D,
         thumbnailURLs: ThumbnailURLs? = nil,
         isTemporary: Bool = false,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.nestId = nestId
        self.alias = alias
        self.address = address
        self.coordinate = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        self.thumbnailURLs = thumbnailURLs
        self.isTemporary = isTemporary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Custom decoder init to handle missing properties
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
        
        // For backward compatibility - if isTemporary is missing, infer from alias
        if let isTemp = try? container.decode(Bool.self, forKey: .isTemporary) {
            isTemporary = isTemp
        } else {
            // If no isTemporary field exists, infer from alias (no alias = temporary)
            isTemporary = alias == nil
        }
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Place, rhs: Place) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Helpers
extension Place {
    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    var displayName: String {
        return alias ?? address.components(separatedBy: ",").first ?? address
    }
} 
