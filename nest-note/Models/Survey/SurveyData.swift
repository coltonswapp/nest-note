import Foundation
import FirebaseFirestore

// MARK: - Survey Response
struct SurveyResponse: Codable {
    let id: String
    let timestamp: Date
    let surveyType: SurveyType
    let version: String
    let responses: [QuestionResponse]
    let metadata: [String: String]
    
    struct QuestionResponse: Codable {
        let questionId: String
        let answers: [String]
    }
    
    enum SurveyType: String, Codable, CaseIterable {
        case parentSurvey = "parent_survey"
        case sitterSurvey = "sitter_survey"
    }
    
    var asDictionary: [String: Any] {
        return [
            "id": id,
            "timestamp": Timestamp(date: timestamp),
            "surveyType": surveyType.rawValue,
            "version": version,
            "responses": responses.map { [
                "questionId": $0.questionId,
                "answers": $0.answers
            ] },
            "metadata": metadata
        ]
    }
}

// MARK: - Feature Vote
struct FeatureVote: Codable {
    let id: String
    let timestamp: Date
    let featureId: String
    let vote: VoteType
    let userId: String
    let comments: String?
    
    enum VoteType: String, Codable {
        case forFeature = "for"
        case againstFeature = "against"
    }
    
    var asDictionary: [String: Any] {
        return [
            "id": id,
            "timestamp": Timestamp(date: timestamp),
            "featureId": featureId,
            "vote": vote.rawValue,
            "userId": userId,
            "comments": comments as Any
        ]
    }
}

// MARK: - Survey Metrics
struct SurveyMetrics: Codable, Equatable, Hashable {
    let totalResponses: Int
    let lastUpdated: Date
    let questionMetrics: [String: QuestionMetric]
    
    struct QuestionMetric: Codable, Equatable, Hashable {
        let totalResponses: Int
        let answerDistribution: [String: Int]
        let percentages: [String: Double]
        
        var asDictionary: [String: Any] {
            return [
                "totalResponses": totalResponses,
                "answerDistribution": answerDistribution,
                "percentages": percentages
            ]
        }
    }
    
    var asDictionary: [String: Any] {
        return [
            "totalResponses": totalResponses,
            "lastUpdated": Timestamp(date: lastUpdated),
            "questionMetrics": questionMetrics.mapValues { $0.asDictionary }
        ]
    }
}

// MARK: - Feature Metrics
struct FeatureMetrics: Codable, Equatable, Hashable {
    let votesFor: Int
    let votesAgainst: Int
    let votePercentage: Double
    let lastUpdated: Date
    
    var asDictionary: [String: Any] {
        return [
            "votes_for": votesFor,
            "votes_against": votesAgainst,
            "vote_percentage": votePercentage,
            "lastUpdated": Timestamp(date: lastUpdated)
        ]
    }
} 
