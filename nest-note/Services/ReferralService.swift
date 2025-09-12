import Foundation
import FirebaseFirestore

final class ReferralService {
    
    // MARK: - Properties
    static let shared = ReferralService()
    private let db = Firestore.firestore()
    
    // Collections
    private let referralsCollection = "referrals"
    private let referralSummariesCollection = "referral_summaries"
    
    private init() {}
    
    // MARK: - Referral Code Validation
    /// Validates a referral code format and checks if it exists in the database
    /// - Parameter referralCode: The referral code entered by user
    /// - Returns: The clean referral code if valid and exists, nil otherwise
    func validateReferralCode(_ referralCode: String) async throws -> String? {
        let cleanCode = referralCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Basic validation - referral codes should be at least 2 characters
        guard cleanCode.count >= 2 && cleanCode.count <= 20 else {
            return nil
        }
        
        // Check if the code exists in the valid codes collection
        let validCodeDoc = try await db.collection("valid_referral_codes").document(cleanCode).getDocument()
        
        guard validCodeDoc.exists else {
            return nil
        }
        
        return cleanCode
    }
    
    /// Quick format validation without database lookup (for UI feedback)
    /// - Parameter referralCode: The referral code entered by user
    /// - Returns: The clean referral code if format is valid, nil otherwise
    func validateReferralCodeFormat(_ referralCode: String) -> String? {
        let cleanCode = referralCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Basic validation - referral codes should be at least 2 characters
        guard cleanCode.count >= 2 && cleanCode.count <= 20 else {
            return nil
        }
        
        // Only allow letters and numbers
        guard cleanCode.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            return nil
        }
        
