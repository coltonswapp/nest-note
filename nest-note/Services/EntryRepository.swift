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
} 