import Foundation

enum SessionInviteStatus: String, Codable {
    case none           // No invite has been created
    case invited        // Invite sent, waiting for response
    case accepted       // Sitter has accepted the invite
    case declined       // Sitter has declined the invite
    case cancelled     // Parent cancelled the invite
    
    var displayName: String {
        switch self {
        case .none:
            return "Not yet invited"
        case .invited:
            return "Invited"
        case .accepted:
            return "Accepted"
        case .declined:
            return "Declined"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    var icon: String {
        switch self {
        case .none:
            return "person.slash"
        case .invited:
            return "checkmark.circle.fill"
        case .accepted:
            return "checkmark.circle.fill"
        case .declined:
            return "hand.raised.palm.facing.fill"
        case .cancelled:
            return "xmark.circle"
        }
    }
}

struct AssignedSitter: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var email: String
    var userID: String?  // Optional if they have an account
    var inviteStatus: SessionInviteStatus 
    var inviteID: String?  // Reference to invite if one exists
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    func asSitterItem() -> SitterItem {
        return SitterItem(id: self.id, name: self.name, email: self.email)
    }
}

class SessionItem: Hashable, Codable, SessionDisplayable {
    
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isMultiDay: Bool
    var events: [SessionEvent]
    var visibilityLevel: VisibilityLevel
    var status: SessionStatus
    var assignedSitter: AssignedSitter?
    var nestID: String
    var ownerID: String?
    
    // Computed property to check if session has an active invite
    var hasActiveInvite: Bool {
        guard let sitter = assignedSitter else { return false }
        return sitter.inviteStatus == .invited || sitter.inviteStatus == .accepted
    }
    
    init(
        id: String = UUID().uuidString,
        title: String = "",
        startDate: Date = Date().roundedToNext15Minutes(), // 2:05PM becomes 2:15PM
        endDate: Date = Date().addingTimeInterval(60 * 60 * 2).roundedToNext15Minutes(), // 2 hours by default
        isMultiDay: Bool = false,
        events: [SessionEvent] = [],
        visibilityLevel: VisibilityLevel = .standard,
        status: SessionStatus = .upcoming,
        assignedSitter: AssignedSitter? = nil,
        nestID: String = NestService.shared.currentNest!.id,
        ownerID: String? = NestService.shared.currentNest?.ownerId
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isMultiDay = isMultiDay
        self.events = events
        self.visibilityLevel = visibilityLevel
        self.status = status
        self.assignedSitter = assignedSitter
        self.nestID = nestID
        self.ownerID = ownerID
    }
    
    /// Determines if the session can be marked as active based on business rules
    var canBeMarkedActive: Bool {
        // Can be marked active if it's upcoming and within 24 hours of start time
        if status == .upcoming {
            return startDate.timeIntervalSinceNow <= 24 * 60 * 60 // 24 hours
        }
        return false
    }
    
    /// Determines if the session can be marked as completed based on business rules
    var canBeMarkedCompleted: Bool {
        // Can be marked completed if it's active or if it's past the start time
        return status == .inProgress || startDate < Date()
    }
    
    /// Infers the status based on dates and current status
    func inferredStatus(at currentDate: Date = Date()) -> SessionStatus {
        // Don't override manually set completed status
        if status == .completed {
            return .completed
        }
        
        // Don't override manually set active status unless the session is over
        if status == .inProgress {
            if currentDate > endDate {
                return .extended
            }
            return .inProgress
        }
        
        // Automatic status inference
        if currentDate < startDate {
            return .upcoming
        } else if currentDate > endDate {
            return .completed
        } else {
            return .inProgress
        }
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SessionItem, rhs: SessionItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startDate
        case endDate
        case isMultiDay
        // Exclude 'events' from CodingKeys to prevent encoding/decoding
        case visibilityLevel
        case status
        case assignedSitter
        case nestID
        case ownerID
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        isMultiDay = try container.decode(Bool.self, forKey: .isMultiDay)
        // Initialize events as an empty array since we're not decoding it
        events = []
        visibilityLevel = try container.decodeIfPresent(VisibilityLevel.self, forKey: .visibilityLevel) ?? .standard
        assignedSitter = try container.decodeIfPresent(AssignedSitter.self, forKey: .assignedSitter)
        nestID = try container.decodeIfPresent(String.self, forKey: .nestID) ?? ""
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID)
        
        // For existing sessions without a status, infer it based on dates
        if let status = try container.decodeIfPresent(SessionStatus.self, forKey: .status) {
            self.status = status
        } else {
            // placeholder
            self.status = .upcoming
            // Infer status based on current date and session dates
            self.status = inferredStatus()
        }
    }
    
    // MARK: - Sitter Management
    func updateAssignedSitter(with sitter: AssignedSitter) {
        self.assignedSitter = sitter
    }
    
    func clearAssignedSitter() {
        self.assignedSitter = nil
    }
}

protocol Containable {
    func contains(_ elements: [Self]) -> Bool
}

enum SessionStatus: String, Codable, Containable {
    case upcoming
    case inProgress = "inProgress"
    case extended
    case completed
    case archived
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        case "active":
            self = .inProgress
        case "complete":
            self = .completed
        default:
            if let status = SessionStatus(rawValue: rawValue) {
                self = status
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Cannot initialize SessionStatus from invalid String value \(rawValue)"
                    )
                )
            }
        }
    }
    
    var icon: String {
        switch self {
        case .upcoming:
            return "calendar.badge.clock"
        case .inProgress:
            return "calendar.badge.checkmark"
        case .extended:
            return "timer.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .archived:
            return "archivebox.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .inProgress:
            return "In Progress"
        default:
            return self.rawValue.capitalized
        }
    }
    
    func contains(_ elements: [SessionStatus]) -> Bool {
        return elements.contains(self)
    }
}

struct SitterItem: Hashable, Codable {
    let id: String
    let name: String
    let email: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    init(id: String, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }
}
