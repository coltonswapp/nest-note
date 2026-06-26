import Foundation

enum ReferralCodeType: String, Codable {
    case creator
    case sitter

    /// Existing admin codes without a `type` field default to creator.
    static func fromFirestoreValue(_ value: String?) -> ReferralCodeType {
        guard let value, let type = ReferralCodeType(rawValue: value) else {
            return .creator
        }
        return type
    }
}

struct ReferralCodeInfo: Equatable {
    let code: String
    let type: ReferralCodeType
    let displayName: String
    let sitterUserId: String?

    var referralCodeTypeAttribute: String { type.rawValue }
}
