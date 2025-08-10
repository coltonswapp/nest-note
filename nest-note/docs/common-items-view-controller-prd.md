# PRD: CommonItemsViewController

## Overview
The `CommonItemsViewController` is a new view controller designed to display suggested common items that users can add to their nest. It provides inspiration and quick-add functionality for entries, places, and routines using a familiar collection view layout with filtering capabilities.

## Features

### Data Display
- **Common Entries**: Pre-populated example entries with suggested codes and other content
- **Common Places**: Example places users might want to track
- **Common Routines**: Template routines with common actions

### Layout Structure
- Reuses existing `NestCategoryViewController` layout patterns:
  - **Entries**: `codes` section (2-column grid) and `other` section (full-width)
  - **Places**: 2-item row grid layout using existing `PlaceCell`
  - **Routines**: 2-item row grid layout using existing `RoutineCell`

### Filtering
- Implements `NNCategoryFilterView` for switching between item types
- Filter options: "Entries", "Places", "Routines"
- Only one type displayed at a time based on filter selection

### Visual Enhancements
- **Places**: Use random `map-placeholder-1` through `map-placeholder-5` images
- Consistent styling with existing nest category views

## Technical Requirements

### Architecture
- Inherits from `NNViewController` with collection view implementation
- Uses `UICollectionViewDiffableDataSource` for data management
- Implements `NNCategoryFilterViewDelegate` for filter handling

### Cell Reuse
- **Entries**: Reuse `HalfWidthCell` and `FullWidthCell` from `NestCategoryViewController`
- **Places**: Reuse existing `PlaceCell` with grid layout configuration
- **Routines**: Reuse existing `RoutineCell`

### Data Source
- Static data arrays for common items
- Suggested entries categorized by type (codes vs other)
- Template places with placeholder images
- Common routine templates

### Integration
- Add navigation option in `SettingsViewController` for testing
- Modal presentation with navigation controller
- Proper dismissal handling

## Implementation Details

### Collection View Sections
```swift
enum Section: CaseIterable {
    case codes    // Short entries (2-column grid)
    case other    // Long entries (full-width)
    case places   // Places (2-column grid)
    case routines // Routines (2-column grid)
}
```

### Filter Implementation
- Use existing `NNCategoryFilterView` component
- Filter buttons: "Entries", "Places", "Routines"
- Update `enabledSections` based on selection
- Animate section transitions

### Suggested Content Examples

#### Sample Entries

**House & Safety Entries:**
- CommonEntry(title: "Garage Code", content: "8005", category: category)
- CommonEntry(title: "Front Door", content: "2208", category: category)
- CommonEntry(title: "Trash Day", content: "Wednesday", category: category)
- CommonEntry(title: "WiFi Password", content: "SuperStrongPassword", category: category)
- CommonEntry(title: "Alarm Code", content: "4321", category: category)
- CommonEntry(title: "Thermostat", content: "68°F", category: category)
- CommonEntry(title: "Trash Pickup", content: "Wednesday Morning", category: category)
- CommonEntry(title: "Shed", content: "1357", category: category) // Short entry
- CommonEntry(title: "Power Outage", content: "Flashlights in kitchen drawer", category: category)
- CommonEntry(title: "Recycling", content: "Blue bin, Fridays", category: category)
- CommonEntry(title: "Yard Service", content: "Every Monday, 11am-2pm", category: category)
- CommonEntry(title: "Water Shutoff", content: "Basement, north wall", category: category)
- CommonEntry(title: "Gas Shutoff", content: "Outside, east side of house", category: category)

**Emergency & Medical Entries:**
- CommonEntry(title: "Emergency Contact", content: "John Doe: 555-123-4567", category: category)
- CommonEntry(title: "Nearest Hospital", content: "City General - 10 Main St", category: category)
- CommonEntry(title: "Fire Evacuation", content: "Meet at mailbox", category: category)
- CommonEntry(title: "Poison Control", content: "1-800-222-1222", category: category)
- CommonEntry(title: "Home Doctor", content: "Dr. Smith: 555-987-6543", category: category)
- CommonEntry(title: "911", content: "Address", category: category) // Short entry
- CommonEntry(title: "EpiPen", content: "Top shelf", category: category) // Short entry
- CommonEntry(title: "Safe", content: "3456", category: category) // Short entry
- CommonEntry(title: "Allergies", content: "Peanuts, penicillin", category: category)
- CommonEntry(title: "Insurance", content: "BlueCross #12345678", category: category)
- CommonEntry(title: "Urgent Care", content: "WalkIn Clinic - 55 Grove St", category: category)
- CommonEntry(title: "Power Company", content: "CityPower: 555-789-0123", category: category)
- CommonEntry(title: "Plumber", content: "Joe's Plumbing: 555-456-7890", category: category)
- CommonEntry(title: "Neighbor Help", content: "Mrs. Wilson: 555-234-5678", category: category)

