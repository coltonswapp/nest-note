import Foundation
import FirebaseFirestore
import Combine

final class SitterViewService: NestItemRepository {
    // MARK: - Properties
    static let shared = SitterViewService()
    private let db = Firestore.firestore()
    private let sessionService = SessionService.shared
    private let nestService = NestService.shared
    
    @Published private(set) var viewState: ViewState = .loading
    
    // MARK: - ItemRepository Integration
    private var itemRepository: ItemRepository?

    /// Coalesces overlapping `fetchCurrentSession` calls onto one in-flight task.
    private let fetchSessionLock = NSLock()
    private var fetchSessionTask: Task<Void, Error>?
    private var pendingForceRefresh = false
    
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
    private var cachedNotes: [String: [NoteItem]]?
    
    // MARK: - Unified Item Caching (following NestService pattern)
    private var cachedItems: [BaseItem] = []
    private var sessionFilteredItems: [BaseItem] = []
    
    // Computed property that filters places from session-filtered items
    private var cachedPlaces: [PlaceItem]? {
        guard !sessionFilteredItems.isEmpty else { return nil }
        return sessionFilteredItems.compactMap { $0 as? PlaceItem }
    }
    
    // Computed property that filters entries from session-filtered items
    private var cachedEntriesItems: [NoteItem]? {
        guard !sessionFilteredItems.isEmpty else { return nil }
        return sessionFilteredItems.compactMap { $0 as? NoteItem }
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
        try await fetchAllFilteredItems()
    }

    /// Unfiltered nest items for resolving attachment IDs on selected parents.
    /// Ensures the full nest cache is warm, then resolves against it (not session-filtered).
    func itemsForAttachmentResolution() async throws -> [BaseItem] {
        _ = try await fetchAllFilteredItems()
        return cachedItems
    }
    
