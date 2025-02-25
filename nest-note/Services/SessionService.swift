import Foundation
import FirebaseFirestore

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
    func getSessionEvents(sessionID: String) async throws -> [SessionEvent] {
        guard let nestID = NestService.shared.currentNest?.id else {
            throw ServiceError.noCurrentNest
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Fetching events for session: \(sessionID)")
        
        let eventsRef = db.collection("nests")
            .document(nestID)
            .collection("sessions")
            .document(sessionID)
            .collection("events")
            .order(by: "startDate", descending: false)
        
        let snapshot = try await eventsRef.getDocuments()
        
        let events = try snapshot.documents.compactMap { document -> SessionEvent? in
            do {
                return try document.data(as: SessionEvent.self)
            } catch {
                Logger.log(level: .error, category: .sessionService, message: "Failed to decode event: \(error.localizedDescription)")
                Logger.log(level: .debug, category: .sessionService, message: "Document data: \(document.data())")
                return nil
            }
        }
        
        Logger.log(level: .info, category: .sessionService, message: "Fetched \(events.count) events ✅")
        return events
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
