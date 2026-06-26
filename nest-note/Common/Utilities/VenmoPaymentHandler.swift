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
    
    static func payWithVenmo(username: String, note: String) {
        let encodedNote = note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? note
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        
        guard let venmoURL = URL(string: "venmo://paycharge?txn=pay&recipients=\(encodedUsername)&note=\(encodedNote)"),
              let webURL = URL(string: "https://account.venmo.com/pay?recipients=\(encodedUsername)&note=\(encodedNote)") else {
            return
        }
        
        if UIApplication.shared.canOpenURL(venmoURL) {
            UIApplication.shared.open(venmoURL)
        } else {
            UIApplication.shared.open(webURL)
        }
    }
}
