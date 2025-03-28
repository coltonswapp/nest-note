import Foundation

struct UserSession: Identifiable, Codable {
    let id: String  // Same as the original sessionID
    let nestID: String
    let title: String
    let startDate: Date
    let endDate: Date
    let status: String  // "upcoming", "active", "completed" 
    
    // Quick access display information
    let nestName: String
    let nestAddress: String?
    
    // Sitter-specific fields
    let inviteAcceptedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case nestID
        case title
        case startDate
        case endDate
        case status
        case nestName
        case nestAddress
        case inviteAcceptedAt
    }
} 