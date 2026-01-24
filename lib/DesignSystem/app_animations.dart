import 'package:flutter/material.dart';

/// Design system animation tokens
/// Provides consistent animation durations and curves throughout the app
class AppAnimations {
  AppAnimations._();

  // Duration tokens
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration slower = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);

  // Curve tokens
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve bounceOut = Curves.bounceOut;
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
  static const Curve decelerate = Curves.decelerate;

  // Semantic animations
  static const Duration buttonPress = instant;
  static const Duration cardHover = fast;
  static const Duration pageTransition = medium;
  static const Duration modalOpen = medium;
  static const Duration fadeIn = slow;
  static const Duration slideIn = medium;

  // Scale animations
  static const double scalePressed = 0.95;
  static const double scaleHover = 1.02;
  static const double scaleButton = 0.85;

  // Slide offsets
  static const double slideOffsetSmall = 0.05;
  static const double slideOffsetMedium = 0.1;
  static const double slideOffsetLarge = 0.3;

  // Stagger delays (for list animations)
  static Duration staggerDelay(int index, {int delayMs = 50}) {
    return Duration(milliseconds: index * delayMs);
  }

  // Common animation combinations
  static const Duration heroAnimation = Duration(milliseconds: 8000);
  static const Curve heroAnimationCurve = Curves.easeInOutQuad;
}
