import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit
import CoreLocation
import CoreImage

// Add this struct to PlacesService
struct CachedImages {
    let light: UIImage
    let dark: UIImage
}

final class PlacesService {
    // MARK: - Properties
    static let shared = PlacesService()
    private let db = Firestore.firestore()
    private let storageRef = Storage.storage(url: "gs://nest-note-21a2a.firebasestorage.app").reference()
    
    // Make places public but read-only
    private(set) var places: [Place] = []
    private var imageAssets: [String: UIImageAsset] = [:] // Cache for image assets
    
    var selectedNestId: String?
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    func createPlace(alias: String, 
                    address: String, 
                    coordinate: CLLocationCoordinate2D, 
                    thumbnailAsset: UIImageAsset,
                    visibilityLevel: VisibilityLevel = .halfDay) async throws -> Place {
        guard let nestId = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        // Check place limit for non-pro users
        let hasUnlimitedPlaces = await SubscriptionService.shared.isFeatureAvailable(.unlimitedPlaces)
        if !hasUnlimitedPlaces {
            let currentPlaceCount = places.filter { !$0.isTemporary }.count
            if currentPlaceCount >= 3 {
                Logger.log(level: .info, category: .placesService, message: "Place creation blocked: limit of 3 reached for free user")
                throw ServiceError.placeLimit
            }
        }
        
        Logger.log(level: .info, category: .placesService, message: "Creating new place: \(alias)")
        
        do {
            let placeID: String = UUID().uuidString
            
            // 1. Upload thumbnails to Storage
            let thumbnailURLs = try await uploadThumbnails(placeID: placeID, from: thumbnailAsset)
            
            // 2. Create and save place document
            let place = Place(
                id: placeID,
                nestId: nestId,
                alias: alias,
                address: address,
                coordinate: coordinate,
                thumbnailURLs: thumbnailURLs,
                isTemporary: false,
                visibilityLevel: visibilityLevel
            )
            
            try await savePlaceDocument(place)
            
            // 3. Update local cache
            places.append(place)
            
            Logger.log(level: .info, category: .placesService, message: "Place created successfully ✅")
            
            // Log success event
            Tracker.shared.track(.nestPlaceAdded)
            
            // Post notification for place creation
            NotificationCenter.default.post(name: .placeDidSave, object: place)
            
            return place
        } catch {
            // Log failure event
            Tracker.shared.track(.nestPlaceAdded, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    func fetchPlaces(includeTemporary: Bool = true, visibilityFilter: VisibilityLevel? = nil) async throws -> [Place] {
        guard let nestId = selectedNestId else {
            throw ServiceError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .placesService, message: "Fetching places for nest: \(nestId)")
        
        let snapshot = try await db.collection("nests")
            .document(nestId)
            .collection("places")
            .getDocuments()
        
        let allPlaces = try snapshot.documents.map { try $0.data(as: Place.self) }
        
        // Filter out temporary places if not requested
        var filteredPlaces = includeTemporary ? allPlaces : allPlaces.filter { !$0.isTemporary }
        
        // Apply visibility filtering if specified
        if let visibilityLevel = visibilityFilter {
            filteredPlaces = filteredPlaces.filter { place in
                visibilityLevel.hasAccess(to: place.visibilityLevel)
            }
            Logger.log(level: .info, category: .placesService, 
                      message: "Applied \(visibilityLevel.title) visibility filter: \(allPlaces.count) -> \(filteredPlaces.count) places")
        }
        
        self.places = filteredPlaces
        
        Logger.log(level: .info, category: .placesService, message: "Fetched \(filteredPlaces.count) places ✅ (\(filteredPlaces.filter(\.isTemporary).count) temp places)")
        return filteredPlaces
    }
    
    func getPlace(for id: String) async -> Place? {
        if places.isEmpty {
            try? await fetchPlaces()
            return self.places.first(where: { $0.id == id })
        } else {
            return self.places.first(where: { $0.id == id })
        }
    }
    
    func updatePlace(_ place: Place, thumbnailAsset: UIImageAsset? = nil) async throws {
        guard let nestId = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .placesService, message: "Updating place: \(place.alias)")
        
        var updatedPlace = place
        
        if let thumbnailAsset = thumbnailAsset {
            // Delete existing thumbnails first
            try await deleteThumbnails(for: place)
            
            // Upload new thumbnails
            let thumbnailURLs = try await uploadThumbnails(placeID: updatedPlace.id, from: thumbnailAsset)
            updatedPlace.thumbnailURLs = thumbnailURLs
        }
        
        // Update Firestore document
        try await db.collection("nests")
            .document(nestId)
            .collection("places")
            .document(place.id)
            .setData(from: updatedPlace, merge: true)
        
        // Update local cache
        if let index = places.firstIndex(where: { $0.id == place.id }) {
            places[index] = updatedPlace
            imageAssets[place.id] = thumbnailAsset
        }
        
        Logger.log(level: .info, category: .placesService, message: "Place updated successfully ✅")
    }
    
    func deletePlace(_ place: Place) async throws {
        guard let nestId = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .placesService, message: "Deleting place: \(place.alias)")
        
        // 1. Delete thumbnails from Storage
        try await deleteThumbnails(for: place)
        
        // 2. Delete Firestore document
        try await db.collection("nests")
            .document(nestId)
            .collection("places")
            .document("\(place.id)")
            .delete()
        
        // 3. Update local cache
        places.removeAll { $0.id == place.id }
        
        Logger.log(level: .info, category: .placesService, message: "Place deleted successfully ✅")
    }
    
    func loadImages(for place: Place) async throws -> UIImage {
        // If the place has no thumbnails (temporary place), return a placeholder
        guard let thumbnailURLs = place.thumbnailURLs else {
            return UIImage(systemName: "mappin.circle") ?? UIImage()
        }
        
        // Load both images concurrently
        
        if let asset = imageAssets[place.id] {
            return asset.image(with: .current)
        }
        
        async let lightImage = loadSingleImage(from: thumbnailURLs.light)
        async let darkImage = loadSingleImage(from: thumbnailURLs.dark)
        
        // Wait for both to complete
        let (light, dark) = try await (lightImage, darkImage)
        
        // Switch to main queue for image registration
        return await MainActor.run {
            // Create a new UIImage with both variants, just like MapThumbnailGenerator
            let asset = UIImageAsset()
            
            // Register light mode image first (important!)
            asset.register(light, with: UITraitCollection(userInterfaceStyle: .light))
            
            // Then register dark mode variant
            asset.register(dark, with: UITraitCollection(userInterfaceStyle: .dark))
            
            // Get the dynamic image with current traits (this is what MapThumbnailGenerator does)
            let dynamicImage = asset.image(with: UITraitCollection.current)
            
            Logger.log(level: .debug, category: .placesService, 
                message: "Created dynamic image for place: \(place.alias)")
            
            imageAssets[place.id] = dynamicImage.imageAsset
            return dynamicImage
        }
    }
    
    private func loadSingleImage(from url: String) async throws -> UIImage {
        guard let imageURL = URL(string: url) else {
            throw ServiceError.invalidData
        }
        
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        
        guard let image = UIImage(data: data) else {
            throw ServiceError.imageConversionFailed
        }
        
        return image
    }
    
    func clearImageCache() {
        imageAssets.removeAll()
    }
    
    func reset() {
        Logger.log(level: .info, category: .placesService, message: "Resetting PlacesService...")
        places = []
        imageAssets.removeAll()
        selectedNestId = nil
    }
    
    /// Sets the places array directly (used for sitter filtered results)
    func setPlaces(_ newPlaces: [Place]) {
        self.places = newPlaces
        Logger.log(level: .info, category: .placesService, message: "Places array set to \(newPlaces.count) items")
    }
    
    // MARK: - Private Methods
    private func savePlaceDocument(_ place: Place) async throws {
        guard let nestId = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        let docRef = db.collection("nests")
            .document(nestId)
            .collection("places")
            .document(place.id)
        
        try docRef.setData(from: place)
    }
    
    private func uploadThumbnails(placeID: String, from asset: UIImageAsset) async throws -> Place.ThumbnailURLs {
        guard let nestId = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        let imageId = placeID
        let lightRef = storageRef.child("nests/\(nestId)/places/\(imageId)_light.jpg")
        let darkRef = storageRef.child("nests/\(nestId)/places/\(imageId)_dark.jpg")
        
        Logger.log(level: .debug, category: .placesService, 
            message: "Uploading thumbnails to nest: \(nestId)")
        
        // FORCE the trait collections we want!
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        
        // Get images with FORCED trait collections
        let lightImage = asset.image(with: lightTraits)
        let darkImage = asset.image(with: darkTraits)
            
        
        // Convert to JPEG data
        guard let lightData = lightImage.jpegData(compressionQuality: 0.7),
              let darkData = darkImage.jpegData(compressionQuality: 0.7) else {
            throw ServiceError.imageConversionFailed
        }
        
        // Debug logging
        Logger.log(level: .debug, category: .placesService, 
            message: "Light image data size: \(lightData.count) bytes")
        Logger.log(level: .debug, category: .placesService, 
            message: "Dark image data size: \(darkData.count) bytes")
        
        let lightHash = lightData.hashValue
        let darkHash = darkData.hashValue
        Logger.log(level: .debug, category: .placesService, 
            message: "Light image hash: \(lightHash)")
        Logger.log(level: .debug, category: .placesService, 
            message: "Dark image hash: \(darkHash)")
        Logger.log(level: .debug, category: .placesService, 
            message: "Images are different: \(lightHash != darkHash)")
        
        // Upload both images
        let lightURL = try await uploadImage(data: lightData, to: lightRef)
        let darkURL = try await uploadImage(data: darkData, to: darkRef)
        
        return Place.ThumbnailURLs(light: lightURL, dark: darkURL)
    }
    
    private func uploadImage(data: Data, to ref: StorageReference) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            // Create the upload task
            let uploadTask = ref.putData(data, metadata: metadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard metadata != nil else {
                    continuation.resume(throwing: ServiceError.imageUploadFailed)
                    return
                }
                
                // Get download URL after successful upload
                ref.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let downloadURL = url else {
                        continuation.resume(throwing: ServiceError.imageUploadFailed)
                        return
                    }
                    
                    continuation.resume(returning: downloadURL.absoluteString)
                }
            }
            
