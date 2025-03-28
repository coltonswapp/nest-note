import Foundation

/// Represents a session that a sitter has been assigned to.
/// Stored in users/[userID]/sitterSessions/[sessionID]
struct SitterSession: Identifiable, Codable {
    /// The ID of the session (same as the original sessionID)
    let id: String
    
    /// The ID of the nest this session belongs to
    let nestID: String
    
    /// The name of the nest this session belongs to
    let nestName: String
    
    /// When the sitter accepted the invite for this session
    let inviteAcceptedAt: Date
    
    /// Creates a new SitterSession
    /// - Parameters:
    ///   - id: The session ID
    ///   - nestID: The nest ID
    ///   - nestName: The name of the nest
    ///   - inviteAcceptedAt: When the invite was accepted
    init(id: String, nestID: String, nestName: String, inviteAcceptedAt: Date = Date()) {
        self.id = id
        self.nestID = nestID
        self.nestName = nestName
        self.inviteAcceptedAt = inviteAcceptedAt
    }
} 