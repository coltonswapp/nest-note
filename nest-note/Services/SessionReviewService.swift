//
//  SessionReviewService.swift
//  nest-note
//
//  Created by Colton Swapp on 11/28/25.
//

import Foundation
import FirebaseFirestore

// MARK: - SessionReview Model
struct SessionReview: Codable, Hashable {
    let id: String
    let userId: String
    let userEmail: String
    let userName: String
    let sessionId: String?
    let nestId: String?
    let userRole: UserRole
    let sessionRating: SessionRating
    let easeOfUse: EaseOfUse
    let futureUse: FutureUse
    let additionalFeedback: String?
    let timestamp: Date
    
    // MARK: - Enums
    enum UserRole: String, Codable, CaseIterable {
        case owner = "owner"
        case sitter = "sitter"
    }
    
    enum SessionRating: String, Codable, CaseIterable {
        case catastrophic = "Catastrophic"
        case bad = "Bad"
        case good = "Good"
        case superb = "Superb"
        
        var isPositive: Bool {
            return self == .good || self == .superb
        }
    }
    
    enum EaseOfUse: String, Codable, CaseIterable {
        case notAtAll = "Not at all"
        case no = "No"
        case yes = "Yes"
        case yesSuper = "Yes, super!"
    }
    
    enum FutureUse: String, Codable, CaseIterable {
        case no = "No"
        case maybe = "We'll see" // For owner: "We'll see", For sitter: "Maybe"
        case probably = "Probably" // For owner: "Probably", For sitter: "Yes"
        case definitely = "Of course!" // Same for both
        
        static func options(for role: UserRole) -> [(value: FutureUse, title: String)] {
            switch role {
            case .owner:
                return [
                    (.no, "No"),
                    (.maybe, "We'll see"),
                    (.probably, "Probably"),
                    (.definitely, "Of course!")
                ]
            case .sitter:
                return [
                    (.no, "No"),
                    (.maybe, "Maybe"),
                    (.probably, "Yes"),
                    (.definitely, "Of Course!")
                ]
            }
        }
    }
    
    // MARK: - Initialization
    init(
        userId: String,
        userEmail: String,
        userName: String,
        sessionId: String? = nil,
        nestId: String? = nil,
        userRole: UserRole,
        sessionRating: SessionRating,
        easeOfUse: EaseOfUse,
        futureUse: FutureUse,
        additionalFeedback: String? = nil
    ) {
        self.id = UUID().uuidString
        self.userId = userId
        self.userEmail = userEmail
        self.userName = userName
        self.sessionId = sessionId
        self.nestId = nestId
        self.userRole = userRole
        self.sessionRating = sessionRating
        self.easeOfUse = easeOfUse
        self.futureUse = futureUse
        self.additionalFeedback = additionalFeedback
        self.timestamp = Date()
    }
    
    init(
        id: String,
        userId: String,
        userEmail: String,
        userName: String,
        sessionId: String?,
        nestId: String?,
        userRole: UserRole,
        sessionRating: SessionRating,
        easeOfUse: EaseOfUse,
        futureUse: FutureUse,
        additionalFeedback: String?,
        timestamp: Date
    ) {
        self.id = id
        self.userId = userId
        self.userEmail = userEmail
        self.userName = userName
        self.sessionId = sessionId
        self.nestId = nestId
        self.userRole = userRole
        self.sessionRating = sessionRating
        self.easeOfUse = easeOfUse
        self.futureUse = futureUse
        self.additionalFeedback = additionalFeedback
        self.timestamp = timestamp
    }
    
    // MARK: - Firebase Dictionary
    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "userId": userId,
            "userEmail": userEmail,
            "userName": userName,
            "userRole": userRole.rawValue,
            "sessionRating": sessionRating.rawValue,
            "easeOfUse": easeOfUse.rawValue,
            "futureUse": futureUse.rawValue,
            "timestamp": Timestamp(date: timestamp)
        ]
        
        if let sessionId = sessionId {
            dict["sessionId"] = sessionId
        }
        if let nestId = nestId {
            dict["nestId"] = nestId
        }
        if let feedback = additionalFeedback, !feedback.isEmpty {
            dict["additionalFeedback"] = feedback
        }
        
        return dict
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SessionReview, rhs: SessionReview) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - SessionReviewService
final class SessionReviewService {
    
