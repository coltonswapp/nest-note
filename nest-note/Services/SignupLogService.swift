//
//  SignupLogService.swift
//  nest-note
//
//  Created by Claude Code on 12/10/2025.
//

import Foundation
import FirebaseStorage
import Combine
import UIKit

/**
 * SignupLogService
 * 
 * Captures application logs during signup and login attempts and uploads them to Firebase Storage.
 * This service helps with debugging authentication failures and understanding user onboarding issues.
 * 
 * Features:
 * - Controlled by remote config flag 'capture_signup_logs' (default: false)
 * - Captures ALL logs during the signup/login process (not just auth-related)
 * - Generates unique filenames with timestamp and user identifier
 * - Uploads to Firebase Storage under 'signup_logs/' path
 * - Includes metadata like result, error, log count, and upload timestamp
 * 
 * Usage:
 * 1. Call `startCapturing(identifier:)` at the beginning of signup/login
 * 2. Call `stopCaptureAndUpload(result:identifier:error:)` when complete
 * 
 * File naming convention:
 * signup_{result}_{identifier}_{timestamp}.txt
 * 
 * Example:
 * - signup_success_user_at_example_com_2025-10-12_14-30-15.txt
 * - signup_failure_apple_signin_1697123456_2025-10-12_14-31-22.txt
 */
final class SignupLogService {
    
    // MARK: - Properties
    static let shared = SignupLogService()
    private let storage = Storage.storage()
    private lazy var storageRef = Storage.storage(url: "gs://nest-note-21a2a.firebasestorage.app").reference()
    private let dateFormatter: DateFormatter
    private let monthYearFormatter: DateFormatter
    
    // Log capture state
    private var capturedLogs: [LogLine] = []
    private var logCancellable: AnyCancellable?
    private var isCapturing = false
    
    // MARK: - Initialization
    private init() {
        // Initialize date formatter for filenames
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        dateFormatter.timeZone = TimeZone.current

        // Initialize month/year formatter for folder organization
        monthYearFormatter = DateFormatter()
        monthYearFormatter.dateFormat = "MMM_yyyy"
        monthYearFormatter.timeZone = TimeZone.current
        monthYearFormatter.locale = Locale(identifier: "en_US") // Ensure consistent month names
    }
    
    // MARK: - Public Methods
    
    /// Starts capturing logs for signup process
    /// - Parameter identifier: A unique identifier for this signup attempt (email, timestamp, etc.)
    func startCapturing(identifier: String? = nil) {
        guard FeatureFlagService.shared.isEnabled(.captureSignupLogs) else {
            Logger.log(level: .info, category: .signup, message: "📋 LOG CAPTURE: Signup log capture is disabled via remote config")
            return
        }
        
        guard !isCapturing else {
            Logger.log(level: .debug, category: .signup, message: "📋 LOG CAPTURE: Already capturing logs")
            return
        }
        
        Logger.log(level: .info, category: .signup, message: "📋 LOG CAPTURE: Starting signup log capture for identifier: \(identifier ?? "unknown")")
        
        isCapturing = true
        capturedLogs.removeAll()
        
        // Subscribe to logger updates on main thread, then move to background for processing
        logCancellable = Logger.shared.$lines
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lines in
                // Process on background queue to avoid blocking UI
                DispatchQueue.global(qos: .background).async {
                    self?.capturedLogs = Array(lines) // Create a copy to avoid reference issues
                }
            }
        
