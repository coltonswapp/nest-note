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

final class NestService: EntryRepository {
    
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
            // Update ItemRepository when nest changes
            if let nestId = currentNest?.id {
                itemRepository = FirebaseItemRepository(nestId: nestId)
            } else {
                itemRepository = nil
            }
            // Clear image cache when switching nests - following PlacesService pattern
            clearImageCache()
        }
    }
    @Published private(set) var isOwner: Bool = false
    
    // MARK: - ItemRepository Integration
    private var itemRepository: ItemRepository?
    
    // Add cached entries (maintained for backward compatibility)
    private var cachedEntries: [String: [BaseEntry]]?
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
        Logger.log(level: .info, category: .nestService, message: "fetchEntries() called - using ItemRepository")
        
        // Return cached entries if available
        if let cachedEntries = cachedEntries {
            Logger.log(level: .info, category: .nestService, message: "Returning \(cachedEntries.values.flatMap { $0 }.count) cached entries")
            return cachedEntries
        }
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        // Fetch all items using ItemRepository
        let allItems = try await itemRepository.fetchItems()
        
        // Filter to only entry items and convert to BaseEntry
        let entries = allItems.compactMap { item -> BaseEntry? in
            guard item.type == .entry, let entryItem = item as? EntryItem else { return nil }
            return entryItem.toBaseEntry()
        }
        
        // Group entries by category
        let groupedEntries = Dictionary(grouping: entries) { $0.category }
        
        // Cache the entries for backward compatibility
        self.cachedEntries = groupedEntries
        
        Logger.log(level: .info, category: .nestService, message: "Fetched \(entries.count) entries using ItemRepository")
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
    
    func clearPlacesCache() {
        // Places are computed from cachedItems, so clear the items cache
        invalidateItemsCache()
    }
    
    // MARK: - Entry Methods
    func createEntry(_ entry: BaseEntry) async throws {
        Logger.log(level: .info, category: .nestService, message: "createEntry() called - using ItemRepository")
        
        guard let itemRepository = itemRepository else {
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
            // Convert BaseEntry to EntryItem
            let entryItem = EntryItem(from: entry)
            
            // Use ItemRepository for creation
            try await itemRepository.createItem(entryItem)
            
            // Update backward compatibility cache
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
        Logger.log(level: .info, category: .nestService, message: "updateEntry() called - using ItemRepository")
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        do {
            // Convert BaseEntry to EntryItem
            let entryItem = EntryItem(from: entry)
            
            // Use ItemRepository for update
            try await itemRepository.updateItem(entryItem)
            
            // Update backward compatibility cache
            if var cachedEntries = cachedEntries {
                if var categoryEntries = cachedEntries[entry.category] {
                    if let index = categoryEntries.firstIndex(where: { $0.id == entry.id }) {
                        categoryEntries[index] = entry
                        cachedEntries[entry.category] = categoryEntries
                        self.cachedEntries = cachedEntries
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
    
    func deleteEntry(_ entry: BaseEntry) async throws {
        Logger.log(level: .info, category: .nestService, message: "deleteEntry() called - using ItemRepository")
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        do {
            // Use ItemRepository for deletion
            try await itemRepository.deleteItem(id: entry.id)
            
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
        // Also clear ItemRepository cache
        itemRepository?.clearItemsCache()
    }
    
    // MARK: - Generic CRUD Methods for All BaseItem Types
    
    /// Generic method to create any BaseItem type
    func createItem<T: BaseItem>(_ item: T) async throws {
        Logger.log(level: .info, category: .nestService, message: "createItem() called for type: \(item.type.rawValue)")
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        try await itemRepository.createItem(item)
        
        // Add item to cache instead of clearing entire cache
        updateItemInCache(item)
        // Clear entries cache to ensure fresh data (backward compatibility)
        clearEntriesCache()
        
        Logger.log(level: .info, category: .nestService, message: "Item created successfully: \(item.title) (\(item.type.rawValue))")
    }
    
    /// Generic method to update any BaseItem type  
    func updateItem<T: BaseItem>(_ item: T) async throws {
        Logger.log(level: .info, category: .nestService, message: "updateItem() called for type: \(item.type.rawValue)")
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        try await itemRepository.updateItem(item)
        
        // Update item in cache instead of clearing entire cache
        updateItemInCache(item)
        // Clear entries cache to ensure fresh data (backward compatibility)
        clearEntriesCache()
        
        Logger.log(level: .info, category: .nestService, message: "Item updated successfully: \(item.title) (\(item.type.rawValue))")
    }
    
    /// Generic method to delete any BaseItem type by ID
    func deleteItem(id: String) async throws {
        Logger.log(level: .info, category: .nestService, message: "deleteItem() called for id: \(id)")
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        try await itemRepository.deleteItem(id: id)
        
        // Remove item from cache instead of clearing entire cache
        removeItemFromCache(id: id)
        // Clear entries cache to ensure fresh data (backward compatibility)
        clearEntriesCache()
        
        Logger.log(level: .info, category: .nestService, message: "Item deleted successfully: \(id)")
    }
    
    /// Fetch all items of any type
    // MARK: - Unified Item Caching
    private var cachedItems: [BaseItem] = []
    private var lastFetchTime: Date?
    private let cacheValidityDuration: TimeInterval = 600 // 10 minutes - more reasonable for navigation
    
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
        
        guard let itemRepository = itemRepository else {
            throw NestError.noCurrentNest
        }
        
        let items = try await itemRepository.fetchItems()
        Logger.log(level: .info, category: .nestService, message: "Fetched \(items.count) total items from repository")
        
        // Update cache
        cachedItems = items
        lastFetchTime = Date()
        
        return items
    }
    
    /// Invalidate the cache (call when items are created/updated/deleted)
    func invalidateItemsCache() {
        Logger.log(level: .info, category: .nestService, message: "🗑️ CACHE INVALIDATED: Clearing \(cachedItems.count) cached items")
        cachedItems = []
        lastFetchTime = nil
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
    
    // MARK: - Folder Contents Structure
    struct FolderContents {
        let entries: [BaseEntry]
        let places: [PlaceItem]
        let subfolders: [FolderData]
        let allPlaces: [PlaceItem] // For passing to child folders
    }
    
    /// Fetch all contents for a specific folder/category
    func fetchFolderContents(for category: String) async throws -> FolderContents {
        Logger.log(level: .info, category: .nestService, message: "📁 fetchFolderContents() called for category: '\(category)'")
        
        // Get all data in one efficient call - use cached data when possible
        let (allGroupedEntries, allPlaces) = try await fetchEntriesAndPlaces()
        let categories = try await fetchCategories()
        
        Logger.log(level: .info, category: .nestService, message: "📁 fetchFolderContents data gathered - using cached data when possible")
        
        // Filter entries for this exact category
        let entries: [BaseEntry]
        if category.contains("/") {
            // For folder paths, find entries that match this exact path
            var matchingEntries: [BaseEntry] = []
            for (_, categoryEntries) in allGroupedEntries {
                for entry in categoryEntries {
                    if entry.category == category {
                        matchingEntries.append(entry)
                    }
                }
            }
            entries = matchingEntries
        } else {
            // For root categories, use the grouped entries
            entries = allGroupedEntries[category] ?? []
        }
        
        // Filter places for this category
        let places = allPlaces.filter { $0.category == category }
        
        // Build subfolders
        let subfolders = buildSubfolders(for: category, allEntries: allGroupedEntries, allPlaces: allPlaces, categories: categories)
        
        Logger.log(level: .info, category: .nestService, message: "Folder contents for '\(category)': \(entries.count) entries, \(places.count) places, \(subfolders.count) subfolders")
        
        return FolderContents(
            entries: entries,
            places: places, 
            subfolders: subfolders,
            allPlaces: allPlaces
        )
    }
    
    private func buildSubfolders(for category: String, allEntries: [String: [BaseEntry]], allPlaces: [PlaceItem], categories: [NestCategory]) -> [FolderData] {
        var folderItems: [FolderData] = []
        var folderCounts: [String: Int] = [:]
        var currentLevelFolders: Set<String> = []
        
        // Count entries in subfolders
        for (_, categoryEntries) in allEntries {
            for entry in categoryEntries {
                let folderPath = entry.category
                
                // Check if this entry belongs to a subfolder of the current category
                if folderPath.hasPrefix(category + "/") {
                    let remainingPath = String(folderPath.dropFirst(category.count + 1))
                    
                    if !remainingPath.isEmpty {
                        let nextFolderComponent = remainingPath.components(separatedBy: "/").first!
                        let nextFolderPath = "\(category)/\(nextFolderComponent)"
                        currentLevelFolders.insert(nextFolderPath)
                        folderCounts[nextFolderPath, default: 0] += 1
                    }
                }
            }
        }
        
        // Count places in subfolders
        for place in allPlaces {
            let folderPath = place.category
            
            if folderPath.hasPrefix(category + "/") {
                let remainingPath = String(folderPath.dropFirst(category.count + 1))
                
                if !remainingPath.isEmpty {
                    let nextFolderComponent = remainingPath.components(separatedBy: "/").first!
                    let nextFolderPath = "\(category)/\(nextFolderComponent)"
                    currentLevelFolders.insert(nextFolderPath)
                    folderCounts[nextFolderPath, default: 0] += 1
                }
            }
        }
        
        // Add empty folders from categories
        for nestCategory in categories {
            let folderPath = nestCategory.name
            
            if folderPath.hasPrefix(category + "/") {
                let remainingPath = String(folderPath.dropFirst(category.count + 1))
                
                if !remainingPath.isEmpty && !remainingPath.contains("/") {
                    currentLevelFolders.insert(folderPath)
                    if folderCounts[folderPath] == nil {
                        folderCounts[folderPath] = 0
                    }
                }
            }
        }
        
        // Create FolderData objects
        for folderPath in currentLevelFolders.sorted() {
            let folderName = folderPath.components(separatedBy: "/").last ?? folderPath
            let matchingCategory = categories.first { $0.name == folderPath }
            let iconName = matchingCategory?.symbolName ?? "folder"
            let image = UIImage(systemName: iconName)
            
            let folderData = FolderData(
                title: folderName,
                image: image,
                itemCount: folderCounts[folderPath] ?? 0,
                fullPath: folderPath,
                category: matchingCategory
            )
            folderItems.append(folderData)
        }
        
        return folderItems
    }
    
    // MARK: - Type-Specific Convenience Methods for Places
    
    /// Fetch all places (PlaceItems)
    func fetchPlaces() async throws -> [PlaceItem] {
        Logger.log(level: .info, category: .nestService, message: "fetchPlaces() called")
        return try await fetchItems(ofType: .place)
    }
    
    /// Fetch both entries and places in a single efficient call
    func fetchEntriesAndPlaces() async throws -> (entries: [String: [BaseEntry]], places: [PlaceItem]) {
        Logger.log(level: .info, category: .nestService, message: "📦 fetchEntriesAndPlaces() called - efficient single fetch")
        
        let allItems = try await fetchAllItems() // Single fetch with caching
        
        // Filter entries and convert EntryItem to BaseEntry for backward compatibility
        let entryItems = allItems.compactMap { item -> BaseEntry? in
            if let entryItem = item as? EntryItem {
                return entryItem.toBaseEntry()
            }
            return item as? BaseEntry // Also support direct BaseEntry if any exist
        }
        let groupedEntries = Dictionary(grouping: entryItems) { $0.category }
        
        // Filter places
        let placeItems = allItems.compactMap { $0 as? PlaceItem }
        
        Logger.log(level: .info, category: .nestService, message: "Efficient fetch complete - \(groupedEntries.count) entry groups, \(placeItems.count) places")
        return (entries: groupedEntries, places: placeItems)
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
        
        // If the place has no thumbnails (temporary place), return a placeholder
        guard let thumbnailURLs = place.thumbnailURLs else {
            Logger.log(level: .debug, category: .nestService, message: "Place has no thumbnails, returning placeholder")
            return UIImage(systemName: "mappin.circle") ?? UIImage()
        }
        
        // Check cache first - exactly like working PlacesService
        if let asset = imageAssets[place.id] {
            Logger.log(level: .debug, category: .nestService, message: "Found cached image asset for place: \(place.alias ?? place.title)")
            return asset.image(with: .current)
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
    
    /// Create a place with convenient signature
    func createPlace(alias: String, 
                    address: String, 
                    coordinate: CLLocationCoordinate2D, 
                    category: String = "Places",
                    thumbnailAsset: UIImageAsset? = nil) async throws -> PlaceItem {
        Logger.log(level: .info, category: .nestService, message: "createPlace() called with alias: \(alias), category: \(category)")
        
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        // Generate ID for the place first
        let placeID = UUID().uuidString
        
        // Handle thumbnailAsset upload first if provided
        var thumbnailURLs: PlaceItem.ThumbnailURLs? = nil
        if let thumbnailAsset = thumbnailAsset {
            Logger.log(level: .info, category: .nestService, message: "📷 THUMBNAIL DEBUG: Starting thumbnail upload for place ID: \(placeID)")
            Logger.log(level: .info, category: .nestService, message: "📷 THUMBNAIL DEBUG: ThumbnailAsset received: \(thumbnailAsset)")
            
            do {
                // Upload thumbnails and get URLs using the actual place ID
                thumbnailURLs = try await uploadThumbnails(placeID: placeID, from: thumbnailAsset)
                
                Logger.log(level: .info, category: .nestService, message: "📷 THUMBNAIL DEBUG: Upload completed successfully!")
                Logger.log(level: .info, category: .nestService, message: "📷 THUMBNAIL DEBUG: Light URL: \(thumbnailURLs?.light ?? "nil")")
                Logger.log(level: .info, category: .nestService, message: "📷 THUMBNAIL DEBUG: Dark URL: \(thumbnailURLs?.dark ?? "nil")")
            } catch {
                Logger.log(level: .error, category: .nestService, message: "📷 THUMBNAIL DEBUG: Upload FAILED with error: \(error)")
                Logger.log(level: .error, category: .nestService, message: "📷 THUMBNAIL DEBUG: Error details: \(error.localizedDescription)")
                // Continue without thumbnails if upload fails
            }
        } else {
            Logger.log(level: .info, category: .nestService, message: "📷 THUMBNAIL DEBUG: No thumbnailAsset provided - place will be created without thumbnails")
        }
        
        // Create PlaceItem with thumbnails if available
        let placeItem = PlaceItem(
            id: placeID,
            nestId: nestId,
            category: category,
            alias: alias,
            address: address,
            coordinate: coordinate,
            thumbnailURLs: thumbnailURLs,
            isTemporary: false
        )
        
        Logger.log(level: .info, category: .nestService, message: "📷 THUMBNAIL DEBUG: Created PlaceItem with thumbnailURLs: \(placeItem.thumbnailURLs != nil ? "YES" : "NO")")
        if let urls = placeItem.thumbnailURLs {
            Logger.log(level: .info, category: .nestService, message: "📷 THUMBNAIL DEBUG: PlaceItem light URL: \(urls.light)")
            Logger.log(level: .info, category: .nestService, message: "📷 THUMBNAIL DEBUG: PlaceItem dark URL: \(urls.dark)")
        }
        
        // Create using ItemRepository
        try await createPlace(placeItem)
        
        Logger.log(level: .info, category: .nestService, message: "Place created successfully: \(placeItem.alias ?? placeItem.title) with thumbnails: \(thumbnailURLs != nil)")
        return placeItem
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
        case folderDepthExceeded
        case imageConversionFailed
        case imageUploadFailed
        case invalidImageURL
        
        var errorDescription: String? {
            switch self {
            case .nestNotFound:
                return "The requested nest could not be found"
            case .noCurrentNest:
                return "No nest is currently selected"
            case .entryLimitReached:
                return "You've reached the 10 entry limit on the free plan. Upgrade to Pro for unlimited entries."
            case .folderDepthExceeded:
                return "Folder depth cannot exceed 3 levels. Please create your folder in a shallower location."
            case .imageConversionFailed:
                return "Failed to convert image to JPEG format"
            case .imageUploadFailed:
                return "Failed to upload image to storage"
            case .invalidImageURL:
                return "Invalid image URL"
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
    
    // MARK: - Folder Validation
    private func validateFolderDepth(for folderPath: String) -> Bool {
        let components = folderPath.components(separatedBy: "/")
        return components.count <= Self.maxFolderDepth
    }
    
    func createCategory(_ category: NestCategory) async throws {
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
            cachedCategories = nil
            
            Logger.log(level: .info, category: .nestService, message: "Category created successfully: \(category.name)")
            
            // Log success event
            Tracker.shared.track(.nestCategoryAdded)
        } catch {
            // Log failure event
            Tracker.shared.track(.nestCategoryAdded, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    func deleteCategory(_ categoryName: String) async throws {
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
            }
            
            // Clear the cached categories to force fresh fetch next time
            cachedCategories = nil
            
            Logger.log(level: .info, category: .nestService, message: "Category deleted successfully: \(categoryName)")
            
            // Log success event
            Tracker.shared.track(.nestCategoryDeleted)
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

// MARK: - Pinned Folders Methods
extension NestService {
    func fetchPinnedCategories() async throws -> [String] {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        // First check if we have it in currentNest
        if let pinnedCategories = currentNest?.pinnedCategories {
            Logger.log(level: .info, category: .nestService, message: "Using cached Pinned Folders from currentNest")
            return pinnedCategories
        }
        
        // Fetch from Firestore
        let docRef = db.collection("nests").document(nestId)
        let document = try await docRef.getDocument()
        
        guard let data = document.data(),
              let pinnedCategories = data["pinnedCategories"] as? [String] else {
            Logger.log(level: .info, category: .nestService, message: "No Pinned Folders found, returning empty array")
            return []
        }
        
        // Update currentNest cache
        if var updatedNest = currentNest {
            updatedNest.pinnedCategories = pinnedCategories
            currentNest = updatedNest
        }
        
        Logger.log(level: .info, category: .nestService, message: "Fetched \(pinnedCategories.count) Pinned Folders")
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
            
            Logger.log(level: .info, category: .nestService, message: "Pinned Folders saved successfully: \(categoryNames)")
            
            // Log success event
            Tracker.shared.track(.pinnedCategoriesUpdated)
        } catch {
            // Log failure event
            Tracker.shared.track(.pinnedCategoriesUpdated, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Thumbnail Upload Methods
    
    private func uploadThumbnails(placeID: String, from asset: UIImageAsset) async throws -> PlaceItem.ThumbnailURLs {
        guard let nestId = currentNest?.id else {
            throw NestError.noCurrentNest
        }
        
        let imageId = placeID
        let lightRef = storageRef.child("nests/\(nestId)/places/\(imageId)_light.jpg")
        let darkRef = storageRef.child("nests/\(nestId)/places/\(imageId)_dark.jpg")
        
        Logger.log(level: .debug, category: .nestService, 
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
            throw NestError.imageConversionFailed
        }
        
        // Debug logging
        Logger.log(level: .debug, category: .nestService, 
            message: "Light image data size: \(lightData.count) bytes")
        Logger.log(level: .debug, category: .nestService, 
            message: "Dark image data size: \(darkData.count) bytes")
        
        let lightHash = lightData.hashValue
        let darkHash = darkData.hashValue
        Logger.log(level: .debug, category: .nestService, 
            message: "Light image hash: \(lightHash)")
        Logger.log(level: .debug, category: .nestService, 
            message: "Dark image hash: \(darkHash)")
        Logger.log(level: .debug, category: .nestService, 
            message: "Images are different: \(lightHash != darkHash)")
        
        // Upload both images
        let lightURL = try await uploadImage(data: lightData, to: lightRef)
        let darkURL = try await uploadImage(data: darkData, to: darkRef)
        
        return PlaceItem.ThumbnailURLs(light: lightURL, dark: darkURL)
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
                    continuation.resume(throwing: NestError.imageUploadFailed)
                    return
                }
                
                // Get download URL after successful upload
                ref.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let downloadURL = url else {
                        continuation.resume(throwing: NestError.imageUploadFailed)
                        return
                    }
                    
                    continuation.resume(returning: downloadURL.absoluteString)
                }
            }
            
            // Start the upload
            uploadTask.resume()
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
} 

