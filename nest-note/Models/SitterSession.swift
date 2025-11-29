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
    
    /// Flag indicating if this session is ready to be archived
    let readyToArchive: Bool?
    
    /// Date when the parent session was marked as completed (if applicable)
    let parentSessionCompletedDate: Date?
    
    /// Date when the parent session was archived (if applicable)
    let parentSessionArchivedDate: Date?
    
    /// When the sitter submitted a session review (nil = not reviewed)
    var reviewedAt: Date?
    
    /// Creates a new SitterSession
    /// - Parameters:
    ///   - id: The session ID
    ///   - nestID: The nest ID
    ///   - nestName: The name of the nest
    ///   - inviteAcceptedAt: When the invite was accepted
    ///   - readyToArchive: Whether this session is ready to be archived
    ///   - parentSessionCompletedDate: When the parent session was completed
    ///   - parentSessionArchivedDate: When the parent session was archived
    ///   - reviewedAt: When the sitter submitted a review
    init(
        id: String,
        nestID: String,
        nestName: String,
        inviteAcceptedAt: Date = Date(),
        readyToArchive: Bool? = false,
        parentSessionCompletedDate: Date? = nil,
        parentSessionArchivedDate: Date? = nil,
        reviewedAt: Date? = nil
    ) {
        self.id = id
        self.nestID = nestID
        self.nestName = nestName
        self.inviteAcceptedAt = inviteAcceptedAt
        self.readyToArchive = readyToArchive
        self.parentSessionCompletedDate = parentSessionCompletedDate
        self.parentSessionArchivedDate = parentSessionArchivedDate
        self.reviewedAt = reviewedAt
    }
} 