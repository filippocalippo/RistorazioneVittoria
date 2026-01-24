# Google Sign-In Setup Guide for Rotante

This guide will walk you through setting up Google Sign-In for your Flutter app on Android and iOS.

## 📋 Prerequisites

- Google Cloud Platform account
- Access to your Supabase dashboard
- Android Studio (for getting SHA-1 fingerprints)
- Xcode (for iOS development)

---

## 🎯 Step 1: Google Cloud Platform Setup

### 1.1 Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Note your project ID for later

### 1.2 Configure OAuth Consent Screen

1. Navigate to **APIs & Credentials** → **OAuth consent screen**
2. Choose **External** user type (or Internal if using Google Workspace)
3. Fill in the required information:
   - **App name**: Rotante
   - **User support email**: Your email
   - **Developer contact information**: Your email
4. Add the following scopes:
   - `.../auth/userinfo.email`
   - `.../auth/userinfo.profile`
   - `openid`
5. Add your privacy policy and terms of service URLs (required for production)
6. Save and continue

### 1.3 Create OAuth Credentials

You need to create **THREE** separate OAuth clients:

#### A. Web Client ID (REQUIRED for all platforms)

1. Go to **APIs & Credentials** → **Credentials**
2. Click **Create Credentials** → **OAuth Client ID**
3. Application type: **Web application**
4. Name: `Rotante Web Client`
5. **Authorized JavaScript origins**: Add your site URL (if using web)
6. **Authorized redirect URIs**: 
   - `https://<your-project-ref>.supabase.co/auth/v1/callback`
   - Replace `<your-project-ref>` with your Supabase project reference
7. Click **Create**
8. **SAVE** the Client ID and Client Secret - you'll need these!

#### B. Android Client ID

1. Click **Create Credentials** → **OAuth Client ID**
2. Application type: **Android**
3. Name: `Rotante Android`
4. Package name: Find this in `android/app/build.gradle` (e.g., `com.example.rotante`)
5. **SHA-1 certificate fingerprint**: 
   
   **For DEBUG builds:**
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   
   **For RELEASE builds:**
   ```bash
   keytool -list -v -keystore <path-to-your-release-keystore> -alias <your-alias>
   ```
   
   Copy the SHA-1 fingerprint (looks like `AA:BB:CC:DD:...`)

6. Click **Create**
7. **IMPORTANT**: Create BOTH debug and release OAuth clients
8. **SAVE** the Client IDs

#### C. iOS Client ID

1. Click **Create Credentials** → **OAuth Client ID**
2. Application type: **iOS**
3. Name: `Rotante iOS`
4. **Bundle ID**: Find this in Xcode or `ios/Runner.xcodeproj/project.pbxproj`
   - Look for `PRODUCT_BUNDLE_IDENTIFIER`
   - Example: `com.example.rotante`
5. **App Store ID**: Leave blank if not published yet
6. **Team ID**: Find in Apple Developer account
7. Click **Create**
8. **SAVE** the Client ID and iOS URL scheme (REVERSED_CLIENT_ID)

---

## 🔧 Step 2: Configure Your Flutter App

### 2.1 Update Google Sign-In Configuration

Open `lib/core/config/google_signin_config.dart` and replace the placeholders:

```dart
class GoogleSignInConfig {
  // Replace with your Web Client ID from Step 1.3.A
  static const String webClientId = 'YOUR-WEB-CLIENT-ID.apps.googleusercontent.com';

  // Replace with your iOS Client ID from Step 1.3.C
  static const String iosClientId = 'YOUR-IOS-CLIENT-ID.apps.googleusercontent.com';
}
```

### 2.2 Configure iOS

Open `ios/Runner/Info.plist` and replace `YOUR_REVERSED_CLIENT_ID_HERE` with the REVERSED_CLIENT_ID from your iOS OAuth client:

```xml
<key>CFBundleURLSchemes</key>
<array>
    <!-- Replace with your actual reversed client ID -->
    <string>com.googleusercontent.apps.123456789-abcdefghijk</string>
</array>
```

**How to find REVERSED_CLIENT_ID:**
- It's shown when you create the iOS OAuth client
- Or reverse your iOS Client ID: `com.googleusercontent.apps.<YOUR_IOS_CLIENT_ID>`

### 2.3 Android Configuration

✅ **Already configured!** The `google_sign_in` package handles Android configuration automatically using your SHA-1 fingerprints from Step 1.3.B.

**Verify your package name** in `android/app/build.gradle`:
```gradle
defaultConfig {
    applicationId "com.example.rotante"  // Must match Google Cloud Console
    // ...
}
```

---

## 🔐 Step 3: Supabase Configuration

### 3.1 Enable Google Provider

