import Foundation
import UIKit

protocol EntryRepository {
    func fetchAllItems() async throws -> [BaseItem]
    
    /// Fetches all entries grouped by category
    func fetchEntries() async throws -> [String: [BaseEntry]]
    
    /// Refreshes entries, clearing any cache
    func refreshEntries() async throws -> [String: [BaseEntry]]
    
    /// Creates a new entry
    func createEntry(_ entry: BaseEntry) async throws
    
    /// Updates an existing entry
    func updateEntry(_ entry: BaseEntry) async throws
    
    /// Deletes an entry
    func deleteEntry(_ entry: BaseEntry) async throws
    
    /// Clears any cached entries
    func clearEntriesCache()
    
    /// Fetches all categories for the current nest
    func fetchCategories() async throws -> [NestCategory]
    
    /// Refreshes categories, clearing any cache
    func refreshCategories() async throws -> [NestCategory]
    
    /// Fetches entries that haven't been updated in a specified timeframe
    /// Default implementation provided in extension
    func fetchOutdatedEntries(olderThan days: Int) async throws -> [BaseEntry]
    
    // MARK: - Place Management
    /// Fetches all places for the current nest
    func fetchPlaces() async throws -> [PlaceItem]
    
    /// Fetches places with filtering options
    func fetchPlacesWithFilter(includeTemporary: Bool) async throws -> [PlaceItem]
    
    /// Gets a specific place by ID
    func getPlace(for id: String) async throws -> PlaceItem?
    
    /// Clears any cached places
    func clearPlacesCache()
    
    // MARK: - Image Management
    /// Loads images for a place with caching
    func loadImages(for place: PlaceItem) async throws -> UIImage
    
    /// Clears the image cache
    func clearImageCache()
} 

// Default implementation for fetchOutdatedEntries
extension EntryRepository {
    func fetchOutdatedEntries(olderThan days: Int = 90) async throws -> [BaseEntry] {
        // Fetch all entries first
        let groupedEntries = try await fetchEntries()
        let allEntries = groupedEntries.values.flatMap { $0 }
        
        // Calculate the date threshold (90 days ago by default)
        let calendar = Calendar.current
        let threshold = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        // Filter entries that haven't been updated for the specified timeframe
        let outdatedEntries = allEntries.filter { entry in
            return entry.updatedAt < threshold
        }
        
        return outdatedEntries
    }
} 
