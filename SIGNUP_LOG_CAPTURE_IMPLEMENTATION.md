# Signup Log Capture Implementation

## Overview
Implemented a comprehensive logging system that captures all application logs during signup and login attempts, then uploads them to Firebase Storage for debugging failed authentication attempts.

## Features Implemented

### 1. Remote Config Toggle
- Added `capture_signup_logs` feature flag to `FeatureFlagService`
- Default value: `false` (for privacy)
- Can be toggled remotely without app update

### 2. SignupLogService
A new service that handles log capture and Firebase Storage upload:

**Key Features:**
- Captures ALL logs during auth process (not just auth-specific logs)
- Generates unique filenames with timestamp and user identifier
- Uploads to Firebase Storage under `signup_logs/` path
- Includes rich metadata (result, error, log count, timestamp)
- Thread-safe with background processing

**File Naming Convention:**
```
signup_{result}_{identifier}_{timestamp}.txt
```

**Examples:**
- `signup_success_user_at_example_com_2025-10-12_14-30-15.txt`
- `signup_failure_apple_signin_1697123456_2025-10-12_14-31-22.txt`

### 3. Integration Points
Updated all authentication methods in `UserService.swift`:

- ✅ `login(email:password:)` - Regular email/password login
- ✅ `signUp(with:)` - Regular email/password signup
- ✅ `signInWithApple(credential:)` - Apple Sign In (login)
- ✅ `signUpWithApple(credential:with:)` - Apple Sign In (signup)
- ✅ `completeAppleSignUp(with:)` - Apple Sign In profile completion

### 4. Log File Structure
Each uploaded file contains:
```
=================================
NEST NOTE SIGNUP LOG
=================================
Signup Result: SUCCESS/FAILURE
Identifier: user@example.com
Error: none / error message
Timestamp: 2025-10-12T14:30:15Z
Total Log Lines: 47
=================================

14:30:01 [INFO] 📋 LOG CAPTURE: Started capturing logs...
14:30:02 [INFO] Attempting signup for email: user@example.com
14:30:03 [DEBUG] Firebase user created successfully
... (all captured logs)
14:30:15 [INFO] 📋 LOG CAPTURE: Signup attempt completed

=================================
END OF LOG
=================================
```

### 5. Privacy & Security
- **Default OFF**: Feature is disabled by default
- **Remote Control**: Can be toggled via Firebase Remote Config
- **No Sensitive Data**: Only captures standard application logs
- **Identifier Sanitization**: Email addresses are sanitized in filenames

## Usage Instructions

### For Development/Testing
1. Enable the feature flag in Firebase Console:
   ```
   capture_signup_logs = true
   ```

2. For debug builds, you can test with:
   ```swift
   #if DEBUG
   await SignupLogService.shared.simulateSignupLogCapture(testIdentifier: "test_user")
   #endif
   ```

### For Production
1. Keep feature flag `false` by default
2. Enable temporarily when investigating specific issues
3. Disable after collecting necessary logs

## Files Modified

### New Files
- `nest-note/Services/SignupLogService.swift` - Main service implementation

### Modified Files
- `nest-note/Services/FeatureFlagService.swift` - Added capture_signup_logs flag
- `nest-note/Services/UserService.swift` - Integrated log capture into all auth methods

## Firebase Storage Structure
```
gs://nest-note-21a2a.firebasestorage.app/
└── signup_logs/
    ├── signup_success_user1_at_example_com_2025-10-12_14-30-15.txt
    ├── signup_failure_user2_at_test_com_2025-10-12_14-35-22.txt
    └── signup_success_apple_signin_1697123456_2025-10-12_15-01-45.txt
```

## Benefits
1. **Comprehensive Debugging**: Captures the full context around authentication failures
2. **Privacy Conscious**: Controlled by remote config, off by default
3. **Unique Identification**: Even without user IDs, each attempt has a unique identifier
4. **Both Success & Failure**: Captures both outcomes to compare patterns
5. **Rich Metadata**: Firebase Storage metadata makes files easily searchable

## Next Steps
1. Monitor Firebase Console for remote config deployment
2. Test in development environment
3. Enable temporarily in production when needed for specific debugging
4. Consider adding log retention policies in Firebase Storage