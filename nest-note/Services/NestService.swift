//
//  NestService.swift
//  nest-note
//
//  Created by Colton Swapp on 1/19/25

import Foundation
import FirebaseFirestore

final class NestService: EntryRepository {
    
    // MARK: - Properties
    static let shared = NestService()
    private let db = Firestore.firestore()
    
    @Published private(set) var currentNest: NestItem? {
        didSet {
            Logger.log(level: .info, category: .nestService, message: "Current nest set, id: \(currentNest?.id)")
        }
    }
    @Published private(set) var isOwner: Bool = false
    
    // Add cached entries
    private var cachedEntries: [String: [BaseEntry]]?
    // Cache for saved sitters
    private var cachedSavedSitters: [SavedSitter]?
    
    // MARK: - SavedSitter Model
    struct SavedSitter: Identifiable, Codable, Hashable {
        let id: String  // Firestore document ID
        var name: String  // Sitter's name
        var email: String  // Sitter's email (primary identifier for matching)
        var userID: String?  // Firebase Auth user ID (added when sitter accepts an invite)
        
        init(id: String = UUID().uuidString, name: String, email: String, userID: String? = nil) {
            self.id = id
            self.name = name
            self.email = email
            self.userID = userID
        }
    }
    
    // MARK: - Initialization
    private init() {}

     // MARK: - Setup
    func setup() async throws {
        guard let currentUser = UserService.shared.currentUser else {
            Logger.log(level: .info, category: .nestService, message: "No current user, skipping nest setup")
            return
        }
        
        // Find first nest where user is the owner
        guard let primaryNestId = currentUser.roles.nestAccess.first(where: { $0.accessLevel == .owner })?.nestId else {
            Logger.log(level: .info, category: .nestService, message: "Owner has no owned nests")
            return
        }
        
        try await fetchAndSetCurrentNest(nestId: primaryNestId)
        Logger.log(level: .info, category: .nestService, message: currentNest != nil ? "Nest setup complete with nest: \(currentNest!)": "Nest setup incomplete.. (no nest found) ❌")
    }
    
    func reset() async {
        Logger.log(level: .info, category: .nestService, message: "Resetting NestService...")
        currentNest = nil
        isOwner = false
        clearEntriesCache()
        clearSavedSittersCache()
        PlacesService.shared.reset()
    }
    
    // MARK: - Current Nest Methods
    func setCurrentNest(_ nest: NestItem) {
        Logger.log(level: .info, category: .nestService, message: "Setting current nest to: \(nest.name)")
        self.currentNest = nest
        PlacesService.shared.selectedNestId = nest.id
    }
    
    func fetchAndSetCurrentNest(nestId: String) async throws {
        Logger.log(level: .info, category: .nestService, message: "Fetching nest: \(nestId)")
        
        let docRef = db.collection("nests").document(nestId)
        let document = try await docRef.getDocument()
        
        guard let nest = try? document.data(as: NestItem.self) else {
            throw NestError.nestNotFound
        }
        
        Logger.log(level: .info, category: .nestService, message: "Nest fetched successfully ✅")
        setCurrentNest(nest)
    }
    
