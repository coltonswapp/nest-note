import Foundation

struct SessionItem {
    var id: String = UUID().uuidString
    var title: String
    var sitter: SitterItem?
    var startDate: Date
    var endDate: Date
    var isMultiDay: Bool
    var events: [SessionEvent] = []
    var visibilityLevel: VisibilityLevel = .standard
    
    init(
        title: String = "",
        sitter: SitterItem? = nil,
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(60 * 60 * 2), // 2 hours by default
        isMultiDay: Bool = false,
        visibilityLevel: VisibilityLevel = .standard
    ) {
        self.title = title
        self.sitter = sitter
        self.startDate = startDate
        self.endDate = endDate
        self.isMultiDay = isMultiDay
        self.visibilityLevel = visibilityLevel
    }
}

struct SitterItem: Hashable {
    let id = UUID()
    let name: String
    let email: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
