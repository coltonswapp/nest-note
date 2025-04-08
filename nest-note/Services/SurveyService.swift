import Foundation
import FirebaseFirestore
import Combine

final class SurveyService {
    // MARK: - Feature Definitions
    enum Feature: String, CaseIterable {
        case nestMembers = "nest_members"
        case multipleNests = "multiple_nests"
        case permanentAccess = "permanent_access"
        case routines = "routines"
        case activitySuggestions = "activity_suggestions"
        case contacts = "contacts"
        case expenses = "expenses"
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .nestMembers:
                return "Nest Members"
            case .multipleNests:
                return "Multiple Nests"
            case .permanentAccess:
                return "Permanent Access"
            case .routines:
                return "Routines"
            case .activitySuggestions:
                return "Activity Suggestions"
            case .contacts:
                return "Contacts"
            case .expenses:
                return "Expenses"
            }
        }
            
        var description: String {
            switch self {
            case .nestMembers:
                return "Nest Co-Owner functionality enables primary owners to add additional owners (like spouses or partners) with full administrative access and control over the nest's information and settings."
            case .multipleNests:
                return "Multi-Nest Support allows users to create and manage separate Nests for different properties or locations under a single account."
            case .permanentAccess:
                return "Permanent Access would provide permanent nest permissions to frequent caregivers like nannies or grandparents, eliminating the need to create individual sessions for regularly scheduled childcare."
            case .routines:
                return "Customizable Routines allow nest owners to create detailed, time-specific schedules for children's activities, pet care, and household tasks that guide caregivers through important daily processes step by step."
            case .activitySuggestions:
                return "Curated age-appropriate activities for caregivers to engage children based on their interests and developmental stage."
            case .contacts:
                return "A centralized Contacts management system for each Nest that stores neighborhood, family, and other important contact details readily accessible to caregivers during sessions."
            case .expenses:
                return "Log and manage expenses incurred during childcare sessions with receipt uploads and reimbursement calculations."
            }
        }
            
        var iconName: String {
            switch self {
            case .nestMembers:
                return "person.3.fill"
            case .multipleNests:
                return "house.fill"
            case .permanentAccess:
                return "person.badge.key.fill"
            case .routines:
                return "clock.fill"
            case .activitySuggestions:
                return "lightbulb.fill"
            case .contacts:
                return "person.2.fill"
            case .expenses:
                return "dollarsign.square.fill"
            }
        }
    }
    
    // MARK: - Properties
    static let shared = SurveyService()
    private let db = Firestore.firestore()
    private let defaults = UserDefaults.standard
    
    private let votedFeaturesKey = "votedFeatures"
    
    // MARK: - Survey Response Methods
    func submitSurveyResponse(_ response: SurveyResponse) async throws {
        let docRef = db.collection("surveyData").document("surveyResponses").collection("responses").document(response.id)
        try await docRef.setData(response.asDictionary)
    }
    
    func getSurveyResponses(type: SurveyResponse.SurveyType, version: String? = nil) async throws -> [SurveyResponse] {
        var query = db.collection("surveyData").document("surveyResponses").collection("responses")
            .whereField("surveyType", isEqualTo: type.rawValue)
        
        if let version = version {
            query = query.whereField("version", isEqualTo: version)
        }
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { document -> SurveyResponse? in
            guard let timestamp = document.data()["timestamp"] as? Timestamp,
                  let surveyType = document.data()["surveyType"] as? String,
                  let version = document.data()["version"] as? String,
                  let responses = document.data()["responses"] as? [[String: Any]],
                  let metadata = document.data()["metadata"] as? [String: String] else {
                return nil
            }
            
            let questionResponses = responses.compactMap { response -> SurveyResponse.QuestionResponse? in
                guard let questionId = response["questionId"] as? String,
                      let answers = response["answers"] as? [String] else {
                    return nil
                }
                return SurveyResponse.QuestionResponse(questionId: questionId, answers: answers)
            }
            
            return SurveyResponse(
                id: document.documentID,
                timestamp: timestamp.dateValue(),
                surveyType: SurveyResponse.SurveyType(rawValue: surveyType) ?? type,
                version: version,
                responses: questionResponses,
                metadata: metadata
            )
        }
    }
    
    // MARK: - Feature Vote Methods
    func hasVotedForFeature(_ featureId: String) -> Bool {
        let votedFeatures = defaults.stringArray(forKey: votedFeaturesKey) ?? []
        return votedFeatures.contains(featureId)
    }
    
    func submitFeatureVote(_ vote: FeatureVote) async throws {
        // Check if user has already voted
        guard !hasVotedForFeature(vote.featureId) else {
            throw SurveyError.alreadyVoted
        }
        
        // Submit vote to Firebase
        let docRef = db.collection("surveyData").document("featureVotes").collection("votes").document(vote.id)
        try await docRef.setData(vote.asDictionary)
        
        // Mark feature as voted in UserDefaults
        var votedFeatures = defaults.stringArray(forKey: votedFeaturesKey) ?? []
        votedFeatures.append(vote.featureId)
        defaults.set(votedFeatures, forKey: votedFeaturesKey)
    }
    
