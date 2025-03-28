import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Errors that can occur during session operations
enum SessionError: LocalizedError {
    case noCurrentNest
    case userNotAuthenticated
    case invalidInviteCode
    case inviteExpired
    case inviteAlreadyUsed
    case sessionNotFound
    
    var errorDescription: String? {
        switch self {
        case .noCurrentNest:
            return "No nest is currently selected"
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidInviteCode:
            return "Invalid invite code"
        case .inviteExpired:
            return "This invite has expired"
        case .inviteAlreadyUsed:
            return "This invite has already been used"
        case .sessionNotFound:
            return "Session not found"
        }
    }
}

class SessionService {
    static let shared = SessionService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    private var sessions: [SessionItem] = []
    
    // Add these types at the top of the file
    enum SessionBucket: Int {
        case upcoming
        case inProgress
        case past
    }

    struct SessionCollection {
        var upcoming: [SessionItem]
        var inProgress: [SessionItem]
        var past: [SessionItem]
    }
    
    // MARK: - Create
    func createSession(_ session: SessionItem) async throws -> SessionItem {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Creating new session: \(session.title)")
        
        try await saveSession(session, nestID: nestID)
        
        // Update local cache
        sessions.append(session)
        
        Logger.log(level: .info, category: .sessionService, message: "Session created successfully ✅")
        return session
    }
    
