# Product Requirements Document: Routines Feature

## Overview
The Routines feature will introduce a new item type (`RoutineItem`) to the unified collection architecture, allowing nest owners to create repeatable, digestible sequences of actions for their sitters. This addresses the common need for structured, recurring instructions.

## User Story
**As a nest owner**, I want to create reusable routine checklists so that my sitters can follow consistent, step-by-step processes for common tasks like bedtime, feeding, or departure procedures.

## Technical Architecture

### 1. Model Layer
- **RoutineItem**: Inherits from `BaseItem` protocol
- **Properties**:
  - Standard `BaseItem` properties (id, type, category, title, createdAt, updatedAt)
  - `routineActions: [String]` - Array of action strings (max 10 actions)
- **ItemType**: Already defined as `.routine` in existing `BaseItem.swift:14`

### 2. Data Model Structure
```swift
class RoutineItem: BaseItem, Codable, Hashable {
    let id: String
    let type: ItemType = .routine
    var title: String
    var category: String
    let createdAt: Date
    var updatedAt: Date
    var routineActions: [String] // Maximum 10 actions
    
    // Validation
    var canAddAction: Bool {
        return routineActions.count < 10
    }
}
```

### 3. User Interface Components

#### RoutineDetailViewController
- **Inheritance**: Extends `NNSheetViewController` (following established pattern)
- **UI Components**:
  - Uses existing `titleLabel` and `titleField` from base class
  - Custom content added via `addContentToContainer()` method
  - Collection/Table view for routine actions
  - Folder label display (bottom left positioning)
  - Inline "Add routine item" row (when `!isReadOnly` and under 10 actions)

#### Cell Design Specifications
- **Layout**: Plain style with no separators
- **Components per cell**:
  - Leading square checkbox
  - Multi-line text label (as many lines as needed)
  - Top-leading alignment for both elements
- **Completion State**: Strikethrough text style when marked complete
- **No Reordering**: Actions maintain creation order (no drag-to-reorder)

#### Add Action Row
- **Inline Editing**: Text field appears directly in the collection/table view
- **Placement**: Bottom row when `!isReadOnly` and `routineActions.count < 10`
- **Behavior**: Tap to focus, return key to save and add action

### 4. State Management

#### Daily Reset System
- **Storage**: UserDefaults-based completion tracking
- **Scope**: Daily basis with timezone-aware midnight reset
- **Key Structure**: `routine_[routineID]_[dateString]_completed_actions`
- **No Backend Persistence**: Completion states are local-only
- **Timezone Handling**: Uses user's local timezone for midnight reset calculation

#### Completion Tracking
```swift
// Example UserDefaults structure
"routine_ABC123_2025-01-30_completed_actions": [0, 2, 4] // Array of completed indices

// Timezone-aware reset logic
private func shouldResetCompletionState(for routineId: String) -> Bool {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let lastResetKey = "routine_\(routineId)_last_reset"
    
    if let lastReset = UserDefaults.standard.object(forKey: lastResetKey) as? Date {
        return !calendar.isDate(lastReset, inSameDayAs: today)
    }
    return true
}
```

## Feature Requirements

### Core Functionality
1. **Create Routine**: Add new routine with title and initial actions
2. **View Routine**: Display routine in read-only mode
3. **Edit Routine**: Modify title and actions (up to 10 actions max)
4. **Action Management**: Add/remove actions (no reordering, creation order maintained)
5. **Inline Action Addition**: Add new actions directly in the list view
6. **Completion Tracking**: Mark individual actions as complete
7. **Daily Reset**: Automatic timezone-aware reset of completion states at midnight

### User Experience
1. **Visual Feedback**: Clear distinction between completed/pending actions
2. **Intuitive Interaction**: Tap to toggle action completion
3. **Consistent UI**: Matches existing sheet presentation patterns
4. **Folder Context**: Clear category/folder indication
5. **Action Limits**: Clear indication when 10-action limit is reached

### Technical Requirements
1. **BaseItem Compliance**: Full integration with unified collection
2. **Sheet Presentation**: Consistent with existing detail views
3. **State Persistence**: Local completion tracking with timezone awareness
4. **Performance**: Efficient rendering for routines with up to 10 actions
5. **No Reordering**: Actions maintain creation order for simplicity

## Development Approach

### Phase 1: Core Implementation
1. Create `RoutineItem` model class with 10-action validation
2. Implement `RoutineDetailViewController` with inline editing
3. Add basic CRUD operations
4. Integrate with Settings screen for testing

### Phase 2: State Management
1. Implement timezone-aware UserDefaults completion tracking
2. Add daily reset mechanism with proper timezone handling
3. Create completion state UI updates
4. Add inline action addition functionality

### Phase 3: Integration & Polish
1. Add to unified collection system
2. Implement proper CRUD through services
3. Add animations and polish
4. Testing and refinement

## Development Integration

### Settings Integration (Development)
- Add debug menu item: "Test Routine Detail"
- Present `RoutineDetailViewController` for testing
- Mock routine data for development/testing

### Existing Pattern Compliance
- Follows `EntryDetailViewController` and `PlaceDetailViewController` patterns
- Uses `NNSheetViewController` base class
- Implements `addContentToContainer()` override
- Standard info button and folder label positioning

## Constraints & Limitations

1. **Action Limit**: Maximum 10 actions per routine
2. **No Reordering**: Actions maintain creation order only
3. **Inline Editing Only**: Add action functionality is inline (no separate sheets)
4. **Local Completion State**: No backend persistence of completion status
5. **Daily Reset**: Completion states reset at user's local midnight

## Success Metrics
- User adoption rate of routine creation
- Average actions per routine (expect 3-7 range)
- Completion rate of routine actions
- User retention after routine feature introduction
- Reduction in repeated manual entry creation for common tasks

## Future Considerations
- Template routines for common scenarios
- Sharing routines between nest owners
- Time-based action scheduling
- Integration with notifications/reminders
- Analytics on most effective routine patterns

---

*This PRD provides a comprehensive foundation for implementing the Routines feature while maintaining consistency with the existing unified collection architecture and user experience patterns. The 10-action limit and inline editing approach ensure simplicity while meeting the core use case of structured, repeatable task lists.*