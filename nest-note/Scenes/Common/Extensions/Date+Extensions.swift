import Foundation
import UIKit

extension Date {
    /// Initialize a Date with specific components
    /// - Parameters:
    ///   - year: The year (e.g., 2024)
    ///   - month: The month (1-12)
    ///   - day: The day (1-31)
    ///   - hour: Optional hour (0-23), defaults to 0
    ///   - minute: Optional minute (0-59), defaults to 0
    ///   - second: Optional second (0-59), defaults to 0
    static func from(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0
    ) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        
        return Calendar.current.date(from: components)
    }
    
    /// Initialize a Date for today with specific time components
    /// - Parameters:
    ///   - hour: The hour (0-23)
    ///   - minute: The minute (0-59)
    ///   - second: Optional second (0-59), defaults to 0
    static func today(hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date? {
        let now = Date()
        let calendar = Calendar.current
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = second
        
        return calendar.date(from: components)
    }
    
    /// Initialize a Date for tomorrow with specific time components
    /// - Parameters:
    ///   - hour: The hour (0-23)
    ///   - minute: The minute (0-59)
    ///   - second: Optional second (0-59), defaults to 0
    static func tomorrow(hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date? {
        guard let today = today(hour: hour, minute: minute, second: second) else { return nil }
        return Calendar.current.date(byAdding: .day, value: 1, to: today)
    }
    
    /// Rounds the date up to the next hour
    /// For example: 2:20 PM becomes 3:00 PM, 2:45 PM becomes 3:00 PM
    func roundedToNextHour() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: self)
        
        // Add 1 hour unless we're exactly on the hour
        let minute = calendar.component(.minute, from: self)
        if minute > 0 {
            components.hour = (components.hour ?? 0) + 1
        }
        
        // Set minutes and seconds to 0
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components) ?? self
    }
    
    /// Rounds the date up to the next 15-minute mark
    /// For example: 2:05 PM becomes 2:15 PM, 2:20 PM becomes 2:30 PM, 2:40 PM becomes 2:45 PM, 2:50 PM becomes 3:00 PM
    func roundedToNext15Minutes() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        
        // Get current minute
        let currentMinute = components.minute ?? 0
        
        // Calculate next 15-minute mark
        let next15MinuteMark = ((currentMinute / 15) + 1) * 15
        
        // If we're already at a 15-minute mark, stay there
        if currentMinute % 15 == 0 {
            return self
        }
        
        // Set to next 15-minute mark
        components.minute = next15MinuteMark
        components.second = 0
        
        // If we've gone past 60 minutes, increment the hour
        if next15MinuteMark >= 60 {
            components.hour = (components.hour ?? 0) + 1
            components.minute = 0
        }
        
        return calendar.date(from: components) ?? self
    }
    
    /// Synchronizes the end date to use the same day as the start date while preserving the end time
    /// Used when toggling from multi-day to single-day session
    /// - Parameters:
    ///   - startDate: The start date to use for the day component
    ///   - endDate: The end date to extract the time component from
    /// - Returns: A new date with startDate's day and endDate's time, or nil if unable to create
    static func syncEndDateToStartDay(startDate: Date, endDate: Date) -> Date? {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
        let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endDate)

        var newComponents = DateComponents()
        newComponents.year = startComponents.year
        newComponents.month = startComponents.month
        newComponents.day = startComponents.day
        newComponents.hour = endTimeComponents.hour
        newComponents.minute = endTimeComponents.minute

        return calendar.date(from: newComponents)
    }

    /// Example usage:
    /// ```
    /// let now = Date() // 2:45 PM
    /// let nextHour = now.roundedToNextHour() // 3:00 PM
    /// let next15Min = now.roundedToNext15Minutes() // 3:00 PM
    ///
    /// // Sync dates for single-day session
    /// let start = Date.from(year: 2024, month: 1, day: 15, hour: 9, minute: 0)! // Jan 15, 9:00 AM
    /// let end = Date.from(year: 2024, month: 1, day: 17, hour: 17, minute: 0)!   // Jan 17, 5:00 PM
    /// let synced = Date.syncEndDateToStartDay(startDate: start, endDate: end)    // Jan 15, 5:00 PM
    /// ```
}

