//
//  RoutineStateManager.swift
//  nest-note
//
//  Created by Claude on 8/7/25.
//

import Foundation
import Combine

class RoutineStateManager: ObservableObject {
    static let shared = RoutineStateManager()
    
    private let userDefaults = UserDefaults.standard
    
    var testingMode: Bool = false
    var testingIntervalMinutes: Int = 5
    
    private init() {}
    
    // MARK: - Key Management
    private func actionStateKey(routineId: String, actionIndex: Int) -> String {
        return "routine_\(routineId)_action_\(actionIndex)"
    }
    
    private func actionTimestampKey(routineId: String, actionIndex: Int) -> String {
        return "routine_\(routineId)_action_\(actionIndex)_ts"
    }
    
    // MARK: - Expiration Logic
    private func hasExpired(_ completionDate: Date) -> Bool {
        let now = Date()
        
        if testingMode {
            // In testing: expire after testingIntervalMinutes
            let expirationDate = completionDate.addingTimeInterval(TimeInterval(testingIntervalMinutes * 60))
            let expired = now > expirationDate
            
            Logger.log(level: .debug, category: .routineStateManager, message: "Testing mode: completion=\(completionDate), expiration=\(expirationDate), now=\(now), expired=\(expired)")
            
            return expired
        } else {
            // In production: expire at next midnight
            let calendar = Calendar.current
            let completionDay = calendar.startOfDay(for: completionDate)
            let today = calendar.startOfDay(for: now)
            let expired = today > completionDay
            
            Logger.log(level: .debug, category: .routineStateManager, message: "Production mode: completionDay=\(completionDay), today=\(today), expired=\(expired)")
            
            return expired
        }
    }
    
    // MARK: - Action State Management
    func isActionCompleted(routineId: String, actionIndex: Int) -> Bool {
        let stateKey = actionStateKey(routineId: routineId, actionIndex: actionIndex)
        let timestampKey = actionTimestampKey(routineId: routineId, actionIndex: actionIndex)
        
        // Check if action is marked as completed
        guard userDefaults.bool(forKey: stateKey) else {
            Logger.log(level: .debug, category: .routineStateManager, message: "Action \(routineId)[\(actionIndex)] not completed (no state key)")
            return false
        }
        
        // Get completion timestamp
        let timestamp = userDefaults.double(forKey: timestampKey)
        guard timestamp > 0 else {
            Logger.log(level: .error, category: .routineStateManager, message: "Action \(routineId)[\(actionIndex)] has state but no timestamp - cleaning up")
            userDefaults.removeObject(forKey: stateKey)
            return false
        }
        
        let completionDate = Date(timeIntervalSince1970: timestamp)
        let expired = hasExpired(completionDate)
        
        if expired {
            Logger.log(level: .info, category: .routineStateManager, message: "Action \(routineId)[\(actionIndex)] expired - removing state")
            // Clean up expired keys
            userDefaults.removeObject(forKey: stateKey)
            userDefaults.removeObject(forKey: timestampKey)
            return false
        }
        
        Logger.log(level: .debug, category: .routineStateManager, message: "Action \(routineId)[\(actionIndex)] is completed and valid")
        return true
    }
    
    func setActionCompleted(_ completed: Bool, routineId: String, actionIndex: Int) {
        let stateKey = actionStateKey(routineId: routineId, actionIndex: actionIndex)
        let timestampKey = actionTimestampKey(routineId: routineId, actionIndex: actionIndex)
        
        if completed {
            let now = Date()
            userDefaults.set(true, forKey: stateKey)
            userDefaults.set(now.timeIntervalSince1970, forKey: timestampKey)
            Logger.log(level: .info, category: .routineStateManager, message: "Action \(routineId)[\(actionIndex)] marked completed at \(now)")
        } else {
            userDefaults.removeObject(forKey: stateKey)
            userDefaults.removeObject(forKey: timestampKey)
            Logger.log(level: .info, category: .routineStateManager, message: "Action \(routineId)[\(actionIndex)] marked incomplete - removing keys")
        }
        
        objectWillChange.send()
    }
    
    func toggleActionCompletion(routineId: String, actionIndex: Int) {
        let currentState = isActionCompleted(routineId: routineId, actionIndex: actionIndex)
        setActionCompleted(!currentState, routineId: routineId, actionIndex: actionIndex)
    }
    
    // MARK: - Routine Progress
    func getRoutineProgress(for routine: RoutineItem) -> (completed: Int, total: Int) {
        let completedActions = routine.routineActions.enumerated().filter { index, _ in
            isActionCompleted(routineId: routine.id, actionIndex: index)
        }.count
        
        Logger.log(level: .debug, category: .routineStateManager, message: "Routine \(routine.id) progress: \(completedActions)/\(routine.routineActions.count)")
        
        return (completed: completedActions, total: routine.routineActions.count)
    }
    
    func isRoutineCompleted(for routine: RoutineItem) -> Bool {
        let progress = getRoutineProgress(for: routine)
        return progress.completed == progress.total && progress.total > 0
    }
    
    func getRoutineCompletionPercentage(for routine: RoutineItem) -> Double {
        let progress = getRoutineProgress(for: routine)
        guard progress.total > 0 else { return 0.0 }
        return Double(progress.completed) / Double(progress.total)
    }
    
    // MARK: - Reset Routine
    func resetRoutine(_ routine: RoutineItem) {
        Logger.log(level: .info, category: .routineStateManager, message: "Manually resetting routine \(routine.id)")
        for index in 0..<routine.routineActions.count {
            setActionCompleted(false, routineId: routine.id, actionIndex: index)
        }
    }
}
