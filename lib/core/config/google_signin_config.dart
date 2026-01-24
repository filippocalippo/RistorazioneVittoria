/// Configuration for Google Sign-In
///
/// To set up Google Sign-In:
/// 1. Create OAuth credentials in Google Cloud Console
/// 2. Create Web Client ID (required)
/// 3. Create iOS Client ID (for iOS)
/// 4. Create Android Client ID with SHA-1 fingerprints (for Android)
/// 5. Add Web Client ID and iOS Client ID below
/// 6. Add Web Client ID to Supabase Dashboard under Auth > Providers > Google
/// 7. Enable "Skip nonce check" in Supabase for iOS support
class GoogleSignInConfig {
  // This is required for both Android and iOS
  // Example: "123456789-abcdefghijk.apps.googleusercontent.com"
  static const String webClientId = '353404922411-8j0paha8h8j9hic9egberj8rpgon30f9.apps.googleusercontent.com';

  // TODO: Replace with your actual iOS Client ID from Google Cloud Console
  // This is only used for iOS
  // Example: "123456789-iosiosios.apps.googleusercontent.com"
  static const String iosClientId = 'YOUR_IOS_CLIENT_ID_HERE';

  // Note: Android doesn't need a separate client ID in code
  // It uses the SHA-1 certificate fingerprints you configured in Google Cloud Console
}