// MARK: - Date Synchronization Utility

/// Result of date synchronization operation
struct DateSynchronizationResult {
    let adjustedStartDate: Date
    let adjustedEndDate: Date
}

/// Result of date validation operation
enum DateValidationResult {
    case valid
    case invalidStartAfterEnd
    case invalidSameTime
    
    var errorTitle: String {
        switch self {
        case .valid:
            return ""
        case .invalidStartAfterEnd, .invalidSameTime:
            return "Invalid Time Range"
        }
    }
    
    var errorMessage: String {
        switch self {
        case .valid:
            return ""
        case .invalidStartAfterEnd:
            return "The start time cannot be after the end time."
        case .invalidSameTime:
            return "The start and end times cannot be the same."
        }
    }
}

/// Utility for validating session date ranges
struct SessionDateValidator {
    /// Validates a date range for sessions
    /// - Parameters:
    ///   - startDate: The start date/time
    ///   - endDate: The end date/time
    ///   - isMultiDay: Whether this is a multi-day session (affects overnight validation)
    /// - Returns: Validation result indicating if dates are valid or what error occurred
    static func validateDateRange(startDate: Date, endDate: Date, isMultiDay: Bool = false) -> DateValidationResult {
        let calendar = Calendar.current
        
        // For single-day sessions, check if this is an overnight session (end time wraps to next day)
        if !isMultiDay {
            let startTime = calendar.dateComponents([.hour, .minute], from: startDate)
            let endTime = calendar.dateComponents([.hour, .minute], from: endDate)
            
            // If end time is before start time, it's likely an overnight session
            // Compare just the time components to detect overnight sessions
            if let startHour = startTime.hour, let startMin = startTime.minute,
               let endHour = endTime.hour, let endMin = endTime.minute {
                let startMinutes = startHour * 60 + startMin
                let endMinutes = endHour * 60 + endMin
                
                // If end time is before start time, it's an overnight session (valid)
                if endMinutes < startMinutes {
                    // This is a valid overnight session - end time is on the next day
                    return .valid
                }
            }
        }
        
        // Check if start date is after end date (for multi-day or same-day sessions)
        if calendar.compare(startDate, to: endDate, toGranularity: .minute) == .orderedDescending {
            return .invalidStartAfterEnd
        }
        
        // Check if start and end times are the same
        if calendar.compare(startDate, to: endDate, toGranularity: .minute) == .orderedSame {
            return .invalidSameTime
        }
        
        return .valid
    }
    
