import Foundation

struct NestCategory: Codable, Hashable {
    let id: String
    var name: String
    var symbolName: String
    var isDefault: Bool
    var isPinned: Bool
    
    init(
        id: String = UUID().uuidString,
        name: String,
        symbolName: String,
        isDefault: Bool = false,
        isPinned: Bool = false
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.isDefault = isDefault
        self.isPinned = isPinned
    }
} 