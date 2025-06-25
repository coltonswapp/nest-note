//
//  VisibilityVisualizer.swift
//  nest-note
//
//  Created by Colton Swapp on 6/24/25.
//

import SwiftUI

struct GridEntry {
    let id = UUID()
    let title: String
    let content: String
    let color: Color
    
    // Use the standard method for determining cell size
    var shouldUseHalfWidthCell: Bool {
        return title.count <= 15 && content.count <= 15
    }
    
    static let sampleEntries: [GridEntry] = {
        let colors: [Color] = [
            .green.opacity(0.3), .blue.opacity(0.3), .purple.opacity(0.3), .orange.opacity(0.3),
            .red.opacity(0.3), .teal.opacity(0.3), .yellow.opacity(0.3), .mint.opacity(0.3),
            .pink.opacity(0.3), .indigo.opacity(0.3), .cyan.opacity(0.3), .brown.opacity(0.3),
            .gray.opacity(0.3)
        ]
        
        var entries: [GridEntry] = []
        var colorIndex = 0
        
        // Household entries
        let householdEntries = [
            ("Garage Code", "8005"),
            ("Front Door", "2208"),
            ("Trash Day", "Wednesday"),
            ("WiFi Password", "SuperStrongPassword"),
            ("Alarm Code", "4321"),
            ("Thermostat", "68°F"),
            ("Trash Pickup", "Wednesday Morning"),
            ("Shed", "1357"),
            ("Power Outage", "Flashlights in kitchen drawer"),
            ("Recycling", "Blue bin, Fridays"),
            ("Yard Service", "Every Monday, 11am-2pm"),
            ("Water Shutoff", "Basement, north wall"),
            ("Gas Shutoff", "Outside, east side of house")
        ]
        
        // Emergency entries
        let emergencyEntries = [
            ("Emergency Contact", "John Doe: 555-123-4567"),
            ("Nearest Hospital", "City General - 10 Main St"),
            ("Fire Evacuation", "Meet at mailbox"),
            ("Poison Control", "1-800-222-1222"),
            ("Home Doctor", "Dr. Smith: 555-987-6543"),
            ("911", "Address"),
            ("EpiPen", "Top shelf"),
            ("Safe", "3456"),
            ("Allergies", "Peanuts, penicillin"),
            ("Insurance", "BlueCross #12345678"),
            ("Urgent Care", "WalkIn Clinic - 55 Grove St"),
            ("Power Company", "CityPower: 555-789-0123"),
            ("Plumber", "Joe's Plumbing: 555-456-7890"),
            ("Neighbor Help", "Mrs. Wilson: 555-234-5678")
        ]
        
        // Rules & Guidelines entries
        let rulesEntries = [
            ("Bedtime", "9:00 PM on weekdays"),
            ("Screen Time", "2 hours max per day"),
            ("House Rules", "No shoes indoors"),
            ("Chores", "Take out trash on Wednesday"),
            ("Snacks", "After 3pm"),
            ("No TV", "After 8pm"),
            ("Bath", "7:30pm"),
            ("Books", "2 at bed"),
            ("Meal Times", "Breakfast 7am, Lunch 12pm, Dinner 6pm"),
            ("Off-Limits", "Dad's office and workshop"),
            ("Study Hour", "4pm-5pm weekdays"),
            ("Playroom Rules", "Clean up before moving to next activity"),
            ("Phone Use", "Only after homework is completed"),
            ("Guest Policy", "Parents must approve all visitors"),
            ("Allowance", "$5 weekly, given on Sunday")
        ]
        
        // Combine all entries
        let allEntryData = householdEntries + emergencyEntries + rulesEntries
        
        for (title, content) in allEntryData {
            entries.append(GridEntry(
                title: title,
                content: content,
                color: colors[colorIndex % colors.count]
            ))
            colorIndex += 1
        }
        
        return entries
    }()
}

struct GridItemView: View {
    let entry: GridEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: entry.shouldUseHalfWidthCell ? 4 : 8) {
            Text(entry.title)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text(entry.content)
                .font(.system(size: entry.shouldUseHalfWidthCell ? 22 : 17, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(entry.shouldUseHalfWidthCell ? 1 : 2)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct VisibilityVisualizer: View {
    private let shortItemSize: CGFloat = 160
    private let longItemWidth: CGFloat = 332  // 2 × 160 + 12 spacing for equal row lengths
    private let standardHeight: CGFloat = 90
    private let spacing: CGFloat = 12
    private let entries = GridEntry.sampleEntries
    private let numberOfRows = 5
    private let targetRowWidth: CGFloat = 676  // All rows equal this width
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Visibility Levels")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Information adapts to your needs - essential details for short visits, comprehensive guides for overnight stays.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: spacing) {
                    ForEach(0..<numberOfRows, id: \.self) { rowIndex in
                        createRow(rowIndex: rowIndex)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: CGFloat(numberOfRows) * (standardHeight + spacing))
        }
        .padding(.vertical)
    }
    
    private func createRow(rowIndex: Int) -> some View {
        let rowPattern = getRowPattern(for: rowIndex)
        
        return HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<rowPattern.count, id: \.self) { itemIndex in
                let entryIndex = (rowIndex * 4 + itemIndex) % entries.count  // Use base 4 for cycling
                let entry = entries[entryIndex]
                let isLongCell = rowPattern[itemIndex]
                
                GridItemView(entry: entry)
                .frame(
                    width: isLongCell ? longItemWidth : shortItemSize,
                    height: standardHeight
                )
            }
        }
        .frame(width: targetRowWidth, alignment: .leading)
    }
    
    private func getRowPattern(for rowIndex: Int) -> [Bool] {
        // Returns array of Bool where true = long cell, false = short cell
        // All patterns total 676px width
        switch rowIndex % 3 {
        case 0:
            return [false, false, false, false]  // 4 short cells = 676px
        case 1:
            return [true, true]  // 2 long cells = 676px
        case 2:
            return [true, false, false]  // 1 long + 2 short = 676px
        default:
            return [false, false, false, false]
        }
    }
    
}

#Preview {
    VisibilityVisualizer()
}
