//
//  SessionReviewManager.swift
//  nest-note
//
//  Created by Colton Swapp on 11/29/25.
//

import UIKit
import FirebaseAuth

/// Manages session review prompts and tracking
final class SessionReviewManager {
    
    // MARK: - Shared Instance
    static let shared = SessionReviewManager()
    
    // MARK: - Properties
    
    /// Key for tracking if we've already prompted for review this app session
    private var hasPromptedThisSession = false

    /// Track the last time we checked for review prompts to prevent rapid duplicate calls
    private var lastCheckTime: Date?
    private let minimumCheckInterval: TimeInterval = 1.0 // 1 second between checks
    
    /// Key for tracking the last time we prompted for review (stored in UserDefaults)
    private let lastPromptDateKey = "SessionReviewManager.lastPromptDate"
    
    /// Key for tracking skipped session IDs (sessions user chose not to review)
    private let skippedSessionsKey = "SessionReviewManager.skippedSessions"
    
    /// Minimum time between prompts (1 day)
    /// Set to 0 for testing to allow immediate prompts
    private let minimumTimeBetweenPrompts: TimeInterval = 24 * 60 * 60 // TODO: Should be (24 * 60 * 60) for production
    
    /// Debug mode - bypasses UserDefaults checks for testing
    private let debugMode: Bool = false
    
    private init() {}
    
    // MARK: - Skip Management
    
    /// Marks a session as skipped so we don't prompt for it again
    func markSessionAsSkipped(_ sessionId: String) {
        var skippedSessions = getSkippedSessions()
        if !skippedSessions.contains(sessionId) {
            skippedSessions.append(sessionId)
            UserDefaults.standard.set(skippedSessions, forKey: skippedSessionsKey)
            Logger.log(level: .info, category: .general, message: "SessionReviewManager: Marked session \(sessionId) as skipped")
        }
    }
    
    /// Checks if a session has been skipped
    func isSessionSkipped(_ sessionId: String) -> Bool {
        return getSkippedSessions().contains(sessionId)
    }
    
    /// Gets the list of skipped session IDs
    private func getSkippedSessions() -> [String] {
        return UserDefaults.standard.stringArray(forKey: skippedSessionsKey) ?? []
    }
    
    /// Clears old skipped sessions (older than 30 days would have expired anyway)
    /// Call this periodically to clean up UserDefaults
    func cleanupOldSkippedSessions() {
        // For now, we'll keep all skipped sessions
        // In the future, we could track skip dates and remove old ones
    }
    
    /// Clears all UserDefaults data for testing purposes
    /// WARNING: Only use this for testing/debugging
    func clearAllReviewData() {
        UserDefaults.standard.removeObject(forKey: lastPromptDateKey)
        UserDefaults.standard.removeObject(forKey: skippedSessionsKey)
        hasPromptedThisSession = false
        Logger.log(level: .info, category: .general, message: "SessionReviewManager: Cleared all review data for testing")
    }
    
    // MARK: - Public Methods
    
    /// Resets the session flag (call when app enters background)
    func resetSessionFlag() {
        hasPromptedThisSession = false
    }
    
    /// Checks if user should be prompted for a session review and presents the review VC if needed
    /// - Parameter presentingViewController: The view controller to present from
    /// - Returns: True if a review prompt was shown
    @discardableResult
    func checkAndPromptForReviewIfNeeded(from presentingViewController: UIViewController) async -> Bool {
        // Prevent rapid duplicate calls
        let now = Date()
        if let lastCheck = lastCheckTime, now.timeIntervalSince(lastCheck) < minimumCheckInterval {
            return false
        }
        lastCheckTime = now

        if debugMode {
            Logger.log(level: .info, category: .general, message: "SessionReviewManager: DEBUG MODE - bypassing UserDefaults checks")
        }

        // Don't prompt more than once per app session (unless debug mode)
        if !debugMode {
            guard !hasPromptedThisSession else {
                Logger.log(level: .info, category: .general, message: "SessionReviewManager: Already prompted this session")
                return false
            }
        }
        
        // Don't prompt too frequently (unless debug mode or minimum time is 0)
        if !debugMode && minimumTimeBetweenPrompts > 0 {
            if let lastPromptDate = UserDefaults.standard.object(forKey: lastPromptDateKey) as? Date {
                let timeSinceLastPrompt = Date().timeIntervalSince(lastPromptDate)
                guard timeSinceLastPrompt >= minimumTimeBetweenPrompts else {
                    Logger.log(level: .info, category: .general, message: "SessionReviewManager: Too soon since last prompt (\(Int(timeSinceLastPrompt / 60)) minutes ago)")
                    return false
                }
            }
        }
        
        // Check based on user mode
        if ModeManager.shared.isSitterMode {
            return await checkAndPromptForSitterReview(from: presentingViewController)
        } else {
            return await checkAndPromptForOwnerReview(from: presentingViewController)
        }
    }
    
    // MARK: - Owner Review Check
    