1. Go to your [Supabase Dashboard](https://app.supabase.com/)
2. Select your project
3. Navigate to **Authentication** → **Providers**
4. Find **Google** and enable it

### 3.2 Add OAuth Credentials

1. **Client ID**: Paste your **Web Client ID** from Step 1.3.A
2. **Client Secret**: Paste your **Web Client Secret** from Step 1.3.A
3. Click **Save**

### 3.3 Configure Client IDs for Native Sign-In

1. Scroll down to **Client IDs** section
2. Add your **Web Client ID** from Step 1.3.A
3. **Enable "Skip nonce check"** ✅ (Required for iOS support!)
4. Click **Save**

---

## 🧪 Step 4: Testing

### 4.1 Test on Android

#### Debug Build
```bash
flutter run --debug
```
- Uses debug SHA-1 certificate
- Should work if you added the debug OAuth client

#### Release Build
```bash
flutter build apk --release
flutter install
```
- Uses release SHA-1 certificate
- Requires release OAuth client to be configured

### 4.2 Test on iOS

#### Simulator
```bash
flutter run -d "iPhone 15 Pro"
```

#### Physical Device
1. Connect your iPhone
2. Trust the device
3. Run:
```bash
flutter run -d <device-id>
```

### 4.3 Common Test Scenarios

✅ **First-time Google user**
- Should create a new profile with role `customer`
- Should navigate to appropriate home screen

✅ **Existing Google user**
- Should fetch existing profile
- Should update last access timestamp

✅ **User cancels sign-in**
- Should show "Accesso con Google annullato"
- Should not create any records

✅ **Network error**
- Should show appropriate error message

---

## 🐛 Troubleshooting

### "Sign in attempt was canceled by user"
- **Cause**: User closed the Google sign-in popup
- **Solution**: Normal behavior, no action needed

### "Token di accesso Google non disponibile"
- **Cause**: Google authentication failed to return tokens
- **Solution**: 
  - Verify OAuth client IDs are correct
  - Check that SHA-1 fingerprints match (Android)
  - Verify bundle ID matches (iOS)

### iOS: "No valid URL schemes found"
- **Cause**: REVERSED_CLIENT_ID not configured in Info.plist
- **Solution**: Follow Step 2.2 above

### Android: "Sign in failed"
- **Cause**: SHA-1 fingerprint mismatch
- **Solution**: 
  - Generate SHA-1 for current keystore
  - Create/update OAuth client in Google Cloud Console
  - Wait 5-10 minutes for changes to propagate

### "Accesso con Google fallito"
- **Cause**: Supabase authentication failed
- **Solution**:
  - Verify Web Client ID is in Supabase dashboard
  - Ensure "Skip nonce check" is enabled for iOS
  - Check Supabase logs for detailed error

### Profile not created for new Google users
- **Cause**: Database error or network issue
- **Solution**: 
  - Check Supabase logs
  - Verify `profiles` table schema
  - Ensure `profiles` table has proper RLS policies

---

## 📱 Platform-Specific Notes

### Android

- **Package Name**: Must match exactly in Google Cloud Console and `build.gradle`
- **SHA-1 Fingerprints**: Different for debug and release builds
- **Testing**: Use debug OAuth client for development, release for production

### iOS

- **Bundle ID**: Must match exactly in Google Cloud Console and Xcode
- **REVERSED_CLIENT_ID**: Required in Info.plist
- **URL Scheme**: Used for redirecting back to app after authentication
- **Skip Nonce Check**: Must be enabled in Supabase

---

## 🔒 Security Best Practices

1. **Never commit credentials to Git**
   - The `google_signin_config.dart` file contains placeholder values
   - Consider using environment variables for production

2. **Use different OAuth clients for debug/release**
   - Prevents production users from accessing debug builds

3. **Rotate credentials periodically**
   - Update Web Client Secret in Supabase dashboard
   - Update Client IDs if compromised

4. **Enable only necessary scopes**
   - Current scopes: email, profile, openid
   - Add more only if needed

5. **Monitor authentication logs**
   - Check Supabase auth logs regularly
   - Set up alerts for failed authentication attempts

---

## 📚 Additional Resources

- [Supabase Auth Docs](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [google_sign_in Package](https://pub.dev/packages/google_sign_in)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Apple Developer Console](https://developer.apple.com/account/)

---

## ✅ Checklist

Before deploying to production, ensure:

- [ ] Web Client ID and Secret configured in Supabase
- [ ] "Skip nonce check" enabled in Supabase for iOS
- [ ] Android debug OAuth client created with debug SHA-1
- [ ] Android release OAuth client created with release SHA-1
- [ ] iOS OAuth client created with correct Bundle ID
- [ ] iOS REVERSED_CLIENT_ID configured in Info.plist
- [ ] Google Sign-In Config file updated with real Client IDs
- [ ] OAuth Consent Screen configured with privacy policy
- [ ] Tested on both Android and iOS devices
- [ ] Error handling tested (cancellation, network errors)
- [ ] New user profile creation tested
- [ ] Existing user login tested

---

## 🎉 You're Done!

Once all steps are completed, your users can sign in with Google on both Android and iOS! The router will automatically handle navigation based on the user's role.

If you encounter any issues, check the troubleshooting section above or review the Supabase authentication logs.
