import Foundation

extension Notification.Name {
    static let sitterReferralDeepLinkReceived = Notification.Name("sitterReferralDeepLinkReceived")
}

enum ReferralDeepLinkStore {
    private static let pendingCodeKey = "pending_sitter_referral_code"
    private static let pendingSourceKey = "pending_sitter_referral_source"

    static var pendingCode: String? {
        get {
            UserDefaults.standard.string(forKey: pendingCodeKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
        }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue.uppercased(), forKey: pendingCodeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: pendingCodeKey)
            }
        }
    }

    static var pendingSource: String? {
        get { UserDefaults.standard.string(forKey: pendingSourceKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: pendingSourceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: pendingSourceKey)
            }
        }
    }

    static func store(code: String, source: String = "deep_link") {
        pendingCode = code
        pendingSource = source
        NotificationCenter.default.post(name: .sitterReferralDeepLinkReceived, object: nil)
        Logger.log(level: .info, category: .referral, message: "Stored pending sitter referral code: \(code)")
    }

    static func consumePendingCode() -> (code: String, source: String)? {
        guard let code = pendingCode, !code.isEmpty else { return nil }
        let source = pendingSource ?? "deep_link"
        clear()
        return (code, source)
    }

    static func clear() {
        pendingCode = nil
        pendingSource = nil
    }
}
