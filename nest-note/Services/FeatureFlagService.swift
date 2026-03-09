//
//  FeatureFlagService.swift
//  nest-note
//
//  Created by Claude Code on 20/7/2025.
//

import Foundation
import FirebaseRemoteConfig

final class FeatureFlagService {

    // MARK: - Properties
    static let shared = FeatureFlagService()
    private var remoteConfig: RemoteConfig
    
    // MARK: - Feature Flags
    enum FeatureFlag: String, CaseIterable {
        case bypassPaywallForTesting = "bypass_paywall_for_testing"
        case testFlightBypassEnabled = "testflight_bypass_enabled"
        case debugAsProUser = "debug_as_pro_user"
        case captureSignupLogs = "capture_signup_logs"
        
        var defaultValue: Bool {
            switch self {
            case .bypassPaywallForTesting, .testFlightBypassEnabled:
                return false // Default to requiring subscriptions
            case .debugAsProUser:
                return true // TESTING: Set to `true` to test as Pro user, `false` to test as Free user
            case .captureSignupLogs:
                return false // Default to not capturing logs for privacy
            }
        }
    }
    
    // MARK: - Remote Config Keys
    enum RemoteConfigKey: String, CaseIterable {
        case freeUserSelectionLimit = "free_user_selection_limit"
        case parentOnboardingFlow = "parent_onboarding_flow"
        
        var defaultValue: Any {
            switch self {
            case .freeUserSelectionLimit:
                return 6
            case .parentOnboardingFlow:
                return "onboarding_config"
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        remoteConfig = RemoteConfig.remoteConfig()
        setupRemoteConfig()
    }
    
    // MARK: - Setup
    private func setupRemoteConfig() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        // Allow more frequent fetches in debug mode
        settings.minimumFetchInterval = 0
        #else
        // Production: fetch every 12 hours
        settings.minimumFetchInterval = 43200
        #endif
        
        remoteConfig.configSettings = settings
        
        // Set default values
        var defaults: [String: NSObject] = [:]
        for flag in FeatureFlag.allCases {
            defaults[flag.rawValue] = flag.defaultValue as NSObject
        }
        for configKey in RemoteConfigKey.allCases {
            defaults[configKey.rawValue] = configKey.defaultValue as? NSObject
        }
        remoteConfig.setDefaults(defaults)
        
        // Fetch initial values
        fetchAndActivate()
    }
    
    // MARK: - Public Methods
    
    /// Fetches the latest remote config values and activates them
    func fetchAndActivate() {
        remoteConfig.fetchAndActivate { [weak self] status, error in
            if let error = error {
                Logger.log(level: .error, category: .general, message: "Failed to fetch remote config: \(error.localizedDescription)")
                return
            }
            
            Logger.log(level: .info, category: .general, message: "Remote config fetched successfully. Status: \(status)")
            self?.logCurrentFlags()
        }
    }
    
    /// Gets the boolean value for a feature flag
    /// Checks UserDefaults for local debug overrides first (DEBUG builds only)
    /// - Parameter flag: The feature flag to check
    /// - Returns: The current value of the feature flag
    func isEnabled(_ flag: FeatureFlag) -> Bool {
        #if DEBUG
        // Check for local debug override first
        let overrideKey = "debug_override_\(flag.rawValue)"
        if UserDefaults.standard.object(forKey: overrideKey) != nil {
            let overrideValue = UserDefaults.standard.bool(forKey: overrideKey)
            Logger.log(level: .debug, category: .general, message: "Feature flag '\(flag.rawValue)': \(overrideValue) (LOCAL OVERRIDE)")
            return overrideValue
        }
        #endif
        
        let value = remoteConfig.configValue(forKey: flag.rawValue).boolValue
        
        #if DEBUG
        Logger.log(level: .debug, category: .general, message: "Feature flag '\(flag.rawValue)': \(value)")
        #endif
        
        return value
    }
    
    /// Sets a local debug override for a feature flag (DEBUG builds only)
    /// This allows overriding RemoteConfig values for testing purposes
    /// - Parameters:
    ///   - flag: The feature flag to override
    ///   - value: The override value
    func setDebugOverride(_ flag: FeatureFlag, value: Bool) {
        #if DEBUG
        let overrideKey = "debug_override_\(flag.rawValue)"
        UserDefaults.standard.set(value, forKey: overrideKey)
        Logger.log(level: .info, category: .general, message: "🔧 DEBUG OVERRIDE: Set '\(flag.rawValue)' to \(value)")
        #endif
    }
    
    /// Removes a local debug override for a feature flag (DEBUG builds only)
    /// - Parameter flag: The feature flag to remove override for
    func removeDebugOverride(_ flag: FeatureFlag) {
        #if DEBUG
        let overrideKey = "debug_override_\(flag.rawValue)"
        UserDefaults.standard.removeObject(forKey: overrideKey)
        Logger.log(level: .info, category: .general, message: "🔧 DEBUG OVERRIDE: Removed override for '\(flag.rawValue)'")
        #endif
    }
    
