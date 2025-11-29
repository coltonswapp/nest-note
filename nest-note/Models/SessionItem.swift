import Foundation

enum EarlyAccessDuration: Int, CaseIterable, Codable {
    case none = 0
    case short = 3      // 3 hours
    case halfDay = 12   // 12 hours  
    case fullDay = 24   // 1 day
    case extended = 48  // 2 days
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .short: return "\(String(self.rawValue)) hours"
        case .halfDay: return "\(String(self.rawValue)) hours"
        case .fullDay: return "\(String(self.rawValue)) hours"
        case .extended: return "\(String(self.rawValue)) hours"
        }
    }
    
    var shortDisplayName: String {
        switch self {
        case .none: return "None"
        case .short: return "\(String(self.rawValue))hr"
        case .halfDay: return "\(String(self.rawValue))hr"
        case .fullDay: return "\(String(self.rawValue))hr"
        case .extended: return "\(String(self.rawValue))hr"
        }
    }
    
    var hours: Int { return rawValue }
    
    var timeInterval: TimeInterval {
        return TimeInterval(hours * 60 * 60) // Convert hours to seconds
    }
}

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
    var status: SessionStatus
    var assignedSitter: AssignedSitter?
    var nestID: String
    var ownerID: String?
    var earlyAccessDuration: EarlyAccessDuration
    var earlyAccessEndDate: Date?
    var entryIds: [String]? // Now stores IDs for all selected items (entries, places, etc.)
    var ownerReviewedAt: Date? // When the owner submitted a session review (nil = not reviewed)
    
    // Computed property to check if session has an active invite
    var hasActiveInvite: Bool {
        guard let sitter = assignedSitter else { return false }
        return sitter.inviteStatus == .invited || sitter.inviteStatus == .accepted
    }
    
    // MARK: - Early Access Logic
    
    /// Checks if the session is currently within its early access period
    var isInEarlyAccess: Bool {
        guard status == .earlyAccess,
              let earlyAccessEnd = earlyAccessEndDate else {
            return false
        }
        return Date() <= earlyAccessEnd
    }
    
    /// Calculates the remaining time in the early access period
    var earlyAccessTimeRemaining: TimeInterval? {
        guard isInEarlyAccess,
              let earlyAccessEnd = earlyAccessEndDate else {
            return nil
        }
        return max(0, earlyAccessEnd.timeIntervalSinceNow)
    }
    
    /// Initiates the early access period for the session
    func startEarlyAccess() {
        guard earlyAccessDuration != .none else {
            // No early access configured, go directly to completed
            status = .completed
            return
        }
        
        status = .earlyAccess
        earlyAccessEndDate = Date().addingTimeInterval(earlyAccessDuration.timeInterval)
    }
    
    /// Ends the early access period and marks session as completed
    func endEarlyAccess() {
        status = .completed
        earlyAccessEndDate = nil
    }
    
    /// Checks if the early access period has expired and updates status if needed
    func checkEarlyAccessExpiry() {
        guard status == .earlyAccess else { return }
        
        if !isInEarlyAccess {
            endEarlyAccess()
        }
    }
    
    init(
        id: String = UUID().uuidString,
        title: String = "",
        startDate: Date = Date().roundedToNext15Minutes(), // 2:05PM becomes 2:15PM
        endDate: Date = Date().addingTimeInterval(60 * 60 * 2).roundedToNext15Minutes(), // 2 hours by default
        isMultiDay: Bool = false,
        events: [SessionEvent] = [],
        status: SessionStatus = .upcoming,
        assignedSitter: AssignedSitter? = nil,
        nestID: String = NestService.shared.currentNest!.id,
        ownerID: String? = NestService.shared.currentNest?.ownerId,
        earlyAccessDuration: EarlyAccessDuration = .halfDay,
        earlyAccessEndDate: Date? = nil,
        entryIds: [String]? = nil,
        ownerReviewedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isMultiDay = isMultiDay
        self.events = events
        self.status = status
        self.assignedSitter = assignedSitter
        self.nestID = nestID
        self.ownerID = ownerID
        self.earlyAccessDuration = earlyAccessDuration
        self.earlyAccessEndDate = earlyAccessEndDate
        self.entryIds = entryIds
        self.ownerReviewedAt = ownerReviewedAt
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
        
        // Handle early access status
        if status == .earlyAccess {
            // Check if early access has expired
            if let earlyAccessEnd = earlyAccessEndDate, currentDate > earlyAccessEnd {
                return .completed
            }
            return .earlyAccess
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
        case status
        case assignedSitter
        case nestID
        case ownerID
        case earlyAccessDuration
        case earlyAccessEndDate
        case entryIds
        case ownerReviewedAt
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
        assignedSitter = try container.decodeIfPresent(AssignedSitter.self, forKey: .assignedSitter)
        nestID = try container.decodeIfPresent(String.self, forKey: .nestID) ?? ""
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID)
        // Handle earlyAccessDuration with backwards compatibility for unknown enum values
        if let earlyAccessRawValue = try container.decodeIfPresent(Int.self, forKey: .earlyAccessDuration) {
            earlyAccessDuration = EarlyAccessDuration(rawValue: earlyAccessRawValue) ?? .halfDay
        } else {
            earlyAccessDuration = .halfDay
        }
        earlyAccessEndDate = try container.decodeIfPresent(Date.self, forKey: .earlyAccessEndDate)
        entryIds = try container.decodeIfPresent([String].self, forKey: .entryIds)
        ownerReviewedAt = try container.decodeIfPresent(Date.self, forKey: .ownerReviewedAt)
        
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
    
    // MARK: - Copy Method
    func copy() -> SessionItem {
        let copiedSession = SessionItem(
            id: self.id,
            title: self.title,
            startDate: self.startDate,
            endDate: self.endDate,
            isMultiDay: self.isMultiDay,
            events: self.events, // Shallow copy of events array
            status: self.status,
            assignedSitter: self.assignedSitter, // AssignedSitter is a struct, so it will be copied by value
            nestID: self.nestID,
            ownerID: self.ownerID,
            earlyAccessDuration: self.earlyAccessDuration,
            earlyAccessEndDate: self.earlyAccessEndDate,
            entryIds: self.entryIds,
            ownerReviewedAt: self.ownerReviewedAt
        )
        return copiedSession
    }
}

protocol Containable {
    func contains(_ elements: [Self]) -> Bool
}

enum SessionStatus: String, Codable, Containable {
    case upcoming
    case inProgress = "inProgress"
    case extended
    case earlyAccess = "earlyAccess"
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
        case .earlyAccess:
            return "clock.badge.checkmark"
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
        case .earlyAccess:
            return "Early Access"
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
