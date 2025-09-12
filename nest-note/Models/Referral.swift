import Foundation

struct Referral: Codable {
    let id: String
    let referralCode: String  // This directly identifies the creator
    let referredUserId: String
    let referredUserEmail: String
    let timestamp: Date
    let userRole: String     // "nester" or "sitter"
    let isValid: Bool        // Whether the referral was successfully processed
    
    init(referralCode: String, referredUserId: String, referredUserEmail: String, userRole: String, isValid: Bool = true) {
        self.id = UUID().uuidString
        self.referralCode = referralCode
        self.referredUserId = referredUserId
        self.referredUserEmail = referredUserEmail
        self.timestamp = Date()
        self.userRole = userRole
        self.isValid = isValid
    }
}

struct ReferralSummary: Codable {
    let referralCode: String  // The creator's referral code
    let totalReferrals: Int
    let monthlyReferrals: [String: Int]  // "YYYY-MM": count
    let lastUpdated: Date
    
    init(referralCode: String) {
        self.referralCode = referralCode
        self.totalReferrals = 0
        self.monthlyReferrals = [:]
        self.lastUpdated = Date()
    }
    
    init(referralCode: String, totalReferrals: Int, monthlyReferrals: [String: Int], lastUpdated: Date) {
        self.referralCode = referralCode
        self.totalReferrals = totalReferrals
        self.monthlyReferrals = monthlyReferrals
        self.lastUpdated = lastUpdated
    }
}

// Extension for date formatting
extension Referral {
    var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: timestamp)
    }
    
    var yearKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: timestamp)
    }
}