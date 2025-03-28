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
    
    /// Fetches entries for the current nest, using cache if available
    func fetchNestEntries() async throws -> [String: [BaseEntry]] {
        // Return cached entries if available
        if let cachedEntries = cachedEntries {
            Logger.log(level: .info, category: .sitterViewService, message: "Using cached entries")
            return cachedEntries
        }
        
        // Get the current nest from our viewState
        guard case .ready(_, let nest) = viewState else {
            throw SessionError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetching entries for nest: \(nest.id)")
        
        // Fetch entries from Firestore
        let entriesRef = db.collection("nests").document(nest.id).collection("entries")
        let snapshot = try await entriesRef.getDocuments()
        let entries = try snapshot.documents.map { try $0.data(as: BaseEntry.self) }
        
        // Group entries by category
        let groupedEntries = Dictionary(grouping: entries) { $0.category }
        
        // Cache the entries
        self.cachedEntries = groupedEntries
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetched \(entries.count) entries ✅")
        return groupedEntries
    }
    
    /// Clears the entries cache
    func clearEntriesCache() {
        Logger.log(level: .info, category: .sitterViewService, message: "Clearing entries cache")
        cachedEntries = nil
    }
    
    /// Forces a refresh of the entries
    func refreshEntries() async throws -> [String: [BaseEntry]] {
        clearEntriesCache()
        return try await fetchNestEntries()
    }
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Session Management
    func fetchCurrentSession() async throws {
        viewState = .loading
        
        // Add artificial delay to make loading state visible
        try await Task.sleep(nanoseconds: 750_000_000) // 0.75 seconds
        
        guard let userID = UserService.shared.currentUser?.id else {
            Logger.log(level: .error, category: .sessionService, message: "No current user")
            viewState = .error(SessionError.userNotAuthenticated)
            return
        }
        
        Logger.log(level: .info, category: .sitterViewService, message: "Fetching current session for sitter: \(userID)")
        
        do {
            // Try to get the current session
            guard let session = try await sessionService.fetchInProgressSitterSession(userID: userID) else {
                await MainActor.run {
                    self.viewState = .noSession
                }
                Logger.log(level: .info, category: .sitterViewService, message: "No active session found")
                return
            }
            
            // Get the sitter session to get the nest ID
            guard let sitterSession = try await sessionService.getSitterSession(sessionID: session.id) else {
                await MainActor.run {
                    self.viewState = .error(SessionError.sessionNotFound)
                }
                return
            }
            
            // Fetch the full nest information
            let nestRef = db.collection("nests").document(sitterSession.nestID)
            let nestDoc = try await nestRef.getDocument()
            var nest = try nestDoc.data(as: NestItem.self)
            
            // Fetch categories for the nest
            let categoriesRef = nestRef.collection("nestCategories")
            let categoriesSnapshot = try await categoriesRef.getDocuments()
            let categories = try categoriesSnapshot.documents.map { try $0.data(as: NestCategory.self) }
            
            // Set the categories on the nest
            nest.categories = categories
            
            // Clear entries cache when switching nests
            if currentNest?.id != nest.id {
                clearEntriesCache()
            }
            
            // Update state with session and nest information first
            await MainActor.run {
                self.viewState = .ready(session: session, nest: nest)
            }
            
            // Then fetch entries for the nest
            _ = try await fetchNestEntries()
            
            Logger.log(level: .info, category: .sitterViewService, message: "Current session, nest, and entries updated ✅")
            
        } catch {
            await MainActor.run {
                self.viewState = .error(error)
            }
            Logger.log(level: .error, category: .sitterViewService, message: "Error fetching session: \(error.localizedDescription)")
            throw error
        }
    }
    
    func reset() {
        Logger.log(level: .info, category: .sitterViewService, message: "Resetting SitterViewService")
        viewState = .loading
        clearEntriesCache()
    }
    
    // MARK: - Session Access
    var hasActiveSession: Bool {
        if case .ready = viewState {
            return true
        }
        return false
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
        guard case .ready(_, let nest) = viewState else {
            throw SessionError.noCurrentNest
        }
        
        let entriesRef = db.collection("nests").document(nest.id).collection("entries")
        try await entriesRef.document(entry.id).setData(from: entry)
        clearEntriesCache()
    }
    
    func updateEntry(_ entry: BaseEntry) async throws {
        guard case .ready(_, let nest) = viewState else {
            throw SessionError.noCurrentNest
        }
        
        let entriesRef = db.collection("nests").document(nest.id).collection("entries")
        try await entriesRef.document(entry.id).setData(from: entry)
        clearEntriesCache()
    }
    
    func deleteEntry(_ entry: BaseEntry) async throws {
        guard case .ready(_, let nest) = viewState else {
            throw SessionError.noCurrentNest
        }
        
        let entriesRef = db.collection("nests").document(nest.id).collection("entries")
        try await entriesRef.document(entry.id).delete()
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
