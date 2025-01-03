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
