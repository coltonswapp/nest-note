import Foundation
import FirebaseFirestore

final class ReferralConversionService {
    static let shared = ReferralConversionService()

    private let db = Firestore.firestore()
    private let collection = "referral_conversions"

    private init() {}

    func fetchConversions(status: ReferralConversionStatus) async throws -> [ReferralConversion] {
        let snapshot = try await db.collection(collection)
            .whereField("status", isEqualTo: status.rawValue)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            try? document.data(as: ReferralConversion.self)
        }
        .sorted { $0.purchaseDate > $1.purchaseDate }
    }

    func markAsPaid(conversionId: String, notes: String?) async throws {
        var updates: [String: Any] = [
            "status": ReferralConversionStatus.paid.rawValue,
            "paidAt": Timestamp(date: Date()),
        ]
        if let notes, !notes.isEmpty {
            updates["payoutNotes"] = notes
        }
        try await db.collection(collection).document(conversionId).updateData(updates)
    }

    func exportCSV(conversions: [ReferralConversion]) -> String {
        var lines = ["sitterName,sitterEmail,sitterVenmo,referredEmail,plan,date,amount,referralCode"]
        let formatter = ISO8601DateFormatter()
        for conversion in conversions {
            let venmo = conversion.sitterVenmo ?? ""
            let date = formatter.string(from: conversion.purchaseDate)
            let row = [
                csvEscape(conversion.sitterName),
                csvEscape(conversion.sitterEmail),
                csvEscape(venmo),
                csvEscape(conversion.referredUserEmail),
                csvEscape(conversion.packageType),
                csvEscape(date),
                csvEscape(conversion.rewardAmountDollars),
                csvEscape(conversion.referralCode),
            ].joined(separator: ",")
            lines.append(row)
        }
        return lines.joined(separator: "\n")
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
