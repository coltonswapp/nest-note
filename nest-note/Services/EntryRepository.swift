import Foundation

protocol EntryRepository {
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