    private func checkAndPromptForOwnerReview(from presentingViewController: UIViewController) async -> Bool {
        guard let nestId = NestService.shared.currentNest?.id else {
            Logger.log(level: .info, category: .general, message: "SessionReviewManager: No current nest")
            return false
        }
        
        // Get all sessions for this nest
        let sessions = SessionService.shared.sessions
        
        // Find an unreviewed session that hasn't been skipped (unless debug mode)
        guard let unreviewedSession = SessionReviewService.shared.findUnreviewedSessionForOwner(sessions: sessions) else {
            Logger.log(level: .info, category: .general, message: "SessionReviewManager: No unreviewed sessions for owner")
            return false
        }
        
        // Skip check if in debug mode, otherwise check if session was skipped
        if !debugMode && isSessionSkipped(unreviewedSession.id) {
            Logger.log(level: .info, category: .general, message: "SessionReviewManager: Session \(unreviewedSession.id) was skipped")
            return false
        }
        
        Logger.log(level: .info, category: .general, message: "SessionReviewManager: Found unreviewed session for owner: \(unreviewedSession.id)")
        
        // Present the review VC
        await MainActor.run {
            presentReviewViewController(
                from: presentingViewController,
                sessionId: unreviewedSession.id,
                nestId: nestId
            )
        }
        
        return true
    }
    
    // MARK: - Sitter Review Check
    
    private func checkAndPromptForSitterReview(from presentingViewController: UIViewController) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            Logger.log(level: .info, category: .general, message: "SessionReviewManager: No authenticated user")
            return false
        }
        
        do {
            // Fetch sitter sessions
            let collection = try await SessionService.shared.fetchSitterSessions(userID: userId)
            let allSessions = collection.past + collection.inProgress
            
            // Get the sitter sessions to check reviewedAt
            let sitterSessionsRef = SessionService.shared.db.collection("users")
                .document(userId)
                .collection("sitterSessions")
            
            let sitterSessionsSnapshot = try await sitterSessionsRef.getDocuments()
            let sitterSessions = try sitterSessionsSnapshot.documents.compactMap { try $0.data(as: SitterSession.self) }
            
            // Find an unreviewed session that hasn't been skipped
            for sitterSession in sitterSessions {
                guard let session = allSessions.first(where: { $0.id == sitterSession.id }) else {
                    continue
                }
                
                // Skip if user already skipped this session (unless debug mode)
                if !debugMode && isSessionSkipped(session.id) {
                    continue
                }
                
                if SessionReviewService.shared.isSitterSessionEligibleForReview(sitterSession, session: session) {
                    Logger.log(level: .info, category: .general, message: "SessionReviewManager: Found unreviewed session for sitter: \(session.id)")

                    // Present the review VC with session data for context
                    await MainActor.run {
                        presentReviewViewController(
                            from: presentingViewController,
                            sessionId: session.id,
                            nestId: session.nestID,
                            session: session
                        )
                    }

                    return true
                }
            }
            
            Logger.log(level: .info, category: .general, message: "SessionReviewManager: No unreviewed sessions for sitter")
            return false
            
        } catch {
            Logger.log(level: .error, category: .general, message: "SessionReviewManager: Error checking sitter sessions: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Present Review VC
    
    private func presentReviewViewController(from viewController: UIViewController, sessionId: String, nestId: String, session: SessionItem? = nil) {
        hasPromptedThisSession = true
        UserDefaults.standard.set(Date(), forKey: lastPromptDateKey)

        // Create session context info
        let sessionInfo = createSessionContextInfo(sessionId: sessionId, nestId: nestId, session: session)
        let reviewVC = SessionReviewViewController(sessionId: sessionId, nestId: nestId, sessionInfo: sessionInfo)

        viewController.present(reviewVC, animated: true)
    }

    /// Creates session context information for displaying to the user
    private func createSessionContextInfo(sessionId: String, nestId: String, session: SessionItem? = nil) -> SessionContextInfo? {
        // If a session is provided directly, use it (for sitters)
        if let providedSession = session {
            return SessionContextInfo(
                sessionTitle: providedSession.title.isEmpty ? nil : providedSession.title,
                nestName: nil, // Keep it simple - no nest name fetching
                sessionDate: providedSession.startDate
            )
        }

        // Otherwise, try to find the session in our current sessions (for owners)
        let allSessions = SessionService.shared.sessions
        guard let foundSession = allSessions.first(where: { $0.id == sessionId }) else {
            return nil
        }

        // For owners, we can use the current nest name if available
        let nestName = NestService.shared.currentNest?.name
        return SessionContextInfo(
            sessionTitle: foundSession.title.isEmpty ? nil : foundSession.title,
            nestName: nestName,
            sessionDate: foundSession.startDate
        )
    }
    
    // MARK: - Deep Link Support
    
    /// Presents a review for a specific session (e.g., from deep link)
    /// - Parameters:
    ///   - sessionId: The session ID to review
    ///   - nestId: The nest ID
    ///   - presentingViewController: The view controller to present from
    func presentReviewForSession(sessionId: String, nestId: String, from presentingViewController: UIViewController) {
        presentReviewViewController(from: presentingViewController, sessionId: sessionId, nestId: nestId)
    }
}