//    func getFeatureVotes(featureId: String? = nil) async throws -> [FeatureVote] {
//        var query = db.collection("surveyData").document("featureVotes").collection("votes")
//        
//        if let featureId = featureId {
//            query = query.whereField("featureId", isEqualTo: featureId)
//        }
//        
//        let snapshot = try await query.getDocuments()
//        return snapshot.documents.compactMap { document -> FeatureVote? in
//            guard let timestamp = document.data()["timestamp"] as? Timestamp,
//                  let featureId = document.data()["featureId"] as? String,
//                  let voteType = document.data()["vote"] as? String,
//                  let userId = document.data()["userId"] as? String else {
//                return nil
//            }
//            
//            return FeatureVote(
//                id: document.documentID,
//                timestamp: timestamp.dateValue(),
//                featureId: featureId,
//                vote: FeatureVote.VoteType(rawValue: voteType) ?? .forFeature,
//                userId: userId,
//                comments: document.data()["comments"] as? String
//            )
//        }
//    }
    
    // MARK: - Metrics Methods
    func getSurveyMetrics(type: SurveyResponse.SurveyType) async throws -> SurveyMetrics {
        let docRef = db.collection("surveyData")
            .document("surveyResponses")
            .collection("metrics")
            .document(type.rawValue)
        
        let document = try await docRef.getDocument()
        
        guard let data = document.data(),
              let totalResponses = data["totalResponses"] as? Int,
              let lastUpdated = (data["lastUpdated"] as? Timestamp)?.dateValue(),
              let questionMetrics = data["questionMetrics"] as? [String: [String: Any]] else {
            throw SurveyError.invalidData
        }
        
        let metrics = questionMetrics.compactMapValues { metric -> SurveyMetrics.QuestionMetric? in
            guard let totalResponses = metric["totalResponses"] as? Int,
                  let answerDistribution = metric["answerDistribution"] as? [String: Int],
                  let percentages = metric["percentages"] as? [String: Double] else {
                return nil
            }
            
            return SurveyMetrics.QuestionMetric(
                totalResponses: totalResponses,
                answerDistribution: answerDistribution,
                percentages: percentages
            )
        }
        
        return SurveyMetrics(
            totalResponses: totalResponses,
            lastUpdated: lastUpdated,
            questionMetrics: metrics
        )
    }
    
    func getFeatureMetrics(featureId: String) async throws -> FeatureMetrics {
        let docRef = db.collection("surveyData")
            .document("featureVotes")
            .collection("metrics")
            .document(featureId)
            
        let document = try await docRef.getDocument()
        
        guard let data = document.data(),
              let votesFor = data["votesFor"] as? Int,
              let votesAgainst = data["votesAgainst"] as? Int,
              let votePercentage = data["votePercentage"] as? Double,
              let lastUpdated = (data["lastUpdated"] as? Timestamp)?.dateValue() else {
            throw SurveyError.invalidData
        }
        
        return FeatureMetrics(
            votesFor: votesFor,
            votesAgainst: votesAgainst,
            votePercentage: votePercentage,
            lastUpdated: lastUpdated
        )
    }
}

// MARK: - Errors
extension SurveyService {
    enum SurveyError: LocalizedError {
        case alreadyVoted
        case invalidData
        
        var errorDescription: String? {
            switch self {
            case .alreadyVoted:
                return "You have already voted for this feature"
            case .invalidData:
                return "Invalid data received from server"
            }
        }
    }
} 
