import Foundation
import FirebaseFirestore

extension SessionService {
    /// Collection name for archived sessions
    private var archivedSessionsCollection: CollectionReference {
        return db.collection("archivedSessions")
    }
    
    /// Archive a completed session
    /// - Parameter session: The session to archive
    /// - Returns: The archived session
    func archiveSession(_ session: SessionItem) async throws -> ArchivedSession {
        // Create an ArchivedSession from the SessionItem
        let archivedSession = ArchivedSession(from: session)
        
        // Save to Firestore
        try await db.collection("nests").document(session.nestID).collection("archivedSessions").document(session.id).setData(from: archivedSession)
        
        // Delete the original session
        try await db.collection("nests").document(session.nestID).collection("sessions").document(session.id).delete()
        
        // Remove from local cache
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions.remove(at: index)
        }
        
        return archivedSession
    }
    
    /// Fetch archived sessions for a nest
    /// - Parameter nestID: The ID of the nest
    /// - Returns: Array of archived sessions
    func fetchArchivedSessions(nestID: String) async throws -> [ArchivedSession] {
        Logger.log(level: .info, category: .sessionService, message: "Fetching archived sessions...")
        let snapshot = try await db.collection("nests").document(nestID).collection("archivedSessions")
            .order(by: "endDate", descending: true)
            .getDocuments()
        
        let archivedSessions = try snapshot.documents.compactMap { document in
            try document.data(as: ArchivedSession.self)
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Fetched \(archivedSessions.count) archived sessions")
        return archivedSessions
    }
    
    /// Fetch all archived sessions for a user (across all nests)
    /// - Parameter userID: The ID of the user
    /// - Returns: Array of archived sessions
    func fetchArchivedSessionsForUser(userID: String) async throws -> [ArchivedSession] {
        let snapshot = try await archivedSessionsCollection
            .whereField("ownerId", isEqualTo: userID)
            .order(by: "endDate", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: ArchivedSession.self)
        }
    }
    
    /// Check if a session exists in the archive
    /// - Parameter sessionID: The ID of the session to check
    /// - Returns: True if the session exists in the archive
    func sessionExistsInArchive(sessionID: String) async throws -> Bool {
        let document = try await archivedSessionsCollection.document(sessionID).getDocument()
        return document.exists
    }
    
    /// Placeholder function to test saving an archived session
    /// This is for testing purposes only and should be removed in production
    func saveTestArchivedSession() async throws {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw SessionError.noCurrentNest
        }
        
        // Create a test session
        let testSession = SessionItem(
            title: "Test Archived Session",
            startDate: Date().addingTimeInterval(-60 * 60 * 24 * 10), // 10 days ago
            endDate: Date().addingTimeInterval(-60 * 60 * 24 * 8),    // 8 days ago
            status: .completed
        )
        
        // Create an archived session from the test session
        let archivedSession = ArchivedSession(from: testSession)
        
        // Save to Firestore
        try await archivedSessionsCollection.document(archivedSession.id).setData(from: archivedSession)
        
        print("Test archived session saved with ID: \(archivedSession.id)")
    }
} 
