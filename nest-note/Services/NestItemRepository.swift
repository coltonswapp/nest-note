import Foundation
import UIKit

protocol NestItemRepository {
    func fetchAllItems() async throws -> [BaseItem]
    
    /// Fetches all notes grouped by category
    func fetchNotes() async throws -> [String: [NoteItem]]
    
    /// Refreshes notes, clearing any cache
    func refreshNotes() async throws -> [String: [NoteItem]]
    
    /// Creates a new note
    func createNote(_ entry: NoteItem) async throws
    
    /// Updates an existing note
    func updateNote(_ entry: NoteItem) async throws
    
    /// Deletes a note
    func deleteNote(_ entry: NoteItem) async throws
    
    /// Clears any cached notes
    func clearNotesCache()
    
    /// Fetches all categories for the current nest
    func fetchCategories() async throws -> [NestCategory]
    
    /// Refreshes categories, clearing any cache
    func refreshCategories() async throws -> [NestCategory]
    
    /// Fetches notes that haven't been updated in a specified timeframe
    /// Default implementation provided in extension
    func fetchOutdatedNotes(olderThan days: Int) async throws -> [NoteItem]
    
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

// Default implementation for fetchOutdatedNotes
extension NestItemRepository {
    func fetchOutdatedNotes(olderThan days: Int = 90) async throws -> [NoteItem] {
        // Fetch all entries first
        let groupedNotes = try await fetchNotes()
        let allNotes = groupedNotes.values.flatMap { $0 }
        
        // Calculate the date threshold (90 days ago by default)
        let calendar = Calendar.current
        let threshold = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        // Filter entries that haven't been updated for the specified timeframe
        let outdatedNotes = allNotes.filter { entry in
            return entry.updatedAt < threshold
        }
        
        return outdatedNotes
    }
}

extension NestItemRepository {
    /// Owner repository that is allowed to mutate nest content.
    /// Demo mode uses `NestService` for owner chrome but blocks writes.
    var allowsNestEdits: Bool {
        self is NestService && !DemoModeService.shared.isActive
    }

    /// Owner add/pin chrome, including demo mode so the nest looks authentic.
    var showsOwnerChrome: Bool {
        self is NestService
    }
} 
