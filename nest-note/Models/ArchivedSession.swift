import Foundation

/// A simplified sitter model for archived sessions
struct CompactSitter: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let contactInfo: String?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    init(id: String, name: String, contactInfo: String? = nil) {
        self.id = id
        self.name = name
        self.contactInfo = contactInfo
    }
    
    /// Create a CompactSitter from an AssignedSitter
    init(from assignedSitter: AssignedSitter) {
        self.id = assignedSitter.id
        self.name = assignedSitter.name
        self.contactInfo = assignedSitter.email
    }
}

/// A simplified session model for archived sessions
class ArchivedSession: Identifiable, Codable, Hashable, SessionDisplayable {
    
    let id: String
    let nestID: String
    let ownerID: String?
    let title: String
    let startDate: Date
    let endDate: Date
    let assignedSitter: AssignedSitter?
    let status: SessionStatus
    let archivedDate: Date
    
    init(
        id: String,
        nestId: String,
        ownerId: String?,
        title: String,
        startDate: Date,
        endDate: Date,
        assignedSitter: AssignedSitter?,
        status: SessionStatus = .completed,
        archivedDate: Date = Date()
    ) {
        self.id = id
        self.nestID = nestId
        self.ownerID = ownerId
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.assignedSitter = assignedSitter
        self.status = status
        self.archivedDate = archivedDate
    }
    
    /// Create an ArchivedSession from a SessionItem
    init(from sessionItem: SessionItem) {
        self.id = sessionItem.id
        self.nestID = sessionItem.nestID
        self.ownerID = sessionItem.ownerID
        self.title = sessionItem.title
        self.startDate = sessionItem.startDate
        self.endDate = sessionItem.endDate
        self.assignedSitter = sessionItem.assignedSitter
        self.status = .completed // Archived sessions are always completed
        self.archivedDate = Date()
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ArchivedSession, rhs: ArchivedSession) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id
        case nestID
        case ownerID
        case title
        case startDate
        case endDate
        case visibilityLevel
        case assignedSitter
        case status
        case archivedDate
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        nestID = try container.decode(String.self, forKey: .nestID)
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID)
        title = try container.decode(String.self, forKey: .title)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        assignedSitter = try container.decodeIfPresent(AssignedSitter.self, forKey: .assignedSitter)
        status = try container.decode(SessionStatus.self, forKey: .status)
        archivedDate = try container.decode(Date.self, forKey: .archivedDate)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(nestID, forKey: .nestID)
        try container.encode(ownerID, forKey: .ownerID)
        try container.encode(title, forKey: .title)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(assignedSitter, forKey: .assignedSitter)
        try container.encode(status, forKey: .status)
        try container.encode(archivedDate, forKey: .archivedDate)
    }
} 
