import Foundation
import FirebaseFirestore
import Combine

final class SitterViewService: EntryRepository {
    // MARK: - Properties
    static let shared = SitterViewService()
    private let db = Firestore.firestore()
    private let sessionService = SessionService.shared
    private let nestService = NestService.shared
    
    @Published private(set) var viewState: ViewState = .loading
    
    // MARK: - ItemRepository Integration
    private var itemRepository: ItemRepository?
    
    enum ViewState {
        case loading
        case ready(session: SessionItem, nest: NestItem)
        case noSession
        case error(Error)
    }
    
    // Computed properties based on viewState
    var currentSession: SessionItem? {
        if case .ready(let session, _) = viewState {
            return session
        }
        return nil
    }
    
    var currentNest: NestItem? {
        if case .ready(_, let nest) = viewState {
            return nest
        }
        return nil
    }
    
    var currentNestName: String? {
        currentNest?.name
    }
    
    var currentNestAddress: String? {
        currentNest?.address
    }
    
    // MARK: - Nest Entries
    private var cachedEntries: [String: [BaseEntry]]?
    
    // MARK: - Unified Item Caching (following NestService pattern)
    private var cachedItems: [BaseItem] = []
    private var sessionFilteredItems: [BaseItem] = []
    
    // Computed property that filters places from session-filtered items
    private var cachedPlaces: [PlaceItem]? {
        guard !sessionFilteredItems.isEmpty else { return nil }
        return sessionFilteredItems.compactMap { $0 as? PlaceItem }
    }
    
    // Computed property that filters entries from session-filtered items
    private var cachedEntriesItems: [BaseEntry]? {
        guard !sessionFilteredItems.isEmpty else { return nil }
        return sessionFilteredItems.compactMap { $0 as? BaseEntry }
    }
    
    // Computed property that filters routines from session-filtered items
    private var cachedRoutines: [RoutineItem]? {
        guard !sessionFilteredItems.isEmpty else { return nil }
        return sessionFilteredItems.compactMap { $0 as? RoutineItem }
    }
    
    // MARK: - Folder Contents Cache (optimizes expensive folder traversals)
    private var cachedFolderContents: [String: FolderContents] = [:]
    
    // MARK: - Image Cache (following NestService pattern)
    private var imageAssets: [String: UIImageAsset] = [:]
    
    func fetchAllItems() async throws -> [BaseItem] {
        return []
    }
    
