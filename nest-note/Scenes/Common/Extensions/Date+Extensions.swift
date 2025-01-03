import Foundation

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
    
    /// Example usage:
    /// ```
    /// let now = Date() // 2:45 PM
    /// let nextHour = now.roundedToNextHour() // 3:00 PM
    /// ```
}

extension Calendar {
    func startOfDay(for date: Date) -> Date {
        return self.date(bySettingHour: 0, minute: 0, second: 0, of: date) ?? date
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