import UIKit

/// Provides empty state configurations for session-related views
enum SessionEmptyStateDataSource {
    /// Configuration for empty states in the main sessions view
    static func nestEmptyState(for bucket: SessionService.SessionBucket) -> (title: String, subtitle: String, icon: UIImage?) {
        switch bucket {
        case .upcoming:
            return (
                "No upcoming sessions",
                "Schedule a session to get started.",
                UIImage(systemName: "calendar.badge.plus")
            )
        case .inProgress:
            return (
                "No active sessions",
                "Sessions in progress will appear here.",
                UIImage(systemName: "calendar.badge.clock")
            )
        case .past:
            return (
                "No past sessions",
                "Your past sessions will appear here.",
                UIImage(systemName: "calendar.badge.checkmark")
            )
        }
    }
    
    /// Configuration for empty states in the sitter sessions view
    static func sitterEmptyState(for bucket: SessionService.SessionBucket) -> (title: String, subtitle: String, icon: UIImage?) {
        switch bucket {
        case .upcoming:
            return (
                "No upcoming sessions",
                "Join a session to get started.",
                UIImage(systemName: "calendar.badge.plus")
            )
        case .inProgress:
            return (
                "No active sessions",
                "Sessions in progress will appear here.",
                UIImage(systemName: "calendar.badge.clock")
            )
        case .past:
            return (
                "No past sessions",
                "Your completed sessions will appear here.",
                UIImage(systemName: "calendar.badge.checkmark")
            )
        }
    }
} 