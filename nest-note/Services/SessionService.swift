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
    let db = Firestore.firestore()
    
    private init() {}
    
    var sessions: [SessionItem] = []
    private var sitterSessionCollection: SessionCollection?
    
    // Add these types at the top of the file
    enum SessionBucket: Int {
        case past
        case inProgress
        case upcoming
    }

    struct SessionCollection {
        var upcoming: [SessionItem]
        var inProgress: [SessionItem]
        var past: [SessionItem]
    }
    
    func reset() async {
        Logger.log(level: .info, category: .nestService, message: "Resetting SessionService...")
        sessions = []
        sitterSessionCollection = nil
    }
    
    func sessionExists(sessionId: String) -> Bool {
        return sessions.contains(where: { $0.id == sessionId })
    }
    
    // MARK: - Create
    func createSession(_ session: SessionItem) async throws -> SessionItem {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Creating new session: \(session.title)")
        
        do {
            try await saveSession(session, nestID: nestID)
            
            // Update local cache
            sessions.append(session)
            
            Logger.log(level: .info, category: .sessionService, message: "Session created successfully ✅")
            
            // Log success event
            Tracker.shared.track(.sessionCreated)
            
            return session
        } catch {
            // Log failure event
            Tracker.shared.track(.sessionCreated, result: false, error: error.localizedDescription)
            throw error
        }
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
        
        guard sessionDoc.exists else {
            Logger.log(level: .error, category: .sessionService, message: "Session document not found ❌ \n Ref:\(sessionRef.path)")
            return nil
        }
        
        do {
            // Use the Firestore decoder which will now skip the events field
            let session = try sessionDoc.data(as: SessionItem.self)
            Logger.log(level: .info, category: .sessionService, message: "Session fetched successfully ✅")
            return session
        } catch {
            Logger.log(level: .error, category: .sessionService, message: "Error decoding session: \(error)")
            throw error
        }
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
        
        do {
            let sessionRef = db.collection("nests")
                .document(nestID)
                .collection("sessions")
                .document(session.id)
            
            try await sessionRef.setData(from: session, merge: true)
            
            // Update local cache
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = session
            }
            
            Logger.log(level: .info, category: .sessionService, message: "Session updated successfully ✅")
            
            // Log success event
            Tracker.shared.track(.sessionUpdated)
        } catch {
            // Log failure event
            Tracker.shared.track(.sessionUpdated, result: false, error: error.localizedDescription)
            throw error
        }
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
            
            // Sort into buckets based on status
            switch session.status {
            case .upcoming:
                result.upcoming.append(session)
            case .inProgress, .extended:
                result.inProgress.append(session)
            case .earlyAccess, .completed, .archived:
                result.past.append(session)
            }
        }
        
        // Sort upcoming sessions by start date (soonest first)
        let sortedUpcoming = sorted.upcoming.sorted { $0.startDate < $1.startDate }
        
        // Sort in-progress sessions by end date (ending soonest first)
        let sortedInProgress = sorted.inProgress.sorted { $0.endDate < $1.endDate }
        
        // Sort past sessions by end date (most recent first)
        let sortedPast = sorted.past.sorted { $0.endDate > $1.endDate }
        
        self.sessions = sessions
        
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
    
    // MARK: - Helper Methods
    /// Determines the correct nestID for a given sessionID
    /// Handles both owner and sitter scenarios using local session cache
    private func getNestIDForSession(sessionID: String) async throws -> String {
        // First, check local sessions array for the nestID (most efficient)
        if let session = sessions.first(where: { $0.id == sessionID }) {
            return session.nestID
        }
        
        // If not in local cache, check if user is a sitter for this session
        guard let userID = Auth.auth().currentUser?.uid else {
            throw SessionError.userNotAuthenticated
        }
        
        let sitterSessionRef = db.collection("users").document(userID)
            .collection("sitterSessions").document(sessionID)
        let sitterSessionDoc = try await sitterSessionRef.getDocument()
        
        if let sitterSession = try? sitterSessionDoc.data(as: SitterSession.self) {
            return sitterSession.nestID
        }
        
        // If we can't find the session in either place, throw an error
        throw SessionError.sessionNotFound
    }
    
    // MARK: - Session Events
    /// Creates or updates a single event in a session
    func updateSessionEvent(_ event: SessionEvent, sessionID: String) async throws {
        // Get the correct nestID for this session (handles both owner and sitter cases)
        let nestID = try await getNestIDForSession(sessionID: sessionID)
        
        Logger.log(level: .info, category: .sessionService, message: "Updating event: \(event.id) for session: \(sessionID) in nest: \(nestID)")
        
        do {
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
            
            // Log success event
            Tracker.shared.track(.sessionEventAdded)
        } catch {
            // Log failure event
            Tracker.shared.track(.sessionEventAdded, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    /// Updates multiple events in a session using a batch write
    func updateSessionEvents(_ events: [SessionEvent], sessionID: String) async throws {
        // Get the correct nestID for this session (handles both owner and sitter cases)
        let nestID = try await getNestIDForSession(sessionID: sessionID)
        
        Logger.log(level: .info, category: .sessionService, message: "Batch updating \(events.count) events for session: \(sessionID) in nest: \(nestID)")
        
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
        
        do {
            let snapshot = try await eventsRef.getDocuments()
            
            // Log the number of documents found
            Logger.log(level: .info, category: .sessionService, message: "Found \(snapshot.documents.count) events for session \(sessionID)")
            
            if snapshot.documents.isEmpty {
                Logger.log(level: .info, category: .sessionService, message: "No events found for session \(sessionID)")
                return []
            }
            
            let events = try snapshot.documents.map { document -> SessionEvent in
                do {
                    let event = try document.data(as: SessionEvent.self)
                    Logger.log(level: .debug, category: .sessionService, message: "Successfully parsed event: \(event.id)")
                    return event
                } catch {
                    Logger.log(level: .error, category: .sessionService, message: "Failed to parse event document \(document.documentID): \(error.localizedDescription)")
                    throw error
                }
            }
            
            let sortedEvents = events.sorted { (event1: SessionEvent, event2: SessionEvent) in
                event1.startDate < event2.startDate
            }
            
            Logger.log(level: .info, category: .sessionService, message: "Successfully fetched and sorted \(sortedEvents.count) events for session \(sessionID)")
            return sortedEvents
            
        } catch {
            Logger.log(level: .error, category: .sessionService, message: "Error fetching events for session \(sessionID): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Deletes a single event from a session
    func deleteSessionEvent(_ eventID: String, sessionID: String) async throws {
        // Get the correct nestID for this session (handles both owner and sitter cases)
        let nestID = try await getNestIDForSession(sessionID: sessionID)
        
        Logger.log(level: .info, category: .sessionService, message: "Deleting event: \(eventID) from session: \(sessionID) in nest: \(nestID)")
        
        do {
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
            
            // Log success event
            Tracker.shared.track(.sessionEventDeleted)
        } catch {
            // Log failure event
            Tracker.shared.track(.sessionEventDeleted, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    /// Deletes all events from a session
    func deleteAllSessionEvents(sessionID: String) async throws {
        // Get the correct nestID for this session (handles both owner and sitter cases)
        let nestID = try await getNestIDForSession(sessionID: sessionID)
        
        Logger.log(level: .info, category: .sessionService, message: "Deleting all events for session: \(sessionID) in nest: \(nestID)")
        
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
        case .earlyAccess:
            // Can only transition to early access from inProgress or extended
            guard session.status == .inProgress || session.status == .extended else {
                throw ServiceError.invalidStatusTransition
            }
            // Start the early access on the session
            updatedSession.startEarlyAccess()
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
        case .archived:
            throw ServiceError.invalidStatusTransition
        }
        
        updatedSession.status = newStatus
        try await updateSession(updatedSession)
    }
    
    /// Completes a session and starts its early access period (if configured)
    func completeSession(_ session: SessionItem) async throws {
        Logger.log(level: .info, category: .sessionService, message: "Completing session: \(session.id)")
        
        var updatedSession = session
        
        // Check if early access is configured
        if updatedSession.earlyAccessDuration != .none {
            // Start early access
            updatedSession.startEarlyAccess()
            Logger.log(level: .info, category: .sessionService, message: "Session moved to early access: \(updatedSession.earlyAccessDuration.displayName)")
        } else {
            // No early access, go directly to completed
            updatedSession.status = .completed
            Logger.log(level: .info, category: .sessionService, message: "Session completed (no early access)")
        }
        
        try await updateSession(updatedSession)
        
        // Post notification about status change
        NotificationCenter.default.post(
            name: .sessionStatusDidChange,
            object: nil,
            userInfo: [
                "sessionId": session.id,
                "newStatus": updatedSession.status.rawValue
            ]
        )
    }
    
    /// Checks all sessions for expired early access periods and updates them
    func checkExpiredEarlyAccessPeriods() async throws {
        Logger.log(level: .info, category: .sessionService, message: "Checking for expired early access periods...")
        
        let earlyAccessSessions = sessions.filter { $0.status == .earlyAccess }
        var expiredCount = 0
        
        for session in earlyAccessSessions {
            if !session.isInEarlyAccess {
                var updatedSession = session
                updatedSession.endEarlyAccess()
                try await updateSession(updatedSession)
                expiredCount += 1
                
                Logger.log(level: .info, category: .sessionService, message: "Early access expired for session: \(session.id)")
                
                // Post notification about status change
                NotificationCenter.default.post(
                    name: .sessionStatusDidChange,
                    object: nil,
                    userInfo: [
                        "sessionId": session.id,
                        "newStatus": updatedSession.status.rawValue
                    ]
                )
            }
        }
        
        if expiredCount > 0 {
            Logger.log(level: .info, category: .sessionService, message: "Expired \(expiredCount) early access periods")
        }
    }
    
    /// Checks all sessions for expired early access periods across all user's nests
    func checkExpiredEarlyAccessPeriodsForUser() async throws {
        guard let userID = UserService.shared.currentUser?.id else {
            Logger.log(level: .debug, category: .sessionService, message: "No current user for early access check")
            return
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Checking expired early access periods for user: \(userID)")
        
        // For sitters, check their active sessions
        let sitterSessionsRef = db.collection("users").document(userID)
            .collection("sitterSessions")
            .limit(to: 50) // Reasonable limit
        
        let sitterSessionsSnapshot = try await sitterSessionsRef.getDocuments()
        let sitterSessions = try sitterSessionsSnapshot.documents.compactMap { try $0.data(as: SitterSession.self) }
        
        var expiredCount = 0
        
        // Check each sitter session
        for sitterSession in sitterSessions {
            if let session = try? await getSession(nestID: sitterSession.nestID, sessionID: sitterSession.id),
               session.status == .earlyAccess && !session.isInEarlyAccess {
                
                var updatedSession = session
                updatedSession.endEarlyAccess()
                
                // Update the session in its nest
                let sessionRef = db.collection("nests")
                    .document(sitterSession.nestID)
                    .collection("sessions")
                    .document(session.id)
                
                try await sessionRef.setData(from: updatedSession, merge: true)
                expiredCount += 1
                
                Logger.log(level: .info, category: .sessionService, message: "Early access expired for sitter session: \(session.id)")
            }
        }
        
        if expiredCount > 0 {
            Logger.log(level: .info, category: .sessionService, message: "Expired \(expiredCount) early access periods for user")
        }
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
        // Preserve the userID if it exists in the current assigned sitter
        let existingUserID = session.assignedSitter?.userID
        
        let assignedSitter = AssignedSitter(
            id: sitter.id,
            name: sitter.name,
            email: sitter.email,
            userID: existingUserID,  // Preserve the existing userID
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
    func createInvite(
        sitterEmail: String,
        sitterName: String,
        sessionID: String
    ) async throws -> (id: String, code: String) {
        // Convert the method to use email parameter directly
        let sitter = SitterItem(id: UUID().uuidString, name: sitterName, email: sitterEmail)
        let code = try await createInviteForSitter(sessionID: sessionID, sitter: sitter)
        let inviteID = "invite-\(code)"
        return (id: inviteID, code: code)
    }
    
    /// Updates an existing invite with new sitter information
    func updateInvite(
        inviteID: String,
        sessionID: String,
        sitterEmail: String,
        sitterName: String
    ) async throws {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw SessionError.noCurrentNest
        }
        
        // Get the current invite
        let inviteRef = db.collection("invites").document(inviteID)
        let inviteDoc = try await inviteRef.getDocument()
        
        guard inviteDoc.exists,
              let invite = try? inviteDoc.data(as: Invite.self) else {
            throw SessionError.sessionNotFound
        }
        
        // Update the invite with new sitter email
        try await inviteRef.updateData([
            "sitterEmail": sitterEmail
        ])
        
        // Update session's assigned sitter if needed
        let sessionRef = db.collection("nests").document(nestID)
            .collection("sessions").document(sessionID)
        
        guard let session = try await getSession(nestID: nestID, sessionID: sessionID) else {
            throw SessionError.sessionNotFound
        }
        
        if var assignedSitter = session.assignedSitter {
            assignedSitter.email = sitterEmail
            assignedSitter.name = sitterName
            
            let encodedSitter = try Firestore.Encoder().encode(assignedSitter)
            try await sessionRef.updateData([
                "assignedSitter": encodedSitter
            ])
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
        
        do {
            // Check if the sitter already has a userID in the SavedSitter record
            var sitterUserID: String? = nil
            if let savedSitter = try? await NestService.shared.fetchSavedSitterById(sitter.id) {
                sitterUserID = savedSitter.userID
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
                userID: sitterUserID,  // Use the userID if available
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
            
            // Log success event
            Tracker.shared.track(.sessionInviteCreated)
            
            return code
        } catch {
            // Log failure event
            Tracker.shared.track(.sessionInviteCreated, result: false, error: error.localizedDescription)
            throw error
        }
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
        case .rejected:
            sessionStatus = .declined
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
        // Preserve the userID if it exists in the current assigned sitter
        let existingUserID = session.assignedSitter?.userID
        
        let updatedSitter = AssignedSitter(
            id: session.assignedSitter?.id ?? UUID().uuidString,
            name: session.assignedSitter?.name ?? "Sitter",
            email: invite.sitterEmail,
            userID: existingUserID,  // Preserve the existing userID
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
                sessions.remove(at: index)
            }
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Invite deleted and session updated successfully ✅")
    }
    
    /// Validates and accepts an invite using the provided code
    func validateAndAcceptInvite(inviteID: String) async throws -> SitterSession {
        Logger.log(level: .info, category: .sessionService, message: "Locating session invite for \(inviteID)")
        
        do {
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
            
            // Update the assigned sitter with the actual joiner's information
            var updatedAssignedSitter = session.assignedSitter
            updatedAssignedSitter?.userID = currentUserID
            updatedAssignedSitter?.inviteStatus = .accepted
            
            // Update email to reflect who actually joined, but preserve the original invited name
            // unless the current user has a proper name set
            if let currentUser = Auth.auth().currentUser {
                // Only update the name if the current user has a proper name in their profile
                // Otherwise, keep the original invited sitter's name
                if let userName = UserService.shared.currentUser?.personalInfo.name, !userName.isEmpty {
                    updatedAssignedSitter?.name = userName
                }
                // Always update email to reflect who actually accepted
                updatedAssignedSitter?.email = currentUser.email ?? ""
            }
            
            // Update the saved sitter with the user's ID
            try await updateSavedSitterWithUserID(
                nestID: invite.nestID,
                sitterEmail: invite.sitterEmail,
                userID: currentUserID
            )
            
            // Encode the updated sitter data before transaction
            let encodedSitter = try Firestore.Encoder().encode(updatedAssignedSitter)
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
            
            // Log success event
            Tracker.shared.track(.sessionInviteAccepted)
            
            // Return the session and invite for UI purposes
            return sitterSession
        } catch {
            // Log failure event
            Tracker.shared.track(.sessionInviteAccepted, result: false, error: error.localizedDescription)
            throw error
        }
    }
    
    // Helper method to update a saved sitter with a user ID
    private func updateSavedSitterWithUserID(nestID: String, sitterEmail: String, userID: String) async throws {
        Logger.log(level: .info, category: .sessionService, message: "Updating saved sitter with user ID: \(userID)")
        
        // Find the saved sitter by email
        if let savedSitter = try await NestService.shared.findSavedSitterByEmail(nestId: nestID, sitterEmail) {
            // Update the saved sitter with the user ID
            try await NestService.shared.updateSavedSitterWithUserID(nestId: nestID, savedSitter, userID: userID)
            Logger.log(level: .info, category: .sessionService, message: "Saved sitter updated with user ID ✅")
        } else {
            Logger.log(level: .error, category: .sessionService, message: "No saved sitter found with email: \(sitterEmail)")
        }
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
        
        let collection = SessionCollection(
            upcoming: sortedUpcoming,
            inProgress: sortedInProgress,
            past: sortedPast
        )
        
        // Store the collection locally
        self.sitterSessionCollection = collection
        
        return collection
    }
    
    /// Deletes a sitter session from a user's collection
    func deleteSitterSession(sessionID: String) async throws {
        guard let userID = Auth.auth().currentUser?.uid else {
            throw SessionError.userNotAuthenticated
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Deleting sitter session: \(sessionID)")
        
        // First, get the sitter session to find the nest ID
        let sitterSessionRef = db.collection("users").document(userID)
            .collection("sitterSessions").document(sessionID)
        
        let sitterSessionDoc = try await sitterSessionRef.getDocument()
        guard let sitterSession = try? sitterSessionDoc.data(as: SitterSession.self) else {
            throw SessionError.sessionNotFound
        }
        
        // Get the session to find the invite ID
        guard let session = try await getSession(nestID: sitterSession.nestID, sessionID: sessionID),
              let inviteID = session.assignedSitter?.inviteID else {
            throw SessionError.sessionNotFound
        }
        
        // Create updated assigned sitter with declined status
        var updatedAssignedSitter = session.assignedSitter
        updatedAssignedSitter?.inviteStatus = .declined
        
        // Update both the invite status and session's assigned sitter
        let inviteRef = db.collection("invites").document(inviteID)
        let sessionRef = db.collection("nests").document(sitterSession.nestID)
            .collection("sessions").document(sessionID)
        
        try await db.runTransaction { transaction, errorPointer in
            // Update invite status
            transaction.updateData([
                "status": InviteStatus.rejected.rawValue
            ], forDocument: inviteRef)
            
            // Update session's assigned sitter
            if let encodedSitter = try? Firestore.Encoder().encode(updatedAssignedSitter) {
                transaction.updateData([
                    "assignedSitter": encodedSitter
                ], forDocument: sessionRef)
            }
            
            return nil
        }
        
        // Delete the sitter session
        try await sitterSessionRef.delete()
        
        // Update local collections
        if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
            sessions.remove(at: index)
        }
        
        // Update the sitterSessionCollection if it exists
        if var collection = sitterSessionCollection {
            // Remove from all buckets
            collection.upcoming.removeAll { $0.id == sessionID }
            collection.inProgress.removeAll { $0.id == sessionID }
            collection.past.removeAll { $0.id == sessionID }
            self.sitterSessionCollection = collection
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Sitter session deleted and invite status updated to rejected ✅")
    }
    
    /// Fetches only the in-progress session for a sitter
    func fetchInProgressSitterSession(userID: String) async throws -> SessionItem? {
        Logger.log(level: .info, category: .sessionService, message: "Fetching sitter sessions for user: \(userID)")
        
        do {
            // First get all sitter sessions - limit to 20 most recent
            let sitterSessionsRef = db.collection("users").document(userID)
                .collection("sitterSessions")
                .order(by: "inviteAcceptedAt", descending: true)
                .limit(to: 20)
            
            let sitterSessionsSnapshot = try await sitterSessionsRef.getDocuments()
            Logger.log(level: .info, category: .sessionService, message: "Found \(sitterSessionsSnapshot.documents.count) sitter session documents")
            
            // Process each document with error handling
            var validSitterSessions: [SitterSession] = []
            for (index, document) in sitterSessionsSnapshot.documents.enumerated() {
                do {
                    let sitterSession = try document.data(as: SitterSession.self)
                    validSitterSessions.append(sitterSession)
                    Logger.log(level: .debug, category: .sessionService, message: "Successfully decoded sitter session \(index + 1): \(sitterSession.id)")
                } catch {
                    Logger.log(level: .error, category: .sessionService, message: "Failed to decode sitter session document \(document.documentID) at index \(index): \(error.localizedDescription)")
                    // Continue processing other documents instead of failing completely
                    continue
                }
            }
            
            Logger.log(level: .info, category: .sessionService, message: "Successfully decoded \(validSitterSessions.count) out of \(sitterSessionsSnapshot.documents.count) sitter sessions")
            
            // For each valid sitter session, fetch the actual session and find the in-progress one
            for (index, sitterSession) in validSitterSessions.enumerated() {
                do {
                    Logger.log(level: .debug, category: .sessionService, message: "Fetching session \(index + 1): \(sitterSession.id) from nest: \(sitterSession.nestID)")
                    
                    guard let session = try await getSession(nestID: sitterSession.nestID, sessionID: sitterSession.id) else {
                        Logger.log(level: .debug, category: .sessionService, message: "Session \(sitterSession.id) not found or inaccessible")
                        continue
                    }
                    
                    Logger.log(level: .debug, category: .sessionService, message: "Session \(session.id) has status: \(session.status)")
                    
                    if session.status == .inProgress || session.status == .extended || session.status == .earlyAccess {
                        // Check if early access is still valid
                        if session.status == .earlyAccess && !session.isInEarlyAccess {
                            Logger.log(level: .debug, category: .sessionService, message: "Session \(session.id) early access has expired, skipping")
                            continue
                        }
                        
                        Logger.log(level: .info, category: .sessionService, message: "Found accessible session: \(session.id) with status: \(session.status) ✅")
                        return session
                    }
                } catch {
                    Logger.log(level: .error, category: .sessionService, message: "Failed to fetch session \(sitterSession.id) from nest \(sitterSession.nestID): \(error.localizedDescription)")
                    // Continue with other sessions instead of failing completely
                    continue
                }
            }
            
            Logger.log(level: .info, category: .sessionService, message: "No in-progress sessions found after checking \(validSitterSessions.count) sessions")
            return nil
            
        } catch {
            Logger.log(level: .error, category: .sessionService, message: "Critical error in fetchInProgressSitterSession: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetches archived sitter sessions for a user
    func fetchArchivedSitterSessions(userID: String, limit: Int = 20) async throws -> [ArchivedSitterSession] {
        Logger.log(level: .info, category: .sessionService, message: "Fetching archived sitter sessions...")
        
        let archivedSessionsRef = db.collection("users").document(userID)
            .collection("archivedSitterSessions")
            .order(by: "archivedDate", descending: true)
            .limit(to: limit)
        
        let snapshot = try await archivedSessionsRef.getDocuments()
        let archivedSessions = try snapshot.documents.compactMap { try $0.data(as: ArchivedSitterSession.self) }
        
        Logger.log(level: .info, category: .sessionService, message: "Fetched \(archivedSessions.count) archived sitter sessions ✅")
        return archivedSessions
    }
    
    /// Combines active and archived sitter sessions for history view
    func fetchSitterSessionHistory(userID: String, limit: Int = 50) async throws -> [Any] {
        Logger.log(level: .info, category: .sessionService, message: "Fetching sitter session history...")
        
        // Get active sitter sessions (with corresponding full session data)
        let sessionCollection = try await fetchSitterSessions(userID: userID)
        
        // Get archived sessions
        let archivedSessions = try await fetchArchivedSitterSessions(userID: userID)
        
        // Combine all sessions (only keep past completed ones from active sessions)
        var allHistory: [Any] = []
        
        // Add completed sessions from the active set
        allHistory.append(contentsOf: sessionCollection.past)
        
        // Add archived sessions
        allHistory.append(contentsOf: archivedSessions)
        
        // If we need to limit the results
        if allHistory.count > limit {
            allHistory = Array(allHistory.prefix(limit))
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Fetched \(allHistory.count) sitter session history items ✅")
        return allHistory
    }
}

// MARK: - Invite Status
enum InviteStatus: String, Codable {
    case pending
    case accepted
    case expired
    case cancelled
    case rejected
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
