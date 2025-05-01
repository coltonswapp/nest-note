import Foundation

/// Represents an archived session that a sitter was assigned to.
/// Stored in users/[userID]/archivedSitterSessions/[sessionID]
struct ArchivedSitterSession: Identifiable, Codable, Hashable {
    /// The ID of the session (same as the original sessionID)
    let id: String
    
    /// The ID of the nest this session belongs to
    let nestID: String
    
    /// The name of the nest this session belongs to
    let nestName: String
    
    /// When the sitter accepted the invite for this session
    let inviteAcceptedAt: Date
    
    /// When this sitter session was archived
    let archivedDate: Date
    
    /// Date when the parent session was marked as completed (if applicable)
    let parentSessionCompletedDate: Date?
    
    /// Date when the parent session was archived (if applicable)
    let parentSessionArchivedDate: Date?
    
    /// Creates a new ArchivedSitterSession
    /// - Parameters:
    ///   - id: The session ID
    ///   - nestID: The nest ID
    ///   - nestName: The name of the nest
    ///   - inviteAcceptedAt: When the invite was accepted
    ///   - archivedDate: When this sitter session was archived
    ///   - parentSessionCompletedDate: When the parent session was completed
    ///   - parentSessionArchivedDate: When the parent session was archived
    init(
        id: String,
        nestID: String,
        nestName: String,
        inviteAcceptedAt: Date,
        archivedDate: Date = Date(),
        parentSessionCompletedDate: Date? = nil,
        parentSessionArchivedDate: Date? = nil
    ) {
        self.id = id
        self.nestID = nestID
        self.nestName = nestName
        self.inviteAcceptedAt = inviteAcceptedAt
        self.archivedDate = archivedDate
        self.parentSessionCompletedDate = parentSessionCompletedDate
        self.parentSessionArchivedDate = parentSessionArchivedDate
    }
    
    /// Create an ArchivedSitterSession from a SitterSession
    init(from sitterSession: SitterSession, archivedDate: Date = Date()) {
        self.id = sitterSession.id
        self.nestID = sitterSession.nestID
        self.nestName = sitterSession.nestName
        self.inviteAcceptedAt = sitterSession.inviteAcceptedAt
        self.archivedDate = archivedDate
        self.parentSessionCompletedDate = sitterSession.parentSessionCompletedDate
        self.parentSessionArchivedDate = sitterSession.parentSessionArchivedDate
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ArchivedSitterSession, rhs: ArchivedSitterSession) -> Bool {
        return lhs.id == rhs.id
    }
} 