import UIKit

enum VenmoPaymentHandler {
    
    /// Normalizes a Venmo username for storage (strips `@`, trims, lowercases). Returns nil if empty or invalid.
    static func normalizeUsername(_ input: String) -> String? {
        var username = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if username.hasPrefix("@") {
            username = String(username.dropFirst())
        }
        username = username.lowercased()
        guard !username.isEmpty, isValidUsername(username) else { return nil }
        return username
    }
    
    static func isValidUsername(_ username: String) -> Bool {
        guard (5...30).contains(username.count) else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return username.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
    
    /// Returns true when the field is empty (skip) or contains a valid username.
    static func isValidInput(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return normalizeUsername(trimmed) != nil
    }
    
    static func displayUsername(_ username: String?) -> String {
        guard let username, !username.isEmpty else { return "Not set" }
        return "@\(username)"
    }
    
    /// Adds an `@` prefix inside the text field so users enter username without the symbol.
    static func applyUsernamePrefix(to textField: UITextField) {
        let prefixWidth: CGFloat = 24
        let fieldHeight: CGFloat = 44
        
        let container = UIView(frame: CGRect(x: 0, y: 0, width: prefixWidth, height: fieldHeight))
        container.isUserInteractionEnabled = false
        
        let label = UILabel(frame: CGRect(x: 6, y: 0, width: prefixWidth - 6, height: fieldHeight))
        label.text = "@"
        label.font = textField.font ?? .bodyL
        label.textColor = .secondaryLabel
        label.textAlignment = .left
        container.addSubview(label)
        
        textField.leftView = container
        textField.leftViewMode = .always
    }
    
    static func payWithVenmo(username: String, note: String, amountCents: Int? = nil) {
        let cleanUsername = username.hasPrefix("@") ? String(username.dropFirst()) : username
        var queryItems = [
            URLQueryItem(name: "txn", value: "pay"),
            URLQueryItem(name: "recipients", value: cleanUsername),
            URLQueryItem(name: "note", value: note)
        ]

        if let amountCents {
            let amount = String(format: "%.2f", Double(amountCents) / 100.0)
            queryItems.append(URLQueryItem(name: "amount", value: amount))
        }

        var venmoComponents = URLComponents(string: "venmo://paycharge")
        venmoComponents?.queryItems = queryItems

        var webComponents = URLComponents(string: "https://account.venmo.com/pay")
        webComponents?.queryItems = queryItems

        guard let venmoURL = venmoComponents?.url,
              let webURL = webComponents?.url else {
            return
        }

        if UIApplication.shared.canOpenURL(venmoURL) {
            UIApplication.shared.open(venmoURL)
        } else {
            UIApplication.shared.open(webURL)
        }
    }
}