    /// Unified method to fetch all items with session filtering applied once
    private func fetchAllFilteredItems() async throws -> [BaseItem] {
        if !sessionFilteredItems.isEmpty {
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
        
        let allItems = try await itemRepository.fetchItems()
        self.cachedItems = allItems

        let filteredItems: [BaseItem]
        if let allowedItemIds = currentSession?.entryIds, !allowedItemIds.isEmpty {
            filteredItems = allItems.filter { allowedItemIds.contains($0.id) }
        } else {
            filteredItems = allItems
        }

        self.sessionFilteredItems = filteredItems
        return filteredItems
    }
    
    /// Fetches entries for the current nest, using cache if available
    func fetchNestNotes() async throws -> [String: [NoteItem]] {
        if let cachedNotes = cachedNotes {
            return cachedNotes
        }
        
        // Get session-filtered items using unified method (this is cached after first call)
        let filteredItems = try await fetchAllFilteredItems()
        
        // Filter to only entry items (already NoteItem from repository)
        let notes = filteredItems.compactMap { item -> NoteItem? in
            guard item.type == .entry, let baseEntry = item as? NoteItem else { return nil }
            return baseEntry
        }
        
        // Group entries by category
        let groupedNotes = Dictionary(grouping: notes) { $0.category }
        
        // Cache the notes
        self.cachedNotes = groupedNotes
        return groupedNotes
    }
    
    /// Clears the entries cache
    func clearNotesCache() {
        debugLog("Clearing entries cache")
        cachedNotes = nil
        // Clear folder contents cache since entries changed
        clearFolderContentsCache()
        // Also clear ItemRepository cache
        itemRepository?.clearItemsCache()
    }
    
    /// Clears the items cache (places are computed from this)
    func clearItemsCache() {
        debugLog("Clearing items cache and session-filtered cache")
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
        debugLog("🐕 DEBUG: Clearing places cache - forcing fresh fetch")
        clearItemsCache()
    }
    
    /// Clears the folder contents cache
    func clearFolderContentsCache() {
        debugLog("📁 Clearing folder contents cache")
        cachedFolderContents.removeAll()
    }
    
    /// Forces a refresh of the notes
    func refreshNotes() async throws -> [String: [NoteItem]] {
        clearNotesCache()
        return try await fetchNestNotes()
    }
    
    /// Forces a refresh of the places
    func refreshPlaces() async throws -> [PlaceItem] {
        clearPlacesCache()
        return try await fetchNestPlaces()
    }
    
    // MARK: - Places
    
    /// Fetches places for the current nest, using cache if available
    func fetchNestPlaces() async throws -> [PlaceItem] {
        debugLog("fetchNestPlaces() called - using unified approach")
        
        // Return cached places if available
        if let cachedPlaces = cachedPlaces {
            debugLog("Using cached places (count: \(cachedPlaces.count))")
            return cachedPlaces
        }
        
        // Get session-filtered items using unified method (this is cached after first call)
        let filteredItems = try await fetchAllFilteredItems()
        
        // Filter to only place items from session-filtered items
        let places = filteredItems.compactMap { item -> PlaceItem? in
            guard item.type == .place, let placeItem = item as? PlaceItem else { return nil }
            return placeItem
        }
        
        debugLog("Fetched \(places.count) places using unified approach ✅")
        return places
    }
    
    // MARK: - Routines
    
    /// Fetches routines for the current nest, using cache if available
    func fetchNestRoutines() async throws -> [RoutineItem] {
        debugLog("fetchNestRoutines() called - using unified approach")
        
        // Return cached routines if available
        if let cachedRoutines = cachedRoutines {
            debugLog("Using cached routines (count: \(cachedRoutines.count))")
            return cachedRoutines
        }
        
        // Get session-filtered items using unified method (this is cached after first call)
        let filteredItems = try await fetchAllFilteredItems()
        
        // Filter to only routine items from session-filtered items
        let routines = filteredItems.compactMap { item -> RoutineItem? in
            guard item.type == .routine, let routineItem = item as? RoutineItem else { return nil }
            return routineItem
        }
        
        debugLog("Fetched \(routines.count) routines using unified approach ✅")
        return routines
    }
    
    /// Forces a refresh of the routines
    func refreshRoutines() async throws -> [RoutineItem] {
        clearItemsCache() // This will clear the session-filtered items which includes routines
        return try await fetchNestRoutines()
    }
    
    /// Fetch both entries and places in a single efficient call (matching NestService pattern)
    func fetchNotesAndPlaces() async throws -> (notes: [String: [NoteItem]], places: [PlaceItem]) {
        debugLog("📦 fetchNotesAndPlaces() called - efficient single fetch")
        
        let filteredItems = try await fetchAllFilteredItems() // Single fetch with session filtering
        
        // Filter entries (already NoteItem from repository)
        let entryItems = filteredItems.compactMap { item -> NoteItem? in
            guard item.type == .entry else { return nil }
            return item as? NoteItem
        }
        let groupedNotes = Dictionary(grouping: entryItems) { $0.category }
        
        // Filter places
        let placeItems = filteredItems.compactMap { $0 as? PlaceItem }
        
        debugLog("Efficient fetch complete - \(groupedNotes.count) entry groups, \(placeItems.count) places")
        return (notes: groupedNotes, places: placeItems)
    }
    
    /// Fetch routines (matching NestService pattern)
    func fetchRoutines() async throws -> [RoutineItem] {
        debugLog("fetchRoutines() called")
        return try await fetchNestRoutines()
    }
    
    // MARK: - Folder Contents Structure (using shared FolderUtility)
    typealias FolderContents = FolderUtility.FolderContents
    
    /// Fetch all contents for a specific folder/category
    func fetchFolderContents(for category: String) async throws -> FolderContents {
        debugLog("📁 fetchFolderContents() called for category: '\(category)'")
        
        // Check cache first to avoid expensive folder traversals
        if let cachedContents = cachedFolderContents[category] {
            debugLog("📁 Using cached folder contents for '\(category)' - \(cachedContents.notes.count) entries, \(cachedContents.places.count) places, \(cachedContents.routines.count) routines, \(cachedContents.subfolders.count) subfolders")
            return cachedContents
        }
        
        debugLog("📁 Cache miss - performing folder traversal for '\(category)'")
        
        let allItems = try await fetchAllFilteredItems()
        let categories = try await fetchCategories()
        
        debugLog("📁 fetchFolderContents data gathered")
        
        let folderContents = FolderUtility.buildFolderContents(
            for: category,
            allItems: allItems,
            categories: categories
        )
        
        debugLog("📊 DEBUGGING FOLDER COUNTS for '\(category)':")
        debugLog("📊 Direct items: \(folderContents.notes.count) entries, \(folderContents.places.count) places, \(folderContents.routines.count) routines")
        debugLog("📊 Subfolders: \(folderContents.subfolders.count)")
        debugLog("📊 Subfolder details: \(folderContents.subfolders.map { "\($0.title)(\($0.itemCount))" }.joined(separator: ", "))")
        debugLog("📊 Total visible items should be: \(folderContents.notes.count + folderContents.places.count + folderContents.routines.count + folderContents.subfolders.count)")
        
        // Cache the result to speed up future requests
        cachedFolderContents[category] = folderContents
        debugLog("📁 Cached folder contents for '\(category)'")
        
        return folderContents
    }
    
    
    // MARK: - Initialization
    private init() {}

    private func debugLog(_ message: String, level: Logger.Level = .info) {
        #if DEBUG
        Logger.log(level: level, category: .sitterViewService, message: message)
        #endif
    }
    
    // MARK: - Session Management
    func fetchCurrentSession(forceRefresh: Bool = false) async throws {
        let (task, isOwner) = takeOrCreateFetchTask(forceRefresh: forceRefresh)
        do {
            try await task.value
        } catch {
            if isOwner {
                _ = finishFetchTask()
            }
            throw error
        }

        guard isOwner else { return }

        if finishFetchTask() {
            try await fetchCurrentSession()
        }
    }

    private func takeOrCreateFetchTask(forceRefresh: Bool) -> (Task<Void, Error>, Bool) {
        fetchSessionLock.lock()
        defer { fetchSessionLock.unlock() }

        if let existing = fetchSessionTask {
            if forceRefresh {
                pendingForceRefresh = true
            }
            return (existing, false)
        }

        let newTask = Task {
            try await self.executeFetchCurrentSession()
        }
        fetchSessionTask = newTask
        return (newTask, true)
    }

    /// Clears the in-flight task. Returns whether a force-refresh follow-up is pending.
    @discardableResult
    private func finishFetchTask() -> Bool {
        fetchSessionLock.lock()
        defer { fetchSessionLock.unlock() }
        fetchSessionTask = nil
        let followUp = pendingForceRefresh
        pendingForceRefresh = false
        return followUp
    }

    private func executeFetchCurrentSession() async throws {
        try Task.checkCancellation()
        await MainActor.run {
            self.viewState = .loading
        }

        try Task.checkCancellation()
        guard let userID = UserService.shared.currentUser?.id, !userID.isEmpty else {
            await MainActor.run {
                self.viewState = .error(SessionError.userNotAuthenticated)
            }
            return
        }

        do {
            let session: SessionItem
            do {
                try Task.checkCancellation()
                guard let fetchedSession = try await sessionService.fetchInProgressSitterSession(userID: userID) else {
                    try Task.checkCancellation()
                    await MainActor.run {
                        self.viewState = .noSession
                    }
                    return
                }
                session = fetchedSession
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                await MainActor.run {
                    self.viewState = .error(error)
                }
                throw error
            }

            let sitterSession: SitterSession
            do {
                try Task.checkCancellation()
                guard let fetchedSitterSession = try await sessionService.getSitterSession(sessionID: session.id) else {
                    try Task.checkCancellation()
                    await MainActor.run {
                        self.viewState = .error(SessionError.sessionNotFound)
                    }
                    return
                }
                sitterSession = fetchedSitterSession
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                await MainActor.run {
                    self.viewState = .error(error)
                }
                throw error
            }

            let nest: NestItem
            do {
                try Task.checkCancellation()
                let nestRef = db.collection("nests").document(sitterSession.nestID)
                let nestDoc = try await nestRef.getDocument()

                guard nestDoc.exists else {
                    try Task.checkCancellation()
                    await MainActor.run {
                        self.viewState = .error(SessionError.sessionNotFound)
                    }
                    return
                }

                var fetchedNest = try nestDoc.data(as: NestItem.self)

                do {
                    let categoriesRef = nestRef.collection("nestCategories")
                    let categoriesSnapshot = try await categoriesRef.getDocuments()

                    var validCategories: [NestCategory] = []
                    for document in categoriesSnapshot.documents {
                        if let category = try? document.data(as: NestCategory.self) {
                            validCategories.append(category)
                        }
                    }

                    fetchedNest.categories = validCategories
                } catch {
                    fetchedNest.categories = []
                }

                nest = fetchedNest
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                await MainActor.run {
                    self.viewState = .error(error)
                }
                throw error
            }

            try Task.checkCancellation()
            await MainActor.run {
                if self.currentNest?.id != nest.id {
                    self.clearNotesCache()
                    self.clearItemsCache()
                    self.clearImageCache()
                }
            }

            try Task.checkCancellation()
            await MainActor.run {
                self.viewState = .ready(session: session, nest: nest)
            }

            do {
                try Task.checkCancellation()
                _ = try await fetchNestNotes()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Nest entries are non-critical for showing the session.
            }

        } catch is CancellationError {
            throw CancellationError()
        } catch {
            await MainActor.run {
                self.viewState = .error(error)
            }
            throw error
        }
    }
    
    func reset() {
        fetchSessionLock.lock()
        fetchSessionTask?.cancel()
        fetchSessionTask = nil
        pendingForceRefresh = false
        fetchSessionLock.unlock()

        debugLog("Resetting SitterViewService")
        viewState = .loading
        clearNotesCache()
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
        debugLog("Setting temporary session context for nest: \(nest.id)")
        
        // Clear any existing caches since we're switching context
        clearNotesCache()
        clearItemsCache()
        clearFolderContentsCache()
        clearImageCache()
        
        // Set the view state to the provided session and nest
        viewState = .ready(session: session, nest: nest)
    }
    
    /// Force clears all caches to ensure fresh data with proper session filtering
    func forceRefreshAllCaches() {
        debugLog("🐕 DEBUG: Force clearing ALL caches to refresh session filtering")
        clearNotesCache()
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
    
    // MARK: - NestItemRepository Implementation
    func fetchNotes() async throws -> [String: [NoteItem]] {
        return try await fetchNestNotes()
    }
    
    func createNote(_ entry: NoteItem) async throws {
        debugLog("createNote() called - using ItemRepository")
        
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
        
        // Create NoteItem directly
        try await itemRepository.createItem(entry)
        clearNotesCache() // This also clears folder contents cache
    }
    
    func updateNote(_ entry: NoteItem) async throws {
        debugLog("updateNote() called - using ItemRepository")
        
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
        
        // Update NoteItem directly
        try await itemRepository.updateItem(entry)
        clearNotesCache() // This also clears folder contents cache
    }
    
    func deleteNote(_ entry: NoteItem) async throws {
        debugLog("deleteNote() called - using ItemRepository")
        
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
        clearNotesCache() // This also clears folder contents cache
    }
    
    // MARK: - Category Methods
    func fetchCategories() async throws -> [NestCategory] {
        guard case .ready(_, let nest) = viewState else {
            throw SessionError.noCurrentNest
        }
        
        debugLog("Fetching categories for nest: \(nest.id)")
        
        let categoriesRef = db.collection("nests").document(nest.id).collection("nestCategories")
        let snapshot = try await categoriesRef.getDocuments()
        let categories = try snapshot.documents.map { try $0.data(as: NestCategory.self) }
        
        debugLog("Fetched \(categories.count) categories")
        return categories
    }
    
    func refreshCategories() async throws -> [NestCategory] {
        return try await fetchCategories()
    }
    
    // MARK: - Place Management (NestItemRepository Protocol Conformance)
    
    /// Fetches all places for the current nest
    func fetchPlaces() async throws -> [PlaceItem] {
        return try await fetchNestPlaces()
    }
    
    /// Fetches places with filtering options
    func fetchPlacesWithFilter(includeTemporary: Bool = true) async throws -> [PlaceItem] {
        debugLog("fetchPlacesWithFilter() called with includeTemporary: \(includeTemporary)")
        
        let placeItems = try await fetchNestPlaces()
        var filteredPlaces = placeItems
        
        // Filter out temporary places if not requested
        if !includeTemporary {
            filteredPlaces = filteredPlaces.filter { !$0.isTemporary }
        }
        
        debugLog("Returning \(filteredPlaces.count) places (\(filteredPlaces.filter(\.isTemporary).count) temporary)")
        return filteredPlaces
    }
    
    /// Gets a specific place by ID
    func getPlace(for id: String) async throws -> PlaceItem? {
        debugLog("getPlace() called for id: \(id)")
        
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
        
        debugLog("Place not found: \(id)")
        return nil
    }
    
    // MARK: - Image Management (following NestService pattern)
    
    /// Loads images for a place with caching (mirrors NestService implementation)
    func loadImages(for place: PlaceItem) async throws -> UIImage {
        debugLog("loadImages() called for place: \(place.alias ?? place.title)")
        
        // If the place has no thumbnails (temporary place), return a placeholder
        guard let thumbnailURLs = place.thumbnailURLs else {
            if DemoModeService.shared.isActive, let placeholder = DemoNestSeed.placeholderImage(for: place) {
                return placeholder
            }
            debugLog("Place has no thumbnails, returning placeholder")
            return UIImage(systemName: "mappin.circle") ?? UIImage()
        }
        
        // Check cache first - exactly like working NestService
        if let asset = imageAssets[place.id] {
            debugLog("Found cached image asset for place: \(place.alias ?? place.title)")
            return asset.image(with: .current)
        }
        
        debugLog("Cache miss - loading images from URLs - Light: \(thumbnailURLs.light), Dark: \(thumbnailURLs.dark)")
        
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
            debugLog("Cached image asset and created dynamic image for place: \(place.alias ?? place.title)")
            
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
        
        debugLog("Loaded image from URL: \(urlString)")
        return image
    }
    
    /// Clear the image cache - following NestService pattern
    func clearImageCache() {
        debugLog("Clearing image cache")
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