    // MARK: - Shared Instance
    static let shared = SessionReviewService()
    
    // MARK: - Properties
    private let db = Firestore.firestore()
    private let collectionPath = "sessionReviews"
    
    // MARK: - Configuration
    /// Maximum age of a session to be eligible for review (30 days)
    static let maxReviewableSessionAge: TimeInterval = 30 * 24 * 60 * 60
    
    /// Minimum session duration to be eligible for review
    /// Set to 0 for testing to allow immediate review of any completed session
    /// Set to 30 * 60 (30 minutes) for production to filter out very short sessions
    static let minReviewableSessionDuration: TimeInterval = 30 * 60 // TODO: Should be (30 * 60) for production
    
    private init() {}
    
    // MARK: - Submit Review
    func submitReview(_ review: SessionReview) async throws {
        let docRef = db.collection(collectionPath).document(review.id)
        try await docRef.setData(review.asDictionary)
        Logger.log(level: .info, category: .general, message: "Session review submitted: \(review.id)")
    }
    
    // MARK: - Fetch Reviews
    func getReviews(limit: Int = 50) async throws -> [SessionReview] {
        let query = db.collection(collectionPath)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { parseReview(from: $0) }
    }
    
    func getReviews(for userId: String) async throws -> [SessionReview] {
        let query = db.collection(collectionPath)
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { parseReview(from: $0) }
    }
    
    func getReviews(byRole role: SessionReview.UserRole, limit: Int = 50) async throws -> [SessionReview] {
        let query = db.collection(collectionPath)
            .whereField("userRole", isEqualTo: role.rawValue)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { parseReview(from: $0) }
    }
    
    // MARK: - Delete Review
    func deleteReview(_ review: SessionReview) async throws {
        let docRef = db.collection(collectionPath).document(review.id)
        try await docRef.delete()
        Logger.log(level: .info, category: .general, message: "Session review deleted: \(review.id)")
    }
    
    // MARK: - Mark Session as Reviewed
    
    /// Marks a session as reviewed by the owner
    func markSessionReviewedByOwner(sessionId: String, nestId: String) async throws {
        let sessionRef = db.collection("nests")
            .document(nestId)
            .collection("sessions")
            .document(sessionId)
        
        try await sessionRef.updateData([
            "ownerReviewedAt": Timestamp(date: Date())
        ])
        
        // Update local cache if available
        if let index = SessionService.shared.sessions.firstIndex(where: { $0.id == sessionId }) {
            SessionService.shared.sessions[index].ownerReviewedAt = Date()
        }
        
        Logger.log(level: .info, category: .general, message: "Session marked as reviewed by owner: \(sessionId)")
    }
    
    /// Marks a session as reviewed by the sitter
    func markSessionReviewedBySitter(sessionId: String, userId: String) async throws {
        let sitterSessionRef = db.collection("users")
            .document(userId)
            .collection("sitterSessions")
            .document(sessionId)
        
        try await sitterSessionRef.updateData([
            "reviewedAt": Timestamp(date: Date())
        ])
        
        Logger.log(level: .info, category: .general, message: "Session marked as reviewed by sitter: \(sessionId)")
    }
    
    // MARK: - Review Eligibility
    
    /// Checks if a session is eligible for review
    /// - Parameters:
    ///   - session: The session to check
    ///   - isOwner: Whether the current user is the owner
    /// - Returns: True if the session can be reviewed
    func isSessionEligibleForReview(_ session: SessionItem, isOwner: Bool) -> Bool {
        // Must be a completed or early access session
        guard session.status == .completed || session.status == .earlyAccess || session.status == .archived else {
            Logger.log(level: .debug, category: .general, message: "SessionReviewService: Session \(session.id) not eligible - status: \(session.status.rawValue)")
            return false
        }
        
        // Must have ended within the last 30 days
        let sessionAge = Date().timeIntervalSince(session.endDate)
        guard sessionAge <= Self.maxReviewableSessionAge else {
            Logger.log(level: .debug, category: .general, message: "SessionReviewService: Session \(session.id) not eligible - too old: \(sessionAge / 86400) days")
            return false
        }
        
        // Must meet minimum duration requirement (if set)
        if Self.minReviewableSessionDuration > 0 {
            let sessionDuration = session.endDate.timeIntervalSince(session.startDate)
            guard sessionDuration >= Self.minReviewableSessionDuration else {
                Logger.log(level: .debug, category: .general, message: "SessionReviewService: Session \(session.id) not eligible - too short: \(sessionDuration / 60) minutes")
                return false
            }
        }
        
        // Check if already reviewed (based on role)
        if isOwner {
            let isEligible = session.ownerReviewedAt == nil
            if isEligible {
                Logger.log(level: .info, category: .general, message: "SessionReviewService: Session \(session.id) is eligible for owner review")
            } else {
                Logger.log(level: .debug, category: .general, message: "SessionReviewService: Session \(session.id) not eligible - already reviewed by owner")
            }
            return isEligible
        } else {
            // For sitters, we need to check the SitterSession - this is handled elsewhere
            return true
        }
    }
    
