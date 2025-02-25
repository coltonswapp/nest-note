import Foundation
import CoreLocation
import FirebaseFirestore

struct Place: Codable, Identifiable, Hashable {
    var id: String
    let nestId: String
    var alias: String
    var address: String
    var coordinate: GeoPoint
    var thumbnailURLs: ThumbnailURLs
    let createdAt: Date
    let updatedAt: Date
    
    struct ThumbnailURLs: Codable, Hashable {
        let light: String
        let dark: String
    }
    
    init(id: String = UUID().uuidString,
         nestId: String,
         alias: String,
         address: String,
         coordinate: CLLocationCoordinate2D,
         thumbnailURLs: ThumbnailURLs,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.nestId = nestId
        self.alias = alias
        self.address = address
        self.coordinate = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        self.thumbnailURLs = thumbnailURLs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
} 
