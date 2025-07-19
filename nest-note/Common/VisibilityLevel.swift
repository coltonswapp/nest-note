//
//  VisibilityLevel.swift
//  nest-note
//
//  Created by Colton Swapp on 10/26/24.
//
import Foundation

enum VisibilityLevel: String, Codable, CaseIterable {
    case always
    case halfDay
    case overnight
    case extended
    
    var title: String {
        switch self {
        case .always: return "Always"
        case .halfDay: return "Half-Day"
        case .overnight: return "Overnight"
        case .extended: return "Extended"
        }
    }
    
    // Returns true if this level has access to the content of the target level
    func hasAccess(to targetLevel: VisibilityLevel) -> Bool {
        let levels: [VisibilityLevel] = [.always, .halfDay, .overnight, .extended]
        guard let currentIndex = levels.firstIndex(of: self),
              let targetIndex = levels.firstIndex(of: targetLevel) else {
            return false
        }
        return currentIndex >= targetIndex
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        // Handle backward compatibility with old enum values
        switch rawValue {
        case "essential":
            self = .always
        case "standard":
            self = .halfDay
        case "extended":
            self = .overnight
        case "comprehensive":
            self = .extended
        case "always":
            self = .always
        case "halfDay":
            self = .halfDay
        case "overnight":
            self = .overnight
        case "extended":
            self = .extended
        default:
            // Default to always for unknown values
            self = .always
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}