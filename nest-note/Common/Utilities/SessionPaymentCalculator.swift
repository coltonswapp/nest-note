import Foundation
import UIKit

enum SessionPaymentCalculationMode: String, CaseIterable {
    case hourly = "Hourly"
    case flat = "Flat Rate"
}

struct SessionPaymentDraft {
    var mode: SessionPaymentCalculationMode = .hourly
    var hours: Double
    var hourlyRateCents: Int = 0
    var numberOfKids: Int = 1
    var extraPerAdditionalKidHourlyCents: Int = 0
    var additionalFlatFeeCents: Int = 0
    var flatRateCents: Int = 0

    var totalCents: Int {
        switch mode {
        case .hourly:
            let base = hours * Double(hourlyRateCents)
            let extraKids = max(0, numberOfKids - 1)
            let kidSurcharge = hours * Double(extraKids) * Double(extraPerAdditionalKidHourlyCents)
            let total = base + kidSurcharge + Double(additionalFlatFeeCents)
            return max(0, Int(total.rounded()))
        case .flat:
            return max(0, flatRateCents)
        }
    }

    var equationText: String {
        switch mode {
        case .hourly:
            return SessionPaymentCalculator.hourlyEquationText(
                hours: hours,
                hourlyRateCents: hourlyRateCents,
                numberOfKids: numberOfKids,
                extraPerAdditionalKidHourlyCents: extraPerAdditionalKidHourlyCents,
                additionalFlatFeeCents: additionalFlatFeeCents,
                totalCents: totalCents
            )
        case .flat:
            let total = SessionPaymentCalculator.formatDollars(fromCents: totalCents, includeCentsIfWhole: false)
            return "Flat rate = \(total)"
        }
    }

    static func prefilled(hours: Double, hourlyRateCents: Int?) -> SessionPaymentDraft {
        var draft = SessionPaymentDraft(hours: hours)
        draft.hourlyRateCents = SessionPaymentCalculator.resolvedHourlyRateCents(hourlyRateCents)
        return draft
    }
}

struct SessionPaymentSummary {
    let durationHours: Double
    let hourlyRateCents: Int
    let totalCents: Int

    var formattedDuration: String {
        SessionPaymentCalculator.formatDurationHours(durationHours)
    }

    var formattedRate: String {
        SessionPaymentCalculator.formatDollars(fromCents: hourlyRateCents, includeCentsIfWhole: false)
    }

    var formattedTotal: String {
        SessionPaymentCalculator.formatDollars(fromCents: totalCents, includeCentsIfWhole: true)
    }

    var equationText: String {
        "\(formattedDuration) × \(formattedRate) = \(SessionPaymentCalculator.formatDollars(fromCents: totalCents, includeCentsIfWhole: false))"
    }
}

enum SessionPaymentCalculator {
    static let minimumHourlyRateCents = 500
    static let maximumHourlyRateCents = 15_000
    static let defaultHourlyRateCents = 1800

    static func resolvedHourlyRateCents(_ cents: Int?) -> Int {
        guard let cents, cents > 0 else { return defaultHourlyRateCents }
        return cents
    }

    static func summary(startDate: Date, endDate: Date, hourlyRateCents: Int) -> SessionPaymentSummary? {
        let durationHours = endDate.timeIntervalSince(startDate) / 3600
        guard durationHours > 0, hourlyRateCents > 0 else { return nil }

        let totalCents = Int((durationHours * Double(hourlyRateCents)).rounded())
        guard totalCents > 0 else { return nil }

        return SessionPaymentSummary(
            durationHours: durationHours,
            hourlyRateCents: hourlyRateCents,
            totalCents: totalCents
        )
    }

    static func summary(for session: SessionItem) -> SessionPaymentSummary? {
        let hourlyRateCents = resolvedHourlyRateCents(session.assignedSitter?.hourlyRateCents)
        return summary(
            startDate: session.startDate,
            endDate: session.endDate,
            hourlyRateCents: hourlyRateCents
        )
    }

    static func displayHourlyRate(_ cents: Int?) -> String {
        guard let cents, cents > 0 else { return "Not set" }
        return "\(formatDollars(fromCents: cents, includeCentsIfWhole: false))/hr"
    }

    static func parseHourlyRateInput(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let sanitized = trimmed
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "/hr", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "hr", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let dollars = Double(sanitized), dollars > 0 else { return nil }
        let cents = Int((dollars * 100).rounded())
        guard (minimumHourlyRateCents...maximumHourlyRateCents).contains(cents) else { return nil }
        return cents
    }