    // MARK: - Save (private helper)
    private func saveSession(_ session: SessionItem, nestID: String) async throws {
        Logger.log(level: .info, category: .sessionService, message: "Saving session to nest: \(nestID)")
        
        let sessionsRef = db.collection("nests").document(nestID).collection("sessions")
        try sessionsRef.document(session.id).setData(from: session)
        
        // If there are events, save them
        if !session.events.isEmpty {
            Logger.log(level: .info, category: .sessionService, message: "Saving \(session.events.count) events for session")
            let eventsRef = sessionsRef.document(session.id).collection("events")
            for event in session.events {
                try eventsRef.document(event.id).setData(from: event)
            }
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Session and events saved successfully ✅")
    }
    
    // MARK: - Read
    func getSession(nestID: String, sessionID: String) async throws -> SessionItem? {
        Logger.log(level: .info, category: .sessionService, message: "Fetching session: \(sessionID)")
        
        let sessionRef = db.collection("nests")
            .document(nestID)
            .collection("sessions")
            .document(sessionID)
        
        let sessionDoc = try await sessionRef.getDocument()
        let session = try sessionDoc.data(as: SessionItem.self)
        
        Logger.log(level: .info, category: .sessionService, message: session != nil ? "Session fetched successfully ✅" : "Session not found ❌")
        return session
    }
    
    func getAllSessions(nestID: String) async throws -> [SessionItem] {
        Logger.log(level: .info, category: .sessionService, message: "Fetching all sessions for nest: \(nestID)")
        
        let sessionsRef = db.collection("nests")
            .document(nestID)
            .collection("sessions")
        
        let snapshot = try await sessionsRef.getDocuments()
        let sessions = try snapshot.documents.compactMap { try $0.data(as: SessionItem.self) }
        
        Logger.log(level: .info, category: .sessionService, message: "Fetched \(sessions.count) sessions ✅")
        return sessions
    }
    
    // MARK: - Update
    func updateSession(_ session: SessionItem) async throws {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Updating session: \(session.id)")
        
        let sessionRef = db.collection("nests")
            .document(nestID)
            .collection("sessions")
            .document(session.id)
        
        try await sessionRef.setData(from: session)
        
        // Update local cache
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Session updated successfully ✅")
    }
    
    // MARK: - Delete
    func deleteSession(nestID: String, sessionID: String) async throws {
        Logger.log(level: .info, category: .sessionService, message: "Deleting session: \(sessionID)")
        
        let sessionRef = db.collection("nests")
            .document(nestID)
            .collection("sessions")
            .document(sessionID)
        
        try await sessionRef.delete()
        Logger.log(level: .info, category: .sessionService, message: "Session deleted successfully ✅")
    }
    
    // MARK: - Fetch Organized Sessions
    func fetchSessions(nestID: String) async throws -> SessionCollection {
        Logger.log(level: .info, category: .sessionService, message: "Fetching and organizing sessions for nest: \(nestID)")
        
        #if DEBUG
        let sessions = self.sessions.isEmpty ? try await getAllSessions(nestID: nestID) : self.sessions
        #else
        let sessions = try await getAllSessions(nestID: nestID)
        #endif
        
        let now = Date()
        
        // Update status and sort sessions into appropriate buckets
        let sorted = sessions.reduce(into: (
            upcoming: [SessionItem](),
            inProgress: [SessionItem](),
            past: [SessionItem]()
        )) { result, session in
            // Create a mutable copy of the session
            var updatedSession = session
            
            // Update the status based on current time and existing status
            let inferredStatus = session.inferredStatus(at: now)
            if inferredStatus != session.status {
                updatedSession.status = inferredStatus
                // In a real implementation, you might want to save this status update back to Firebase
            }
            
            // Sort into buckets based on status
            switch updatedSession.status {
            case .upcoming:
                result.upcoming.append(updatedSession)
            case .inProgress, .extended:
                result.inProgress.append(updatedSession)
            case .completed:
                result.past.append(updatedSession)
            }
        }
        
        // Sort upcoming sessions by start date (soonest first)
        let sortedUpcoming = sorted.upcoming.sorted { $0.startDate < $1.startDate }
        
        // Sort in-progress sessions by end date (ending soonest first)
        let sortedInProgress = sorted.inProgress.sorted { $0.endDate < $1.endDate }
        
        // Sort past sessions by end date (most recent first)
        let sortedPast = sorted.past.sorted { $0.endDate > $1.endDate }
        
        Logger.log(level: .info, category: .sessionService, message: "Sessions organized: \(sessions.count) total (Upcoming: \(sortedUpcoming.count), In Progress: \(sortedInProgress.count), Past: \(sortedPast.count)) ✅")
        
        return SessionCollection(
            upcoming: sortedUpcoming,
            inProgress: sortedInProgress,
            past: sortedPast
        )
    }
    
    // Helper method for specific bucket
    func fetchSessions(nestID: String, bucket: SessionBucket) async throws -> [SessionItem] {
        let collection = try await fetchSessions(nestID: nestID)
        switch bucket {
        case .upcoming:
            return collection.upcoming
        case .inProgress:
            return collection.inProgress
        case .past:
            return collection.past
        }
    }
    
    // MARK: - Session Events
    /// Creates or updates a single event in a session
    func updateSessionEvent(_ event: SessionEvent, sessionID: String) async throws {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Updating event: \(event.id) for session: \(sessionID)")
        
        let eventRef = db.collection("nests")
            .document(nestID)
            .collection("sessions")
            .document(sessionID)
            .collection("events")
            .document(event.id)
        
        try await eventRef.setData(from: event)
        
        // Update local cache
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }) {
            if let eventIndex = sessions[sessionIndex].events.firstIndex(where: { $0.id == event.id }) {
                sessions[sessionIndex].events[eventIndex] = event
            } else {
                sessions[sessionIndex].events.append(event)
            }
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Event updated successfully ✅")
    }
    
    /// Updates multiple events in a session using a batch write
    func updateSessionEvents(_ events: [SessionEvent], sessionID: String) async throws {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Batch updating \(events.count) events for session: \(sessionID)")
        
        let batch = db.batch()
        let sessionRef = db.collection("nests")
            .document(nestID)
            .collection("sessions")
            .document(sessionID)
        
        for event in events {
            let eventRef = sessionRef.collection("events").document(event.id)
            try batch.setData(from: event, forDocument: eventRef)
        }
        
        try await batch.commit()
        
        // Update local cache
        if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
            sessions[index].events = events
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Batch event update successful ✅")
    }
    
