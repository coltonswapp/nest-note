//
//  NestService.swift
//  nest-note
//
//  Created by Colton Swapp on 1/19/25

import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit
import CoreImage
import CoreLocation
import MapKit

final class NestService: NestItemRepository {
    
    // MARK: - Properties
    static let shared = NestService()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private lazy var storageRef = Storage.storage(url: "gs://nest-note-21a2a.firebasestorage.app").reference()
    
    // Cache for place image assets - following PlacesService pattern
    private var imageAssets: [String: UIImageAsset] = [:]
    
    @Published private(set) var currentNest: NestItem? {
        didSet {
            Logger.log(level: .info, category: .nestService, message: "Current nest set, id: \(currentNest?.id)")
            guard let nestId = currentNest?.id else {
                itemRepository = nil
                clearImageCache()
                return
            }

            // Only reset repository and image cache when switching nests — not when metadata updates
            if oldValue?.id != nestId {
                itemRepository = FirebaseItemRepository(nestId: nestId)
                clearImageCache()
                clearNotesCache()
                clearSavedSittersCache()
                clearCategoriesCache()
                invalidateItemsCache()
            }
        }
    }
    @Published private(set) var isOwner: Bool = false
    
    // MARK: - ItemRepository Integration
    private var itemRepository: ItemRepository?
    
    // Add cached entries (maintained for backward compatibility)
    private var cachedNotes: [String: [NoteItem]]?
    // Cache for saved sitters
    private var cachedSavedSitters: [SavedSitter]?
    
    // MARK: - Constants
    private static let maxFolderDepth = 3
    
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