**Pet Care Entries:**
- CommonEntry(title: "Dog Food", content: "1 cup", category: category) // Short entry
- CommonEntry(title: "Cat", content: "Indoor", category: category) // Short entry
- CommonEntry(title: "Fish", content: "Feed 2x", category: category) // Short entry
- CommonEntry(title: "Toys", content: "In bin", category: category) // Short entry
- CommonEntry(title: "Treat Rules", content: "Max 2 per day", category: category)
- CommonEntry(title: "Pet Names", content: "Dog: Max, Cat: Luna, Fish: Bubbles", category: category)
- CommonEntry(title: "No-Go Areas", content: "Keep pets out of formal dining room", category: category)
- CommonEntry(title: "Pet Sitter", content: "Emily: 555-222-3333", category: category)
- CommonEntry(title: "Leash Location", content: "Hanging by front door", category: category)
- CommonEntry(title: "Pet Emergency", content: "Animal Hospital: 555-789-4561", category: category)

#### Sample Places
- CommonPlace(name: "Grandma's House", icon: "house.fill")
- CommonPlace(name: "School", icon: "graduationcap.fill")
- CommonPlace(name: "Bus Stop", icon: "bus.fill")
- CommonPlace(name: "Dance Studio", icon: "figure.dance")
- CommonPlace(name: "Soccer Practice", icon: "soccerball")
- CommonPlace(name: "Favorite Park", icon: "tree.fill")
- CommonPlace(name: "Rec Center", icon: "building.2.fill")
- CommonPlace(name: "Swimming Pool", icon: "figure.pool.swim")

#### Sample Routines
- CommonRoutine(name: "Morning Wake Up", icon: "sun.rise.fill")
- CommonRoutine(name: "Bedtime Routine", icon: "moon.stars.fill")
- CommonRoutine(name: "After School", icon: "backpack.fill")
- CommonRoutine(name: "Pet Care", icon: "pawprint.fill")
- CommonRoutine(name: "Meal Prep", icon: "fork.knife")
- CommonRoutine(name: "Bath Time", icon: "bathtub.fill")
- CommonRoutine(name: "Homework Time", icon: "pencil.and.scribble")
- CommonRoutine(name: "Screen Time Setup", icon: "tv.fill")
- CommonRoutine(name: "Leaving House", icon: "door.left.hand.open")
- CommonRoutine(name: "Coming Home", icon: "house.fill")
- CommonRoutine(name: "Emergency Protocol", icon: "exclamationmark.triangle.fill")
- CommonRoutine(name: "Quiet Time", icon: "book.closed.fill")

## Testing Integration

Add to `SettingsViewController.swift` debug section:
```swift
("Common Items", "sparkles")
```

Handle selection:
```swift
case "Common Items":
    let commonItemsVC = CommonItemsViewController()
    let nav = UINavigationController(rootViewController: commonItemsVC)
    present(nav, animated: true)
```

## User Experience

1. **Access**: Navigate from Settings → Common Items (debug)
2. **Filter**: Tap filter buttons to switch between content types
3. **Browse**: Scroll through suggested items in familiar grid layout
4. **Visual Feedback**: Consistent with existing app patterns and styling

## Next Steps

1. Create `CommonItemsViewController.swift` in appropriate scenes directory
2. Implement collection view with diffable data source
3. Add static data arrays for suggested content
4. Integrate `NNCategoryFilterView` component
5. Test filtering and layout functionality
6. Refine suggested content based on user feedback

This PRD ensures the `CommonItemsViewController` integrates seamlessly with existing components while providing users with helpful inspiration for populating their nest with common items.
