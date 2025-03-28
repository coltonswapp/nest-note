import Foundation

final class SessionEventGenerator {
    static func generateRandomEvents(in dateInterval: DateInterval, count: Int = 10) -> [SessionEvent] {
        let calendar = Calendar.current
        var eventsByDate: [Date: [SessionEvent]] = [:]
        var currentDate = dateInterval.start
        
        let eventTitles = [
            "Soccer Practice",
            "Dance Class",
            "Piano Lesson",
            "School Pickup",
            "Swimming Class",
            "Homework Time",
            "Bedtime Routine",
            "Art Class",
            "Gymnastics",
            "Doctor Appointment"
        ]
        
        while currentDate <= dateInterval.end {
            // 30% chance of having no events
            let shouldHaveEvents = Double.random(in: 0...1) > 0.3
            
            if shouldHaveEvents {
                let numberOfEvents = Int.random(in: 1...5)
                var dateEvents: [SessionEvent] = []
                
                for _ in 0..<numberOfEvents {
                    let randomHour = Int.random(in: 8...20)
                    let eventDate = calendar.date(bySettingHour: randomHour, minute: 0, second: 0, of: currentDate)!
                    let endDate = calendar.date(byAdding: .hour, value: 1, to: eventDate)!
                    
                    let event = SessionEvent(
                        title: eventTitles.randomElement()!,
                        startDate: eventDate,
                        endDate: endDate,
                        eventColor: NNColors.EventColors.ColorType.allCases.randomElement() ?? .blue
                    )
                    dateEvents.append(event)
                }
                
                // Sort events by time
                dateEvents.sort { $0.startDate < $1.startDate }
                let startOfDay = calendar.startOfDay(for: currentDate)
                eventsByDate[startOfDay] = dateEvents
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Flatten the dictionary into a sorted array
        return eventsByDate.values
            .flatMap { $0 }
            .sorted { $0.startDate < $1.startDate }
    }
} 
