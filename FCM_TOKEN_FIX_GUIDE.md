# FCM Token Fix - Implementation & Testing Guide

## Problem Summary
FCM tokens were not being saved on physical devices after adding Google Sign-In, while working fine in the emulator. This was caused by a timing/race condition where:
1. Firebase initializes at app startup
2. FCM token is retrieved before user authentication completes
3. Token save is skipped because `currentUser == null`

## Changes Made

### 1. Firebase Config (`lib/core/config/firebase_config.dart`)
**Added:**
- `_pendingFcmToken`: Static variable to store FCM token when no user is logged in
- `_setupAuthStateListener()`: Listens for auth state changes and saves pending token when user signs in
- `saveFcmTokenForCurrentUser()`: Public method to manually trigger FCM token save

**Modified:**
- `_saveFcmToken()`: Now stores token as pending if user is not logged in, instead of just skipping
- `initialize()`: Now calls `_setupAuthStateListener()` to set up the auth listener

### 2. Auth Service (`lib/core/services/auth_service.dart`)
**Added:**
- Explicit FCM token save after:
  - Regular email/password sign-in
  - Sign-up
  - Google Sign-In (both native and OAuth flows)

## How It Works Now

### Scenario 1: User Not Logged In (App Startup)
1. Firebase initializes and gets FCM token
2. Token save attempt detects no logged-in user
3. Token is stored in `_pendingFcmToken` variable
4. User logs in via any method (email, Google, etc.)
5. Auth state listener detects sign-in event
6. Pending token is automatically saved to database

### Scenario 2: User Logs In
1. User completes authentication (any method)
2. Auth service explicitly calls `FirebaseConfig.saveFcmTokenForCurrentUser()`
3. Token is retrieved from Firebase and saved to database
4. This provides a backup if auth state listener didn't trigger

### Scenario 3: Token Refresh
1. Firebase triggers `onTokenRefresh` event
2. New token is automatically saved via existing listener
3. If user is not logged in, token becomes pending

## Testing on Physical Device

### Step 1: Enable Debug Logging
The logs already include debug messages. Check these key log messages:

**During Firebase initialization:**
```
[Firebase] FCM token retrieved (value hidden for privacy)
```

**If no user logged in:**
```
[Firebase] No user logged in, storing token as pending
```

**After successful login:**
```
[Firebase] 🔐 User signed in, saving pending FCM token
[Firebase] ✓ FCM token saved to database
```

**After Google Sign-In:**
```
[AuthService] Saving FCM token
[Firebase] ✓ FCM token saved to database
```

### Step 2: View Logs on Physical Device

**Option A: Using Android Studio (Recommended)**
1. Connect your phone via USB
2. Enable USB Debugging on your phone
3. Open Android Studio
4. View → Tool Windows → Logcat
5. Filter by "Firebase" or "AuthService"

**Option B: Using Flutter DevTools**
1. Connect your phone via USB
2. Run: `flutter run --release` (or `flutter run`)
3. Press `w` in terminal to open DevTools
4. Go to Logging tab
5. Filter for "Firebase" or "AuthService"

**Option C: Using ADB (Command Line)**
```bash
# View all logs
adb logcat

# Filter for Flutter logs only
adb logcat -s flutter

# Save logs to file
adb logcat > logs.txt
```

### Step 3: Test the Fix

**Test Case 1: Fresh Install**
1. Uninstall the app completely from your phone
2. Install and run the app
3. Sign in with Google (or email)
4. Check logs for: "✓ FCM token saved to database"
5. Verify in Supabase dashboard that `fcm_token` is populated in profiles table

**Test Case 2: Already Installed**
1. Clear app data (Settings → Apps → Rotante → Storage → Clear Data)
2. Launch app
3. Sign in with Google
4. Check logs for token save confirmation
5. Verify in Supabase

**Test Case 3: Token Refresh**
1. While logged in, force a token refresh:
   - Go to device Settings → Apps → Rotante → Storage → Clear Cache
   - Restart the app
2. Check logs for "FCM token refreshed"
3. Verify updated token in Supabase

### Step 4: Verify in Supabase Dashboard

1. Go to Supabase Dashboard
2. Navigate to Table Editor → profiles
3. Find your user record
4. Check that `fcm_token` column has a value
5. Token format should be: `<long-string-of-characters>`

## Additional Debugging

### If Token Still Not Saving

**Check 1: Google Services Configuration**
Ensure `google-services.json` is correct and matches your Firebase project:
- Location: `android/app/google-services.json`
- Verify `package_name` matches your app: "com.example.rotante"

**Check 2: Firebase Console**
1. Go to Firebase Console → Project Settings → Cloud Messaging
2. Verify "Cloud Messaging API" is enabled
3. Check if your device appears in "Test on device" section

**Check 3: Network Issues**
- Ensure phone has internet connection
- Check if Firebase can reach servers
- Try on both WiFi and mobile data

**Check 4: Permissions**
Check Android permissions in device settings:
- Notifications enabled for Rotante
- No battery optimization blocking background services

### Manual Token Check

Add this test code temporarily to verify token retrieval works:

```dart
// In your login screen after successful login, add:
import 'package:firebase_messaging/firebase_messaging.dart';

final token = await FirebaseMessaging.instance.getToken();
print('MANUAL TOKEN CHECK: ${token?.substring(0, 20)}...');
```

## Rollback Instructions

If you need to revert these changes:

```bash
git checkout HEAD -- lib/core/config/firebase_config.dart
git checkout HEAD -- lib/core/services/auth_service.dart
```

## Expected Behavior After Fix

✅ **Emulator:** Token saves immediately after login (as before)  
✅ **Physical Device:** Token saves after login (now fixed)  
✅ **Session Restore:** Pending token saves when app restarts with active session  
✅ **Token Refresh:** New tokens automatically update in database  
✅ **All Auth Methods:** Works with email/password, Google Sign-In (native + OAuth)

## Notes

- The auth state listener provides automatic token saving when user logs in
- Explicit `saveFcmTokenForCurrentUser()` calls provide redundancy
- Token is stored as pending if retrieved before user authentication
- No breaking changes to existing functionality
- Safe to deploy - gracefully handles all error cases without crashing

## Success Indicators

You'll know it's working when you see these logs on physical device:

1. `[Firebase] ✓ Firebase initialized`
2. `[Firebase] ✓ FCM permissions granted`
3. `[Firebase] FCM token retrieved`
4. `[AuthService] Google sign-in completed successfully` (or regular sign-in)
5. `[AuthService] Saving FCM token`
6. `[Firebase] ✓ FCM token saved to database`

If you see all of these, your FCM token is successfully saved! 🎉
