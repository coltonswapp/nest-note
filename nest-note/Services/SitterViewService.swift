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
    
    var currentSessionVisibilityLevel: VisibilityLevel? {
        currentSession?.visibilityLevel
    }
    
    // MARK: - Nest Entries
    private var cachedEntries: [String: [BaseEntry]]?
    private var cachedPlaces: [PlaceItem]?
    
    /// Fetches entries for the current nest, using cache if available
    func fetchNestEntries() async throws -> [String: [BaseEntry]] {
        Logger.log(level: .info, category: .sitterViewService, message: "fetchNestEntries() called - using ItemRepository")
        
        // Return cached entries if available
        if let cachedEntries = cachedEntries {
            Logger.log(level: .info, category: .sitterViewService, message: "Using cached entries")
            return cachedEntries
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
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetching entries for nest: \(nest.id)")
        
        // Fetch all items using ItemRepository
        let allItems = try await itemRepository.fetchItems()
        
        // Filter to only entry items and convert to BaseEntry
        let entries = allItems.compactMap { item -> BaseEntry? in
            guard item.type == .entry, let entryItem = item as? EntryItem else { return nil }
            return entryItem.toBaseEntry()
        }
        
        // Group entries by category
        let groupedEntries = Dictionary(grouping: entries) { $0.category }
        
        // Cache the entries
        self.cachedEntries = groupedEntries
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetched \(entries.count) entries using ItemRepository ✅")
        return groupedEntries
    }
    
    /// Clears the entries cache
    func clearEntriesCache() {
        Logger.log(level: .info, category: .sitterViewService, message: "Clearing entries cache")
        cachedEntries = nil
        // Also clear ItemRepository cache
        itemRepository?.clearItemsCache()
    }
    
    /// Clears the places cache
    func clearPlacesCache() {
        Logger.log(level: .info, category: .sitterViewService, message: "Clearing places cache")
        cachedPlaces = nil
        // ItemRepository cache is shared, so clearing entries cache also clears places
    }
    
    /// Forces a refresh of the entries
    func refreshEntries() async throws -> [String: [BaseEntry]] {
        clearEntriesCache()
        return try await fetchNestEntries()
    }
    
    // MARK: - Places
    
//    /// Fetches places for the current nest, filtered by visibility level
//    func fetchNestPlaces() async throws -> [PlaceItem] {
//        Logger.log(level: .info, category: .sitterViewService, message: "fetchNestPlaces() called - using ItemRepository")
//        
//        // Return cached places if available
//        if let cachedPlaces = cachedPlaces {
//            Logger.log(level: .info, category: .sitterViewService, message: "Using cached places")
//            return cachedPlaces
//        }
//        
//        // Get the current session and nest from our viewState
//        guard case .ready(let session, let nest) = viewState else {
//            throw SessionError.noCurrentNest
//        }
//        
//        // Initialize ItemRepository if needed
//        if itemRepository == nil {
//            itemRepository = FirebaseItemRepository(nestId: nest.id)
//        }
//        
//        guard let itemRepository = itemRepository else {
//            throw SessionError.noCurrentNest
//        }
//        
//        Logger.log(level: .info, category: .sitterViewService, message: "Fetching places for nest: \(nest.id)")
//        
//        // Fetch all items using ItemRepository
//        let allItems = try await itemRepository.fetchItems()
//        
//        // Filter to only place items and convert to Place
//        let allPlaces = allItems.compactMap { item -> PlaceItem? in
//            guard item.type == .place, let placeItem = item as? PlaceItem else { return nil }
//            return placeItem.toPlace()
//        }
//        
//        // Filter places based on sitter's visibility level from the session
//        let sitterVisibilityLevel = session.visibilityLevel
//        let filteredPlaces = allPlaces.filter { place in
//            sitterVisibilityLevel.hasAccess(to: place.visibilityLevel)
//        }
//        
//        // Cache the filtered places
//        self.cachedPlaces = filteredPlaces
//        
//        Logger.log(level: .info, category: .sitterViewService, 
//                  message: "Fetched \(allPlaces.count) places, filtered to \(filteredPlaces.count) based on \(sitterVisibilityLevel.title) access level using ItemRepository ✅")
//        return filteredPlaces
//    }
    
    /// Forces a refresh of the places
//    func refreshPlaces() async throws -> [PlaceItem] {
//        clearPlacesCache()
//        return try await fetchNestPlaces()
//    }
    
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
                Logger.log(level: .debug, category: .sitterViewService, message: "Successfully fetched session: \(session.id)")
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
                    self.clearPlacesCache()
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
        clearPlacesCache()
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
        clearPlacesCache()
        
        // Set the view state to the provided session and nest
        viewState = .ready(session: session, nest: nest)
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
        
        // Convert BaseEntry to EntryItem and create
        let entryItem = EntryItem(from: entry)
        try await itemRepository.createItem(entryItem)
        clearEntriesCache()
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
        
        // Convert BaseEntry to EntryItem and update
        let entryItem = EntryItem(from: entry)
        try await itemRepository.updateItem(entryItem)
        clearEntriesCache()
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
        clearEntriesCache()
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
} 