        // Add initial log entry
        Logger.log(level: .info, category: .signup, message: "📋 LOG CAPTURE: Started capturing logs for signup attempt - identifier: \(identifier ?? "unknown")")
    }
    
    /// Stops capturing logs and uploads them to Firebase Storage
    /// - Parameters:
    ///   - result: The result of the signup attempt (success/failure)
    ///   - identifier: A unique identifier for this signup attempt
    ///   - error: Optional error if the signup failed
    func stopCaptureAndUpload(result: SignupResult, identifier: String? = nil, error: String? = nil) async {
        guard FeatureFlagService.shared.isEnabled(.captureSignupLogs) else {
            return
        }

        guard isCapturing else {
            Logger.log(level: .info, category: .signup, message: "📋 LOG CAPTURE: Not currently capturing logs - this may indicate capture was never started or already completed")
            return
        }
        
        Logger.log(level: .info, category: .signup, message: "📋 LOG CAPTURE: Stopping capture and uploading logs - result: \(result), identifier: \(identifier ?? "unknown")")
        
        // Stop capturing
        isCapturing = false
        logCancellable?.cancel()
        logCancellable = nil
        
        // Add final log entry
        Logger.log(level: .info, category: .signup, message: "📋 LOG CAPTURE: Signup attempt completed - result: \(result), error: \(error ?? "none")")
        
        // Upload to Firebase Storage
        await uploadLogs(result: result, identifier: identifier, error: error)
        
        // Clear captured logs
        capturedLogs.removeAll()
    }
    
    // MARK: - Testing & Debug Methods
    
    #if DEBUG
    /// Test method to simulate a signup log capture (Debug only)
    /// - Parameter testIdentifier: Test identifier for the simulation
    func simulateSignupLogCapture(testIdentifier: String = "test_user") async {
        Logger.log(level: .info, category: .signup, message: "🧪 SIMULATION: Starting signup log simulation for: \(testIdentifier)")
        
        startCapturing(identifier: testIdentifier)
        
        // Simulate some signup process logs
        Logger.log(level: .info, category: .signup, message: "🧪 SIMULATION: Starting Firebase authentication...")
        Logger.log(level: .debug, category: .signup, message: "🧪 SIMULATION: Validating email format...")
        Logger.log(level: .debug, category: .signup, message: "🧪 SIMULATION: Creating Firebase user...")
        Logger.log(level: .info, category: .signup, message: "🧪 SIMULATION: Firebase user created successfully")
        Logger.log(level: .debug, category: .signup, message: "🧪 SIMULATION: Setting display name...")
        Logger.log(level: .info, category: .signup, message: "🧪 SIMULATION: Creating default nest...")
        Logger.log(level: .debug, category: .signup, message: "🧪 SIMULATION: Saving user profile...")
        Logger.log(level: .info, category: .signup, message: "🧪 SIMULATION: Signup completed successfully!")
        
        // Wait a moment to let logs accumulate
        try? await Task.sleep(for: .seconds(1))
        
        // Stop and upload
        await stopCaptureAndUpload(result: .success, identifier: testIdentifier)
        
        Logger.log(level: .info, category: .signup, message: "🧪 SIMULATION: Simulation complete!")
    }
    
    /// Gets the current capture status for debugging
    var captureStatus: (isCapturing: Bool, logCount: Int) {
        return (isCapturing: isCapturing, logCount: capturedLogs.count)
    }
    #endif
    
    // MARK: - Private Methods
    
    /// Uploads captured logs to Firebase Storage
    private func uploadLogs(result: SignupResult, identifier: String?, error: String?) async {
        do {
            let filename = generateFilename(result: result, identifier: identifier)
            let logContent = generateLogContent(result: result, identifier: identifier, error: error)
            
            Logger.log(level: .info, category: .signup, message: "📋 LOG UPLOAD: Uploading \(capturedLogs.count) log lines to file: \(filename)")

            // Create storage reference with monthly folder organization
            let monthYear = monthYearFormatter.string(from: Date()).lowercased()
            let storagePath = "signup_logs/\(monthYear)/\(filename)"
            let logsRef = storageRef.child(storagePath)

            Logger.log(level: .info, category: .signup, message: "📋 LOG UPLOAD: Storage path: \(storagePath)")
            
            // Convert log content to data with explicit UTF-8 encoding
            guard let logData = logContent.data(using: .utf8) else {
                Logger.log(level: .error, category: .signup, message: "📋 LOG UPLOAD: Failed to convert log content to data")
                return
            }
            
            // Set metadata with explicit UTF-8 encoding and app version info
            let metadata = StorageMetadata()
            metadata.contentType = "text/plain; charset=utf-8"

            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

            metadata.customMetadata = [
                "signup_result": result.rawValue,
                "identifier": identifier ?? "unknown",
                "error": error ?? "none",
                "log_count": String(capturedLogs.count),
                "upload_timestamp": ISO8601DateFormatter().string(from: Date()),
                "app_version": appVersion,
                "build_number": buildNumber,
                "ios_version": UIDevice.current.systemVersion,
                "device_model": UIDevice.current.model,
                "month_year": monthYear
            ]
            
            // Upload the file
            _ = try await logsRef.putDataAsync(logData, metadata: metadata)
            
            Logger.log(level: .info, category: .signup, message: "📋 LOG UPLOAD: ✅ Successfully uploaded signup logs to Firebase Storage: \(filename)")
            
        } catch {
            Logger.log(level: .error, category: .signup, message: "📋 LOG UPLOAD: ❌ Failed to upload signup logs: \(error.localizedDescription)")
        }
    }
    
    /// Generates a unique filename for the log file
    private func generateFilename(result: SignupResult, identifier: String?) -> String {
        let timestamp = dateFormatter.string(from: Date())
        let cleanIdentifier = identifier?.replacingOccurrences(of: "@", with: "_at_")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: " ", with: "_") ?? "unknown"
        
        return "signup_\(result.rawValue)_\(cleanIdentifier)_\(timestamp).txt"
    }
    
    /// Generates the content for the log file
    private func generateLogContent(result: SignupResult, identifier: String?, error: String?) -> String {
        // Get app version information
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"

        var content = """
        =================================
        NEST NOTE SIGNUP LOG
        =================================
        App Version: \(appVersion) (\(buildNumber))
        Bundle ID: \(bundleIdentifier)
        iOS Version: \(UIDevice.current.systemVersion)
        Device Model: \(UIDevice.current.model)
        =================================
        Signup Result: \(result.rawValue.uppercased())
        Identifier: \(identifier ?? "unknown")
        Error: \(error ?? "none")
        Timestamp: \(ISO8601DateFormatter().string(from: Date()))
        Total Log Lines: \(capturedLogs.count)
        =================================

        """
        
        // Add all captured logs
        for log in capturedLogs {
            content += "\(log.timestamp) [\(log.level.rawValue.uppercased())] \(log.description)\n"
        }
        
        content += """
        
        =================================
        END OF LOG
        =================================
        """
        
        return content
    }
}

// MARK: - Supporting Types

enum SignupResult: String {
    case success = "success"
    case failure = "failure"
}

// MARK: - Storage Extension

private extension StorageReference {
    func putDataAsync(_ uploadData: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
        return try await withCheckedThrowingContinuation { continuation in
            putData(uploadData, metadata: metadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let metadata = metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: NSError(domain: "StorageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown storage error"]))
                }
            }
        }
    }
}
