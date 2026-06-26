import UIKit

enum OnboardingSetupErrorTargetStep {
    case email
    case password
    case createNest
}

struct OnboardingSetupErrorPresentation {
    let alertTitle: String
    let alertMessage: String
    let toastTitle: String
    let toastSubtitle: String
    let targetStep: OnboardingSetupErrorTargetStep

    static func presentation(for error: Error) -> OnboardingSetupErrorPresentation {
        let rootError = underlyingError(from: error)

        if let authError = rootError as? AuthError {
            return presentation(for: authError)
        }

        if let nestError = rootError as? NestService.NestError {
            return presentation(for: nestError)
        }

        let description = rootError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty, description != AuthError.unknown.errorDescription {
            return OnboardingSetupErrorPresentation(
                alertTitle: "Setup Failed",
                alertMessage: description,
                toastTitle: "Setup Failed",
                toastSubtitle: description,
                targetStep: .email
            )
        }

        return genericPresentation
    }

    private static func presentation(for authError: AuthError) -> OnboardingSetupErrorPresentation {
        switch authError {
        case .emailAlreadyInUse:
            let message = "This email is already registered. Try signing in or use a different email."
            return OnboardingSetupErrorPresentation(
                alertTitle: "Email Already Registered",
                alertMessage: message,
                toastTitle: "Email Already Registered",
                toastSubtitle: message,
                targetStep: .email
            )
        case .emailInvalid:
            let message = authError.errorDescription ?? "Please enter a valid email address"
            return OnboardingSetupErrorPresentation(
                alertTitle: "Invalid Email",
                alertMessage: message,
                toastTitle: "Invalid Email",
                toastSubtitle: message,
                targetStep: .email
            )
        case .passwordTooWeak, .weakPassword:
            let message = authError.errorDescription ?? "Password must be at least 6 characters"
            return OnboardingSetupErrorPresentation(
                alertTitle: "Password Too Weak",
                alertMessage: message,
                toastTitle: "Password Too Weak",
                toastSubtitle: message,
                targetStep: .password
            )
        case .networkError:
            let message = authError.errorDescription ?? "Unable to connect. Please check your internet connection"
            return OnboardingSetupErrorPresentation(
                alertTitle: "Connection Problem",
                alertMessage: message,
                toastTitle: "Connection Problem",
                toastSubtitle: message,
                targetStep: .email
            )
        case .invalidCredentials, .userNotFound, .invalidUserData, .unknown:
            let message = authError.errorDescription ?? genericPresentation.alertMessage
            return OnboardingSetupErrorPresentation(
                alertTitle: "Account Creation Failed",
                alertMessage: message,
                toastTitle: "Account Creation Failed",
                toastSubtitle: message,
                targetStep: .email
            )
        }
    }

    private static func presentation(for nestError: NestService.NestError) -> OnboardingSetupErrorPresentation {
        let message = nestError.errorDescription ?? "Failed to create your nest. Please try again."
        return OnboardingSetupErrorPresentation(
            alertTitle: "Nest Creation Failed",
            alertMessage: message,
            toastTitle: "Nest Creation Failed",
            toastSubtitle: message,
            targetStep: .createNest
        )
    }

    private static var genericPresentation: OnboardingSetupErrorPresentation {
        OnboardingSetupErrorPresentation(
            alertTitle: "Setup Failed",
            alertMessage: "Something went wrong during setup. Please try again.",
            toastTitle: "Setup Failed",
            toastSubtitle: "Something went wrong during setup. Please try again.",
            targetStep: .email
        )
    }

    private static func underlyingError(from error: Error) -> Error {
        if let onboardingError = error as? OnboardingError,
           let failureInfo = onboardingError.failureInfo {
            return failureInfo.underlyingError
        }
        return error
    }
}
