# Check-Ins Feature - Product Requirements Document

## Executive Summary

The Check-Ins feature enables sitters to provide real-time updates to nest owners during active sessions by submitting photos and captions. This passive communication system ensures transparency and peace of mind for parents while maintaining minimal overhead for sitters.

## Background & Problem Statement

**Problem**: During longer-term stays, nest owners lack visibility into day-to-day activities at their property. This creates anxiety about pet care, child safety, and general home maintenance.

**Current State**: Communication relies on active messaging or phone calls, which can be intrusive and inconsistent.

**Desired State**: A seamless, low-friction system for sitters to provide regular updates without interrupting the flow of their responsibilities.

## Goals & Success Metrics

### Primary Goals
- Increase trust and transparency between sitters and owners
- Reduce owner anxiety during sessions
- Encourage consistent communication patterns
- Maintain sitter workflow efficiency

### Success Metrics
- 75% of active sessions receive at least one check-in
- Average of 2-3 check-ins per day for multi-day sessions
- 90% owner satisfaction with check-in content quality
- <30 second average time to submit a check-in

## User Stories

### Sitter Perspective
- As a sitter, I want to quickly share updates about pets/kids so owners know everything is going well
- As a sitter, I want to document activities with photos so there's a visual record
- As a sitter, I want the process to be fast so it doesn't interrupt my caregiving duties

### Owner Perspective  
- As an owner, I want to see regular updates during sessions so I can relax while away
- As an owner, I want to view check-ins in chronological order so I can follow the story
- As an owner, I want photo evidence that my pets/home are being cared for properly

## Feature Specification

### Data Model

```swift
struct SessionCheckIn: Hashable, Codable {
    let id: String
    let sessionID: String
    let submittedBy: String // Sitter user ID
    let submittedAt: Date
    let caption: String
    let imageURL: String? // Optional photo
    let imageMetadata: ImageMetadata? // Size, format, etc.
    
    init(id: String = UUID().uuidString, 
         sessionID: String, 
         submittedBy: String, 
         caption: String, 
         imageURL: String? = nil) {
        self.id = id
        self.sessionID = sessionID
        self.submittedBy = submittedBy
        self.submittedAt = Date()
        self.caption = caption
        self.imageURL = imageURL
        self.imageMetadata = nil
    }
}

struct ImageMetadata: Codable {
    let originalSize: CGSize
    let fileSize: Int
    let format: String
}
```

### Database Structure
```
nests/{nestId}/sessions/{sessionId}/checkIns/{checkInId}
```

This follows the same pattern as `sessionEvents`, placing check-ins at the same hierarchical level in Firestore.

### User Interface Components

#### Sitter Interface (SitterSessionDetailViewController)
1. **"Add Check-In" Button**: Prominent floating action button or cell in collection view
2. **Check-In Creation Sheet**: 
   - Photo capture/selection interface
   - Text input for caption (max 280 characters)
   - Quick send button
3. **Recent Check-Ins Section**: Show last 2-3 check-ins submitted by sitter

#### Owner Interface (EditSessionViewController)  
1. **Check-Ins Section**: New collection view section showing recent check-ins
2. **Check-In Cell**: Photo thumbnail, caption preview, timestamp
3. **"View All Check-Ins"**: Navigation to detailed check-ins timeline
4. **Check-In Detail View**: Full-screen photo with complete caption

### Technical Implementation

#### Phase 1: Core Functionality
- `SessionCheckIn` model creation
- Basic CRUD operations in `SessionService`
- Photo upload/storage integration
- UI components in both view controllers

#### Phase 2: Enhanced Experience  
- Push notifications for new check-ins
- Photo compression/optimization
- Offline check-in queuing
- Check-in templates/quick actions

### API Design

```swift
// SessionService extensions
extension SessionService {
    func createCheckIn(_ checkIn: SessionCheckIn, image: UIImage?) async throws
    func getCheckIns(for sessionID: String) async throws -> [SessionCheckIn]
    func deleteCheckIn(_ checkInID: String, sessionID: String) async throws
}
```

## Special Considerations

### Privacy & Security
- All check-ins are private to the session participants
- Photos are stored securely with access controls
- Image metadata is stripped to protect location data
- Deletion capabilities for inappropriate content

### Performance
- Image compression before upload (max 1MB)
- Lazy loading of check-in images
- Local caching for recent check-ins
- Background upload with retry logic

### Accessibility
- VoiceOver support for all UI elements
- Dynamic type support for text content
- High contrast image overlays
- Alternative text for uploaded photos

### Internationalization
- All user-facing strings externalized
- RTL layout support
- Cultural considerations for photo content

## Impact Assessment

### Positive Impacts
- **User Engagement**: Increased session activity and communication
- **Trust Building**: Visual proof of quality care
- **Differentiation**: Unique feature vs. competitors
- **Data Collection**: Rich content for improving service quality

### Potential Risks
- **Storage Costs**: Photo storage will increase cloud costs
- **Content Moderation**: Need policies for inappropriate images
- **Performance**: Large images could slow app performance
- **Privacy Concerns**: Photo content may reveal sensitive information

### Mitigation Strategies
- Implement aggressive image compression
- Establish clear content guidelines
- Add photo deletion capabilities
- Limit check-in frequency (e.g., max 10 per day)

## Dependencies

### Technical Dependencies
- Firebase Storage for image hosting
- Image compression libraries
- Camera/photo library permissions
- Network connectivity for uploads

### Business Dependencies  
- Legal review of photo storage/sharing policies
- Content moderation guidelines
- Customer support training for check-in issues

## Success Criteria & KPIs

### Launch Criteria
- [ ] Basic check-in creation/viewing functionality
- [ ] Photo upload/display working
- [ ] Integration with existing session flow
- [ ] Performance testing completed
- [ ] Security review passed

### Post-Launch Metrics (30 days)
- Check-in adoption rate: >60% of active sessions
- Average check-ins per session: >1.5
- Photo attachment rate: >80%
- User satisfaction score: >4.2/5
- Technical performance: <2% error rate

## Timeline

### Phase 1 (4 weeks)
- Week 1: Data model and service layer
- Week 2: Sitter interface implementation  
- Week 3: Owner interface implementation
- Week 4: Testing, polish, and integration

### Phase 2 (2 weeks)
- Week 5-6: Enhanced features and optimizations

## Future Enhancements

- Video check-ins (short clips)
- Check-in templates ("Pet fed", "All good", etc.)
- Automatic check-in reminders
- Check-in analytics for owners
- Integration with smart home devices
- AI-powered content suggestions

---

*This PRD serves as the foundational document for implementing the Check-Ins feature. All technical decisions should align with the architecture patterns established in the existing sessionEvents system.*