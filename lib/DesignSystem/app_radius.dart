import 'package:flutter/material.dart';

/// Design system border radius tokens
/// Provides consistent corner radius values throughout the app
class AppRadius {
  AppRadius._();

  // Radius values
  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 28.0;
  static const double huge = 32.0;
  static const double massive = 40.0;

  // Semantic radius
  static const double button = lg; // 16px
  static const double buttonLarge = xl; // 20px
  static const double card = xxl; // 24px
  static const double cardLarge = xxxl; // 28px
  static const double input = lg; // 16px
  static const double chip = sm; // 8px
  static const double chipLarge = md; // 12px
  static const double badge = md; // 12px
  static const double modal = huge; // 32px
  static const double modalLarge = massive; // 40px
  static const double image = lg; // 16px
  static const double imageLarge = xl; // 20px

  // Border radius helpers
  static BorderRadius radiusXS = BorderRadius.circular(xs);
  static BorderRadius radiusSM = BorderRadius.circular(sm);
  static BorderRadius radiusMD = BorderRadius.circular(md);
  static BorderRadius radiusLG = BorderRadius.circular(lg);
  static BorderRadius radiusXL = BorderRadius.circular(xl);
  static BorderRadius radiusXXL = BorderRadius.circular(xxl);
  static BorderRadius radiusXXXL = BorderRadius.circular(xxxl);
  static BorderRadius radiusHuge = BorderRadius.circular(huge);
  static BorderRadius radiusMassive = BorderRadius.circular(massive);

  // Circular radius (for pills/fully rounded)
  static const double circular = 999.0;
  static BorderRadius radiusCircular = BorderRadius.circular(circular);
}