    /// Fetches all events for a session
    func getSessionEvents(for sessionID: String, nestID: String) async throws -> [SessionEvent] {
        Logger.log(level: .info, category: .sessionService, message: "Fetching events for session \(sessionID)")
        
        let eventsRef = db.collection("nests").document(nestID)
            .collection("sessions").document(sessionID)
            .collection("events")
        
        let snapshot = try await eventsRef.getDocuments()
        
        let events = try snapshot.documents.map { document -> SessionEvent in
            try document.data(as: SessionEvent.self)
        }
        
        return events.sorted { (event1: SessionEvent, event2: SessionEvent) in
            event1.startDate < event2.startDate
        }
    }
    
    /// Deletes a single event from a session
    func deleteSessionEvent(_ eventID: String, sessionID: String) async throws {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Deleting event: \(eventID) from session: \(sessionID)")
        
        let eventRef = db.collection("nests")
            .document(nestID)
            .collection("sessions")
            .document(sessionID)
            .collection("events")
            .document(eventID)
        
        try await eventRef.delete()
        
        // Update local cache
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }) {
            sessions[sessionIndex].events.removeAll { $0.id == eventID }
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Event deleted successfully ✅")
    }
    
    /// Deletes all events from a session
    func deleteAllSessionEvents(sessionID: String) async throws {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Deleting all events for session: \(sessionID)")
        
        let eventsRef = db.collection("nests")
            .document(nestID)
            .collection("sessions")
            .document(sessionID)
            .collection("events")
        
        // Get all events
        let snapshot = try await eventsRef.getDocuments()
        
        // Delete in batches of 500 (Firestore batch limit)
        let batch = db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()
        
        // Update local cache
        if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
            sessions[index].events.removeAll()
        }
        
        Logger.log(level: .info, category: .sessionService, message: "All events deleted successfully ✅")
    }
    
    // Add a new method to update session status
    func updateSessionStatus(_ session: SessionItem, to newStatus: SessionStatus) async throws {
        var updatedSession = session
        
        // Validate the status change
        switch newStatus {
        case .inProgress:
            guard session.canBeMarkedActive else {
                throw ServiceError.invalidStatusTransition
            }
        case .completed:
            guard session.canBeMarkedCompleted else {
                throw ServiceError.invalidStatusTransition
            }
        case .upcoming:
            // Can only be marked as upcoming if it hasn't started yet
            guard session.startDate > Date() else {
                throw ServiceError.invalidStatusTransition
            }
        case .extended:
            // Extended status should only be inferred, not manually set
            throw ServiceError.invalidStatusTransition
        }
        
        updatedSession.status = newStatus
        try await updateSession(updatedSession)
    }
    
    // MARK: - Invite Methods
    
    /// Generates a unique 6-digit invite code
    private func generateUniqueInviteCode() async throws -> String {
        var code: String
        var isUnique = false
        
        Logger.log(level: .info, category: .sessionService, message: "Starting invite code generation...")
        
        // Keep generating until we find a unique one
        repeat {
            // Generate random 6-digit code
            code = String(format: "%06d", Int.random(in: 100000...999999))
            
            // Check if it exists in Firestore
            let docRef = db.collection("invites").document("invite-\(code)")
            
            Logger.log(level: .info, category: .sessionService, message: "Seeing if \(docRef.path) exists...")
            
            let snapshot = try await docRef.getDocument()
            isUnique = !snapshot.exists
            
            Logger.log(level: .info, category: .sessionService, message: "\(docRef.path) \(isUnique ? "exists" : "doesn't exist")...")
            
        } while !isUnique
        
        return code
    }
    
    /// Updates the sitter status for a session
    private func updateSessionSitterStatus(
        sessionID: String,
        sitter: NestService.SavedSitter,
        status: SessionInviteStatus,
        inviteID: String?
    ) async throws {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw SessionError.noCurrentNest
        }
        
        let docRef = db.collection("nests").document(nestID)
            .collection("sessions").document(sessionID)
        
        // Get the current session to maintain other fields
        guard let session = try await getSession(nestID: nestID, sessionID: sessionID) else {
            throw SessionError.sessionNotFound
        }
        
        // Create or update the assigned sitter
        let assignedSitter = AssignedSitter(
            id: sitter.id,
            name: sitter.name,
            email: sitter.email,
            userID: nil,
            inviteStatus: status,
            inviteID: inviteID
        )
        
        // Update Firestore with the new assigned sitter
        try await docRef.updateData([
            "assignedSitter": try Firestore.Encoder().encode(assignedSitter)
        ])
        
        // Update local cache if available
        if var session = sessions.first(where: { $0.id == sessionID }) {
            session.assignedSitter = assignedSitter
            
            if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
                sessions[index] = session
            }
        }
    }
    
    /// Creates an invite for a sitter to join a session
    func createInviteForSitter(
        sessionID: String,
        sitter: SitterItem
    ) async throws -> String {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw SessionError.noCurrentNest
        }
        
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw SessionError.userNotAuthenticated
        }
        
        // Get current nest name
        guard let nestName = NestService.shared.currentNest?.name else {
            throw SessionError.noCurrentNest
        }
        
        // Generate unique code
        let code = try await generateUniqueInviteCode()
        let inviteID = "invite-\(code)"
        
        Logger.log(level: .info, category: .sessionService, message: "Creating invite... \(inviteID)")
        
        // Create invite object
        let invite = Invite(
            id: inviteID,
            nestID: nestID,
            nestName: nestName,  // Include nest name
            sessionID: sessionID,
            sitterEmail: sitter.email,
            status: .pending,
            createdBy: currentUserID
        )
        
        // Create assigned sitter
        let assignedSitter = AssignedSitter(
            id: sitter.id,
            name: sitter.name,
            email: sitter.email,
            userID: nil,
            inviteStatus: .invited,
            inviteID: inviteID
        )
        
        // Get references
        let inviteRef = db.collection("invites").document(inviteID)
        let sessionRef = db.collection("nests").document(nestID)
            .collection("sessions").document(sessionID)
        
        // Encode data before transaction
        let encodedInvite = try Firestore.Encoder().encode(invite)
        let encodedSitter = try Firestore.Encoder().encode(assignedSitter)
        
        try await db.runTransaction { transaction, errorPointer in
            // Create invite document
            transaction.setData(encodedInvite, forDocument: inviteRef)
            
            // Update session with assigned sitter
            transaction.updateData([
                "assignedSitter": encodedSitter
            ], forDocument: sessionRef)
            
            return nil
        }
        
        // Update local cache if available
        if var session = sessions.first(where: { $0.id == sessionID }) {
            session.assignedSitter = assignedSitter
            if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
                sessions[index] = session
            }
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Invite created successfully ✅")
        return code
    }
    
    /// Updates both the invite and session's sitter status atomically
    private func updateInviteAndSitterStatusAtomically(
        inviteID: String,
        sessionID: String,
        to status: InviteStatus
    ) async throws {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw SessionError.noCurrentNest
        }
        
        // Map InviteStatus to SessionInviteStatus
        let sessionStatus: SessionInviteStatus
        switch status {
        case .pending:
            sessionStatus = .invited
        case .accepted:
            sessionStatus = .accepted
        case .expired, .cancelled:
            sessionStatus = .cancelled
        }
        
        // Get references
        let inviteRef = db.collection("invites").document(inviteID)
        let sessionRef = db.collection("nests").document(nestID)
            .collection("sessions").document(sessionID)
        
        // Get current documents before transaction
        let inviteDoc = try await inviteRef.getDocument()
        let sessionDoc = try await sessionRef.getDocument()
        
        guard let invite = try? inviteDoc.data(as: Invite.self),
              let session = try? sessionDoc.data(as: SessionItem.self) else {
            throw SessionError.sessionNotFound
        }
        
        // Create updated assigned sitter
        let updatedSitter = AssignedSitter(
            id: session.assignedSitter?.id ?? UUID().uuidString,
            name: session.assignedSitter?.name ?? invite.sitterEmail,
            email: invite.sitterEmail,
            userID: session.assignedSitter?.userID,
            inviteStatus: sessionStatus,
            inviteID: inviteID
        )
        
        // Encode the sitter data before transaction
        let encodedSitter = try Firestore.Encoder().encode(updatedSitter)
        
        try await db.runTransaction { [weak self] transaction, errorPointer in
            // Update both documents atomically
            transaction.updateData([
                "status": status.rawValue
            ], forDocument: inviteRef)
            
            transaction.updateData([
                "assignedSitter": encodedSitter
            ], forDocument: sessionRef)
            
            return nil
        }
        
        // Update local cache if available
        if var session = sessions.first(where: { $0.id == sessionID }) {
            session.assignedSitter = updatedSitter
            if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
                sessions[index] = session
            }
        }
    }
    
    /// Updates the status of an invite and its associated session
    func updateInviteStatus(
        inviteID: String,
        to status: InviteStatus,
        sessionID: String
    ) async throws {
        try await updateInviteAndSitterStatusAtomically(
            inviteID: inviteID,
            sessionID: sessionID,
            to: status
        )
    }
    
    /// Fetches the full invite information for a session if it exists
    func fetchSessionInvite(for session: SessionItem) async throws -> Invite? {
        // If session has no invite ID, return nil
        guard let sitter = session.assignedSitter,
              let inviteID = sitter.inviteID else {
            return nil
        }
        
        let inviteRef = db.collection("invites").document(inviteID)
        let snapshot = try await inviteRef.getDocument()
        
        guard snapshot.exists else {
            // If invite doesn't exist but session thinks it does, clean up the session
            if let sitter = session.assignedSitter {
                // Create SavedSitter from AssignedSitter
                let savedSitter = NestService.SavedSitter(
                    id: sitter.id,
                    name: sitter.name,
                    email: sitter.email
                )
                
                try await updateSessionSitterStatus(
                    sessionID: session.id,
                    sitter: savedSitter,
                    status: .none,
                    inviteID: nil
                )
            }
            return nil
        }
        
        return try snapshot.data(as: Invite.self)
    }
    
    /// Fetches all active invites for a session (pending or accepted)
    func fetchActiveInvites(for sessionID: String) async throws -> [Invite] {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw SessionError.noCurrentNest
        }
        
        // Get the session first to check if it has an active sitter
        guard let session = try await getSession(nestID: nestID, sessionID: sessionID) else {
            throw SessionError.sessionNotFound
        }
        
        // If there's no assigned sitter or no invite ID, return empty array
        guard let sitter = session.assignedSitter,
              let inviteID = sitter.inviteID else {
            return []
        }
        
        let invitesRef = db.collection("invites")
            .whereField("sessionID", isEqualTo: sessionID)
            .whereField("nestID", isEqualTo: nestID)
            .whereField("status", in: ["pending", "accepted"])
        
        let snapshot = try await invitesRef.getDocuments()
        return try snapshot.documents.map { try $0.data(as: Invite.self) }
    }
    
    /// Checks and updates expired invites for a session
    func checkAndUpdateExpiredInvites(for session: SessionItem) async throws {
        guard let inviteID = session.assignedSitter?.inviteID else { return }
        
        let invite = try await fetchSessionInvite(for: session)
        guard let invite = invite else { return }
        
        // Check if invite is expired
        if invite.expiresAt < Date() && invite.status == .pending {
            // Update invite status to expired
            try await updateInviteStatus(
                inviteID: inviteID,
                to: .expired,
                sessionID: session.id
            )
        }
    }
    
    /// Fetches the session and its current invite status
    func fetchSessionWithInvite(nestID: String, sessionID: String) async throws -> (SessionItem, Invite?) {
        guard let session = try await getSession(nestID: nestID, sessionID: sessionID) else {
            throw SessionError.sessionNotFound
        }
        
        let invite = try await fetchSessionInvite(for: session)
        return (session, invite)
    }
    
    /// Deletes an invite and removes the assigned sitter from the session atomically
    func deleteInvite(inviteID: String, sessionID: String) async throws {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw SessionError.noCurrentNest
        }
        
        // Get references
        let inviteRef = db.collection("invites").document(inviteID)
        let sessionRef = db.collection("nests").document(nestID)
            .collection("sessions").document(sessionID)
        
        try await db.runTransaction { transaction, errorPointer in
            // Delete the invite document
            transaction.deleteDocument(inviteRef)
            
            // Update session to remove assigned sitter
            transaction.updateData([
                "assignedSitter": FieldValue.delete()
            ], forDocument: sessionRef)
            
            return nil
        }
        
        // Update local cache if available
        if var session = sessions.first(where: { $0.id == sessionID }) {
            session.assignedSitter = nil
            if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
                sessions[index] = session
            }
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Invite deleted and session updated successfully ✅")
    }
    
    /// Validates and accepts an invite using the provided code
    func validateAndAcceptInvite(inviteID: String) async throws -> SitterSession {
        Logger.log(level: .info, category: .sessionService, message: "Locating session invite for \(inviteID)")
        
        let formattedInviteCode: String = "invite-\(inviteID)"
        
        let inviteRef = db.collection("invites").document(formattedInviteCode)
        
        // Get the invite document
        let inviteDoc = try await inviteRef.getDocument()
        guard inviteDoc.exists,
              let invite = try? inviteDoc.data(as: Invite.self) else {
            throw SessionError.invalidInviteCode
        }
        
        // Validate expiration
        if invite.expiresAt < Date() {
            throw SessionError.inviteExpired
        }
        
        // Validate status
        guard invite.status == .pending else {
            throw SessionError.inviteAlreadyUsed
        }
        
        // Get the session
        guard let session = try await getSession(nestID: invite.nestID, sessionID: invite.sessionID) else {
            throw SessionError.sessionNotFound
        }
        
        // Get current user ID if available
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw SessionError.userNotAuthenticated
        }
        
        // Create a new SitterSession
        let sitterSession = SitterSession(
            id: invite.sessionID,
            nestID: invite.nestID,
            nestName: invite.nestName,
            inviteAcceptedAt: Date()
        )
        
        // Encode the sitter data before transaction
        let encodedSitter = try Firestore.Encoder().encode(session.assignedSitter)
        let encodedSitterSession = try Firestore.Encoder().encode(sitterSession)
        
        // Update documents atomically
        try await self.db.runTransaction { transaction, errorPointer in
            // Update invite status
            transaction.updateData([
                "status": InviteStatus.accepted.rawValue,
                "acceptedAt": FieldValue.serverTimestamp(),
                "acceptedBy": currentUserID
            ], forDocument: inviteRef)
            
            // Update session's assigned sitter
            transaction.updateData([
                "assignedSitter": encodedSitter
            ], forDocument: self.db.collection("nests").document(invite.nestID)
                .collection("sessions").document(invite.sessionID))
            
            // Create SitterSession document
            let sitterSessionRef = self.db.collection("users").document(currentUserID)
                .collection("sitterSessions").document(invite.sessionID)
            transaction.setData(encodedSitterSession, forDocument: sitterSessionRef)
            
            return nil
        }
        
        // Log the acceptance
        Logger.log(level: .info, category: .sessionService, message: "Invite \(inviteID) accepted by user \(currentUserID)")
        
        // Return the session and invite for UI purposes
        return sitterSession
    }
    
    /// Validates an invite without accepting it
    func validateInvite(code: String) async throws -> (SessionItem, Invite) {
        Logger.log(level: .info, category: .sessionService, message: "Validating invite code: \(code)")
        
        let inviteID = "invite-\(code)"
        let inviteRef = db.collection("invites").document(inviteID)
        
        // Get the invite document
        let inviteDoc = try await inviteRef.getDocument()
        guard inviteDoc.exists,
              let invite = try? inviteDoc.data(as: Invite.self) else {
            throw SessionError.invalidInviteCode
        }
        
        // Validate expiration
        if invite.expiresAt < Date() {
            throw SessionError.inviteExpired
        }
        
        // Validate status
        guard invite.status == .pending else {
            throw SessionError.inviteAlreadyUsed
        }
        
        // Get the session
        guard let session = try await getSession(nestID: invite.nestID, sessionID: invite.sessionID) else {
            throw SessionError.sessionNotFound
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Invite validation successful ✅")
        return (session, invite)
    }
    
    // MARK: - Sitter Sessions
    
    /// Fetches a specific sitter session by ID
    func getSitterSession(sessionID: String) async throws -> SitterSession? {
        guard let userID = Auth.auth().currentUser?.uid else {
            throw SessionError.userNotAuthenticated
        }
        
        let sitterSessionRef = db.collection("users").document(userID)
            .collection("sitterSessions").document(sessionID)
        
        let snapshot = try await sitterSessionRef.getDocument()
        return try? snapshot.data(as: SitterSession.self)
    }
    
    /// Fetches all sessions for a sitter
    func fetchSitterSessions(userID: String) async throws -> SessionCollection {
        Logger.log(level: .info, category: .sessionService, message: "Fetching sitter sessions for user: \(userID)")
        
        // First, get all sitter sessions
        let sitterSessionsRef = db.collection("users").document(userID)
            .collection("sitterSessions")
        
        let sitterSessionsSnapshot = try await sitterSessionsRef.getDocuments()
        let sitterSessions = try sitterSessionsSnapshot.documents.compactMap { try $0.data(as: SitterSession.self) }
        
        // Then, fetch the actual sessions from their respective nests
        var allSessions: [SessionItem] = []
        for sitterSession in sitterSessions {
            if let session = try? await getSession(nestID: sitterSession.nestID, sessionID: sitterSession.id) {
                allSessions.append(session)
            }
        }
        
        // Sort sessions into buckets
        let now = Date()
        
        let upcoming = allSessions.filter { $0.startDate > now }
        let inProgress = allSessions.filter { $0.startDate <= now && $0.endDate > now }
        let past = allSessions.filter { $0.endDate <= now }
        
        // Sort each bucket
        let sortedUpcoming = upcoming.sorted { $0.startDate < $1.startDate }
        let sortedInProgress = inProgress.sorted { $0.endDate < $1.endDate }
        let sortedPast = past.sorted { $0.endDate > $1.endDate }
        
        Logger.log(level: .info, category: .sessionService, message: "Fetched \(allSessions.count) sitter sessions ✅")
        
        return SessionCollection(
            upcoming: sortedUpcoming,
            inProgress: sortedInProgress,
            past: sortedPast
        )
    }
    
    /// Fetches only the in-progress session for a sitter
    func fetchInProgressSitterSession(userID: String) async throws -> SessionItem? {
        Logger.log(level: .info, category: .sessionService, message: "Fetching sitter sessions...")
        
        // First get all sitter sessions for this user
        let sitterSessionsRef = db.collection("users").document(userID)
            .collection("sitterSessions")
        
        let sitterSessionsSnapshot = try await sitterSessionsRef.getDocuments()
        let sitterSessions = try sitterSessionsSnapshot.documents.compactMap { try $0.data(as: SitterSession.self) }
        
        // For each sitter session, fetch the actual session and find the in-progress one
        for sitterSession in sitterSessions {
            if let session = try await getSession(nestID: sitterSession.nestID, sessionID: sitterSession.id),
               session.status == .inProgress || session.status == .extended {
                Logger.log(level: .info, category: .sessionService, message: "Found in-progress session ✅")
                return session
            }
        }
        
        Logger.log(level: .info, category: .sessionService, message: "No in-progress sessions found")
        return nil
    }
}

