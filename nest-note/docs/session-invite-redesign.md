# Session Invite System Redesign

## Overview
Plan to update the session invite system to remove the requirement of having a sitter email, making it more accessible for users who don't have established sitter contacts yet.

## Current System Analysis

### Dependencies on Sitter Email
The current system has these email dependencies:
- `Invite` model requires `sitterEmail` field (SessionService.swift:1144)
- `createInviteForSitter()` method requires a `SitterItem` with email (lines 500-503)
- Email is used for linking the invite to saved sitters (line 887)
- Email validation during invite acceptance (lines 842-846)

### Current Flow
1. User must have a sitter with email in their contacts
2. Creates targeted invite for specific sitter email
3. Sitter receives invite code
4. System validates email during acceptance

## Proposed Solution: Flexible Invite System

### 1. New Invite Types
Create two invite types:
- **Targeted Invite**: Has a specific sitter email (maintains current behavior)
- **Open Invite**: No specific sitter, anyone with the code can join

### 2. Updated Models

```swift
// New invite type enum
enum InviteType: String, Codable {
    case targeted    // For specific sitter
    case open        // For anyone with code
}

// Updated Invite model
struct Invite: Codable, Identifiable {
    let id: String
    let nestID: String
    let nestName: String
    let sessionID: String
    let type: InviteType                // NEW: Invite type
    let sitterEmail: String?            // CHANGED: Now optional
    let status: InviteStatus
    let createdAt: Date
    let expiresAt: Date
    let createdBy: String
    let maxAcceptances: Int?            // NEW: For open invites
    let currentAcceptances: Int         // NEW: Track current acceptances
}

// New model for sitter info during open invite acceptance
struct SitterInfo: Codable {
    let name: String
    let email: String?
    let phone: String?
}
```

### 3. Updated Service Methods

```swift
// NEW: Method for creating open invites
func createOpenInvite(
    sessionID: String, 
    maxAcceptances: Int? = 1
) async throws -> String

// UPDATED: Support both invite types
func createInviteForSitter(
    sessionID: String, 
    sitter: SitterItem?  // Now optional
) async throws -> String

// NEW: Handle open invite acceptance with sitter info
func acceptOpenInvite(
    inviteCode: String, 
    sitterInfo: SitterInfo
) async throws -> SitterSession

// UPDATED: Validate invite without email requirement
func validateInvite(code: String) async throws -> (SessionItem, Invite)
```

### 4. Database Schema Changes

#### Invite Collection Updates
- Make `sitterEmail` optional in invite documents
- Add `type` field to distinguish invite types
- Add `maxAcceptances` and `currentAcceptances` for open invites
- Maintain backward compatibility with existing invites

#### Session Collection Updates
- Update session's `assignedSitter` to be nullable initially for open invites
- Add support for multiple sitters per session (future enhancement)

### 5. Implementation Plan

#### Phase 1: Core Model Updates
1. Update `Invite` model with new fields
2. Add `InviteType` enum
3. Create `SitterInfo` model
4. Update database migration strategy

#### Phase 2: Service Layer Updates
1. Add `createOpenInvite()` method
2. Update `createInviteForSitter()` to handle optional sitter
3. Implement `acceptOpenInvite()` method
4. Update validation logic for both invite types

#### Phase 3: UI/UX Updates
1. Add invite type selection in session creation
2. Update invite sharing flow for open invites
3. Create sitter info collection flow for open invite acceptance
4. Update existing targeted invite flows

#### Phase 4: Testing & Migration
1. Test backward compatibility with existing invites
2. Implement database migration for new fields
3. Add analytics for invite type usage
4. Performance testing with multiple invite types

### 6. User Flows

#### Targeted Invite Flow (Existing)
1. User selects specific sitter from contacts
2. Creates targeted invite with sitter email
3. Shares invite code with that sitter
4. Sitter accepts using existing validation

#### New Open Invite Flow
1. User creates session without selecting sitter
2. Creates open invite (no email required)
3. Shares invite code publicly (social media, neighbors, etc.)
4. Any sitter can accept by providing their info
5. System creates new sitter contact for future use

### 7. Benefits

- **Removes Barrier**: Users can create sessions without having sitter contacts
- **Maintains Compatibility**: Existing targeted invite flow continues working
- **Flexible Workflow**: Supports both "I have a specific sitter" and "I need to find a sitter" scenarios
- **Better UX**: Users can share invite codes on social media, with neighbors, etc.
- **Network Growth**: Helps users discover new sitters in their community

### 8. Considerations

#### Security
- Implement rate limiting on open invite creation
- Add reporting mechanism for inappropriate invite usage
- Consider geographic restrictions for open invites

#### Business Logic
- Define rules for multiple acceptances of open invites
- Handle edge cases where session is filled before invite expires
- Plan for future multi-sitter session support

#### Data Management
- Strategy for cleaning up unused open invites
- Analytics on invite type usage and conversion rates
- Performance impact of supporting both invite types

### 9. Migration Strategy

#### Backward Compatibility
- Existing invites treated as `targeted` type by default
- All existing functionality continues to work
- Gradual rollout of open invite features

#### Database Migration
```swift
// Add new fields with defaults for existing documents
- type: "targeted" (default for existing invites)
- maxAcceptances: null (not applicable for targeted)
- currentAcceptances: 0 or 1 based on status
```

## Next Steps

1. **Review and Approval**: Get stakeholder approval for the approach
2. **Technical Design**: Create detailed technical specifications
3. **Prototype**: Build MVP with core open invite functionality
4. **User Testing**: Test new flow with target users
5. **Full Implementation**: Roll out complete solution with analytics

---

*Created: 2025-05-28*  
*Status: Planning Phase*  
*Priority: High - Removes key user adoption barrier*