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
    
    // MARK: - Unified Item Caching (following NestService pattern)
    private var cachedItems: [BaseItem] = []
    
    // Computed property that filters places from cached items
    private var cachedPlaces: [PlaceItem]? {
        guard !cachedItems.isEmpty else { return nil }
        return cachedItems.compactMap { $0 as? PlaceItem }
    }
    
    // MARK: - Image Cache (following NestService pattern)
    private var imageAssets: [String: UIImageAsset] = [:]
    
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
        
        // Fetch all items using ItemRepository and cache them
        let allItems = try await itemRepository.fetchItems()
        self.cachedItems = allItems
        
        // Filter to only entry items and convert to BaseEntry
        let allEntries = allItems.compactMap { item -> BaseEntry? in
            guard item.type == .entry, let entryItem = item as? EntryItem else { return nil }
            return entryItem.toBaseEntry()
        }
        
        // Apply session-specific entry filtering if specified
        let entries: [BaseEntry]
        if let allowedEntryIds = currentSession?.entryIds, !allowedEntryIds.isEmpty {
            // Filter entries to only those in the session's allowed list
            entries = allEntries.filter { allowedEntryIds.contains($0.id) }
            Logger.log(level: .info, category: .sitterViewService, message: "Filtered \(allEntries.count) entries to \(entries.count) based on session entryIds")
        } else {
            // Backward compatibility: show all entries if no filtering specified
            entries = allEntries
            Logger.log(level: .info, category: .sitterViewService, message: "No entry filtering applied - showing all \(entries.count) entries")
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
    
    /// Clears the items cache (places are computed from this)
    func clearItemsCache() {
        Logger.log(level: .info, category: .sitterViewService, message: "Clearing items cache")
        cachedItems = []
        // Also clear ItemRepository cache
        itemRepository?.clearItemsCache()
    }
    
    /// Clears the places cache (now a no-op since places are computed)
    func clearPlacesCache() {
        // Places are now computed from cachedItems, so just clear that
        clearItemsCache()
    }
    
    /// Forces a refresh of the entries
    func refreshEntries() async throws -> [String: [BaseEntry]] {
        clearEntriesCache()
        return try await fetchNestEntries()
    }
    
    // MARK: - Places
    
    /// Fetches places for the current nest, using cache if available
    func fetchNestPlaces() async throws -> [PlaceItem] {
        Logger.log(level: .info, category: .sitterViewService, message: "fetchNestPlaces() called - using ItemRepository")
        
        // Return cached places if available
        if let cachedPlaces = cachedPlaces {
            Logger.log(level: .info, category: .sitterViewService, message: "Using cached places")
            return cachedPlaces
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
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetching places for nest: \(nest.id)")
        
        // Fetch all items using ItemRepository and cache them
        let allItems = try await itemRepository.fetchItems()
        self.cachedItems = allItems
        
        // Filter to only place items from cached items
        let allPlaces = cachedItems.compactMap { item -> PlaceItem? in
            guard item.type == .place, let placeItem = item as? PlaceItem else { return nil }
            return placeItem
        }
        
        // Apply session-specific place filtering if specified
        let places: [PlaceItem]
        if let allowedItemIds = currentSession?.entryIds, !allowedItemIds.isEmpty {
            // Filter places to only those in the session's allowed list
            places = allPlaces.filter { allowedItemIds.contains($0.id) }
            Logger.log(level: .info, category: .sitterViewService, message: "Filtered \(allPlaces.count) places to \(places.count) based on session entryIds")
        } else {
            // Backward compatibility: show all places if no filtering specified
            places = allPlaces
            Logger.log(level: .info, category: .sitterViewService, message: "No place filtering applied - showing all \(places.count) places")
        }
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetched \(places.count) places using ItemRepository ✅")
        return places
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
        Logger.log(level: .info, category: .sitterViewService, message: "📁 fetchFolderContents() called for category: '\(category)'")
        
        // Get all data in one efficient call
        let allGroupedEntries = try await fetchNestEntries()
        let allPlaces = try await fetchNestPlaces()
        let categories = try await fetchCategories()
        
        Logger.log(level: .info, category: .sitterViewService, message: "📁 fetchFolderContents data gathered")
        
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
        
        Logger.log(level: .info, category: .sitterViewService, message: "Folder contents for '\(category)': \(entries.count) entries, \(places.count) places, \(subfolders.count) subfolders")
        
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
        clearImageCache()
        
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
