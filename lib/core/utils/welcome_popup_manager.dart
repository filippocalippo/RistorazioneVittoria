import 'package:shared_preferences/shared_preferences.dart';

/// Manages the welcome popup state in persistent storage
class WelcomePopupManager {
  static const String _storageKey = 'welcome_popup_shown';

  /// Check if the welcome popup has been shown for the current session
  static Future<bool> hasBeenShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getInt(_storageKey) ?? 0;
      return value >= 1;
    } catch (e) {
      return false; // If there's an error, allow showing the popup
    }
  }

  /// Mark the welcome popup as shown
  static Future<void> markAsShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_storageKey, 1);
    } catch (e) {
      // Silently fail - not critical if we can't save
    }
  }

  /// Reset the welcome popup state (call on sign out)
  static Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_storageKey, 0);
    } catch (e) {
      // Silently fail - not critical
    }
  }
}
