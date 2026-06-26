import Foundation

enum ReferralApplicationSource: String {
    case manual
    case deepLink = "deep_link"
}

enum ReferralApplicationOutcome {
    case creator(ReferralCodeInfo)
    case sitter(ReferralCodeInfo)

    var codeInfo: ReferralCodeInfo {
        switch self {
        case .creator(let info), .sitter(let info):
            return info
        }
    }
}

enum ReferralCodeApplicationHelper {
    static func apply(
        _ input: String,
        source: ReferralApplicationSource = .manual
    ) async throws -> ReferralApplicationOutcome? {
        guard let codeInfo = try await ReferralService.shared.validateReferralCodeInfo(input) else {
            Tracker.shared.track(.referralValidationFailed)
            return nil
        }

        await RevenueCatAttributeService.shared.syncReferralCode(codeInfo.code, type: codeInfo.type)
        Tracker.shared.trackReferralCodeApplied(type: codeInfo.type, source: source.rawValue, code: codeInfo.code)

        switch codeInfo.type {
        case .creator:
            return .creator(codeInfo)
        case .sitter:
            return .sitter(codeInfo)
        }
    }
}
