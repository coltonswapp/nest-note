import Foundation

enum ServiceError: LocalizedError {
    case noCurrentNest
    case invalidData
    case unauthorized
    case networkError(Error)
    case documentNotFound
    case unknown(Error)
    case invalidStatusTransition
    case cannotDelete
    case imageConversionFailed
    case imageUploadFailed
    case invalidOperation(String)
    
    var errorDescription: String? {
        switch self {
        case .noCurrentNest:
            return "No active nest selected"
        case .invalidData:
            return "The data appears to be invalid or corrupted"
        case .unauthorized:
            return "You don't have permission to perform this action"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .documentNotFound:
            return "The requested document was not found"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        case .invalidStatusTransition:
            return "Invalid session status transition"
        case .cannotDelete:
            return "Unable to delete"
        case .imageConversionFailed:
            return "Failed to convert image to data"
        case .imageUploadFailed:
            return "Failed to upload image"
        case .invalidOperation:
            return "Invalid operation"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .noCurrentNest:
            return "Please select or create a nest before performing this action"
        case .invalidData:
            return "The data structure doesn't match what was expected"
        case .unauthorized:
            return "Your current permissions don't allow this operation"
        case .networkError:
            return "There was a problem connecting to the server"
        case .documentNotFound:
            return "The document may have been deleted or never existed"
        case .unknown:
            return "An internal error occurred"
        case .invalidStatusTransition:
            return "Can't set that status now"
        case .cannotDelete:
            return "No valid ID provided"
        case .imageConversionFailed:
            return "Failed to convert image to data"
        case .imageUploadFailed:
            return "The image upload to storage failed"
        case .invalidOperation:
            return "Try again"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noCurrentNest:
            return "Go to settings to select or create a nest"
        case .invalidData:
            return "Try refreshing the data or contact support if the problem persists"
        case .unauthorized:
            return "Contact the nest owner to request necessary permissions"
        case .networkError:
            return "Check your internet connection and try again"
        case .documentNotFound:
            return "Refresh your data to get the latest changes"
        case .unknown:
            return "Try again or contact support if the problem persists"
        case .invalidStatusTransition:
            return "Try again"
        case .cannotDelete:
            return "Reload and try again"
        case .imageConversionFailed:
            return "Reload and try again"
        case .imageUploadFailed:
            return "Check your connection and try again"
        case .invalidOperation:
            return "Try again"
        }
    }
} 
