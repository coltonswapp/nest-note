//
//  VisibilityLevel.swift
//  nest-note
//
//  Created by Colton Swapp on 10/26/24.
//
import Foundation

enum VisibilityLevel: String, Codable, CaseIterable {
    case essential
    case standard
    case extended
    case comprehensive
    
    var title: String {
        switch self {
        case .essential: return "Essential"
        case .standard: return "Standard"
        case .extended: return "Extended"
        case .comprehensive: return "Comprehensive"
        }
    }
    
    // Returns true if this level has access to the content of the target level
    func hasAccess(to targetLevel: VisibilityLevel) -> Bool {
        let levels: [VisibilityLevel] = [.essential, .standard, .extended, .comprehensive]
        guard let currentIndex = levels.firstIndex(of: self),
              let targetIndex = levels.firstIndex(of: targetLevel) else {
            return false
        }
        return currentIndex >= targetIndex
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if let level = VisibilityLevel(rawValue: rawValue) {
            self = level
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid visibility level: \(rawValue)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
