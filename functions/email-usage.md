# SendGrid Email Functions Usage Guide

## Setup Complete ✅

Your Firebase Functions now have SendGrid email functionality configured with:
- SendGrid dependency installed
- API key configured in Firebase environment
- Three email functions available

## Available Email Functions

### 1. `sendSessionInviteEmail` - Callable Function

Sends a beautifully formatted email invite to sitters.

**Usage from your iOS app:**
```swift
let functions = Functions.functions()
let data: [String: Any] = [
    "sitterEmail": "sitter@example.com",
    "sitterName": "John Doe", 
    "sessionData": [
        "title": "Weekend Pet Sitting",
        "startDate": session.startDate,
        "endDate": session.endDate,
        "location": "123 Main St"
    ],
    "inviteLink": "https://your-app.com/invite/abc123"
]

functions.httpsCallable("sendSessionInviteEmail").call(data) { result, error in
    if let error = error {
        print("Error sending invite: \(error)")
    } else {
        print("Invite sent successfully!")
    }
}
```

### 2. `sendSessionReminderEmail` - Callable Function

Sends reminder emails to session owners or sitters.

**Usage:**
```swift
let data: [String: Any] = [
    "userEmail": "user@example.com",
    "userName": "Jane Smith",
    "sessionData": sessionData,
    "userRole": "owner" // or "sitter"
]

functions.httpsCallable("sendSessionReminderEmail").call(data) { result, error in
    // Handle response
}
```

### 3. `sendEmail` - Generic Email Function

For sending custom emails (admin use).

**Usage:**
```swift
let data: [String: Any] = [
    "to": "recipient@example.com",
    "subject": "Custom Subject",
    "text": "Plain text message",
    "html": "<h1>HTML formatted message</h1>", // optional
    "from": "support@nestnoteapp.com" // optional
]

functions.httpsCallable("sendEmail").call(data) { result, error in
    // Handle response
}
```

## Email Templates Included

### Session Invite Email
- Professional HTML design
- Session details clearly displayed
- Call-to-action button for accepting
- Mobile-responsive layout

### Session Reminder Email  
- Time-sensitive information
- Different messaging for owners vs sitters
- Clean, readable format

## Next Steps

1. **Verify Sender Domain**: In SendGrid, verify your sender domain (currently set to `support@nestnoteapp.com`)
2. **Test Email Functions**: Use the Firebase emulator to test locally
3. **Deploy Functions**: Run `firebase deploy --only functions` to deploy
4. **Integration**: Call these functions from your iOS app when:
   - Sending session invites
   - Session reminders (maybe 1-2 hours before)
   - Other email notifications

## Testing

Test locally with the Firebase emulator:
```bash
firebase emulators:start --only functions
```

## Important Notes

- All functions require user authentication
- SendGrid API key is securely stored in Firebase environment
- Email templates use emoji and modern styling
- Error handling included with detailed logging
- Invalid/expired tokens are automatically cleaned up 