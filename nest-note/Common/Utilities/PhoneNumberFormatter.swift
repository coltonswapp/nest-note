import Foundation

enum PhoneNumberFormatter {
    
    static func digits(from input: String) -> String {
        String(input.filter(\.isNumber).prefix(10))
    }
    
    static func isValid(_ digits: String) -> Bool {
        (9...10).contains(digits.count)
    }
    
    static func formattedDisplay(for input: String) -> String {
        let limited = digits(from: input)
        var result = ""
        for (index, character) in limited.enumerated() {
            switch index {
            case 0:
                result += "("
            case 3:
                result += ") "
            case 6:
                result += "-"
            default:
                break
            }
            result.append(character)
        }
        return result
    }
    
    static func displayString(for stored: String?) -> String? {
        guard let stored, !stored.isEmpty else { return nil }
        return formattedDisplay(for: stored)
    }
}
