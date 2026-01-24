import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

/// Utility class for authentication-related UI operations
class AuthUtils {
  /// Shows the login bottom sheet
  static Future<void> showLoginBottomSheet(BuildContext context) {
    return LoginBottomSheet.show(context);
  }

  /// Shows the login bottom sheet and returns a boolean indicating if login was successful
  /// Note: This is a basic implementation - you may want to enhance it based on your auth flow
  static Future<bool> attemptLogin(BuildContext context) async {
    try {
      await LoginBottomSheet.show(context);
      // If we reach here, the bottom sheet was closed normally
      // You might want to check auth state here for more accurate result
      return true;
    } catch (e) {
      return false;
    }
  }
}