    /// Finds the most recent unreviewated session for an owner
    func findUnreviewedSessionForOwner(sessions: [SessionItem]) -> SessionItem? {
        let eligibleSessions = sessions
            .filter { isSessionEligibleForReview($0, isOwner: true) }
            .sorted { $0.endDate > $1.endDate } // Most recent first
        
        return eligibleSessions.first
    }
    
    /// Checks if a sitter session is eligible for review
    func isSitterSessionEligibleForReview(_ sitterSession: SitterSession, session: SessionItem) -> Bool {
        // Already reviewed
        guard sitterSession.reviewedAt == nil else {
            Logger.log(level: .debug, category: .general, message: "SessionReviewService: Sitter session \(session.id) not eligible - already reviewed")
            return false
        }
        
        // Must be a completed or early access session
        guard session.status == .completed || session.status == .earlyAccess || session.status == .archived else {
            Logger.log(level: .debug, category: .general, message: "SessionReviewService: Sitter session \(session.id) not eligible - status: \(session.status.rawValue)")
            return false
        }
        
        // Must have ended within the last 30 days
        let sessionAge = Date().timeIntervalSince(session.endDate)
        guard sessionAge <= Self.maxReviewableSessionAge else {
            Logger.log(level: .debug, category: .general, message: "SessionReviewService: Sitter session \(session.id) not eligible - too old: \(sessionAge / 86400) days")
            return false
        }
        
        // Must meet minimum duration requirement (if set)
        if Self.minReviewableSessionDuration > 0 {
            let sessionDuration = session.endDate.timeIntervalSince(session.startDate)
            guard sessionDuration >= Self.minReviewableSessionDuration else {
                Logger.log(level: .debug, category: .general, message: "SessionReviewService: Sitter session \(session.id) not eligible - too short: \(sessionDuration / 60) minutes")
                return false
            }
        }
        
        Logger.log(level: .info, category: .general, message: "SessionReviewService: Sitter session \(session.id) is eligible for review")
        return true
    }
    
    // MARK: - Helpers
    private func parseReview(from document: DocumentSnapshot) -> SessionReview? {
        guard let data = document.data(),
              let userId = data["userId"] as? String,
              let userEmail = data["userEmail"] as? String,
              let userName = data["userName"] as? String,
              let userRoleRaw = data["userRole"] as? String,
              let userRole = SessionReview.UserRole(rawValue: userRoleRaw),
              let sessionRatingRaw = data["sessionRating"] as? String,
              let sessionRating = SessionReview.SessionRating(rawValue: sessionRatingRaw),
              let easeOfUseRaw = data["easeOfUse"] as? String,
              let easeOfUse = SessionReview.EaseOfUse(rawValue: easeOfUseRaw),
              let futureUseRaw = data["futureUse"] as? String,
              let futureUse = SessionReview.FutureUse(rawValue: futureUseRaw),
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        return SessionReview(
            id: document.documentID,
            userId: userId,
            userEmail: userEmail,
            userName: userName,
            sessionId: data["sessionId"] as? String,
            nestId: data["nestId"] as? String,
            userRole: userRole,
            sessionRating: sessionRating,
            easeOfUse: easeOfUse,
            futureUse: futureUse,
            additionalFeedback: data["additionalFeedback"] as? String,
            timestamp: timestamp
        )
    }
}

