//
//  RatingManager.swift
//  nest-note
//
//  Created by Colton Swapp on 8/24/25.
//

import Foundation
import StoreKit
import UIKit

enum RatingMoment: String {
    case appLaunch
    case entryCreated
    case sitterInvited
    case onboardingComplete
    case sessionJoined
    case sessionCompleted
    case sitterRequestAccepted
    case premiumPurchase
    case manual
}

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
        static let hasTriggeredOnboardingReview = "hasTriggeredOnboardingReview"
    }
    
    // MARK: - Properties
    private let defaults = UserDefaults.standard
    private let minimumDaysBetweenRequests: Double = 5 // 5 days between rating requests
    private var scheduledReviewWorkItem: DispatchWorkItem?
    
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
    
    // MARK: - High-Confidence Milestones
    
    func trackOnboardingComplete() {
        guard !defaults.bool(forKey: Keys.hasTriggeredOnboardingReview) else { return }
        defaults.set(true, forKey: Keys.hasTriggeredOnboardingReview)
        scheduleReviewRequest(delay: 1.0, moment: .onboardingComplete)
    }
    
    func trackSessionJoined() {
        scheduleReviewRequest(delay: 0.5, moment: .sessionJoined)
    }
    
    func trackSessionCompleted() {
        scheduleReviewRequest(delay: 1.5, moment: .sessionCompleted)
    }
    
    func trackSitterRequestAccepted() {
        scheduleReviewRequest(delay: 0.5, moment: .sitterRequestAccepted)
    }
    
    func trackPremiumPurchase() {
        scheduleReviewRequest(delay: 1.5, moment: .premiumPurchase)
    }
    
    // MARK: - Manual Rating Request
    func requestRatingManually() {
        scheduleReviewRequest(delay: 0, moment: .manual, force: true)
    }
    
    // MARK: - Milestone Checks
    private func checkEntriesMilestone() {
        let entriesCount = defaults.integer(forKey: Keys.entriesCreatedCount)
        if entriesCount >= 3 {
            scheduleReviewRequest(delay: 0, moment: .entryCreated)
        }
    }
    
    private func checkSitterInvitationMilestone() {
        let hasInvited = defaults.bool(forKey: Keys.hasInvitedSitter)
        if hasInvited {
            scheduleReviewRequest(delay: 0, moment: .sitterInvited)
        }
    }
    
    private func checkAppLaunchMilestone() {
        let launchCount = defaults.integer(forKey: Keys.appLaunchCount)
        if launchCount >= 5 {
            scheduleReviewRequest(delay: 0, moment: .appLaunch)
        }
    }
    
    // MARK: - Rating Request Logic
    private func scheduleReviewRequest(delay: TimeInterval, moment: RatingMoment, force: Bool = false) {
        scheduledReviewWorkItem?.cancel()
        
        guard shouldRequestRating(force: force) else { return }
        
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.presentReviewRequest(moment: moment, force: force)
            }
        }
        scheduledReviewWorkItem = workItem
        
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        } else {
            DispatchQueue.main.async(execute: workItem)
        }
    }
    
    @MainActor
    private func presentReviewRequest(moment: RatingMoment, force: Bool) {
        guard shouldRequestRating(force: force) else { return }
        
        if #available(iOS 18.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                AppStore.requestReview(in: windowScene)
                markRatingRequested(moment: moment)
            }
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
            markRatingRequested(moment: moment)
        }
    }
    
    private func markRatingRequested(moment: RatingMoment) {
        defaults.set(true, forKey: Keys.hasRequestedRating)
        defaults.set(Date(), forKey: Keys.lastRatingRequestDate)
        
        Logger.log(
            level: .info,
            category: .general,
            message: "Requested App Store rating (moment: \(moment.rawValue))"
        )
    }
    
    private func shouldRequestRating(force: Bool = false) -> Bool {
        // Always allow manual requests
        if force { return true }
        
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
