import Foundation

enum PhoneNumberExtractor {

    /// Detects phone numbers in freeform text via `NSDataDetector`.
    static func phoneNumbers(in text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue) else {
            return []
        }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        var results: [String] = []
        var seenDialKeys = Set<String>()

        detector.enumerateMatches(in: trimmed, options: [], range: range) { match, _, _ in
            guard let match else { return }
            let display: String
            if let phone = match.phoneNumber {
                display = phone
            } else if let matchRange = Range(match.range, in: trimmed) {
                display = String(trimmed[matchRange])
            } else {
                return
            }

            let dialKey = dialString(from: display)
            guard !dialKey.isEmpty, !seenDialKeys.contains(dialKey) else { return }
            seenDialKeys.insert(dialKey)
            results.append(display.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return results
    }

    /// Keeps leading `+` and digits for `tel:` URLs.
    static func dialString(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let hasPlus = trimmed.first == "+"
        let digits = trimmed.filter(\.isNumber)
        if hasPlus, !digits.isEmpty {
            return "+" + digits
        }
        return digits
    }
}