    /// Unified method to fetch all items with session filtering applied once
    private func fetchAllFilteredItems() async throws -> [BaseItem] {
        Logger.log(level: .info, category: .sitterViewService, message: "fetchAllFilteredItems() called")
        
        // Return cached session-filtered items if available
        if !sessionFilteredItems.isEmpty {
            Logger.log(level: .info, category: .sitterViewService, message: "Using cached session-filtered items (count: \(sessionFilteredItems.count))")
            return sessionFilteredItems
        }
        
        // Get the current nest from our viewState
        guard case .ready(_, let nest) = viewState else {
            throw SessionError.noCurrentNest
        }
        
        // Initialize ItemRepository if needed
        if itemRepository == nil {
            itemRepository = FirebaseItemRepository(nestId: nest.id)
        }
        
        guard let itemRepository = itemRepository else {
            throw SessionError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetching all items for nest: \(nest.id)")
        
        // Fetch all items using ItemRepository ONCE
        let allItems = try await itemRepository.fetchItems()
        self.cachedItems = allItems
        
        // Apply session-specific filtering if specified
        let filteredItems: [BaseItem]
        if let allowedItemIds = currentSession?.entryIds, !allowedItemIds.isEmpty {
            // Filter all items to only those in the session's allowed list
            filteredItems = allItems.filter { allowedItemIds.contains($0.id) }
            Logger.log(level: .info, category: .sitterViewService, message: "Filtered \(allItems.count) items to \(filteredItems.count) based on session entryIds")
            Logger.log(level: .info, category: .sitterViewService, message: "Session entryIds: \(allowedItemIds)")
            Logger.log(level: .info, category: .sitterViewService, message: "All item IDs: \(allItems.map { $0.id })")
            Logger.log(level: .info, category: .sitterViewService, message: "Filtered item IDs: \(filteredItems.map { $0.id })")
        } else {
            // Backward compatibility: show all items if no filtering specified
            filteredItems = allItems
            Logger.log(level: .info, category: .sitterViewService, message: "No item filtering applied - showing all \(filteredItems.count) items")
            Logger.log(level: .info, category: .sitterViewService, message: "Session entryIds is nil or empty: \(currentSession?.entryIds?.description ?? "nil")")
        }
        
        // Cache the session-filtered items
        self.sessionFilteredItems = filteredItems
        
        Logger.log(level: .info, category: .sitterViewService, message: "Cached \(filteredItems.count) session-filtered items ✅")
        return filteredItems
    }
    
    /// Fetches entries for the current nest, using cache if available
    func fetchNestEntries() async throws -> [String: [BaseEntry]] {
        Logger.log(level: .info, category: .sitterViewService, message: "fetchNestEntries() called - using unified approach")
        
        // Return cached entries if available
        if let cachedEntries = cachedEntries {
            Logger.log(level: .info, category: .sitterViewService, message: "Using cached entries")
            return cachedEntries
        }
        
        // Get session-filtered items using unified method (this is cached after first call)
        let filteredItems = try await fetchAllFilteredItems()
        
        // Filter to only entry items (already BaseEntry from repository)
        let entries = filteredItems.compactMap { item -> BaseEntry? in
            guard item.type == .entry, let baseEntry = item as? BaseEntry else { return nil }
            return baseEntry
        }
        
        // Group entries by category
        let groupedEntries = Dictionary(grouping: entries) { $0.category }
        
        // Cache the entries
        self.cachedEntries = groupedEntries
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetched \(entries.count) entries using unified approach ✅")
        return groupedEntries
    }
    
    /// Clears the entries cache
    func clearEntriesCache() {
        Logger.log(level: .info, category: .sitterViewService, message: "Clearing entries cache")
        cachedEntries = nil
        // Clear folder contents cache since entries changed
        clearFolderContentsCache()
        // Also clear ItemRepository cache
        itemRepository?.clearItemsCache()
    }
    
    /// Clears the items cache (places are computed from this)
    func clearItemsCache() {
        Logger.log(level: .info, category: .sitterViewService, message: "Clearing items cache and session-filtered cache")
        cachedItems = []
        sessionFilteredItems = []
        // Clear folder contents cache since items changed
        clearFolderContentsCache()
        // Also clear ItemRepository cache
        itemRepository?.clearItemsCache()
    }
    
    /// Clears the places cache (now a no-op since places are computed)
    func clearPlacesCache() {
        // Places are now computed from cachedItems, so just clear that
        Logger.log(level: .info, category: .sitterViewService, message: "🐕 DEBUG: Clearing places cache - forcing fresh fetch")
        clearItemsCache()
    }
    
    /// Clears the folder contents cache
    func clearFolderContentsCache() {
        Logger.log(level: .info, category: .sitterViewService, message: "📁 Clearing folder contents cache")
        cachedFolderContents.removeAll()
    }
    
    /// Forces a refresh of the entries
    func refreshEntries() async throws -> [String: [BaseEntry]] {
        clearEntriesCache()
        return try await fetchNestEntries()
    }
    
    /// Forces a refresh of the places
    func refreshPlaces() async throws -> [PlaceItem] {
        clearPlacesCache()
        return try await fetchNestPlaces()
    }
    
    // MARK: - Places
    
    /// Fetches places for the current nest, using cache if available
    func fetchNestPlaces() async throws -> [PlaceItem] {
        Logger.log(level: .info, category: .sitterViewService, message: "fetchNestPlaces() called - using unified approach")
        
        // Return cached places if available
        if let cachedPlaces = cachedPlaces {
            Logger.log(level: .info, category: .sitterViewService, message: "Using cached places (count: \(cachedPlaces.count))")
            return cachedPlaces
        }
        
        // Get session-filtered items using unified method (this is cached after first call)
        let filteredItems = try await fetchAllFilteredItems()
        
        // Filter to only place items from session-filtered items
        let places = filteredItems.compactMap { item -> PlaceItem? in
            guard item.type == .place, let placeItem = item as? PlaceItem else { return nil }
            return placeItem
        }
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetched \(places.count) places using unified approach ✅")
        return places
    }
    
    // MARK: - Routines
    
    /// Fetches routines for the current nest, using cache if available
    func fetchNestRoutines() async throws -> [RoutineItem] {
        Logger.log(level: .info, category: .sitterViewService, message: "fetchNestRoutines() called - using unified approach")
        
        // Return cached routines if available
        if let cachedRoutines = cachedRoutines {
            Logger.log(level: .info, category: .sitterViewService, message: "Using cached routines (count: \(cachedRoutines.count))")
            return cachedRoutines
        }
        
        // Get session-filtered items using unified method (this is cached after first call)
        let filteredItems = try await fetchAllFilteredItems()
        
        // Filter to only routine items from session-filtered items
        let routines = filteredItems.compactMap { item -> RoutineItem? in
            guard item.type == .routine, let routineItem = item as? RoutineItem else { return nil }
            return routineItem
        }
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetched \(routines.count) routines using unified approach ✅")
        return routines
    }
    
    /// Forces a refresh of the routines
    func refreshRoutines() async throws -> [RoutineItem] {
        clearItemsCache() // This will clear the session-filtered items which includes routines
        return try await fetchNestRoutines()
    }
    
    /// Fetch both entries and places in a single efficient call (matching NestService pattern)
    func fetchEntriesAndPlaces() async throws -> (entries: [String: [BaseEntry]], places: [PlaceItem]) {
        Logger.log(level: .info, category: .sitterViewService, message: "📦 fetchEntriesAndPlaces() called - efficient single fetch")
        
        let filteredItems = try await fetchAllFilteredItems() // Single fetch with session filtering
        
        // Filter entries (already BaseEntry from repository)
        let entryItems = filteredItems.compactMap { item -> BaseEntry? in
            guard item.type == .entry else { return nil }
            return item as? BaseEntry
        }
        let groupedEntries = Dictionary(grouping: entryItems) { $0.category }
        
        // Filter places
        let placeItems = filteredItems.compactMap { $0 as? PlaceItem }
        
        Logger.log(level: .info, category: .sitterViewService, message: "Efficient fetch complete - \(groupedEntries.count) entry groups, \(placeItems.count) places")
        return (entries: groupedEntries, places: placeItems)
    }
    
    /// Fetch routines (matching NestService pattern)
    func fetchRoutines() async throws -> [RoutineItem] {
        Logger.log(level: .info, category: .sitterViewService, message: "fetchRoutines() called")
        return try await fetchNestRoutines()
    }
    
    // MARK: - Folder Contents Structure (using shared FolderUtility)
    typealias FolderContents = FolderUtility.FolderContents
    
    /// Fetch all contents for a specific folder/category
    func fetchFolderContents(for category: String) async throws -> FolderContents {
        Logger.log(level: .info, category: .sitterViewService, message: "📁 fetchFolderContents() called for category: '\(category)'")
        
        // Check cache first to avoid expensive folder traversals
        if let cachedContents = cachedFolderContents[category] {
            Logger.log(level: .info, category: .sitterViewService, message: "📁 Using cached folder contents for '\(category)' - \(cachedContents.entries.count) entries, \(cachedContents.places.count) places, \(cachedContents.routines.count) routines, \(cachedContents.subfolders.count) subfolders")
            return cachedContents
        }
        
        Logger.log(level: .info, category: .sitterViewService, message: "📁 Cache miss - performing folder traversal for '\(category)'")
        
        // Get all data in one efficient call - matching NestService pattern
        let (allGroupedEntries, allPlaces) = try await fetchEntriesAndPlaces()
        let allRoutines = try await fetchRoutines()
        let categories = try await fetchCategories()
        
        Logger.log(level: .info, category: .sitterViewService, message: "📁 fetchFolderContents data gathered")
        
        // Build folder contents using shared utility (SitterViewService now supports routines)
        let folderContents = FolderUtility.buildFolderContents(
            for: category,
            allGroupedEntries: allGroupedEntries,
            allPlaces: allPlaces,
            allRoutines: allRoutines,
            categories: categories
        )
        
        Logger.log(level: .info, category: .sitterViewService, message: "📊 DEBUGGING FOLDER COUNTS for '\(category)':")
        Logger.log(level: .info, category: .sitterViewService, message: "📊 Direct items: \(folderContents.entries.count) entries, \(folderContents.places.count) places, \(folderContents.routines.count) routines")
        Logger.log(level: .info, category: .sitterViewService, message: "📊 Subfolders: \(folderContents.subfolders.count)")
        Logger.log(level: .info, category: .sitterViewService, message: "📊 Subfolder details: \(folderContents.subfolders.map { "\($0.title)(\($0.itemCount))" }.joined(separator: ", "))")
        Logger.log(level: .info, category: .sitterViewService, message: "📊 Total visible items should be: \(folderContents.entries.count + folderContents.places.count + folderContents.routines.count + folderContents.subfolders.count)")
        
        // Cache the result to speed up future requests
        cachedFolderContents[category] = folderContents
        Logger.log(level: .info, category: .sitterViewService, message: "📁 Cached folder contents for '\(category)'")
        
        return folderContents
    }
    
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Session Management
    func fetchCurrentSession() async throws {
        Logger.log(level: .info, category: .sitterViewService, message: "Starting fetchCurrentSession")
        
        // Safely update viewState on main actor
        await MainActor.run {
            self.viewState = .loading
        }
        
        // Add artificial delay to make loading state visible
        do {
            try await Task.sleep(nanoseconds: 750_000_000) // 0.75 seconds
        } catch {
            Logger.log(level: .error, category: .sitterViewService, message: "Task sleep interrupted: \(error.localizedDescription)")
            // Continue anyway
        }
        
        // Validate user ID
        guard let userID = UserService.shared.currentUser?.id, !userID.isEmpty else {
            Logger.log(level: .error, category: .sitterViewService, message: "No current user or empty user ID")
            await MainActor.run {
                self.viewState = .error(SessionError.userNotAuthenticated)
            }
            return
        }
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetching current session for sitter: \(userID)")
        
        do {
            // Step 1: Try to get the current session with additional validation
            Logger.log(level: .debug, category: .sitterViewService, message: "Step 1: Fetching in-progress session")
            
            let session: SessionItem
            do {
                guard let fetchedSession = try await sessionService.fetchInProgressSitterSession(userID: userID) else {
                    Logger.log(level: .info, category: .sitterViewService, message: "No active session found for user")
                    await MainActor.run {
                        self.viewState = .noSession
                    }
                    return
                }
                session = fetchedSession
                Logger.log(level: .debug, category: .sitterViewService, message: "Successfully fetched session: \(session.id) with status: \(session.status)")
            } catch {
                Logger.log(level: .error, category: .sitterViewService, message: "Failed to fetch in-progress session: \(error.localizedDescription)")
                await MainActor.run {
                    self.viewState = .error(error)
                }
                throw error
            }
            
            // Step 2: Get the sitter session to get the nest ID
            Logger.log(level: .debug, category: .sitterViewService, message: "Step 2: Fetching sitter session for session ID: \(session.id)")
            
            let sitterSession: SitterSession
            do {
                guard let fetchedSitterSession = try await sessionService.getSitterSession(sessionID: session.id) else {
                    Logger.log(level: .error, category: .sitterViewService, message: "Sitter session not found for session ID: \(session.id)")
                    await MainActor.run {
                        self.viewState = .error(SessionError.sessionNotFound)
                    }
                    return
                }
                sitterSession = fetchedSitterSession
                Logger.log(level: .debug, category: .sitterViewService, message: "Successfully fetched sitter session for nest: \(sitterSession.nestID)")
            } catch {
                Logger.log(level: .error, category: .sitterViewService, message: "Failed to fetch sitter session: \(error.localizedDescription)")
                await MainActor.run {
                    self.viewState = .error(error)
                }
                throw error
            }
            
            // Step 3: Fetch the full nest information with validation
            Logger.log(level: .debug, category: .sitterViewService, message: "Step 3: Fetching nest information for ID: \(sitterSession.nestID)")
            
            let nest: NestItem
            do {
                let nestRef = db.collection("nests").document(sitterSession.nestID)
                let nestDoc = try await nestRef.getDocument()
                
                guard nestDoc.exists else {
                    Logger.log(level: .error, category: .sitterViewService, message: "Nest document does not exist: \(sitterSession.nestID)")
                    await MainActor.run {
                        self.viewState = .error(SessionError.sessionNotFound)
                    }
                    return
                }
                
                var fetchedNest = try nestDoc.data(as: NestItem.self)
                Logger.log(level: .debug, category: .sitterViewService, message: "Successfully decoded nest: \(fetchedNest.name)")
                
                // Step 4: Fetch categories for the nest with error handling
                Logger.log(level: .debug, category: .sitterViewService, message: "Step 4: Fetching categories for nest")
                
                do {
                    let categoriesRef = nestRef.collection("nestCategories")
                    let categoriesSnapshot = try await categoriesRef.getDocuments()
                    
                    var validCategories: [NestCategory] = []
                    for (index, document) in categoriesSnapshot.documents.enumerated() {
                        do {
                            let category = try document.data(as: NestCategory.self)
                            validCategories.append(category)
                        } catch {
                            Logger.log(level: .error, category: .sitterViewService, message: "Failed to decode category at index \(index): \(error.localizedDescription)")
                            // Continue with other categories
                        }
                    }
                    
                    fetchedNest.categories = validCategories
                    Logger.log(level: .debug, category: .sitterViewService, message: "Successfully fetched \(validCategories.count) categories")
                } catch {
                    Logger.log(level: .error, category: .sitterViewService, message: "Failed to fetch categories, continuing without them: \(error.localizedDescription)")
                    fetchedNest.categories = []
                }
                
                nest = fetchedNest
            } catch {
                Logger.log(level: .error, category: .sitterViewService, message: "Failed to fetch nest information: \(error.localizedDescription)")
                await MainActor.run {
                    self.viewState = .error(error)
                }
                throw error
            }
            
            // Step 5: Clear caches when switching nests (with nil safety)
            await MainActor.run {
                if self.currentNest?.id != nest.id {
                    Logger.log(level: .debug, category: .sitterViewService, message: "Switching nests, clearing caches")
                    self.clearEntriesCache()
                    self.clearItemsCache()
                    self.clearImageCache()
                }
            }
            
            // Step 6: Update state with session and nest information
            Logger.log(level: .debug, category: .sitterViewService, message: "Step 6: Updating view state")
            await MainActor.run {
                self.viewState = .ready(session: session, nest: nest)
            }
            
            // Step 7: Fetch entries for the nest (non-critical, don't fail if this errors)
            Logger.log(level: .debug, category: .sitterViewService, message: "Step 7: Fetching nest entries")
            do {
                _ = try await fetchNestEntries()
                Logger.log(level: .debug, category: .sitterViewService, message: "Successfully fetched nest entries")
            } catch {
                Logger.log(level: .error, category: .sitterViewService, message: "Failed to fetch nest entries (non-critical): \(error.localizedDescription)")
                // Don't fail the entire operation for this
            }
            
            Logger.log(level: .info, category: .sitterViewService, message: "fetchCurrentSession completed successfully ✅")
            
        } catch {
            Logger.log(level: .error, category: .sitterViewService, message: "Critical error in fetchCurrentSession: \(error.localizedDescription)")
            await MainActor.run {
                self.viewState = .error(error)
            }
            throw error
        }
    }
    
    func reset() {
        Logger.log(level: .info, category: .sitterViewService, message: "Resetting SitterViewService")
        viewState = .loading
        clearEntriesCache()
        clearItemsCache()
        clearFolderContentsCache()
        clearImageCache()
        // Clear ItemRepository reference
        itemRepository = nil
    }
    
    // MARK: - Session Access
    var hasActiveSession: Bool {
        if case .ready = viewState {
            return true
        }
        return false
    }
    
    /// Temporarily sets the view state for a specific session context
    /// Used when sitter needs to explore a nest from a session detail view
    func setTemporarySessionContext(session: SessionItem, nest: NestItem) {
        Logger.log(level: .info, category: .sitterViewService, message: "Setting temporary session context for nest: \(nest.id)")
        
        // Clear any existing caches since we're switching context
        clearEntriesCache()
        clearItemsCache()
        clearFolderContentsCache()
        clearImageCache()
        
        // Set the view state to the provided session and nest
        viewState = .ready(session: session, nest: nest)
    }
    
    /// Force clears all caches to ensure fresh data with proper session filtering
    func forceRefreshAllCaches() {
        Logger.log(level: .info, category: .sitterViewService, message: "🐕 DEBUG: Force clearing ALL caches to refresh session filtering")
        clearEntriesCache()
        clearItemsCache()
        clearFolderContentsCache()
        clearImageCache()
        // Also clear ItemRepository cache
        itemRepository?.clearItemsCache()
    }
    
    // MARK: - Notifications
    func notifySessionChange() {
        NotificationCenter.default.post(name: .sessionDidChange, object: nil)
    }
    
    // MARK: - EntryRepository Implementation
    func fetchEntries() async throws -> [String: [BaseEntry]] {
        return try await fetchNestEntries()
    }
    
    func createEntry(_ entry: BaseEntry) async throws {
        Logger.log(level: .info, category: .sitterViewService, message: "createEntry() called - using ItemRepository")
        
        guard case .ready(_, let nest) = viewState else {
            throw SessionError.noCurrentNest
        }
        
        // Initialize ItemRepository if needed
        if itemRepository == nil {
            itemRepository = FirebaseItemRepository(nestId: nest.id)
        }
        
        guard let itemRepository = itemRepository else {
            throw SessionError.noCurrentNest
        }
        
        // Create BaseEntry directly
        try await itemRepository.createItem(entry)
        clearEntriesCache() // This also clears folder contents cache
    }
    
    func updateEntry(_ entry: BaseEntry) async throws {
        Logger.log(level: .info, category: .sitterViewService, message: "updateEntry() called - using ItemRepository")
        
        guard case .ready(_, let nest) = viewState else {
            throw SessionError.noCurrentNest
        }
        
        // Initialize ItemRepository if needed
        if itemRepository == nil {
            itemRepository = FirebaseItemRepository(nestId: nest.id)
        }
        
        guard let itemRepository = itemRepository else {
            throw SessionError.noCurrentNest
        }
        
        // Update BaseEntry directly
        try await itemRepository.updateItem(entry)
        clearEntriesCache() // This also clears folder contents cache
    }
    
    func deleteEntry(_ entry: BaseEntry) async throws {
        Logger.log(level: .info, category: .sitterViewService, message: "deleteEntry() called - using ItemRepository")
        
        guard case .ready(_, let nest) = viewState else {
            throw SessionError.noCurrentNest
        }
        
        // Initialize ItemRepository if needed
        if itemRepository == nil {
            itemRepository = FirebaseItemRepository(nestId: nest.id)
        }
        
        guard let itemRepository = itemRepository else {
            throw SessionError.noCurrentNest
        }
        
        // Delete using ItemRepository
        try await itemRepository.deleteItem(id: entry.id)
        clearEntriesCache() // This also clears folder contents cache
    }
    
    // MARK: - Category Methods
    func fetchCategories() async throws -> [NestCategory] {
        guard case .ready(_, let nest) = viewState else {
            throw SessionError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetching categories for nest: \(nest.id)")
        
        let categoriesRef = db.collection("nests").document(nest.id).collection("nestCategories")
        let snapshot = try await categoriesRef.getDocuments()
        let categories = try snapshot.documents.map { try $0.data(as: NestCategory.self) }
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetched \(categories.count) categories")
        return categories
    }
    
    func refreshCategories() async throws -> [NestCategory] {
        return try await fetchCategories()
    }
    
    // MARK: - Place Management (EntryRepository Protocol Conformance)
    
    /// Fetches all places for the current nest
    func fetchPlaces() async throws -> [PlaceItem] {
        return try await fetchNestPlaces()
    }
    
    /// Fetches places with filtering options
    func fetchPlacesWithFilter(includeTemporary: Bool = true) async throws -> [PlaceItem] {
        Logger.log(level: .info, category: .sitterViewService, message: "fetchPlacesWithFilter() called with includeTemporary: \(includeTemporary)")
        
        let placeItems = try await fetchNestPlaces()
        var filteredPlaces = placeItems
        
        // Filter out temporary places if not requested
        if !includeTemporary {
            filteredPlaces = filteredPlaces.filter { !$0.isTemporary }
        }
        
        Logger.log(level: .info, category: .sitterViewService, message: "Returning \(filteredPlaces.count) places (\(filteredPlaces.filter(\.isTemporary).count) temporary)")
        return filteredPlaces
    }
    
    /// Gets a specific place by ID
    func getPlace(for id: String) async throws -> PlaceItem? {
        Logger.log(level: .info, category: .sitterViewService, message: "getPlace() called for id: \(id)")
        
        guard case .ready(_, let nest) = viewState else {
            throw SessionError.noCurrentNest
        }
        
        // Initialize ItemRepository if needed
        if itemRepository == nil {
            itemRepository = FirebaseItemRepository(nestId: nest.id)
        }
        
        guard let itemRepository = itemRepository else {
            throw SessionError.noCurrentNest
        }
        
        // Try ItemRepository first
        if let item = try await itemRepository.fetchItem(id: id),
           let placeItem = item as? PlaceItem {
            return placeItem
        }
        
        Logger.log(level: .info, category: .sitterViewService, message: "Place not found: \(id)")
        return nil
    }
    
    // MARK: - Image Management (following NestService pattern)
    
    /// Loads images for a place with caching (mirrors NestService implementation)
    func loadImages(for place: PlaceItem) async throws -> UIImage {
        Logger.log(level: .debug, category: .sitterViewService, message: "loadImages() called for place: \(place.alias ?? place.title)")
        
        // If the place has no thumbnails (temporary place), return a placeholder
        guard let thumbnailURLs = place.thumbnailURLs else {
            Logger.log(level: .debug, category: .sitterViewService, message: "Place has no thumbnails, returning placeholder")
            return UIImage(systemName: "mappin.circle") ?? UIImage()
        }
        
        // Check cache first - exactly like working NestService
        if let asset = imageAssets[place.id] {
            Logger.log(level: .debug, category: .sitterViewService, message: "Found cached image asset for place: \(place.alias ?? place.title)")
            return asset.image(with: .current)
        }
        
        Logger.log(level: .debug, category: .sitterViewService, message: "Cache miss - loading images from URLs - Light: \(thumbnailURLs.light), Dark: \(thumbnailURLs.dark)")
        
        // Load both images concurrently - exactly like working NestService
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
            
            // Cache the asset for future use - following NestService pattern
            self.imageAssets[place.id] = dynamicImage.imageAsset
            Logger.log(level: .debug, category: .sitterViewService, message: "Cached image asset and created dynamic image for place: \(place.alias ?? place.title)")
            
            return dynamicImage
        }
    }
    
    private func loadSingleImage(from urlString: String) async throws -> UIImage {
        guard let imageURL = URL(string: urlString) else {
            throw SitterViewError.invalidImageURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        
        guard let image = UIImage(data: data) else {
            throw SitterViewError.imageConversionFailed
        }
        
        Logger.log(level: .debug, category: .sitterViewService, message: "Loaded image from URL: \(urlString)")
        return image
    }
    
    /// Clear the image cache - following NestService pattern
    func clearImageCache() {
        Logger.log(level: .info, category: .sitterViewService, message: "Clearing image cache")
        imageAssets.removeAll()
    }
}

// MARK: - SitterView Errors
extension SitterViewService {
    enum SitterViewError: LocalizedError {
        case invalidImageURL
        case imageConversionFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidImageURL:
                return "Invalid image URL"
            case .imageConversionFailed:
                return "Failed to convert image data to UIImage"
            }
        }
    }
} 