// MARK: - Invite Status
enum InviteStatus: String, Codable {
    case pending
    case accepted
    case expired
    case cancelled
}

// MARK: - Invite Model
struct Invite: Codable, Identifiable {
    let id: String  // Format: "invite-123456"
    let nestID: String
    let nestName: String  // Add nestName field
    let sessionID: String
    let sitterEmail: String
    let status: InviteStatus
    let createdAt: Date
    let expiresAt: Date
    let createdBy: String
    
    // Helper computed property for getting the raw code
    var rawCode: String {
        let parts = id.split(separator: "-")
        return parts.count > 1 ? String(parts[1]) : ""
    }
    
    init(
        id: String,
        nestID: String,
        nestName: String,  // Add nestName parameter
        sessionID: String,
        sitterEmail: String,
        status: InviteStatus,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        createdBy: String
    ) {
        self.id = id
        self.nestID = nestID
        self.nestName = nestName
        self.sessionID = sessionID
        self.sitterEmail = sitterEmail
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt ?? createdAt.addingTimeInterval(48 * 60 * 60) // 48 hours validity
        self.createdBy = createdBy
    }
}

#if DEBUG
extension SessionService {
    static func generateDebugSessions() -> [SessionItem] {
        let now = Date()
        var sessions: [SessionItem] = []
        
        // Generate 1 in-progress session
        let inProgressSession = SessionItem(
            title: "Weekend Getaway",
            startDate: now.addingTimeInterval(-24 * 60 * 60), // Started yesterday
            endDate: now.addingTimeInterval(24 * 60 * 60),    // Ends tomorrow
            isMultiDay: true
        )
        sessions.append(inProgressSession)
        
        // Generate 10 past sessions
        let pastSessionTitles = [
            "Birthday Party",
            "Anniversary Dinner",
            "Holiday Coverage",
            "Date Night",
            "Business Trip",
            "Family Reunion",
            "Wedding Weekend",
            "Spring Break",
            "Summer Vacation",
            "New Year's Party"
        ]
        
        for (index, title) in pastSessionTitles.enumerated() {
            let daysAgo = Double((index + 1) * 3) // Space them out every 3 days
            let isMultiDay = [true, false].randomElement()!
            
            let endDate = now.addingTimeInterval(-daysAgo * 24 * 60 * 60)
            let startDate = endDate.addingTimeInterval(isMultiDay ? -48 * 60 * 60 : -3 * 60 * 60)
            
            let session = SessionItem(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isMultiDay: isMultiDay
            )
            sessions.append(session)
        }
        
        // Generate 5 upcoming sessions
        let upcomingSessionTitles = [
            "Valentine's Dinner",
            "Spring Break Trip",
            "Anniversary Trip to Cabo",
            "Summer BBQ",
            "Family Photos"
        ]
        
        for (index, title) in upcomingSessionTitles.enumerated() {
            let daysAhead = Double((index + 1) * 5) // Space them out every 5 days
            let isMultiDay = [true, false].randomElement()!
            
            let startDate = now.addingTimeInterval(daysAhead * 24 * 60 * 60)
            let endDate = startDate.addingTimeInterval(isMultiDay ? 72 * 60 * 60 : 4 * 60 * 60)
            
            let session = SessionItem(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isMultiDay: isMultiDay
            )
            sessions.append(session)
        }
        
        return sessions
    }
    
    func loadDebugSessions() {
        // Instead of saving to Firebase, just update the in-memory sessions
        self.sessions = SessionService.generateDebugSessions()
        Logger.log(level: .debug, category: .sessionService, message: "Loaded \(sessions.count) debug sessions in memory")
    }
    
    // Add a method to clear debug sessions
    func clearDebugSessions() {
        self.sessions = []
        Logger.log(level: .debug, category: .sessionService, message: "Cleared debug sessions from memory")
    }
}
#endif 
