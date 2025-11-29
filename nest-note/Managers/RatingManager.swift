//
//  RatingManager.swift
//  nest-note
//
//  Created by Colton Swapp on 8/24/25.
//

import Foundation
import StoreKit

final class RatingManager {
    
    // MARK: - Shared Instance
    static let shared = RatingManager()
    
    // MARK: - Keys
    private struct Keys {
        static let entriesCreatedCount = "entriesCreatedCount"
        static let hasInvitedSitter = "hasInvitedSitter"
        static let appLaunchCount = "appLaunchCount"
        static let hasRequestedRating = "hasRequestedRating"
        static let lastRatingRequestDate = "lastRatingRequestDate"
    }
    
    // MARK: - Properties
    private let defaults = UserDefaults.standard
    private let minimumDaysBetweenRequests: Double = 5 // 5 days between rating requests
    
    // MARK: - Initialization
    private init() {
        trackAppLaunch()
    }
    
    // MARK: - App Launch Tracking
    func trackAppLaunch() {
        let currentCount = defaults.integer(forKey: Keys.appLaunchCount)
        defaults.set(currentCount + 1, forKey: Keys.appLaunchCount)
        
        checkAppLaunchMilestone()
    }
    
    // MARK: - Entry Creation Tracking
    func trackEntryCreation() {
        let currentCount = defaults.integer(forKey: Keys.entriesCreatedCount)
        defaults.set(currentCount + 1, forKey: Keys.entriesCreatedCount)
        
        checkEntriesMilestone()
    }
    
    // MARK: - Sitter Invitation Tracking
    func trackSitterInvitation() {
        defaults.set(true, forKey: Keys.hasInvitedSitter)
        
        checkSitterInvitationMilestone()
    }
    
    // MARK: - Manual Rating Request
    func requestRatingManually() {
        requestAppStoreRating(force: true)
    }
    
    // MARK: - Milestone Checks
    private func checkEntriesMilestone() {
        let entriesCount = defaults.integer(forKey: Keys.entriesCreatedCount)
        if entriesCount >= 3 {
            requestAppStoreRating()
        }
    }
    
    private func checkSitterInvitationMilestone() {
        let hasInvited = defaults.bool(forKey: Keys.hasInvitedSitter)
        if hasInvited {
            requestAppStoreRating()
        }
    }
    
    private func checkAppLaunchMilestone() {
        let launchCount = defaults.integer(forKey: Keys.appLaunchCount)
        if launchCount >= 5 {
            requestAppStoreRating()
        }
    }
    
    // MARK: - Rating Request Logic
    private func requestAppStoreRating(force: Bool = false) {
        // Check if we should request rating
        guard shouldRequestRating(force: force) else { return }
        
        // Request rating on main thread
        DispatchQueue.main.async {
            if #available(iOS 18.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    AppStore.requestReview(in: windowScene)
                    
                    // Mark that we've requested a rating
                    self.defaults.set(true, forKey: Keys.hasRequestedRating)
                    self.defaults.set(Date(), forKey: Keys.lastRatingRequestDate)
                    
                    Logger.log(level: .info, category: .general, message: "Requested App Store rating")
                }
            } else {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                    
                    // Mark that we've requested a rating
                    self.defaults.set(true, forKey: Keys.hasRequestedRating)
                    self.defaults.set(Date(), forKey: Keys.lastRatingRequestDate)
                    
                    Logger.log(level: .info, category: .general, message: "Requested App Store rating")
                }
            }
        }
    }
    
    private func shouldRequestRating(force: Bool = false) -> Bool {
        // Always allow manual requests
        if force { return true }
        
        // Don't request if we've never requested before and haven't hit any milestones
        let hasRequestedBefore = defaults.bool(forKey: Keys.hasRequestedRating)
        
        // If we've requested before, check the time interval
        if hasRequestedBefore {
            if let lastRequestDate = defaults.object(forKey: Keys.lastRatingRequestDate) as? Date {
                let daysSinceLastRequest = Date().timeIntervalSince(lastRequestDate) / 86400 // seconds in a day
                if daysSinceLastRequest < minimumDaysBetweenRequests {
                    return false
                }
            }
        }
        
        return true
    }
    
}