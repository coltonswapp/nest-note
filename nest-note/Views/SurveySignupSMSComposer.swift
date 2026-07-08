import UIKit

enum SurveySignupSMSComposer {
    static func welcomeMessage(firstName: String, surveyType: SurveyResponse.SurveyType) -> String {
        let greeting = "hi \(firstName) — my name is Colton from the NestNote app."
        let thanks = "Thanks so much for signing up! If you have any questions I can answer, let me know!"

        guard surveyType == .sitterSurvey else {
            return [greeting, "", thanks].joined(separator: "\n")
        }

        let referral = "Also, I'm giving $10 via Venmo per family you get to sign up to NestNote!! 💰 let me know if you refer someone so I can get you some cash!!"
        return [greeting, "", thanks, "", referral].joined(separator: "\n")
    }

    static func firstName(from fullName: String?) -> String {
        guard let fullName else { return "there" }
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "there" }
        return trimmed.components(separatedBy: .whitespaces).first ?? trimmed
    }

    static func smsURL(phone: String?, body: String) -> URL? {
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.insert(charactersIn: ":/")
        guard let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowedCharacters) else {
            return nil
        }

        if let phoneNumber = sanitizedPhoneNumber(from: phone) {
            return URL(string: "sms:\(phoneNumber)?body=\(encodedBody)")
        }
        return URL(string: "sms:?body=\(encodedBody)")
    }

    @discardableResult
    static func openMessages(phone: String?, body: String) -> Bool {
        guard let url = smsURL(phone: phone, body: body),
              UIApplication.shared.canOpenURL(url) else {
            return false
        }
        UIApplication.shared.open(url)
        HapticsHelper.lightHaptic()
        return true
    }

    private static func sanitizedPhoneNumber(from phone: String?) -> String? {
        guard let phone else { return nil }
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("+") {
            let digits = trimmed.filter { $0.isNumber }
            return digits.isEmpty ? nil : "+\(digits)"
        }

        let digits = trimmed.filter { $0.isNumber }
        guard digits.count >= 10 else { return nil }
        if digits.count == 10 {
            return digits
        }
        if digits.count == 11, digits.first == "1" {
            return "+\(digits)"
        }
        return digits
    }
}
