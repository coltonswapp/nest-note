import Foundation

struct SurveyQuestion: Codable {
    enum Layout: String, Codable {
        case list
        case grid
    }

    let id: String
    let title: String
    let subtitle: String?
    let options: [String]
    let optionSubtitles: [String]?
    let isMultiSelect: Bool
    /// `grid` renders options in a 2-column layout; defaults to single-column `list`.
    let layout: Layout?

    // Optional metadata that might be useful
    let category: String?
    let order: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case options
        case optionSubtitles = "option_subtitles"
        case isMultiSelect = "multi_select"
        case layout
        case category
        case order
    }

    var columnCount: Int {
        layout == .grid ? 2 : 1
    }

    // Filter out DEBUG options in release builds
    var filteredOptions: [String] {
        #if DEBUG
        return options
        #else
        return options.filter { !$0.hasPrefix("DEBUG") }
        #endif
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