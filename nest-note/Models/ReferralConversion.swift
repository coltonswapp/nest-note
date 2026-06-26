import Foundation
import FirebaseFirestore
import FirebaseFirestore

enum ReferralConversionStatus: String, Codable {
    case pendingPayout = "pending_payout"
    case paid
    case clawedBack = "clawed_back"
}

struct ReferralConversion: Codable, Identifiable {
    @DocumentID var documentID: String?
    let referralCode: String
    let referralCodeType: String
    let sitterUserId: String
    let sitterName: String
    let sitterEmail: String
    let sitterVenmo: String?
    let referredUserId: String
    let referredUserEmail: String
    let productId: String
    let packageType: String
    let purchaseDate: Date
    let revenueUsd: Double
    let rewardAmountCents: Int
    let status: ReferralConversionStatus
    let rcTransactionId: String
    let payoutBlockedReason: String?
    let paidAt: Date?
    let payoutNotes: String?

    var id: String { documentID ?? rcTransactionId }

    var rewardAmountDollars: String {
        String(format: "$%.0f", Double(rewardAmountCents) / 100.0)
    }

    var hasVenmoOnFile: Bool {
        guard let venmo = sitterVenmo?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !venmo.isEmpty
    }
}
