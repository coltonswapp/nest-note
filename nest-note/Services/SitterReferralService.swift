import Foundation
import FirebaseFirestore

final class SitterReferralService {
    static let shared = SitterReferralService()

    private let db = Firestore.firestore()
    private var cachedCodeByUserId: [String: String] = [:]

    private init() {}

    /// Idempotent — safe to call on every Copy Invite tap.
    func getOrCreateCode(for user: NestUser) async throws -> String {
        if let cached = cachedCodeByUserId[user.id] {
            return cached
        }

        if let existing = user.sitterReferralCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           !existing.isEmpty {
            let code = existing.uppercased()
            cachedCodeByUserId[user.id] = code
            return code
        }

        let code = try await createUniqueCode(for: user)
        cachedCodeByUserId[user.id] = code
        return code
    }

    private func createUniqueCode(for user: NestUser) async throws -> String {
        let displayName = user.personalInfo.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = Self.codePrefix(from: displayName)

        for _ in 0..<8 {
            let suffix = Self.randomSuffix()
            let candidate = "\(prefix)\(suffix)"

            let doc = try await db.collection("valid_referral_codes").document(candidate).getDocument()
            guard !doc.exists else { continue }

            let codeData: [String: Any] = [
                "code": candidate,
                "type": ReferralCodeType.sitter.rawValue,
                "sitterUserId": user.id,
                "creatorName": displayName.isEmpty ? "Sitter" : displayName,
                "creatorEmail": user.personalInfo.email,
                "rewardAmountCents": 1000,
                "createdAt": Timestamp(date: Date()),
                "isActive": true,
            ]

            try await db.collection("valid_referral_codes").document(candidate).setData(codeData)
            try await db.collection("users").document(user.id).updateData([
                "sitterReferralCode": candidate,
            ])

            user.sitterReferralCode = candidate
            Logger.log(level: .info, category: .referral, message: "Created sitter referral code \(candidate) for user \(user.id)")
            return candidate
        }

        throw ReferralError.networkError
    }

    private static func codePrefix(from name: String) -> String {
        let letters = name.uppercased().filter { $0.isLetter }
        let prefix = String(letters.prefix(4))
        return prefix.count >= 2 ? prefix : "SIT"
    }

    private static func randomSuffix() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<3).map { _ in chars.randomElement()! })
    }
}
