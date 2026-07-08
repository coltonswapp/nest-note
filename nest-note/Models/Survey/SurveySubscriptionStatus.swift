import UIKit
import FirebaseFirestore

struct UserSubscriptionSnapshot: Equatable {
    let status: String
    let productId: String?
    let periodType: String?
    let updatedAt: Date?

    static func parse(from data: [String: Any]?) -> UserSubscriptionSnapshot? {
        guard let subscription = data?["subscription"] as? [String: Any],
              let status = subscription["status"] as? String,
              !status.isEmpty else {
            return nil
        }

        let productId = subscription["productId"] as? String
        let periodType = subscription["periodType"] as? String
        let updatedAt = (subscription["updatedAt"] as? Timestamp)?.dateValue()
        return UserSubscriptionSnapshot(
            status: status,
            productId: productId,
            periodType: periodType,
            updatedAt: updatedAt
        )
    }

    var isTrialPeriod: Bool {
        if status == "trial" || status == "trial_cancelled" {
            return true
        }
        return periodType?.uppercased() == "TRIAL"
    }
}

enum SurveySubscriptionStatus: Hashable {
    case sitterFree
    case skippedPaywall
    case convertedAtSignup
    case trial
    case active
    case cancelled
    case trialCancelled
    case expired
    case billingIssue
    case unknown

    static func resolve(survey: SurveyResponse, liveSnapshot: UserSubscriptionSnapshot?) -> SurveySubscriptionStatus {
        let metadata = survey.metadata
        let role = metadata["role"]
        let isSitter = survey.surveyType == .sitterSurvey || role == NestUser.UserType.sitter.rawValue
        if isSitter {
            return .sitterFree
        }

        let paywallConverted = metadata["paywall_converted"]
        let startedTrialAtSignup = metadata["paywall_started_trial"] == "true"

        if let liveSnapshot {
            if liveSnapshot.isTrialPeriod {
                return liveSnapshot.status == "trial_cancelled" ? .trialCancelled : .trial
            }

            switch liveSnapshot.status {
            case "active":
                if paywallConverted == "true" {
                    return .convertedAtSignup
                }
                return .active
            case "cancelled":
                return .cancelled
            case "expired":
                return .expired
            case "billing_issue":
                return .billingIssue
            default:
                break
            }
        }

        if startedTrialAtSignup {
            return .trial
        }

        switch paywallConverted {
        case "true":
            return .convertedAtSignup
        case "false":
            return .skippedPaywall
        default:
            return .unknown
        }
    }

    var shortLabel: String {
        switch self {
        case .sitterFree: return "FREE"
        case .skippedPaywall: return "SKIPPED"
        case .convertedAtSignup: return "NEW SUB"
        case .trial: return "TRIAL"
        case .active: return "RENEWAL"
        case .cancelled: return "CANCELLED"
        case .trialCancelled: return "TRIAL"
        case .expired: return "EXPIRED"
        case .billingIssue: return "BILLING"
        case .unknown: return "UNKNOWN"
        }
    }

    var detailLabel: String {
        switch self {
        case .sitterFree:
            return "Sitter — no subscription"
        case .skippedPaywall:
            return "Skipped paywall at signup"
        case .convertedAtSignup:
            return "Started paid subscription during onboarding"
        case .trial:
            return "Started free trial during onboarding"
        case .active:
            return "Active subscription"
        case .cancelled:
            return "Cancelled — access until period ends"
        case .trialCancelled:
            return "Trial cancelled — access until trial ends"
        case .expired:
            return "Subscription expired"
        case .billingIssue:
            return "Billing issue"
        case .unknown:
            return "Subscription status unknown"
        }
    }

    var tagStyle: SubscriptionTagStyle {
        switch self {
        case .trial:
            return SubscriptionTagStyle(
                textColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ?
                        UIColor(red: 0.98, green: 0.86, blue: 0.28, alpha: 1) :
                        UIColor(red: 0.62, green: 0.48, blue: 0.02, alpha: 1)
                },
                backgroundColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ?
                        UIColor(red: 0.24, green: 0.20, blue: 0.08, alpha: 1) :
                        UIColor(red: 0.99, green: 0.96, blue: 0.78, alpha: 1)
                }
            )
        case .active:
            return SubscriptionTagStyle(
                textColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ?
                        UIColor(red: 0.37, green: 0.92, blue: 0.83, alpha: 1) :
                        UIColor(red: 0.09, green: 0.58, blue: 0.42, alpha: 1)
                },
                backgroundColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ?
                        UIColor(red: 0.10, green: 0.18, blue: 0.13, alpha: 1) :
                        UIColor(red: 0.86, green: 0.97, blue: 0.91, alpha: 1)
                }
            )
        case .convertedAtSignup:
            return SubscriptionTagStyle(
                textColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ?
                        UIColor(red: 0.65, green: 0.71, blue: 0.99, alpha: 1) :
                        UIColor(red: 0.35, green: 0.40, blue: 0.85, alpha: 1)
                },
                backgroundColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ?
                        UIColor(red: 0.15, green: 0.13, blue: 0.25, alpha: 1) :
                        UIColor(red: 0.90, green: 0.91, blue: 0.99, alpha: 1)
                }
            )
        case .trialCancelled, .cancelled, .expired, .skippedPaywall, .billingIssue, .sitterFree:
            return SubscriptionTagStyle(
                textColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ?
                        UIColor(white: 0.78, alpha: 1) :
                        UIColor.secondaryLabel
                },
                backgroundColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ?
                        UIColor(white: 0.22, alpha: 1) :
                        UIColor(white: 0.93, alpha: 1)
                }
            )
        case .unknown:
            return SubscriptionTagStyle(
                textColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ?
                        UIColor(white: 0.82, alpha: 1) :
                        UIColor.secondaryLabel
                },
                backgroundColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ?
                        UIColor(white: 0.34, alpha: 1) :
                        UIColor(white: 0.88, alpha: 1)
                }
            )
        }
    }

    var isOutlier: Bool {
        switch self {
        case .skippedPaywall, .expired, .billingIssue, .unknown:
            return true
        default:
            return false
        }
    }
}

struct SubscriptionTagStyle: Equatable {
    let textColor: UIColor
    let backgroundColor: UIColor
}