    /// Checks if a local debug override exists for a feature flag
    /// - Parameter flag: The feature flag to check
    /// - Returns: True if a local override exists, false otherwise
    func hasDebugOverride(_ flag: FeatureFlag) -> Bool {
        #if DEBUG
        let overrideKey = "debug_override_\(flag.rawValue)"
        return UserDefaults.standard.object(forKey: overrideKey) != nil
        #else
        return false
        #endif
    }
    
    /// Gets the integer value for a remote config key
    /// - Parameter key: The remote config key to fetch
    /// - Returns: The current value of the remote config key
    func getIntValue(for key: RemoteConfigKey) -> Int {
        let value = Int(remoteConfig.configValue(forKey: key.rawValue).numberValue)
        
        #if DEBUG
        Logger.log(level: .debug, category: .general, message: "Remote config '\(key.rawValue)': \(value)")
        #endif
        
        return value
    }
    
    /// Gets the free user selection limit from remote config
    func getFreeUserSelectionLimit() -> Int {
        return getIntValue(for: .freeUserSelectionLimit)
    }

    /// Gets the string value for a remote config key
    func getStringValue(for key: RemoteConfigKey) -> String {
        let rawValue = remoteConfig.configValue(forKey: key.rawValue).stringValue
        let value = rawValue.isEmpty ? (key.defaultValue as? String ?? "") : rawValue

        #if DEBUG
        Logger.log(level: .debug, category: .general, message: "Remote config '\(key.rawValue)': \(value)")
        #endif

        return value
    }

    /// Gets the onboarding flow config file name from Remote Config (used by A/B test)
    func getOnboardingFlowConfigName() -> String {
        return getStringValue(for: .parentOnboardingFlow)
    }
    
    /// Checks if paywall bypass is enabled for testing
    /// This combines multiple conditions for maximum flexibility
    /// - Returns: True if paywall should be bypassed, false otherwise
    func shouldBypassPaywall() -> Bool {
        // Check if general bypass is enabled
        let generalBypass = isEnabled(.bypassPaywallForTesting)
        
        // Check if TestFlight-specific bypass is enabled
        let testFlightBypass = isEnabled(.testFlightBypassEnabled)
        
        // Check if we're running in TestFlight
        let isTestFlight = isRunningInTestFlight()
        
        // Bypass if either general bypass is on, or if TestFlight bypass is on AND we're in TestFlight
        let shouldBypass = generalBypass || (testFlightBypass && isTestFlight)
        
        #if DEBUG
        Logger.log(level: .debug, category: .general, message: "Paywall bypass check - General: \(generalBypass), TestFlight: \(testFlightBypass), IsTestFlight: \(isTestFlight), Result: \(shouldBypass)")
        #endif
        
        return shouldBypass
    }
    
    /// Checks if signup log capture is enabled
    /// - Returns: True if signup logs should be captured, false otherwise
    func shouldCaptureSignupLogs() -> Bool {
        return isEnabled(.captureSignupLogs)
    }
    
    // MARK: - Debug User Status
    
    /// Gets the current debug user status (free or pro)
    /// - Returns: "free" or "pro" based on debugAsProUser flag
    func getDebugUserStatus() -> String {
        #if DEBUG
        return isEnabled(.debugAsProUser) ? "pro" : "free"
        #else
        return "free"
        #endif
    }
    
    /// Sets the debug user status (free or pro)
    /// - Parameter status: "free" or "pro"
    func setDebugUserStatus(_ status: String) {
        #if DEBUG
        let isPro = status.lowercased() == "pro"
        setDebugOverride(.debugAsProUser, value: isPro)
        Logger.log(level: .info, category: .general, message: "🔧 DEBUG USER STATUS: Set to \(status)")
        #endif
    }
    
    // MARK: - Private Methods
    
    /// Detects if the app is running in TestFlight
    /// - Returns: True if running in TestFlight, false otherwise
    private func isRunningInTestFlight() -> Bool {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        
        return appStoreReceiptURL.lastPathComponent == "sandboxReceipt"
    }
    
    /// Logs current feature flag values for debugging
    private func logCurrentFlags() {
        #if DEBUG
        Logger.log(level: .info, category: .general, message: "=== Current Feature Flags & Config ===")
        for flag in FeatureFlag.allCases {
            let value = isEnabled(flag)
            Logger.log(level: .info, category: .general, message: "\(flag.rawValue): \(value)")
        }
        for configKey in RemoteConfigKey.allCases {
            if configKey.defaultValue is String {
                let value = getStringValue(for: configKey)
                Logger.log(level: .info, category: .general, message: "\(configKey.rawValue): \(value)")
            } else {
                let value = getIntValue(for: configKey)
                Logger.log(level: .info, category: .general, message: "\(configKey.rawValue): \(value)")
            }
        }
        Logger.log(level: .info, category: .general, message: "TestFlight detected: \(isRunningInTestFlight())")
        Logger.log(level: .info, category: .general, message: "Should bypass paywall: \(shouldBypassPaywall())")
        Logger.log(level: .info, category: .general, message: "=====================================")
        #endif
    }
}
