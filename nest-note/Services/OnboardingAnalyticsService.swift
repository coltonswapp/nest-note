//
//  OnboardingAnalyticsService.swift
//  nest-note
//
//  Created by Claude Code on 11/25/24.
//

import Foundation
import FirebaseAnalytics

final class OnboardingAnalyticsService {

    static let shared = OnboardingAnalyticsService()

    // MARK: - Properties
    private var sessionData = OnboardingSessionData()

    // MARK: - Session Data Model
    private struct OnboardingSessionData {
        var variant: String = ""
        var startTime: Date = Date()
        var surveyResponses: [SurveyResponse.QuestionResponse] = []
        var discoveryMethod: String = ""
        var hasConverted: Bool = false
        var conversionType: String = ""
        var productId: String = ""
        var currentStep: String = ""
        var stepsCompleted: [String] = []
        var metadata: [String: String] = [:]
    }

    private init() {}

    // MARK: - Session Management

    /// Starts a new onboarding session
    func startSession(variant: String) {
        sessionData = OnboardingSessionData()
        sessionData.variant = variant
        sessionData.startTime = Date()

        // Initialize metadata with onboarding info
        sessionData.metadata = [
            "onboarding_variant": variant,
            "session_type": "parent_onboarding",
            "start_time": ISO8601DateFormatter().string(from: Date())
        ]

        Logger.log(level: .info, category: .general, message: "📊 ONBOARDING: Started session - variant: \(variant)")

        // Track session start
        Analytics.logEvent("parent_onboarding_started", parameters: [
            "onboarding_variant": variant,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }

    /// Records a step completion
    func recordStepCompleted(_ stepId: String) {
        sessionData.currentStep = stepId
        sessionData.stepsCompleted.append(stepId)

        Logger.log(level: .info, category: .general, message: "📊 ONBOARDING: Step completed - \(stepId)")
    }

    /// Records survey response
    func recordSurveyResponse(questionId: String, answers: [String]) {
        let questionResponse = SurveyResponse.QuestionResponse(questionId: questionId, answers: answers)
        sessionData.surveyResponses.append(questionResponse)

        // Update discovery method if this is that question
        if questionId == "discovery_method", let firstAnswer = answers.first {
            sessionData.discoveryMethod = firstAnswer
            sessionData.metadata["discovery_method"] = firstAnswer
        }

        Logger.log(level: .info, category: .general, message: "📊 ONBOARDING: Survey response - \(questionId): \(answers.joined(separator: ", "))")

        // Track individual question responses for detailed analysis
        Analytics.logEvent("parent_onboarding_response", parameters: [
            "onboarding_variant": sessionData.variant,
            "question_id": questionId,
            "answers": answers.joined(separator: ","),
            "answer_count": answers.count
        ])
    }


    /// Records conversion event
    func recordConversion(type: String, productId: String? = nil) {
        sessionData.hasConverted = true
        sessionData.conversionType = type
        sessionData.productId = productId ?? ""

        let duration = Date().timeIntervalSince(sessionData.startTime)

        // Update metadata with conversion info
        sessionData.metadata["converted"] = "true"
        sessionData.metadata["conversion_type"] = type
        sessionData.metadata["conversion_duration_seconds"] = String(Int(duration))
        if let productId = productId {
            sessionData.metadata["product_id"] = productId
        }

        Logger.log(level: .info, category: .general, message: "📊 ONBOARDING: Conversion - \(type) after \(Int(duration))s")

        // Track conversion with full context
        var parameters: [String: Any] = [
            "onboarding_variant": sessionData.variant,
            "conversion_type": type,
            "onboarding_duration_seconds": Int(duration),
            "steps_completed": sessionData.stepsCompleted.count,
            "discovery_method": sessionData.discoveryMethod
        ]

        if let productId = productId {
            parameters["product_id"] = productId
        }

        // Add survey responses to conversion event
        for response in sessionData.surveyResponses {
            switch response.questionId {
            case "top_priority":
                parameters["top_priority"] = response.answers.first ?? ""
            case "communication_methods":
                parameters["communication_methods"] = response.answers.joined(separator: ",")
            case "care_responsibilities":
                parameters["care_responsibilities"] = response.answers.joined(separator: ",")
            default:
                break
            }
        }

        Analytics.logEvent("parent_onboarding_conversion", parameters: parameters)
    }

    /// Records session completion (whether converted or not)
    func completeSession() {
        let duration = Date().timeIntervalSince(sessionData.startTime)

        // Update final metadata
        sessionData.metadata["completed"] = "true"
        sessionData.metadata["final_step"] = sessionData.currentStep
        sessionData.metadata["total_duration_seconds"] = String(Int(duration))
        sessionData.metadata["steps_completed"] = String(sessionData.stepsCompleted.count)

        if !sessionData.hasConverted {
            sessionData.metadata["converted"] = "false"
        }

        Logger.log(level: .info, category: .general, message: "📊 ONBOARDING: Session completed - converted: \(sessionData.hasConverted), duration: \(Int(duration))s")

        // Save to existing survey system
        saveSurveyResponse()

        // Track completion with full session summary
        var parameters: [String: Any] = [
            "onboarding_variant": sessionData.variant,
            "converted": sessionData.hasConverted,
            "conversion_type": sessionData.conversionType,
            "onboarding_duration_seconds": Int(duration),
            "steps_completed": sessionData.stepsCompleted.count,
            "discovery_method": sessionData.discoveryMethod,
            "final_step": sessionData.currentStep
        ]

        // Add key survey insights
        for response in sessionData.surveyResponses {
            switch response.questionId {
            case "top_priority":
                parameters["top_priority"] = response.answers.first ?? ""
            case "discovery_method":
                parameters["discovery_source"] = response.answers.first ?? ""
            default:
                break
            }
        }

        Analytics.logEvent("parent_onboarding_completed", parameters: parameters)
    }

    /// Saves onboarding session as SurveyResponse for viewing in existing UI
    private func saveSurveyResponse() {
        let surveyResponse = SurveyResponse(
            id: UUID().uuidString,
            timestamp: sessionData.startTime,
            surveyType: .parentSurvey, // Integrates with existing parent survey system
            version: "onboarding_\(sessionData.variant)",
            responses: sessionData.surveyResponses,
            metadata: sessionData.metadata
        )

        Task {
            do {
                try await SurveyService.shared.submitSurveyResponse(surveyResponse)
                Logger.log(level: .info, category: .survey, message: "📊 SURVEY: Saved onboarding session as parent survey response - variant: \(sessionData.variant)")
            } catch {
                Logger.log(level: .error, category: .survey, message: "📊 SURVEY: Failed to save onboarding response - \(error.localizedDescription)")
            }
        }
    }

    /// Records drop-off (user exits before completion)
    func recordDropOff(reason: String = "unknown") {
        let duration = Date().timeIntervalSince(sessionData.startTime)

        // Update metadata with drop-off info
        sessionData.metadata["completed"] = "false"
        sessionData.metadata["drop_off_reason"] = reason
        sessionData.metadata["drop_off_step"] = sessionData.currentStep
        sessionData.metadata["total_duration_seconds"] = String(Int(duration))

        Logger.log(level: .info, category: .general, message: "📊 ONBOARDING: Drop-off - step: \(sessionData.currentStep), reason: \(reason)")

        // Save partial session to survey system
        saveSurveyResponse()

        Analytics.logEvent("parent_onboarding_dropoff", parameters: [
            "onboarding_variant": sessionData.variant,
            "last_step": sessionData.currentStep,
            "steps_completed": sessionData.stepsCompleted.count,
            "duration_seconds": Int(duration),
            "drop_reason": reason,
            "discovery_method": sessionData.discoveryMethod
        ])
    }

    // MARK: - Quick Access Methods

    /// Gets current variant for other components to use
    var currentVariant: String {
        return sessionData.variant
    }

    /// Gets formatted session summary for debugging
    var sessionSummary: String {
        return """
        Variant: \(sessionData.variant)
        Steps: \(sessionData.stepsCompleted.count)
        Responses: \(sessionData.surveyResponses.count)
        Discovery: \(sessionData.discoveryMethod)
        Converted: \(sessionData.hasConverted)
        Duration: \(Int(Date().timeIntervalSince(sessionData.startTime)))s
        """
    }
}