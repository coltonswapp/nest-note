import Foundation

struct SessionItem: Hashable, Codable {
    var id: String = UUID().uuidString
    var title: String
    var associatedSitterID: String?
    var startDate: Date
    var endDate: Date
    var isMultiDay: Bool
    var events: [SessionEvent] = []
    var visibilityLevel: VisibilityLevel = .standard
    var status: SessionStatus = .upcoming
    
    init(
        title: String = "",
        sitterID: String? = nil,
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(60 * 60 * 2), // 2 hours by default
        isMultiDay: Bool = false,
        visibilityLevel: VisibilityLevel = .standard
    ) {
        self.title = title
        self.associatedSitterID = sitterID
        self.startDate = startDate
        self.endDate = endDate
        self.isMultiDay = isMultiDay
        self.visibilityLevel = visibilityLevel
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case associatedSitterID
        case startDate
        case endDate
        case isMultiDay
        case events
        case visibilityLevel
        case status
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        associatedSitterID = try container.decodeIfPresent(String.self, forKey: .associatedSitterID)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        isMultiDay = try container.decode(Bool.self, forKey: .isMultiDay)
        events = try container.decodeIfPresent([SessionEvent].self, forKey: .events) ?? []
        visibilityLevel = try container.decodeIfPresent(VisibilityLevel.self, forKey: .visibilityLevel) ?? .standard
        
        // For existing sessions without a status, infer it based on dates
        if let status = try container.decodeIfPresent(SessionStatus.self, forKey: .status) {
            self.status = status
        } else {
            // Infer status based on current date and session dates
            self.status = inferredStatus()
        }
    }
}

enum SessionStatus: String, Codable {
    case upcoming
    case inProgress = "inProgress"
    case extended
    case completed
    
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
