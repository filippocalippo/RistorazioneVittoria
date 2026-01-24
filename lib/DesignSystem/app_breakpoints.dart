import 'package:flutter/material.dart';

/// Design system breakpoint tokens
/// Provides consistent responsive breakpoints throughout the app
class AppBreakpoints {
  AppBreakpoints._();

  // Breakpoint values
  static const double mobile = 0;
  static const double mobileLarge = 480;
  static const double tablet = 768;
  static const double desktop = 1024;
  static const double desktopLarge = 1440;
  static const double desktopXL = 1920;

  // Helper methods to check current breakpoint
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < tablet;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tablet && width < desktop;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktop;
  }

  static bool isDesktopLarge(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopLarge;
  }

  // Get current breakpoint name
  static String getCurrentBreakpoint(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileLarge) return 'mobile';
    if (width < tablet) return 'mobileLarge';
    if (width < desktop) return 'tablet';
    if (width < desktopLarge) return 'desktop';
    if (width < desktopXL) return 'desktopLarge';
    return 'desktopXL';
  }

  // Responsive value helper
  static T responsive<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }
}
