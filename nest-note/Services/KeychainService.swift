import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    
    private let serviceName = "nestnote.app"
    
    private init() {}
    
    // MARK: - Save Credentials
    func saveCredentials(email: String, password: String) -> Bool {
        // First check if credentials already exist
        if credentialsExist(for: email) {
            // Update existing credentials
            return updateCredentials(email: email, password: password)
        } else {
            // Save new credentials
            return addCredentials(email: email, password: password)
        }
    }
    
    private func addCredentials(email: String, password: String) -> Bool {
        let passwordData = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: serviceName,
            kSecAttrAccount as String: email,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            Logger.log(level: .info, category: .general, message: "Credentials saved to keychain successfully")
            return true
        } else {
            Logger.log(level: .error, category: .general, message: "Failed to save credentials to keychain: \(status)")
            return false
        }
    }
    
    private func updateCredentials(email: String, password: String) -> Bool {
        let passwordData = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: serviceName,
            kSecAttrAccount as String: email
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: passwordData
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status == errSecSuccess {
            Logger.log(level: .info, category: .general, message: "Credentials updated in keychain successfully")
            return true
        } else {
            Logger.log(level: .error, category: .general, message: "Failed to update credentials in keychain: \(status)")
            return false
        }
    }
    
    // MARK: - Retrieve Credentials
    func retrieveCredentials(for email: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: serviceName,
            kSecAttrAccount as String: email,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess,
           let passwordData = item as? Data,
           let password = String(data: passwordData, encoding: .utf8) {
            Logger.log(level: .info, category: .general, message: "Retrieved credentials from keychain successfully")
            return password
        } else {
            Logger.log(level: .info, category: .general, message: "No credentials found in keychain for email: \(email)")
            return nil
        }
    }
    
    func retrieveAllStoredEmails() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: serviceName,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]
        
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        
        if status == errSecSuccess,
           let itemsArray = items as? [[String: Any]] {
            let emails = itemsArray.compactMap { $0[kSecAttrAccount as String] as? String }
            Logger.log(level: .info, category: .general, message: "Retrieved \(emails.count) stored email addresses from keychain")
            return emails
        } else {
            Logger.log(level: .info, category: .general, message: "No stored credentials found in keychain")
            return []
        }
    }
    
    // MARK: - Check Existence
    func credentialsExist(for email: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: serviceName,
            kSecAttrAccount as String: email,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Delete Credentials
    func deleteCredentials(for email: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: serviceName,
            kSecAttrAccount as String: email
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            Logger.log(level: .info, category: .general, message: "Credentials deleted from keychain successfully")
            return true
        } else {
            Logger.log(level: .error, category: .general, message: "Failed to delete credentials from keychain: \(status)")
            return false
        }
    }
    
    func deleteAllCredentials() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            Logger.log(level: .info, category: .general, message: "All credentials deleted from keychain successfully")
            return true
        } else if status == errSecItemNotFound {
            Logger.log(level: .info, category: .general, message: "No credentials found to delete from keychain")
            return true
        } else {
            Logger.log(level: .error, category: .general, message: "Failed to delete all credentials from keychain: \(status)")
            return false
        }
    }
    
    // MARK: - User Preference Management
    func shouldPromptForSaving() -> Bool {
        // Check user preferences for credential saving
        return !UserDefaults.standard.bool(forKey: "disableCredentialSaving")
    }
    
    func setCredentialSavingPreference(_ enabled: Bool) {
        UserDefaults.standard.set(!enabled, forKey: "disableCredentialSaving")
    }
}