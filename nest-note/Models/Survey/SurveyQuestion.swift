import Foundation

struct SurveyQuestion: Codable {
    let id: String
    let title: String
    let subtitle: String?
    let options: [String]
    let isMultiSelect: Bool
    
    // Optional metadata that might be useful
    let category: String?
    let order: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case options
        case isMultiSelect = "multi_select"
        case category
        case order
    }
}

struct SurveyConfiguration: Codable {
    let questions: [SurveyQuestion]
    let version: String
    
    static func loadLocal(named filename: String = "survey_config") -> SurveyConfiguration? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        return try? JSONDecoder().decode(SurveyConfiguration.self, from: data)
    }
} 