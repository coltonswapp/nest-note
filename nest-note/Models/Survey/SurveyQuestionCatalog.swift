import Foundation

enum SurveyQuestionCatalog {
    private static let parentQuestions: [String: String] = {
        guard let config = SurveyConfiguration.loadLocal(named: "parent_survey_config") else { return [:] }
        return Dictionary(uniqueKeysWithValues: config.questions.map { ($0.id, $0.title) })
    }()

    private static let sitterQuestions: [String: String] = {
        guard let config = SurveyConfiguration.loadLocal(named: "sitter_survey_config") else { return [:] }
        return Dictionary(uniqueKeysWithValues: config.questions.map { ($0.id, $0.title) })
    }()

    static func title(for questionId: String, surveyType: SurveyResponse.SurveyType) -> String {
        let catalog = surveyType == .parentSurvey ? parentQuestions : sitterQuestions
        if let title = catalog[questionId] {
            return title
        }
        return questionId.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