    // MARK: - Firestore Methods
    func createNest(ownerId: String, name: String, address: String) async throws -> NestItem {
        Logger.log(level: .info, category: .nestService, message: "Creating new nest for user: \(ownerId)")
        
        do {
            let nest = NestItem(
                ownerId: ownerId,
                name: name,
                address: address
            )
            
            let docRef = db.collection("nests").document(nest.id)
            try await docRef.setData(try Firestore.Encoder().encode(nest))
            
            // Create default categories
            try await createDefaultCategories(for: nest.id)
            
            Logger.log(level: .info, category: .nestService, message: "Nest created successfully with default categories ✅")
            
            // Set as current nest after creation
            setCurrentNest(nest)
            
            // Log success event
            Tracker.shared.track(.nestCreated)
            
            return nest
        } catch {
            // Log failure event
            Tracker.shared.track(.nestCreated, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - EntryRepository Implementation
    func fetchEntries() async throws -> [String: [BaseEntry]] {
        // Return cached entries if available
        if let cachedEntries = cachedEntries {
            return cachedEntries
        }
        
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let snapshot = try await db.collection("nests").document(nestId).collection("entries").getDocuments()
        let entries = try snapshot.documents.map { try $0.data(as: BaseEntry.self) }
        
        // Group entries by category
        let groupedEntries = Dictionary(grouping: entries) { $0.category }
        
        // Cache the entries
        self.cachedEntries = groupedEntries
        
        return groupedEntries
    }
    
    func refreshEntries() async throws -> [String: [BaseEntry]] {
        clearEntriesCache()
        return try await fetchEntries()
    }
    
    /// Gets the current count of entries across all categories
    /// - Returns: Total number of entries in the current nest
    func getCurrentEntryCount() async throws -> Int {
        let groupedEntries = try await fetchEntries()
        return groupedEntries.values.flatMap { $0 }.count
    }
    
    // MARK: - Category Methods
    private var cachedCategories: [NestCategory]?
    
    func fetchCategories() async throws -> [NestCategory] {
        // Return cached categories if available
        if let cachedCategories = cachedCategories {
            Logger.log(level: .info, category: .nestService, message: "Using cached categories")
            return cachedCategories
        }
        
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .nestService, message: "Fetching categories from Firestore")
        let snapshot = try await db.collection("nests").document(nestId).collection("nestCategories").getDocuments()
        let categories = try snapshot.documents.map { try $0.data(as: NestCategory.self) }
        
        // Cache the categories
        self.cachedCategories = categories
        
        // Update current nest's categories
        if var updatedNest = currentNest {
            updatedNest.categories = categories
            currentNest = updatedNest
        }
        
        Logger.log(level: .info, category: .nestService, message: "Fetched \(categories.count) categories")
        return categories
    }
    
    func refreshCategories() async throws -> [NestCategory] {
        Logger.log(level: .info, category: .nestService, message: "Refreshing categories")
        cachedCategories = nil
        return try await fetchCategories()
    }
    
    func clearCategoriesCache() {
        Logger.log(level: .info, category: .nestService, message: "Clearing categories cache")
        cachedCategories = nil
    }
    
    // MARK: - Entry Methods
    func createEntry(_ entry: BaseEntry) async throws {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        // Check entry limit for free tier users
        let hasUnlimitedEntries = await SubscriptionService.shared.isFeatureAvailable(.unlimitedEntries)
        if !hasUnlimitedEntries {
            let currentCount = try await getCurrentEntryCount()
            if currentCount >= 10 {
                throw NestError.entryLimitReached
            }
        }
        
        do {
            let docRef = db.collection("nests").document(nestId).collection("entries").document(entry.id)
            try await docRef.setData(try Firestore.Encoder().encode(entry))
            
            // Update cache if it exists
            if var cachedEntries = cachedEntries {
                if var categoryEntries = cachedEntries[entry.category] {
                    categoryEntries.append(entry)
                    cachedEntries[entry.category] = categoryEntries
                    self.cachedEntries = cachedEntries
                } else {
                    // If category doesn't exist yet, create it
                    cachedEntries[entry.category] = [entry]
                    self.cachedEntries = cachedEntries
                }
            }
            
            Logger.log(level: .info, category: .nestService, message: "Entry created successfully: \(entry.title)")
            
            // Log success event
            Tracker.shared.track(.entryCreated)
        } catch {
            // Log failure event
            Tracker.shared.track(.entryCreated, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    func updateEntry(_ entry: BaseEntry) async throws {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        do {
            let docRef = db.collection("nests").document(nestId).collection("entries").document(entry.id)
            try await docRef.setData(try Firestore.Encoder().encode(entry))
            
            // Update cache if it exists
            if var cachedEntries = cachedEntries {
                if var categoryEntries = cachedEntries[entry.category] {
                    if let index = categoryEntries.firstIndex(where: { $0.id == entry.id }) {
                        categoryEntries[index] = entry
                        cachedEntries[entry.category] = categoryEntries
                        self.cachedEntries = cachedEntries
                    }
                }
            }
            
            Logger.log(level: .info, category: .nestService, message: "Entry updated successfully in Firestore: \(entry.title)")
            
            // Log success event
            Tracker.shared.track(.entryUpdated)
        } catch {
            // Log failure event
            Tracker.shared.track(.entryUpdated, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    func deleteEntry(_ entry: BaseEntry) async throws {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        do {
            let docRef = db.collection("nests").document(nestId).collection("entries").document(entry.id)
            try await docRef.delete()
            
            // Update cache if it exists
            if var updatedNest = currentNest {
                updatedNest.entries?.removeAll { $0.id == entry.id }
                currentNest = updatedNest
            }
            
            clearEntriesCache()
            
            // Log success event
            Tracker.shared.track(.entryDeleted)
        } catch {
            // Log failure event
            Tracker.shared.track(.entryDeleted, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    // Add method to clear cache
    func clearEntriesCache() {
        Logger.log(level: .info, category: .nestService, message: "Clearing entries cache")
        cachedEntries = nil
    }
    
    // Add this method to find entries older than a specified timeframe
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
        
        Logger.log(level: .info, category: .nestService, message: "Found \(outdatedEntries.count) entries older than \(days) days")
        return outdatedEntries
    }
}

// MARK: - Errors
extension NestService {
    enum NestError: LocalizedError {
        case nestNotFound
        case noCurrentNest
        case entryLimitReached
        
        var errorDescription: String? {
            switch self {
            case .nestNotFound:
                return "The requested nest could not be found"
            case .noCurrentNest:
                return "No nest is currently selected"
            case .entryLimitReached:
                return "You've reached the 10 entry limit on the free plan. Upgrade to Pro for unlimited entries."
            }
        }
    }
}

// MARK: - Default Categories
extension NestService {
    static let defaultCategories: [NestCategory] = [
        NestCategory(name: "Household", symbolName: "house.fill", isDefault: true, isPinned: true),
        NestCategory(name: "Emergency", symbolName: "exclamationmark.triangle.fill", isDefault: true, isPinned: true),
        NestCategory(name: "Rules & Guidelines", symbolName: "list.bullet", isDefault: true),
        NestCategory(name: "Pets", symbolName: "pawprint.fill", isDefault: true),
        NestCategory(name: "School & Education", symbolName: "book.fill", isDefault: true),
        NestCategory(name: "Social & Interpersonal", symbolName: "person.2.fill", isDefault: true),
        NestCategory(name: "Other", symbolName: "folder.fill", isDefault: true)
    ]
}

// Add these methods to the NestService class
extension NestService {
    func createDefaultCategories(for nestId: String) async throws {
        let categoriesRef = db.collection("nests").document(nestId).collection("nestCategories")
        
        for category in Self.defaultCategories {
            try await categoriesRef.document(category.id).setData(try Firestore.Encoder().encode(category))
        }
        
        Logger.log(level: .info, category: .nestService, message: "Created \(Self.defaultCategories.count) default categories")
    }
    
    func createCategory(_ category: NestCategory) async throws {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        do {
            let docRef = db.collection("nests").document(nestId).collection("nestCategories").document(category.id)
            try await docRef.setData(try Firestore.Encoder().encode(category))
            
            // Update current nest's categories
            if var updatedNest = currentNest {
                if updatedNest.categories == nil {
                    updatedNest.categories = []
                }
                updatedNest.categories?.append(category)
                currentNest = updatedNest
            }
            
            Logger.log(level: .info, category: .nestService, message: "Category created successfully: \(category.name)")
            
            // Log success event
            Tracker.shared.track(.nestCategoryAdded)
        } catch {
            // Log failure event
            Tracker.shared.track(.nestCategoryAdded, result: false, error: error.localizedDescription)
            throw error
        }
    }
}

// MARK: - SavedSitter Methods
extension NestService {
    // Fetch all saved sitters for the current nest
    func fetchSavedSitters() async throws -> [SavedSitter] {
        // Return cached sitters if available
        if let cachedSavedSitters = cachedSavedSitters {
            Logger.log(level: .info, category: .nestService, message: "Using cached saved sitters")
            return cachedSavedSitters
        }
        
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let snapshot = try await db.collection("nests").document(nestId).collection("savedSitters").getDocuments()
        let savedSitters = try snapshot.documents.map { try $0.data(as: SavedSitter.self) }
        
        Logger.log(level: .info, category: .nestService, message: "Fetched \(savedSitters.count) saved sitters from Firestore")
        
        // Cache the sitters
        self.cachedSavedSitters = savedSitters
        
        return savedSitters
    }
    
    // Fetch a saved sitter by ID from cache or Firestore
    func fetchSavedSitterById(_ id: String) async throws -> SavedSitter? {
        // First check the cache
        if let sitter = cachedSavedSitters?.first(where: { $0.id == id }) {
            Logger.log(level: .info, category: .nestService, message: "Found sitter \(id) in cache")
            return sitter
        }
        
        // If not in cache, fetch all sitters (which will update cache)
        let sitters = try await fetchSavedSitters()
        return sitters.first(where: { $0.id == id })
    }
    
    // Add a new saved sitter
    func addSavedSitter(_ sitter: SavedSitter) async throws {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let docRef = db.collection("nests").document(nestId).collection("savedSitters").document(sitter.id)
        try await docRef.setData(try Firestore.Encoder().encode(sitter))
        
        // Update cache if it exists
        if var sitters = cachedSavedSitters {
            // Check if sitter with same ID already exists
            if let index = sitters.firstIndex(where: { $0.id == sitter.id }) {
                sitters[index] = sitter
            } else {
                sitters.append(sitter)
            }
            cachedSavedSitters = sitters
        }
        
        Logger.log(level: .info, category: .nestService, message: "Saved sitter added successfully: \(sitter.name)")
    }
    
    // Delete a saved sitter
    func deleteSavedSitter(_ sitter: SavedSitter) async throws {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let docRef = db.collection("nests").document(nestId).collection("savedSitters").document(sitter.id)
        try await docRef.delete()
        
        // Update cache if it exists
        if var sitters = cachedSavedSitters {
            sitters.removeAll { $0.id == sitter.id }
            cachedSavedSitters = sitters
        }
        
        Logger.log(level: .info, category: .nestService, message: "Saved sitter deleted successfully: \(sitter.name)")
    }
    
    // Clear saved sitters cache
    func clearSavedSittersCache() {
        Logger.log(level: .info, category: .nestService, message: "Clearing saved sitters cache")
        cachedSavedSitters = nil
    }
    
    // Force refresh saved sitters
    func refreshSavedSitters() async throws -> [SavedSitter] {
        clearSavedSittersCache()
        return try await fetchSavedSitters()
    }
    
    // Update a saved sitter with a userID
    func updateSavedSitterWithUserID(nestId: String,_ sitter: SavedSitter, userID: String) async throws {
        
        
        Logger.log(level: .info, category: .nestService, message: "Updating saved sitter with userID: \(userID)")
        
        // Create updated sitter with userID
        let updatedSitter = SavedSitter(
            id: sitter.id,
            name: sitter.name,
            email: sitter.email,
            userID: userID
        )
        
        // Update in Firestore
        let docRef = db.collection("nests").document(nestId).collection("savedSitters").document(sitter.id)
        try await docRef.setData(try Firestore.Encoder().encode(updatedSitter), merge: true)
        
        // Update cache if it exists
        if var sitters = cachedSavedSitters {
            if let index = sitters.firstIndex(where: { $0.id == sitter.id }) {
                sitters[index] = updatedSitter
                cachedSavedSitters = sitters
            }
        }
        
        Logger.log(level: .info, category: .nestService, message: "Saved sitter updated with userID ✅")
    }
    
    // Find a saved sitter by email
    func findSavedSitterByEmail(nestId: String, _ email: String) async throws -> SavedSitter? {
        // First check the cache
        if let sitter = cachedSavedSitters?.first(where: { $0.email == email }) {
            Logger.log(level: .info, category: .nestService, message: "Found sitter with email \(email) in cache")
            return sitter
        }
        
        // Query Firestore
        let savedSittersRef = db.collection("nests").document(nestId).collection("savedSitters")
        let query = savedSittersRef.whereField("email", isEqualTo: email)
        let snapshot = try await query.getDocuments()
        
        if let document = snapshot.documents.first {
            let sitter = try document.data(as: SavedSitter.self)
            
            // Update cache if it exists
            if var sitters = cachedSavedSitters {
                if let index = sitters.firstIndex(where: { $0.id == sitter.id }) {
                    sitters[index] = sitter
                } else {
                    sitters.append(sitter)
                }
                cachedSavedSitters = sitters
            }
            
            return sitter
        }
        
        return nil
    }
}

// MARK: - Nest Update Methods
extension NestService {
    func updateNestName(_ nestId: String, _ newName: String) async throws {
        guard let currentNest else {
            throw NestError.noCurrentNest
        }
        
        do {
            // Update in Firestore
            let docRef = db.collection("nests").document(nestId)
            try await docRef.updateData([
                "name": newName,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            self.currentNest?.name = newName
            
            // Post notification for UI updates
            NotificationCenter.default.post(name: .userInformationUpdated, object: nil)
            
            Logger.log(level: .info, category: .nestService, message: "Nest name updated successfully to: \(newName)")
            
            // Log success event
            Tracker.shared.track(.nestNameUpdated)
        } catch {
            // Log failure event
            Tracker.shared.track(.nestNameUpdated, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    func updateNestAddress(_ nestId: String, _ newAddress: String) async throws {
        guard let currentNest else {
            throw NestError.noCurrentNest
        }
        
        do {
            // Update in Firestore
            let docRef = db.collection("nests").document(nestId)
            try await docRef.updateData([
                "address": newAddress,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            self.currentNest?.address = newAddress
            
            // Post notification for UI updates
            NotificationCenter.default.post(name: .userInformationUpdated, object: nil)
            
            Logger.log(level: .info, category: .nestService, message: "Nest address updated successfully to: \(newAddress)")
            
            // Log success event
            Tracker.shared.track(.nestAddressUpdated)
        } catch {
            // Log failure event
            Tracker.shared.track(.nestAddressUpdated, result: false, error: error.localizedDescription)
            throw error
        }
    }
}

// MARK: - Pinned Categories Methods
extension NestService {
    func fetchPinnedCategories() async throws -> [String] {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        // First check if we have it in currentNest
        if let pinnedCategories = currentNest?.pinnedCategories {
            Logger.log(level: .info, category: .nestService, message: "Using cached pinned categories from currentNest")
            return pinnedCategories
        }
        
        // Fetch from Firestore
        let docRef = db.collection("nests").document(nestId)
        let document = try await docRef.getDocument()
        
        guard let data = document.data(),
              let pinnedCategories = data["pinnedCategories"] as? [String] else {
            Logger.log(level: .info, category: .nestService, message: "No pinned categories found, returning empty array")
            return []
        }
        
        // Update currentNest cache
        if var updatedNest = currentNest {
            updatedNest.pinnedCategories = pinnedCategories
            currentNest = updatedNest
        }
        
        Logger.log(level: .info, category: .nestService, message: "Fetched \(pinnedCategories.count) pinned categories")
        return pinnedCategories
    }
    
    func savePinnedCategories(_ categoryNames: [String]) async throws {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        do {
            // Update in Firestore
            let docRef = db.collection("nests").document(nestId)
            try await docRef.updateData([
                "pinnedCategories": categoryNames,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // Update currentNest cache
            if var updatedNest = currentNest {
                updatedNest.pinnedCategories = categoryNames
                currentNest = updatedNest
            }
            
            Logger.log(level: .info, category: .nestService, message: "Pinned categories saved successfully: \(categoryNames)")
            
            // Log success event
            Tracker.shared.track(.pinnedCategoriesUpdated)
        } catch {
            // Log failure event
            Tracker.shared.track(.pinnedCategoriesUpdated, result: false, error: error.localizedDescription)
            throw error
        }
    }
} 