        if await DemoModeService.shared.shouldLoadDemoNestOnSetup(),
           let demoNestId = DemoModeService.shared.nestId {
            try await fetchAndSetCurrentNest(nestId: demoNestId)
            Logger.log(level: .info, category: .nestService, message: "Nest setup loaded demo nest: \(demoNestId)")
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

    private func ensureNestIsWritable() throws {
        guard !DemoModeService.shared.isActive else {
            throw NestError.demoModeReadOnly
        }
    }
    
    func reset() async {
        Logger.log(level: .info, category: .nestService, message: "Resetting NestService...")
        currentNest = nil
        isOwner = false
        clearNotesCache()
        clearSavedSittersCache()
        clearCategoriesCache()
        invalidateItemsCache()
        clearImageCache()
        Logger.log(level: .info, category: .nestService, message: "All NestService caches cleared ✅")
    }
    
    // MARK: - Current Nest Methods
    func setCurrentNest(_ nest: NestItem) {
        Logger.log(level: .info, category: .nestService, message: "Setting current nest to: \(nest.name)")
        self.currentNest = nest
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
    func createNest(ownerId: String, name: String, address: String, careResponsibilities: [String]? = nil) async throws -> NestItem {
        try ensureNestIsWritable()
        Logger.log(level: .info, category: .nestService, message: "🏠 NEST CREATION: Starting nest creation for user: \(ownerId)")
        Logger.log(level: .info, category: .nestService, message: "🏠 NEST CREATION: Name: '\(name)', Address: '\(address)'")
        Logger.log(level: .info, category: .nestService, message: "🏠 NEST CREATION: Care responsibilities: \(careResponsibilities ?? [])")

        do {
            // Step 1: Create NestItem object
            Logger.log(level: .info, category: .nestService, message: "🏠 STEP 1: Creating NestItem object...")
            var nest = NestItem(
                ownerId: ownerId,
                name: name,
                address: address
            )
            nest.pinnedCategories = ["Household", "Emergency"]
            Logger.log(level: .info, category: .nestService, message: "🏠 STEP 1: ✅ NestItem created with ID: \(nest.id)")

            // Step 2: Encode nest data
            Logger.log(level: .info, category: .nestService, message: "🏠 STEP 2: Encoding nest data...")
            let nestData = try Firestore.Encoder().encode(nest)
            Logger.log(level: .info, category: .nestService, message: "🏠 STEP 2: ✅ Nest data encoded successfully")

            // Step 3: Save nest to Firestore
            Logger.log(level: .info, category: .nestService, message: "🏠 STEP 3: Saving nest to Firestore...")
            let docRef = db.collection("nests").document(nest.id)
            Logger.log(level: .info, category: .nestService, message: "🏠 STEP 3: Document path: nests/\(nest.id)")

            try await docRef.setData(nestData)
            Logger.log(level: .info, category: .nestService, message: "🏠 STEP 3: ✅ Nest document saved to Firestore")

            // Step 4: Create categories separately after nest creation
            Logger.log(level: .info, category: .nestService, message: "🏠 STEP 4: Creating categories for nest...")
            do {
                try await createCategoriesForNest(nestId: nest.id, careResponsibilities: careResponsibilities)
                Logger.log(level: .info, category: .nestService, message: "🏠 STEP 4: ✅ Categories created successfully")
            } catch {
                Logger.log(level: .error, category: .nestService, message: "🏠 STEP 4: ⚠️ Category creation failed: \(error.localizedDescription)")
                Logger.log(level: .error, category: .nestService, message: "🏠 STEP 4: ⚠️ Continuing without categories - nest creation still successful")
                // Don't throw - nest creation succeeded, categories can be created later
            }

            // Step 5: Set as current nest
            Logger.log(level: .info, category: .nestService, message: "🏠 STEP 5: Setting as current nest...")
            setCurrentNest(nest)
            Logger.log(level: .info, category: .nestService, message: "🏠 STEP 5: ✅ Current nest set")

            // Step 6: Track success
            Logger.log(level: .info, category: .nestService, message: "🏠 STEP 6: Logging success event...")
            Tracker.shared.track(.nestCreated)
            Logger.log(level: .info, category: .nestService, message: "🏠 STEP 6: ✅ Success event logged")

            Logger.log(level: .info, category: .nestService, message: "🏠 ✅ NEST CREATION COMPLETE: Nest '\(nest.name)' created successfully!")
            return nest
        } catch {
            Logger.log(level: .error, category: .nestService, message: "🏠 ❌ NEST CREATION FAILED: \(error.localizedDescription)")
            Logger.log(level: .error, category: .nestService, message: "🏠 ❌ Error type: \(type(of: error))")
            Logger.log(level: .error, category: .nestService, message: "🏠 ❌ Full error: \(error)")

            // Log failure event
            Tracker.shared.track(.nestCreated, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - NestItemRepository Implementation
    func fetchNotes() async throws -> [String: [NoteItem]] {
        Logger.log(level: .info, category: .nestService, message: "fetchNotes() called - using ItemRepository")
        
        // Return cached entries if available
        if let cachedNotes = cachedNotes {
            Logger.log(level: .info, category: .nestService, message: "Returning \(cachedNotes.values.flatMap { $0 }.count) cached entries")
            return cachedNotes
        }
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        // Fetch all items using ItemRepository
        let allItems = try await itemRepository.fetchItems()
        
        // Filter to only entry items (already NoteItem from repository)
        let notes = allItems.compactMap { item -> NoteItem? in
            guard item.type == .entry, let baseEntry = item as? NoteItem else { return nil }
            return baseEntry
        }
        
        // Group entries by category
        let groupedNotes = Dictionary(grouping: notes) { $0.category }
        
        // Cache the entries for backward compatibility
        self.cachedNotes = groupedNotes
        
        Logger.log(level: .info, category: .nestService, message: "Fetched \(notes.count) entries using ItemRepository")
        return groupedNotes
    }
    
    func refreshNotes() async throws -> [String: [NoteItem]] {
        clearNotesCache()
        return try await fetchNotes()
    }
    
    /// Gets the current count of notes across all categories
    /// - Returns: Total number of notes in the current nest
    func getCurrentNoteCount() async throws -> Int {
        let groupedNotes = try await fetchNotes()
        return groupedNotes.values.flatMap { $0 }.count
    }

    // MARK: - Category Methods
    private var cachedCategories: [NestCategory]?
    /// Bumped on category mutations so an in-flight fetch cannot write stale data back into the cache.
    private var categoriesCacheEpoch = 0
    
    func fetchCategories() async throws -> [NestCategory] {
        // Return cached categories if available
        if let cachedCategories = cachedCategories {
            Logger.log(level: .info, category: .nestService, message: "Using cached categories")
            return cachedCategories
        }

        if let inflightFetchCategoriesTask {
            return try await inflightFetchCategoriesTask.value
        }

        let epoch = categoriesCacheEpoch
        let task = Task { [self] () throws -> [NestCategory] in
            guard let nestId = currentNest?.id else {
                throw NestError.noCurrentNest
            }

            Logger.log(level: .info, category: .nestService, message: "Fetching categories from Firestore")
            let snapshot = try await db.collection("nests").document(nestId).collection("nestCategories").getDocuments()
            let categories = try snapshot.documents.map { try $0.data(as: NestCategory.self) }

            if epoch == categoriesCacheEpoch {
                self.cachedCategories = categories

                if var updatedNest = currentNest {
                    updatedNest.categories = categories
                    currentNest = updatedNest
                }

                Logger.log(level: .info, category: .nestService, message: "Fetched \(categories.count) categories")
                return categories
            }

            Logger.log(level: .info, category: .nestService, message: "Fetched \(categories.count) categories (discarded stale cache write)")
            return self.cachedCategories ?? categories
        }

        inflightFetchCategoriesTask = task
        defer { inflightFetchCategoriesTask = nil }

        return try await task.value
    }
    
    func refreshCategories() async throws -> [NestCategory] {
        Logger.log(level: .info, category: .nestService, message: "Refreshing categories")
        clearCategoriesCache()
        return try await fetchCategories()
    }
    
    func clearCategoriesCache() {
        Logger.log(level: .info, category: .nestService, message: "Clearing categories cache")
        categoriesCacheEpoch += 1
        cachedCategories = nil
        inflightFetchCategoriesTask = nil
    }
    
    func clearPlacesCache() {
        // Places are computed from cachedItems, so clear the items cache
        invalidateItemsCache()
    }
    
    // MARK: - Note Methods
    func createNote(_ entry: NoteItem) async throws {
        Logger.log(level: .info, category: .nestService, message: "createNote() called - using ItemRepository")
        try ensureNestIsWritable()
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        do {
            // Use ItemRepository for creation (NoteItem directly)
            try await itemRepository.createItem(entry)
            
            // Update backward compatibility cache
            if var cachedNotes = cachedNotes {
                if var categoryEntries = cachedNotes[entry.category] {
                    categoryEntries.append(entry)
                    cachedNotes[entry.category] = categoryEntries
                    self.cachedNotes = cachedNotes
                } else {
                    // If category doesn't exist yet, create it
                    cachedNotes[entry.category] = [entry]
                    self.cachedNotes = cachedNotes
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
    
    func updateNote(_ entry: NoteItem) async throws {
        Logger.log(level: .info, category: .nestService, message: "updateNote() called - using ItemRepository")
        try ensureNestIsWritable()
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        do {
            // Use ItemRepository for update (NoteItem directly)
            try await itemRepository.updateItem(entry)
            
            // Update backward compatibility cache
            if var cachedNotes = cachedNotes {
                if var categoryEntries = cachedNotes[entry.category] {
                    if let index = categoryEntries.firstIndex(where: { $0.id == entry.id }) {
                        categoryEntries[index] = entry
                        cachedNotes[entry.category] = categoryEntries
                        self.cachedNotes = cachedNotes
                    }
                }
            }
            
            Logger.log(level: .info, category: .nestService, message: "Entry updated successfully: \(entry.title)")
            
            // Log success event
            Tracker.shared.track(.entryUpdated)
        } catch {
            // Log failure event
            Tracker.shared.track(.entryUpdated, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    func deleteNote(_ entry: NoteItem) async throws {
        Logger.log(level: .info, category: .nestService, message: "deleteNote() called - using ItemRepository")
        try ensureNestIsWritable()
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        do {
            // Use ItemRepository for deletion
            try await itemRepository.deleteItem(id: entry.id)
            
            // Update cache if it exists
            if var updatedNest = currentNest {
                updatedNest.notes?.removeAll { $0.id == entry.id }
                currentNest = updatedNest
            }
            
            clearNotesCache()
            
            // Log success event
            Tracker.shared.track(.entryDeleted)
        } catch {
            // Log failure event
            Tracker.shared.track(.entryDeleted, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    // Add method to clear cache
    func clearNotesCache() {
        Logger.log(level: .info, category: .nestService, message: "Clearing entries cache")
        cachedNotes = nil
        // Also clear ItemRepository cache
        itemRepository?.clearItemsCache()
    }
    
    // MARK: - Routine Methods
    
    func createRoutine(_ routine: RoutineItem) async throws {
        Logger.log(level: .info, category: .nestService, message: "createRoutine() called - using ItemRepository")
        try ensureNestIsWritable()
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        do {
            // Use ItemRepository for creation
            try await itemRepository.createItem(routine)

            updateItemInCache(routine)
            clearNotesCache()

            Logger.log(level: .info, category: .nestService, message: "Routine created successfully: \(routine.title)")
            
            // Log success event
            Tracker.shared.track(.routineCreated)
        } catch {
            // Log failure event
            Tracker.shared.track(.routineCreated, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    func updateRoutine(_ routine: RoutineItem) async throws {
        Logger.log(level: .info, category: .nestService, message: "updateRoutine() called - using ItemRepository")
        try ensureNestIsWritable()
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        do {
            // Use ItemRepository for update
            try await itemRepository.updateItem(routine)

            updateItemInCache(routine)
            clearNotesCache()

            Logger.log(level: .info, category: .nestService, message: "Routine updated successfully: \(routine.title)")
            
            // Log success event
            Tracker.shared.track(.routineUpdated)
        } catch {
            // Log failure event
            Tracker.shared.track(.routineUpdated, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    func deleteRoutine(_ routine: RoutineItem) async throws {
        Logger.log(level: .info, category: .nestService, message: "deleteRoutine() called - using ItemRepository")
        try ensureNestIsWritable()
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        do {
            // Use ItemRepository for deletion
            try await itemRepository.deleteItem(id: routine.id)

            removeItemFromCache(id: routine.id)
            clearNotesCache()

            Logger.log(level: .info, category: .nestService, message: "Routine deleted successfully: \(routine.title)")
            
            // Log success event
            Tracker.shared.track(.routineDeleted)
        } catch {
            // Log failure event
            Tracker.shared.track(.routineDeleted, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Generic CRUD Methods for All BaseItem Types
    
    /// Generic method to create any BaseItem type
    func createItem<T: BaseItem>(_ item: T) async throws {
        Logger.log(level: .info, category: .nestService, message: "createItem() called for type: \(item.type.rawValue)")
        try ensureNestIsWritable()
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        try await itemRepository.createItem(item)
        
        // Add item to cache instead of clearing entire cache
        updateItemInCache(item)
        // Clear entries cache to ensure fresh data (backward compatibility)
        clearNotesCache()

        Logger.log(level: .info, category: .nestService, message: "Item created successfully: \(item.title) (\(item.type.rawValue))")
    }
    
    /// Generic method to update any BaseItem type  
    func updateItem<T: BaseItem>(_ item: T) async throws {
        Logger.log(level: .info, category: .nestService, message: "updateItem() called for type: \(item.type.rawValue)")
        try ensureNestIsWritable()
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        try await itemRepository.updateItem(item)
        
        // Update item in cache instead of clearing entire cache
        updateItemInCache(item)
        // Clear entries cache to ensure fresh data (backward compatibility)
        clearNotesCache()
        
        Logger.log(level: .info, category: .nestService, message: "Item updated successfully: \(item.title) (\(item.type.rawValue))")
    }
    
    /// Generic method to delete any BaseItem type by ID
    func deleteItem(id: String) async throws {
        Logger.log(level: .info, category: .nestService, message: "deleteItem() called for id: \(id)")
        try ensureNestIsWritable()
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        try await itemRepository.deleteItem(id: id)
        
        // Remove item from cache instead of clearing entire cache
        removeItemFromCache(id: id)
        // Clear entries cache to ensure fresh data (backward compatibility)
        clearNotesCache()
        
        Logger.log(level: .info, category: .nestService, message: "Item deleted successfully: \(id)")
    }
    
    /// Fetch all items of any type
    // MARK: - Unified Item Caching
    private var cachedItems: [BaseItem] = []
    private var lastFetchTime: Date?
    private let cacheValidityDuration: TimeInterval = 600 // 10 minutes - more reasonable for navigation
    private var inflightFetchAllItemsTask: Task<[BaseItem], Error>?
    private var inflightFetchCategoriesTask: Task<[NestCategory], Error>?
    /// Bumped on item mutations so an in-flight fetch cannot write stale data back into the cache.
    private var itemsCacheEpoch = 0
    
    // Computed property that filters places from cached items
    private var cachedPlaces: [PlaceItem]? {
        guard !cachedItems.isEmpty else { return nil }
        return cachedItems.compactMap { $0 as? PlaceItem }
    }
    
    private var isCacheValid: Bool {
        guard let lastFetch = lastFetchTime else { return false }
        return Date().timeIntervalSince(lastFetch) < cacheValidityDuration
    }
    
    func fetchAllItems() async throws -> [BaseItem] {
        Logger.log(level: .info, category: .nestService, message: "fetchAllItems() called")
        
        // Log cache status for debugging
        if let lastFetch = lastFetchTime {
            let cacheAge = Date().timeIntervalSince(lastFetch)
            Logger.log(level: .info, category: .nestService, message: "Cache age: \(cacheAge)s, valid: \(isCacheValid), items: \(cachedItems.count)")
        } else {
            Logger.log(level: .info, category: .nestService, message: "No cache data available")
        }
        
        // Return cached items if cache is still valid
        if isCacheValid && !cachedItems.isEmpty {
            Logger.log(level: .info, category: .nestService, message: "✅ CACHE HIT: Returning \(cachedItems.count) cached items")
            return cachedItems
        }
        
        Logger.log(level: .info, category: .nestService, message: "🌐 CACHE MISS: Fetching fresh data from backend")

        if let inflightFetchAllItemsTask {
            return try await inflightFetchAllItemsTask.value
        }

        let epoch = itemsCacheEpoch
        let task = Task { [self] () throws -> [BaseItem] in
            guard let itemRepository = itemRepository else {
                throw NestError.noCurrentNest
            }

            let items = try await itemRepository.fetchItems()
            Logger.log(level: .info, category: .nestService, message: "Fetched \(items.count) total items from repository")

            if epoch == itemsCacheEpoch {
                cachedItems = items
                lastFetchTime = Date()
                return items
            }

            return cachedItems.isEmpty ? items : cachedItems
        }

        inflightFetchAllItemsTask = task
        defer { inflightFetchAllItemsTask = nil }

        return try await task.value
    }

    /// Snapshot of nest items for resolving attachment IDs.
    /// Prefers the in-memory cache so opening a detail screen does not look like a fetch.
    func itemsForAttachmentResolution() async throws -> [BaseItem] {
        if !cachedItems.isEmpty {
            return cachedItems
        }
        return try await fetchAllItems()
    }
    
    /// Invalidate the cache (call when items are created/updated/deleted)
    func invalidateItemsCache() {
        Logger.log(level: .info, category: .nestService, message: "🗑️ CACHE INVALIDATED: Clearing \(cachedItems.count) cached items")
        itemsCacheEpoch += 1
        cachedItems = []
        lastFetchTime = nil
        inflightFetchAllItemsTask = nil
        itemRepository?.clearItemsCache()
    }

    /// Drop all nest item/category caches after an out-of-band write (e.g. demo seeder).
    func purgeCachesAfterExternalMutation() {
        invalidateItemsCache()
        clearNotesCache()
        clearCategoriesCache()
        clearSavedSittersCache()
    }
    
    /// Add or update an item in the cache
    private func updateItemInCache<T: BaseItem>(_ item: T) {
        // Remove existing item with same ID if it exists
        cachedItems.removeAll { $0.id == item.id }
        // Add the updated item
        cachedItems.append(item)
        Logger.log(level: .info, category: .nestService, message: "Updated item in cache: \(item.id)")
    }
    
    /// Remove an item from the cache
    private func removeItemFromCache(id: String) {
        let initialCount = cachedItems.count
        cachedItems.removeAll { $0.id == id }
        let removedCount = initialCount - cachedItems.count
        Logger.log(level: .info, category: .nestService, message: "Removed \(removedCount) item(s) from cache with id: \(id)")
    }
    
    /// Bulk update multiple items in the cache
    private func updateItemsInCache<T: BaseItem>(_ items: [T]) {
        for item in items {
            updateItemInCache(item)
        }
        Logger.log(level: .info, category: .nestService, message: "Bulk updated \(items.count) items in cache")
    }
    
    /// Fetch items filtered by type (uses cached data when possible)
    func fetchItems<T: BaseItem>(ofType type: ItemType) async throws -> [T] {
        Logger.log(level: .info, category: .nestService, message: "fetchItems() called for type: \(type.rawValue)")
        
        let allItems = try await fetchAllItems() // This uses cache when valid
        let filteredItems = allItems.compactMap { item -> T? in
            guard item.type == type else { return nil }
            return item as? T
        }
        
        Logger.log(level: .info, category: .nestService, message: "Filtered \(filteredItems.count) items of type: \(type.rawValue)")
        return filteredItems
    }
    
    // MARK: - Folder Contents Structure (using shared FolderUtility)
    typealias FolderContents = FolderUtility.FolderContents
    
    /// Fetch all contents for a specific folder/category
    func fetchFolderContents(for category: String) async throws -> FolderContents {
        Logger.log(level: .info, category: .nestService, message: "📁 fetchFolderContents() called for category: '\(category)'")
        
        let allItems = try await fetchAllItems()
        let categories = try await fetchCategories()
        
        Logger.log(level: .info, category: .nestService, message: "📁 fetchFolderContents data gathered - using cached data when possible")
        
        let folderContents = FolderUtility.buildFolderContents(
            for: category,
            allItems: allItems,
            categories: categories
        )
        
        Logger.log(level: .info, category: .nestService, message: "Folder contents for '\(category)': \(folderContents.notes.count) entries, \(folderContents.places.count) places, \(folderContents.routines.count) routines, \(folderContents.subfolders.count) subfolders")
        
        return folderContents
    }
    
    
    // MARK: - Type-Specific Convenience Methods for Places
    
    /// Fetch all places (PlaceItems)
    func fetchPlaces() async throws -> [PlaceItem] {
        Logger.log(level: .info, category: .nestService, message: "fetchPlaces() called")
        return try await fetchItems(ofType: .place)
    }
    
    /// Fetch both entries and places in a single efficient call
    func fetchNotesAndPlaces() async throws -> (notes: [String: [NoteItem]], places: [PlaceItem]) {
        Logger.log(level: .info, category: .nestService, message: "📦 fetchNotesAndPlaces() called - efficient single fetch")
        
        let allItems = try await fetchAllItems() // Single fetch with caching
        
        // Filter entries (already NoteItem from repository)
        let entryItems = allItems.compactMap { item -> NoteItem? in
            guard item.type == .entry else { return nil }
            return item as? NoteItem
        }
        let groupedNotes = Dictionary(grouping: entryItems) { $0.category }
        
        // Filter places
        let placeItems = allItems.compactMap { $0 as? PlaceItem }
        
        Logger.log(level: .info, category: .nestService, message: "Efficient fetch complete - \(groupedNotes.count) entry groups, \(placeItems.count) places")
        return (notes: groupedNotes, places: placeItems)
    }
    
    /// Create a new place
    func createPlace(_ place: PlaceItem) async throws {
        Logger.log(level: .info, category: .nestService, message: "createPlace() called: \(place.title)")
        try await createItem(place)
        // Cache already updated by createItem() - no need to invalidate
    }
    
    /// Update an existing place
    func updatePlace(_ place: PlaceItem) async throws {
        Logger.log(level: .info, category: .nestService, message: "updatePlace() called: \(place.title)")
        try await updateItem(place)
        // Cache already updated by updateItem() - no need to invalidate
    }

    /// Update a place with optional thumbnail regeneration for location changes.
    /// Prefer passing `thumbnailAsset` from the map picker to avoid a second snapshot.
    /// Thumbnail Storage work runs in the background after Firestore is updated.
    func updatePlace(
        _ place: PlaceItem,
        shouldRegenerateThumbnails: Bool = false,
        newCoordinate: CLLocationCoordinate2D? = nil,
        thumbnailAsset: UIImageAsset? = nil
    ) async throws -> PlaceItem {
        Logger.log(level: .info, category: .nestService, message: "updatePlace() called with thumbnail regeneration: \(shouldRegenerateThumbnails)")

        var updatedPlace = place
        var assetForUpload: UIImageAsset?

        if shouldRegenerateThumbnails {
            if let thumbnailAsset {
                assetForUpload = thumbnailAsset
            } else if let coordinate = newCoordinate {
                do {
                    let newThumbnail = try await generateThumbnailForCoordinate(coordinate)
                    assetForUpload = createImageAsset(from: newThumbnail)
                } catch {
                    Logger.log(level: .error, category: .nestService, message: "Failed to regenerate thumbnails: \(error.localizedDescription)")
                }
            }

            if let assetForUpload {
                imageAssets[place.id] = assetForUpload
            }
        }

        // Persist metadata immediately; Storage uploads are non-blocking
        try await updateItem(updatedPlace)
        Logger.log(level: .info, category: .nestService, message: "Place updated successfully: \(updatedPlace.title)")

        if let assetForUpload {
            scheduleThumbnailUpload(
                for: updatedPlace,
                asset: assetForUpload,
                deleteExisting: place.thumbnailURLs != nil
            )
        }

        return updatedPlace
    }
    
    /// Delete a place by ID
    func deletePlace(id: String) async throws {
        Logger.log(level: .info, category: .nestService, message: "deletePlace() called: \(id)")
        try await deleteItem(id: id)
        // Cache already updated by deleteItem() - no need to invalidate
    }
    
    /// Delete a place by PlaceItem object
    func deletePlace(_ place: PlaceItem) async throws {
        Logger.log(level: .info, category: .nestService, message: "deletePlace() called for place: \(place.alias ?? place.title)")
        
        // Delete thumbnails first if they exist
        if place.thumbnailURLs != nil {
            do {
                try await deleteThumbnails(for: place)
                Logger.log(level: .info, category: .nestService, message: "Thumbnails deleted for place: \(place.id)")
            } catch {
                Logger.log(level: .error, category: .nestService, message: "Failed to delete thumbnails for place: \(error.localizedDescription)")
                // Continue with place deletion even if thumbnail deletion fails
            }
        }
        
        try await deletePlace(id: place.id)
    }
    
    /// Load images for a place from thumbnail URLs (patterned after working PlacesService)
    func loadImages(for place: PlaceItem) async throws -> UIImage {
        Logger.log(level: .debug, category: .nestService, message: "loadImages() called for place: \(place.alias ?? place.title)")
        
        // Prefer in-memory assets (including ones staged before Storage URLs exist)
        if let asset = imageAssets[place.id] {
            Logger.log(level: .debug, category: .nestService, message: "Found cached image asset for place: \(place.alias ?? place.title)")
            return asset.image(with: .current)
        }
        
        // If the place has no thumbnails (temporary place / upload pending), return a placeholder
        guard let thumbnailURLs = place.thumbnailURLs else {
            if DemoModeService.shared.isActive, let placeholder = DemoNestSeed.placeholderImage(for: place) {
                Logger.log(level: .debug, category: .nestService, message: "Using demo map placeholder for place: \(place.alias ?? place.title)")
                return placeholder
            }
            Logger.log(level: .debug, category: .nestService, message: "Place has no thumbnails, returning placeholder")
            return UIImage(systemName: "mappin.circle") ?? UIImage()
        }
        
        Logger.log(level: .debug, category: .nestService, message: "Cache miss - loading images from URLs - Light: \(thumbnailURLs.light), Dark: \(thumbnailURLs.dark)")
        
        // Load both images concurrently - exactly like working PlacesService
        async let lightImage = loadSingleImage(from: thumbnailURLs.light)
        async let darkImage = loadSingleImage(from: thumbnailURLs.dark)
        
        // Wait for both to complete
        let (light, dark) = try await (lightImage, darkImage)
        
        // Switch to main queue for image registration - matching working pattern
        return await MainActor.run {
            // Create a new UIImage with both variants, just like MapThumbnailGenerator
            let asset = UIImageAsset()
            
            // Register light mode image first (important!)
            asset.register(light, with: UITraitCollection(userInterfaceStyle: .light))
            
            // Then register dark mode variant
            asset.register(dark, with: UITraitCollection(userInterfaceStyle: .dark))
            
            // Get the dynamic image with current traits (this is what MapThumbnailGenerator does)
            let dynamicImage = asset.image(with: UITraitCollection.current)
            
            // Cache the asset for future use - following PlacesService pattern
            self.imageAssets[place.id] = dynamicImage.imageAsset
            Logger.log(level: .debug, category: .nestService, message: "Cached image asset and created dynamic image for place: \(place.alias ?? place.title)")
            
            return dynamicImage
        }
    }
    
    private func loadSingleImage(from urlString: String) async throws -> UIImage {
        guard let imageURL = URL(string: urlString) else {
            throw NestError.invalidImageURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        
        guard let image = UIImage(data: data) else {
            throw NestError.imageConversionFailed
        }
        
        Logger.log(level: .debug, category: .nestService, message: "Loaded image from URL: \(urlString)")
        return image
    }
    
    /// Clear the image cache - following PlacesService pattern
    func clearImageCache() {
        Logger.log(level: .info, category: .nestService, message: "Clearing image cache")
        imageAssets.removeAll()
    }

    /// Clear cached image for a specific place
    func clearImageCache(for placeId: String) {
        imageAssets.removeValue(forKey: placeId)
        Logger.log(level: .debug, category: .nestService, message: "Cleared cached image for place: \(placeId)")
    }
    
    /// Fetch places with basic filtering
    func fetchPlacesWithFilter(includeTemporary: Bool = true) async throws -> [PlaceItem] {
        Logger.log(level: .info, category: .nestService, message: "fetchPlacesWithFilter() called with includeTemporary: \(includeTemporary)")
        
        let placeItems = try await fetchPlaces()
        var filteredPlaces = placeItems
        
        // Filter out temporary places if not requested
        if !includeTemporary {
            filteredPlaces = filteredPlaces.filter { !$0.isTemporary }
        }
        
        Logger.log(level: .info, category: .nestService, message: "Returning \(filteredPlaces.count) places (\(filteredPlaces.filter(\.isTemporary).count) temporary)")
        return filteredPlaces
    }
    
    /// Get a specific place by ID
    func getPlace(for id: String) async throws -> PlaceItem? {
        Logger.log(level: .info, category: .nestService, message: "getPlace() called for id: \(id)")
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        // Try ItemRepository first
        if let item = try await itemRepository.fetchItem(id: id),
           let placeItem = item as? PlaceItem {
            return placeItem
        }
        
        Logger.log(level: .info, category: .nestService, message: "Place not found: \(id)")
        return nil
    }
    
    /// Create a temporary place in memory (not saved to Firestore)
    func createTemporaryPlaceInMemory(address: String, coordinate: CLLocationCoordinate2D) -> PlaceItem {
        Logger.log(level: .info, category: .nestService, message: "createTemporaryPlaceInMemory() called")
        
        // Come back to this? 7/30/26
        let placeItem = PlaceItem(
            nestId: currentNest?.id ?? "temp-nest",
            alias: nil, // No alias = temporary
            address: address,
            coordinate: coordinate,
            isTemporary: true
        )
        
        Logger.log(level: .info, category: .nestService, message: "Created temporary place in memory: \(placeItem.id)")
        return placeItem
    }
    
    /// Create a place with convenient signature.
    /// Firestore write completes first; map thumbnails upload in the background and patch URLs after.
    func createPlace(alias: String, 
                    address: String, 
                    coordinate: CLLocationCoordinate2D, 
                    category: String = "Places",
                    thumbnailAsset: UIImageAsset? = nil,
                    attachmentIds: [String] = []) async throws -> PlaceItem {
        Logger.log(level: .info, category: .nestService, message: "createPlace() called with alias: \(alias), category: \(category)")
        
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let placeID = UUID().uuidString
        
        // Stage local thumbs so the list can render immediately while Storage uploads
        if let thumbnailAsset {
            imageAssets[placeID] = thumbnailAsset
        }
        
        let placeItem = PlaceItem(
            id: placeID,
            nestId: nestId,
            category: category,
            alias: alias,
            address: address,
            coordinate: coordinate,
            thumbnailURLs: nil,
            isTemporary: false,
            attachmentIds: attachmentIds
        )
        
        try await createPlace(placeItem)
        
        if let thumbnailAsset {
            scheduleThumbnailUpload(for: placeItem, asset: thumbnailAsset, deleteExisting: false)
        }
        
        Logger.log(level: .info, category: .nestService, message: "Place created successfully: \(placeItem.alias ?? placeItem.title); thumbnails uploading in background: \(thumbnailAsset != nil)")
        return placeItem
    }
    
    // Add this method to find entries older than a specified timeframe
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
        
        Logger.log(level: .info, category: .nestService, message: "Found \(outdatedNotes.count) entries older than \(days) days")
        return outdatedNotes
    }
}

// MARK: - Errors
extension NestService {
    enum NestError: LocalizedError {
        case nestNotFound
        case noCurrentNest
        case noteLimitReached
        case folderDepthExceeded
        case imageConversionFailed
        case imageUploadFailed
        case invalidImageURL
        case creationFailed
        case demoModeReadOnly
        
        var errorDescription: String? {
            switch self {
            case .nestNotFound:
                return "The requested nest could not be found"
            case .noCurrentNest:
                return "No nest is currently selected"
            case .noteLimitReached:
                return "You've reached the 10 note limit on the free plan. Upgrade to Pro for unlimited notes."
            case .folderDepthExceeded:
                return "Folder depth cannot exceed 3 levels. Please create your folder in a shallower location."
            case .imageConversionFailed:
                return "Failed to convert image to JPEG format"
            case .imageUploadFailed:
                return "Failed to upload image to storage"
            case .invalidImageURL:
                return "Invalid image URL"
            case .creationFailed:
                return "Failed to create nest and categories"
            case .demoModeReadOnly:
                return "Changes aren't saved in the demo nest."
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
    
    /// Creates categories for a nest based on survey responses. Called after nest creation.
    func createCategoriesForNest(nestId: String, careResponsibilities: [String]? = nil) async throws {
        Logger.log(level: .info, category: .nestService, message: "📁 CATEGORY CREATION: Starting category creation for nest: \(nestId)")
        Logger.log(level: .info, category: .nestService, message: "📁 CATEGORY CREATION: Care responsibilities: \(careResponsibilities ?? [])")

        do {
            let categoriesRef = db.collection("nests").document(nestId).collection("nestCategories")
            var categoriesToCreate: [NestCategory] = []

            // Step 1: Always create required default folders (Nest Score expects Household + Emergency)
            Logger.log(level: .info, category: .nestService, message: "📁 STEP 1: Creating default Household and Emergency categories...")
            let householdCategory = NestCategory(name: "Household", symbolName: "house.fill", isDefault: true, isPinned: true)
            let emergencyCategory = NestCategory(name: "Emergency", symbolName: "exclamationmark.triangle.fill", isDefault: true, isPinned: true)
            categoriesToCreate.append(householdCategory)
            categoriesToCreate.append(emergencyCategory)
            Logger.log(level: .info, category: .nestService, message: "📁 STEP 1: ✅ Default categories prepared")

            // Step 2: Create categories based on care responsibilities from survey
            if let careResponsibilities = careResponsibilities {
                Logger.log(level: .info, category: .nestService, message: "📁 STEP 2: Processing \(careResponsibilities.count) care responsibilities...")
                for responsibility in careResponsibilities {
                    let category = createCategoryForCareResponsibility(responsibility)
                    if !categoriesToCreate.contains(where: { $0.name == category.name }) {
                        categoriesToCreate.append(category)
                        Logger.log(level: .info, category: .nestService, message: "📁 STEP 2: Added category for '\(responsibility)': \(category.name)")
                    } else {
                        Logger.log(level: .info, category: .nestService, message: "📁 STEP 2: Skipped duplicate category for '\(responsibility)'")
                    }
                }
                Logger.log(level: .info, category: .nestService, message: "📁 STEP 2: ✅ Care responsibility categories prepared")
            } else {
                Logger.log(level: .info, category: .nestService, message: "📁 STEP 2: No care responsibilities provided, using defaults only")
            }

            // Step 3: Create all categories in Firestore
            Logger.log(level: .info, category: .nestService, message: "📁 STEP 3: Creating \(categoriesToCreate.count) categories in Firestore...")
            for (index, category) in categoriesToCreate.enumerated() {
                Logger.log(level: .info, category: .nestService, message: "📁 STEP 3: Creating category \(index + 1)/\(categoriesToCreate.count): '\(category.name)'")
                try await categoriesRef.document(category.id).setData(try Firestore.Encoder().encode(category))
                Logger.log(level: .info, category: .nestService, message: "📁 STEP 3: ✅ Category '\(category.name)' created successfully")
            }

            Logger.log(level: .info, category: .nestService, message: "📁 ✅ CATEGORY CREATION COMPLETE: Created \(categoriesToCreate.count) categories successfully!")

        } catch {
            Logger.log(level: .error, category: .nestService, message: "📁 ❌ CATEGORY CREATION FAILED: \(error.localizedDescription)")
            Logger.log(level: .error, category: .nestService, message: "📁 ❌ Error type: \(type(of: error))")
            Logger.log(level: .error, category: .nestService, message: "📁 ❌ Full error: \(error)")
            throw error
        }
    }

    @available(*, deprecated, message: "This method is no longer used. Category creation is now handled by createCategoriesForNest.")
    func createCategoriesBasedOnSurvey(for nestId: String, careResponsibilities: [String]? = nil) async throws {
        let categoriesRef = db.collection("nests").document(nestId).collection("nestCategories")
        var categoriesToCreate: [NestCategory] = []
        
        // Always create required default folders (Nest Score expects Household + Emergency)
        let householdCategory = NestCategory(name: "Household", symbolName: "house.fill", isDefault: true, isPinned: true)
        let emergencyCategory = NestCategory(name: "Emergency", symbolName: "exclamationmark.triangle.fill", isDefault: true, isPinned: true)
        categoriesToCreate.append(householdCategory)
        categoriesToCreate.append(emergencyCategory)
        
        // Create categories based on care responsibilities from survey
        if let careResponsibilities = careResponsibilities {
            for responsibility in careResponsibilities {
                let category = createCategoryForCareResponsibility(responsibility)
                if !categoriesToCreate.contains(where: { $0.name == category.name }) {
                    categoriesToCreate.append(category)
                }
            }
        }
        
        // Create all categories in Firestore
        for category in categoriesToCreate {
            try await categoriesRef.document(category.id).setData(try Firestore.Encoder().encode(category))
        }
        
        Logger.log(level: .info, category: .nestService, message: "Created \(categoriesToCreate.count) personalized categories based on survey responses")
    }
    
    private func createCategoryForCareResponsibility(_ responsibility: String) -> NestCategory {
        switch responsibility {
        case "Children":
            return NestCategory(name: "Children", symbolName: "figure.child", isDefault: false, isPinned: false)
        case "Pets":
            return NestCategory(name: "Pets", symbolName: "pawprint.fill", isDefault: false, isPinned: false)
        case "House":
            // Household is always created as the default pinned folder
            return NestCategory(name: "Household", symbolName: "house.fill", isDefault: true, isPinned: true)
        case "Plants":
            return NestCategory(name: "Plants", symbolName: "leaf.fill", isDefault: false, isPinned: false)
        default:
            // For any unknown responsibility, create a generic folder
            return NestCategory(name: responsibility, symbolName: "folder.fill", isDefault: false, isPinned: false)
        }
    }
    
    // MARK: - Folder Validation
    private func validateFolderDepth(for folderPath: String) -> Bool {
        let components = folderPath.components(separatedBy: "/")
        return components.count <= Self.maxFolderDepth
    }
    
    func createCategory(_ category: NestCategory) async throws {
        try ensureNestIsWritable()
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        // Validate folder depth
        guard validateFolderDepth(for: category.name) else {
            throw NestError.folderDepthExceeded
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
            
            // Clear the cached categories to force fresh fetch next time
            clearCategoriesCache()
            
            Logger.log(level: .info, category: .nestService, message: "Folder created successfully: \(category.name)")
            
            // Log success event
            Tracker.shared.track(.nestCategoryAdded)
        } catch {
            // Log failure event
            Tracker.shared.track(.nestCategoryAdded, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    func deleteCategory(_ categoryName: String) async throws {
        try ensureNestIsWritable()
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        do {
            // First, find and delete all entries that belong to this category or its subfolders
            let entriesCollection = db.collection("nests").document(nestId).collection("entries")
            let entriesQuery = entriesCollection.whereField("category", isEqualTo: categoryName)
            let entriesSnapshot = try await entriesQuery.getDocuments()
            
            // Also find entries in subfolders (categories that start with this categoryName + "/")
            let subfolderQuery = entriesCollection.whereField("category", isGreaterThanOrEqualTo: categoryName + "/")
                .whereField("category", isLessThan: categoryName + "/\u{f8ff}") // Unicode high character for range query
            let subfolderSnapshot = try await subfolderQuery.getDocuments()
            
            // Delete all entries in this category and its subfolders
            let batch = db.batch()
            for document in entriesSnapshot.documents + subfolderSnapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
            
            // Find the category document to delete
            let categoriesCollection = db.collection("nests").document(nestId).collection("nestCategories")
            let categoryQuery = categoriesCollection.whereField("name", isEqualTo: categoryName)
            let categorySnapshot = try await categoryQuery.getDocuments()
            
            // Delete the category document(s)
            for document in categorySnapshot.documents {
                try await document.reference.delete()
            }
            
            // Also delete any subcategories
            let subcategoryQuery = categoriesCollection.whereField("name", isGreaterThanOrEqualTo: categoryName + "/")
                .whereField("name", isLessThan: categoryName + "/\u{f8ff}")
            let subcategorySnapshot = try await subcategoryQuery.getDocuments()
            
            for document in subcategorySnapshot.documents {
                try await document.reference.delete()
            }
            
            // Update current nest's categories by removing the deleted category and subcategories
            if var updatedNest = currentNest {
                updatedNest.categories?.removeAll { category in
                    category.name == categoryName || category.name.hasPrefix(categoryName + "/")
                }
                currentNest = updatedNest
                cachedCategories = updatedNest.categories
            } else {
                cachedCategories = nil
            }
            categoriesCacheEpoch += 1
            inflightFetchCategoriesTask = nil

            // Drop cached items in this folder so FolderUtility cannot reconstruct it.
            itemsCacheEpoch += 1
            inflightFetchAllItemsTask = nil
            cachedItems.removeAll { item in
                item.category == categoryName || item.category.hasPrefix(categoryName + "/")
            }
            itemRepository?.clearItemsCache()
            
            Logger.log(level: .info, category: .nestService, message: "Category deleted successfully: \(categoryName)")
            
            // Log success event
            Tracker.shared.track(.nestCategoryDeleted)
            NotificationCenter.default.post(name: .nestCategoryDidChange, object: categoryName)
        } catch {
            // Log failure event  
            Tracker.shared.track(.nestCategoryDeleted, result: false, error: error.localizedDescription)
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
        try ensureNestIsWritable()
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
        try ensureNestIsWritable()
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
        try ensureNestIsWritable()
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
        try ensureNestIsWritable()
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
    
    func updateNest(_ nest: NestItem) async throws {
        try ensureNestIsWritable()
        let db = Firestore.firestore()
        let data = try Firestore.Encoder().encode(nest)
        
        do {
            try await db.collection("nests").document(nest.id).setData(data)
            Logger.log(level: .info, category: .nestService, message: "Nest updated successfully")
        } catch {
            Logger.log(level: .error, category: .nestService, message: "Error updating nest: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Pinned Folders Methods
extension NestService {
    /// Filters out legacy synthetic pins (e.g. "Places") that are not real folders.
    private static func sanitizedPinnedCategories(_ categoryNames: [String]) -> [String] {
        categoryNames.filter { $0 != "Places" }
    }
    
    func fetchPinnedCategories() async throws -> [String] {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        // First check if we have it in currentNest
        if let pinnedCategories = currentNest?.pinnedCategories {
            Logger.log(level: .info, category: .nestService, message: "Using cached Pinned Folders from currentNest")
            return Self.sanitizedPinnedCategories(pinnedCategories)
        }
        
        // Fetch from Firestore
        let docRef = db.collection("nests").document(nestId)
        let document = try await docRef.getDocument()
        
        guard let data = document.data(),
              let pinnedCategories = data["pinnedCategories"] as? [String] else {
            Logger.log(level: .info, category: .nestService, message: "No Pinned Folders found, returning empty array")
            return []
        }
        
        let sanitized = Self.sanitizedPinnedCategories(pinnedCategories)
        
        // Update currentNest cache
        if var updatedNest = currentNest {
            updatedNest.pinnedCategories = sanitized
            currentNest = updatedNest
        }
        
        Logger.log(level: .info, category: .nestService, message: "Fetched \(sanitized.count) Pinned Folders")
        return sanitized
    }
    
    func savePinnedCategories(_ categoryNames: [String]) async throws {
        try ensureNestIsWritable()
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let sanitized = Self.sanitizedPinnedCategories(categoryNames)
        
        do {
            // Update in Firestore
            let docRef = db.collection("nests").document(nestId)
            try await docRef.updateData([
                "pinnedCategories": sanitized,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // Update currentNest cache
            if var updatedNest = currentNest {
                updatedNest.pinnedCategories = sanitized
                currentNest = updatedNest
            }

            await MainActor.run {
                NotificationCenter.default.post(name: .pinnedCategoriesDidChange, object: nil)
            }
            
            Logger.log(level: .info, category: .nestService, message: "Pinned Folders saved successfully: \(sanitized)")
            
            // Log success event
            Tracker.shared.track(.pinnedCategoriesUpdated)
        } catch {
            // Log failure event
            Tracker.shared.track(.pinnedCategoriesUpdated, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Thumbnail Upload Methods
    
    /// Uploads light/dark thumbs after the place document exists, then patches URLs.
    private func scheduleThumbnailUpload(
        for place: PlaceItem,
        asset: UIImageAsset,
        deleteExisting: Bool
    ) {
        Task { [weak self] in
            guard let self else { return }
            do {
                if deleteExisting {
                    try await self.deleteThumbnails(for: place)
                }
                
                let urls = try await self.uploadThumbnails(placeID: place.id, from: asset)
                var updatedPlace = place
                updatedPlace.thumbnailURLs = urls
                updatedPlace.updatedAt = Date()
                
                try await self.updateItem(updatedPlace)
                
                Logger.log(
                    level: .info,
                    category: .nestService,
                    message: "Background thumbnail upload completed for place: \(place.id)"
                )
                
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .placeThumbnailsDidUpdate,
                        object: updatedPlace
                    )
                }
            } catch {
                Logger.log(
                    level: .error,
                    category: .nestService,
                    message: "Background thumbnail upload failed for place \(place.id): \(error.localizedDescription)"
                )
            }
        }
    }
    
    private func uploadThumbnails(placeID: String, from asset: UIImageAsset) async throws -> PlaceItem.ThumbnailURLs {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let imageId = placeID
        let lightRef = storageRef.child("nests/\(nestId)/places/\(imageId)_light.jpg")
        let darkRef = storageRef.child("nests/\(nestId)/places/\(imageId)_dark.jpg")
        
        Logger.log(level: .debug, category: .nestService, 
            message: "Uploading thumbnails to nest: \(nestId)")
        
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        
        let lightImage = asset.image(with: lightTraits)
        let darkImage = asset.image(with: darkTraits)
        
        guard let lightData = lightImage.jpegData(compressionQuality: 0.6),
              let darkData = darkImage.jpegData(compressionQuality: 0.6) else {
            throw NestError.imageConversionFailed
        }
        
        Logger.log(level: .debug, category: .nestService, 
            message: "Light image data size: \(lightData.count) bytes")
        Logger.log(level: .debug, category: .nestService, 
            message: "Dark image data size: \(darkData.count) bytes")
        
        // Upload light and dark in parallel
        async let lightURL = uploadImage(data: lightData, to: lightRef)
        async let darkURL = uploadImage(data: darkData, to: darkRef)
        
        return try await PlaceItem.ThumbnailURLs(light: lightURL, dark: darkURL)
    }
    
    private func uploadImage(data: Data, to ref: StorageReference) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            var didResume = false
            let resumeOnce: (Result<String, Error>) -> Void = { result in
                guard !didResume else { return }
                didResume = true
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            // putData starts the upload immediately; no need to call resume()
            _ = ref.putData(data, metadata: metadata) { metadata, error in
                if let error = error {
                    resumeOnce(.failure(error))
                    return
                }
                
                guard metadata != nil else {
                    resumeOnce(.failure(NestError.imageUploadFailed))
                    return
                }
                
                ref.downloadURL { url, error in
                    if let error = error {
                        resumeOnce(.failure(error))
                        return
                    }
                    
                    guard let downloadURL = url else {
                        resumeOnce(.failure(NestError.imageUploadFailed))
                        return
                    }
                    
                    resumeOnce(.success(downloadURL.absoluteString))
                }
            }
        }
    }
    
    private func deleteThumbnails(for place: PlaceItem) async throws {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let lightRef = storageRef.child("nests/\(nestId)/places/\(place.id)_light.jpg")
        let darkRef = storageRef.child("nests/\(nestId)/places/\(place.id)_dark.jpg")
        
        Logger.log(level: .debug, category: .nestService, message: "Light ref to delete: \(lightRef.fullPath)")
        Logger.log(level: .debug, category: .nestService, message: "Dark ref to delete: \(darkRef.fullPath)")
        
        do {
            // Delete both thumbnails concurrently, but handle errors individually
            async let lightDelete: Void = {
                do {
                    try await lightRef.delete()
                } catch {
                    Logger.log(
                        level: .error,
                        category: .nestService,
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
                        category: .nestService,
                        message: "Failed to delete dark thumbnail: \(error.localizedDescription)"
                    )
                    // Don't throw - we want to continue with the update
                }
            }()
            
            // Wait for both operations to complete
            _ = try await (lightDelete, darkDelete)
            
            Logger.log(
                level: .info,
                category: .nestService,
                message: "Successfully deleted thumbnails"
            )
        } catch {
            Logger.log(
                level: .error,
                category: .nestService,
                message: "Error during thumbnail deletion: \(error.localizedDescription)"
            )
            // Continue without throwing - we don't want thumbnail deletion failures
            // to prevent place updates/deletions
        }
    }

    // MARK: - Helper Methods for Thumbnail Generation

    /// Generate thumbnail for a coordinate
    private func generateThumbnailForCoordinate(_ coordinate: CLLocationCoordinate2D) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            MapThumbnailGenerator.shared.generateDynamicThumbnail(
                for: coordinate,
                visibleRegion: MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 300,
                    longitudinalMeters: 300
                )
            ) { thumbnail in
                if let thumbnail = thumbnail {
                    continuation.resume(returning: thumbnail)
                } else {
                    continuation.resume(throwing: NestError.imageConversionFailed)
                }
            }
        }
    }

    /// Create image asset from UIImage
    private func createImageAsset(from image: UIImage) -> UIImageAsset {
        let asset = UIImageAsset()
        asset.register(image, with: UITraitCollection(userInterfaceStyle: .light))
        asset.register(image, with: UITraitCollection(userInterfaceStyle: .dark))
        return asset
    }
} 