    static func formatHourlyRateInput(_ cents: Int?) -> String {
        guard let cents, cents > 0 else { return "" }
        return formatDollars(fromCents: cents, includeCentsIfWhole: false)
    }

    static func isValidHourlyRateInput(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return parseHourlyRateInput(trimmed) != nil
    }

    static func formatDurationHours(_ hours: Double) -> String {
        let rounded = (hours * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded)) hrs"
        }
        return "\(String(format: "%.1f", rounded)) hrs"
    }

    static func formatDollars(fromCents cents: Int, includeCentsIfWhole: Bool) -> String {
        let dollars = Double(cents) / 100.0
        if includeCentsIfWhole || cents % 100 != 0 {
            return String(format: "$%.2f", dollars)
        }
        return String(format: "$%.0f", dollars)
    }

    static func hourlyEquationText(
        hours: Double,
        hourlyRateCents: Int,
        numberOfKids: Int,
        extraPerAdditionalKidHourlyCents: Int,
        additionalFlatFeeCents: Int,
        totalCents: Int
    ) -> String {
        let duration = formatDurationHours(hours)
        let rate = formatDollars(fromCents: hourlyRateCents, includeCentsIfWhole: false)
        var parts = ["\(duration) × \(rate)/hr"]

        let extraKids = max(0, numberOfKids - 1)
        if extraKids > 0, extraPerAdditionalKidHourlyCents > 0 {
            let kidRate = formatDollars(fromCents: extraPerAdditionalKidHourlyCents, includeCentsIfWhole: false)
            parts.append("\(duration) × \(extraKids) extra kid\(extraKids == 1 ? "" : "s") × \(kidRate)/hr")
        }

        if additionalFlatFeeCents > 0 {
            parts.append(formatDollars(fromCents: additionalFlatFeeCents, includeCentsIfWhole: false) + " flat")
        }

        let total = formatDollars(fromCents: totalCents, includeCentsIfWhole: false)
        if parts.count == 1, additionalFlatFeeCents == 0 {
            return "\(parts[0]) = \(total)"
        }
        return parts.joined(separator: " + ") + " = \(total)"
    }

    static func parseCurrencyInput(_ input: String) -> Int? {
        parseHourlyRateInput(input)
    }

    static func formatCurrencyInput(_ cents: Int) -> String {
        guard cents > 0 else { return "" }
        return formatDollars(fromCents: cents, includeCentsIfWhole: false)
    }

    static func parseHoursInput(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    static func formatHoursInput(_ hours: Double) -> String {
        let rounded = (hours * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }

    static func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60

        switch (hours, remainder) {
        case (0, let mins):
            return "\(mins) min"
        case (1, 0):
            return "1 hr"
        case (let hrs, 0):
            return "\(hrs) hr"
        case (1, let mins):
            return "1 hr, \(mins) min"
        case (let hrs, let mins):
            return "\(hrs) hr, \(mins) min"
        }
    }

    static func attributedDuration(minutes: Int) -> NSAttributedString {
        let plain = formatDuration(minutes: minutes)
        let attributed = NSMutableAttributedString(
            string: plain,
            attributes: [
                .font: UIFont.h2,
                .foregroundColor: UIColor.label
            ]
        )

        let unitPattern = #"\b(hr|min)\b"#
        guard let regex = try? NSRegularExpression(pattern: unitPattern) else {
            return attributed
        }

        let range = NSRange(plain.startIndex..<plain.endIndex, in: plain)
        regex.enumerateMatches(in: plain, range: range) { match, _, _ in
            guard let match, let stringRange = Range(match.range, in: plain) else { return }
            attributed.addAttributes(
                [
                    .font: UIFont.bodyL,
                    .foregroundColor: UIColor.secondaryLabel
                ],
                range: NSRange(stringRange, in: plain)
            )
        }

        return attributed
    }

    static func minutes(fromHours hours: Double) -> Int {
        let rawMinutes = Int((hours * 60).rounded())
        let clamped = min(1440, max(15, rawMinutes))
        let remainder = clamped % 15
        if remainder == 0 { return clamped }
        return remainder < 8 ? clamped - remainder : clamped + (15 - remainder)
    }

    static func hours(fromMinutes minutes: Int) -> Double {
        Double(minutes) / 60.0
    }

    static func presentPaymentCalculator(
        from viewController: UIViewController,
        configuration: SessionPaymentViewController.Configuration
    ) {
        let paymentVC = SessionPaymentViewController(configuration: configuration)
        let nav = UINavigationController(rootViewController: paymentVC)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        viewController.present(nav, animated: true)
    }
}

extension SessionItem {
    var isPaymentMoment: Bool {
        status == .extended || status == .completed
    }
}