        return cleanCode
    }
    
    // MARK: - Referral Attribution
    /// Records a referral for a new user signup
    /// - Parameters:
    ///   - referralCode: The referral code entered by the user
    ///   - userId: The Firebase user ID of the new user
    ///   - userEmail: The email of the new user
    ///   - userRole: The role selected by the user ("nester" or "sitter")
    /// - Throws: Error if the referral cannot be recorded
    func recordReferral(referralCode: String, for userId: String, email: String, role: String) async throws {
        guard let validReferralCode = try await validateReferralCode(referralCode) else {
            throw ReferralError.invalidCode
        }
        
        // Create referral record
        let referral = Referral(
            referralCode: validReferralCode,
            referredUserId: userId,
            referredUserEmail: email,
            userRole: role
        )
        
        // Save to Firestore
        try await saveReferral(referral)
        
        // Update referral summary
        try await updateReferralSummary(for: validReferralCode)
        
        // Track analytics
        trackReferralEvent(referral)
        
        Logger.log(level: .info, category: .referral, message: "Recorded referral for code: \(validReferralCode), user: \(userId)")
    }
    
    // MARK: - Private Methods
    private func saveReferral(_ referral: Referral) async throws {
        let referralData = try Firestore.Encoder().encode(referral)
        try await db.collection(referralsCollection).document(referral.id).setData(referralData)
    }
    
    private func updateReferralSummary(for referralCode: String) async throws {
        let summaryRef = db.collection(referralSummariesCollection).document(referralCode)
        
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let summarySnapshot: DocumentSnapshot
            do {
                summarySnapshot = try transaction.getDocument(summaryRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            var summary: ReferralSummary
            if summarySnapshot.exists {
                do {
                    summary = try summarySnapshot.data(as: ReferralSummary.self)
                } catch {
                    summary = ReferralSummary(referralCode: referralCode)
                }
            } else {
                summary = ReferralSummary(referralCode: referralCode)
            }
            
            // Update totals
            let currentMonth = self.currentMonthKey()
            let newTotalReferrals = summary.totalReferrals + 1
            var newMonthlyReferrals = summary.monthlyReferrals
            newMonthlyReferrals[currentMonth] = (newMonthlyReferrals[currentMonth] ?? 0) + 1
            
            let updatedSummary = ReferralSummary(
                referralCode: summary.referralCode,
                totalReferrals: newTotalReferrals,
                monthlyReferrals: newMonthlyReferrals,
                lastUpdated: Date()
            )
            
            do {
                let summaryData = try Firestore.Encoder().encode(updatedSummary)
                transaction.setData(summaryData, forDocument: summaryRef)
            } catch let encodeError as NSError {
                errorPointer?.pointee = encodeError
                return nil
            }
            
            return nil
        }
    }
    
    private func trackReferralEvent(_ referral: Referral) {
        Tracker.shared.track(.referralRecorded)
        Logger.log(level: .info, category: .referral, message: "Tracked referral event for code: \(referral.referralCode)")
    }
    
    private func currentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    // MARK: - Analytics & Reporting
    /// Gets referral summary for a specific referral code
    /// - Parameter referralCode: The referral code to get summary for
    /// - Returns: ReferralSummary if found, nil otherwise
    func getReferralSummary(for referralCode: String) async throws -> ReferralSummary? {
        let document = try await db.collection(referralSummariesCollection).document(referralCode).getDocument()
        
        guard document.exists else { return nil }
        return try document.data(as: ReferralSummary.self)
    }
    
    /// Gets all referrals for a specific referral code
    /// - Parameter referralCode: The referral code
    /// - Returns: Array of referrals
    func getReferrals(for referralCode: String, limit: Int = 100) async throws -> [Referral] {
        let query = db.collection(referralsCollection)
            .whereField("referralCode", isEqualTo: referralCode)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { document in
            try document.data(as: Referral.self)
        }
    }
    
    /// Gets referral counts for a specific month
    /// - Parameters:
    ///   - referralCode: The referral code
    ///   - month: Month in "YYYY-MM" format
    /// - Returns: Number of referrals for that month
    func getReferralCount(for referralCode: String, month: String) async throws -> Int {
        let summary = try await getReferralSummary(for: referralCode)
        return summary?.monthlyReferrals[month] ?? 0
    }
    
    /// Gets top referral creators (for admin purposes)
    /// - Parameter limit: Maximum number of creators to return
    /// - Returns: Array of referral summaries sorted by total referrals
    func getTopCreators(limit: Int = 10) async throws -> [ReferralSummary] {
        let query = db.collection(referralSummariesCollection)
            .order(by: "totalReferrals", descending: true)
            .limit(to: limit)
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { document in
            try document.data(as: ReferralSummary.self)
        }
    }
    
    // MARK: - Admin Functions
    /// Creates a new referral code (admin only)
    /// - Parameters:
    ///   - code: The referral code to create (e.g., "HEIDI", "SYDNEY")
    ///   - creatorName: The name of the creator this code belongs to
    ///   - creatorEmail: Optional email of the creator
    ///   - notes: Optional notes about this referral code
    /// - Throws: Error if the code cannot be created
    func createReferralCode(_ code: String, creatorName: String, creatorEmail: String? = nil, notes: String? = nil) async throws {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Basic validation
        guard cleanCode.count >= 2 && cleanCode.count <= 20 else {
            throw ReferralError.invalidCode
        }
        
        guard cleanCode.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            throw ReferralError.invalidCode
        }
        
        // Check if code already exists
        let existingDoc = try await db.collection("valid_referral_codes").document(cleanCode).getDocument()
        if existingDoc.exists {
            throw ReferralError.codeAlreadyExists
        }
        
        // Create the referral code document
        let referralCodeData: [String: Any] = [
            "code": cleanCode,
            "creatorName": creatorName,
            "creatorEmail": creatorEmail ?? "",
            "notes": notes ?? "",
            "createdAt": Timestamp(date: Date()),
            "isActive": true
        ]
        
        try await db.collection("valid_referral_codes").document(cleanCode).setData(referralCodeData)
        
        Logger.log(level: .info, category: .referral, message: "Created referral code: \(cleanCode) for creator: \(creatorName)")
    }
    
    /// Deactivates a referral code (admin only)
    /// - Parameter code: The referral code to deactivate
    /// - Throws: Error if the code cannot be deactivated
    func deactivateReferralCode(_ code: String) async throws {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        try await db.collection("valid_referral_codes").document(cleanCode).updateData([
            "isActive": false,
            "deactivatedAt": Timestamp(date: Date())
        ])
        
        Logger.log(level: .info, category: .referral, message: "Deactivated referral code: \(cleanCode)")
    }
    
    /// Gets all valid referral codes (admin only)
    /// - Returns: Array of referral code documents
    func getAllReferralCodes() async throws -> [(code: String, creatorName: String, creatorEmail: String, isActive: Bool, createdAt: Date)] {
        let snapshot = try await db.collection("valid_referral_codes").getDocuments()
        
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let code = data["code"] as? String,
                  let creatorName = data["creatorName"] as? String,
                  let creatorEmail = data["creatorEmail"] as? String,
                  let isActive = data["isActive"] as? Bool,
                  let createdAtTimestamp = data["createdAt"] as? Timestamp else {
                return nil
            }
            
            return (
                code: code,
                creatorName: creatorName,
                creatorEmail: creatorEmail,
                isActive: isActive,
                createdAt: createdAtTimestamp.dateValue()
            )
        }
    }
}

// MARK: - Error Types
enum ReferralError: LocalizedError {
    case invalidCode
    case duplicateReferral
    case networkError
    case codeAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Invalid referral code format or code does not exist"
        case .duplicateReferral:
            return "Referral already recorded for this user"
        case .networkError:
            return "Network error while processing referral"
        case .codeAlreadyExists:
            return "Referral code already exists"
        }
    }
}