            // Start the upload
            uploadTask.resume()
        }
    }
    
    private func deleteThumbnails(for place: Place) async throws {
        guard let nestId = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        let lightRef = storageRef.child("nests/\(nestId)/places/\(place.id)_light.jpg")
        let darkRef = storageRef.child("nests/\(nestId)/places/\(place.id)_dark.jpg")
        
        print("Light ref to delete: \(lightRef.fullPath)")
        print("Dark ref to delete: \(darkRef.fullPath)")
        
        do {
            // Delete both thumbnails concurrently, but handle errors individually
            async let lightDelete: Void = {
                do {
                    try await lightRef.delete()
                } catch {
                    Logger.log(
                        level: .error,
                        category: .placesService,
                        message: "Failed to delete light thumbnail: \(error.localizedDescription)"
                    )
                    // Don't throw - we want to continue with dark thumbnail deletion
                }
            }()
            
            async let darkDelete: Void = {
                do {
                    try await darkRef.delete()
                } catch {
                    Logger.log(
                        level: .error,
                        category: .placesService,
                        message: "Failed to delete dark thumbnail: \(error.localizedDescription)"
                    )
                    // Don't throw - we want to continue with the update
                }
            }()
            
            // Wait for both operations to complete
            _ = try await (lightDelete, darkDelete)
            
            Logger.log(
                level: .info,
                category: .placesService,
                message: "Successfully deleted thumbnails"
            )
        } catch {
            Logger.log(
                level: .error,
                category: .placesService,
                message: "Error during thumbnail deletion: \(error.localizedDescription)"
            )
            // Continue without throwing - we don't want thumbnail deletion failures 
            // to prevent place updates/deletions
        }
    }
    
    // Add this method to create a temporary place WITHOUT saving to Firestore
    func createTemporaryPlaceInMemory(address: String, 
                                     coordinate: CLLocationCoordinate2D) -> Place {
        guard let nestId = NestService.shared.currentNest?.id else {
            fatalError("No current nest")
        }
        
        Logger.log(level: .info, category: .placesService, message: "Creating in-memory temporary place")
        
        let placeID: String = UUID().uuidString
        
        // Create temporary place without thumbnails and without saving to Firestore
        let place = Place(
            id: placeID,
            nestId: nestId,
            alias: nil,
            address: address,
            coordinate: coordinate,
            thumbnailURLs: nil,
            isTemporary: true,
            visibilityLevel: .halfDay
        )
        
        Logger.log(level: .info, category: .placesService, message: "In-memory temporary place created ✅")
        return place
    }
    
    // Add method to save a temporary place that was previously only in memory
    func saveTemporaryPlace(_ place: Place) async throws {
        guard place.isTemporary else {
            throw ServiceError.invalidOperation("Cannot save non-temporary place with this method")
        }
        
        try await savePlaceDocument(place)
        
        places.append(place)
        Logger.log(level: .info, category: .placesService, message: "Temporary place saved to Firestore ✅")
    }
    
    // Add method to clean up temporary places
    func cleanupTemporaryPlaces(olderThan date: Date? = nil) {
        if let date = date {
            places.removeAll { $0.isTemporary && $0.createdAt < date }
        } else {
            // Remove all temporary places that aren't associated with an active event
            // This would require checking against EventsService
            places.removeAll { $0.isTemporary }
        }
    }
}

// MARK: - Debug Support
#if DEBUG
extension PlacesService {
    func loadDebugPlaces() {
        guard let nestId = NestService.shared.currentNest?.id else { return }
        
        let debugPlaces = [
            Place(
                nestId: nestId,
                alias: "Home",
                address: "123 Main St, Salt Lake City, UT 84111",
                coordinate: CLLocationCoordinate2D(latitude: 40.7608, longitude: -111.8910),
                thumbnailURLs: .init(light: "debug_url", dark: "debug_url"),
                isTemporary: false,
                visibilityLevel: .halfDay
            ),
            Place(
                nestId: nestId,
                alias: "School",
                address: "456 Education Ave, Salt Lake City, UT 84112",
                coordinate: CLLocationCoordinate2D(latitude: 40.7645, longitude: -111.8465),
                thumbnailURLs: .init(light: "debug_url", dark: "debug_url"),
                isTemporary: false,
                visibilityLevel: .overnight
            )
        ]
        
        self.places = debugPlaces
        Logger.log(level: .debug, category: .placesService, message: "Loaded \(places.count) debug places")
    }
    
    func clearDebugPlaces() {
        self.places = []
        Logger.log(level: .debug, category: .placesService, message: "Cleared debug places")
    }
}
#endif