    /// Validates a date range and shows an alert if invalid
    /// - Parameters:
    ///   - startDate: The start date/time
    ///   - endDate: The end date/time
    ///   - isMultiDay: Whether this is a multi-day session (affects overnight validation)
    ///   - viewController: The view controller to present the alert from
    /// - Returns: true if valid, false if invalid (alert is shown automatically)
    static func validateAndShowAlertIfNeeded(startDate: Date, endDate: Date, isMultiDay: Bool = false, in viewController: UIViewController) -> Bool {
        let result = validateDateRange(startDate: startDate, endDate: endDate, isMultiDay: isMultiDay)
        
        guard result == .valid else {
            let alert = UIAlertController(
                title: result.errorTitle,
                message: result.errorMessage,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            viewController.present(alert, animated: true)
            return false
        }
        
        return true
    }
}

/// Utility for synchronizing session dates when start date/time changes
struct SessionDateSynchronizer {
    /// Synchronizes dates based on picker type and session configuration
    /// - Parameters:
    ///   - pickerType: The type of date picker that was changed
    ///   - newDate: The new date selected from the picker
    ///   - previousStartDate: The previous start date (before change)
    ///   - currentEndDate: The current end date
    ///   - isMultiDay: Whether this is a multi-day session
    /// - Returns: Adjusted start and end dates
    static func synchronizeDates(
        pickerType: NNDateTimePickerSheet.PickerType,
        newDate: Date,
        previousStartDate: Date,
        currentEndDate: Date,
        isMultiDay: Bool
    ) -> DateSynchronizationResult {
        let calendar = Calendar.current
        // Initialize with previous values - only change what's being edited
        var adjustedStartDate = previousStartDate
        var adjustedEndDate = currentEndDate
        
        switch pickerType {
        case .startDate:
            adjustedStartDate = newDate
            
            if isMultiDay {
                // For multi-day stays, if start date is now after end date, adjust end date
                if adjustedStartDate >= adjustedEndDate {
                    // Calculate the original duration between start and end dates
                    let duration = calendar.dateComponents([.day, .hour, .minute], from: previousStartDate, to: currentEndDate)
                    
                    // If there was a positive duration, preserve it relative to the new start date
                    if let days = duration.day, days > 0 {
                        if let adjustedEnd = calendar.date(byAdding: .day, value: days, to: adjustedStartDate) {
                            adjustedEndDate = adjustedEnd
                        } else {
                            // Fallback: set end date to start date + 1 day
                            adjustedEndDate = calendar.date(byAdding: .day, value: 1, to: adjustedStartDate) ?? adjustedEndDate
                        }
                    } else {
                        // Default: set end date to start date + 1 day
                        adjustedEndDate = calendar.date(byAdding: .day, value: 1, to: adjustedStartDate) ?? adjustedEndDate
                    }
                }
            } else {
                // If single-day session, sync end date to the new start date's day
                if let syncedEndDate = Date.syncEndDateToStartDay(startDate: adjustedStartDate, endDate: adjustedEndDate) {
                    // Ensure end time is after start time - if not, adjust end time to be 1 hour after start
                    if syncedEndDate <= adjustedStartDate {
                        adjustedEndDate = calendar.date(byAdding: .hour, value: 1, to: adjustedStartDate) ?? syncedEndDate
                    } else {
                        adjustedEndDate = syncedEndDate
                    }
                }
            }
            
        case .startTime:
            adjustedStartDate = newDate
            
            // If single-day session, sync end date to the new start date's day
            if !isMultiDay {
                if let syncedEndDate = Date.syncEndDateToStartDay(startDate: adjustedStartDate, endDate: adjustedEndDate) {
                    // Ensure end time is after start time - if not, adjust end time to be 1 hour after start
                    if syncedEndDate <= adjustedStartDate {
                        adjustedEndDate = calendar.date(byAdding: .hour, value: 1, to: adjustedStartDate) ?? syncedEndDate
                    } else {
                        adjustedEndDate = syncedEndDate
                    }
                }
            }
            
        case .endDate, .endTime:
            adjustedEndDate = newDate
            
            // If end time is now before or equal to start time, adjust start time to be 1 hour before end time
            if adjustedEndDate <= adjustedStartDate {
                adjustedStartDate = calendar.date(byAdding: .hour, value: -1, to: adjustedEndDate) ?? adjustedStartDate
            }
        }
        
        return DateSynchronizationResult(
            adjustedStartDate: adjustedStartDate,
            adjustedEndDate: adjustedEndDate
        )
    }
}

extension Calendar {
    func startOfDay(for date: Date) -> Date {
        return self.date(bySettingHour: 0, minute: 0, second: 0, of: date) ?? date
    }
    
    func middleOfDay(for date: Date) -> Date {
        return self.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }
    
    func endOfDay(for date: Date) -> Date {
        return self.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }
}

// Usage examples:
/*
 // Create a specific date
 let christmas2024 = Date.from(year: 2024, month: 12, day: 25)
 
 // Create a date with time
 let newYearsEve = Date.from(year: 2024, month: 12, day: 31, hour: 23, minute: 59)
 
 // Create a date for today at 3:30 PM
 let todayAfternoon = Date.today(hour: 15, minute: 30)
 
 // Create a date for tomorrow at 9 AM
 let tomorrowMorning = Date.tomorrow(hour: 9)
 */ 
