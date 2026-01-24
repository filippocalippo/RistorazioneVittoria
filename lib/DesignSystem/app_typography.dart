import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Design system typography tokens
/// Provides consistent text styles throughout the app
class AppTypography {
  AppTypography._();

  // Font family (matching HTML reference)
  static String get fontFamily => 'Poppins';

  // Font weights (matching HTML reference: 400, 500, 600, 700)
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;
  static const FontWeight black = FontWeight.w900;

  // Font sizes
  static const double fontSizeXS = 10.0;
  static const double fontSizeSM = 12.0;
  static const double fontSizeMD = 14.0;
  static const double fontSizeLG = 16.0;
  static const double fontSizeXL = 18.0;
  static const double fontSizeXXL = 20.0;
  static const double fontSizeXXXL = 24.0;
  static const double fontSizeHuge = 28.0;
  static const double fontSizeMassive = 32.0;
  static const double fontSizeGiant = 40.0;
  static const double fontSizeColossal = 48.0;

  // Line heights
  static const double lineHeightTight = 1.0;
  static const double lineHeightSnug = 1.1;
  static const double lineHeightNormal = 1.3;
  static const double lineHeightRelaxed = 1.5;
  static const double lineHeightLoose = 1.6;

  // Letter spacing
  static const double letterSpacingTight = -1.5;
  static const double letterSpacingNormal = -0.5;
  static const double letterSpacingWide = 0.3;
  static const double letterSpacingExtraWide = 1.2;
  static const double letterSpacingUltraWide = 1.5;

  // Display styles (Hero text)
  static TextStyle displayLarge = GoogleFonts.poppins(
    fontSize: 72,
    fontWeight: bold,
    color: AppColors.textPrimary,
    height: lineHeightTight,
    letterSpacing: letterSpacingTight,
  );

  static TextStyle displayMedium = GoogleFonts.poppins(
    fontSize: 56,
    fontWeight: bold,
    color: AppColors.textPrimary,
    height: lineHeightTight,
    letterSpacing: letterSpacingTight,
  );

  static TextStyle displaySmall = GoogleFonts.poppins(
    fontSize: fontSizeColossal,
    fontWeight: bold,
    color: AppColors.textPrimary,
    height: lineHeightTight,
    letterSpacing: letterSpacingTight,
  );

  // Headline styles
  static TextStyle headlineLarge = GoogleFonts.poppins(
    fontSize: fontSizeGiant,
    fontWeight: bold,
    color: AppColors.textPrimary,
    height: lineHeightSnug,
    letterSpacing: letterSpacingTight,
  );

  static TextStyle headlineMedium = GoogleFonts.poppins(
    fontSize: fontSizeMassive,
    fontWeight: bold,
    color: AppColors.textPrimary,
    height: lineHeightNormal,
  );

  static TextStyle headlineSmall = GoogleFonts.poppins(
    fontSize: fontSizeHuge,
    fontWeight: bold,
    color: AppColors.textPrimary,
    height: lineHeightNormal,
  );

  // Title styles
  static TextStyle titleLarge = GoogleFonts.poppins(
    fontSize: fontSizeXXL,
    fontWeight: semiBold,
    color: AppColors.textPrimary,
  );

  static TextStyle titleMedium = GoogleFonts.poppins(
    fontSize: fontSizeXL,
    fontWeight: semiBold,
    color: AppColors.textPrimary,
  );

  static TextStyle titleSmall = GoogleFonts.poppins(
    fontSize: fontSizeLG,
    fontWeight: semiBold,
    color: AppColors.textPrimary,
  );

  // Body styles
  static TextStyle bodyLarge = GoogleFonts.poppins(
    fontSize: fontSizeXL,
    fontWeight: regular,
    color: AppColors.textSecondary,
    height: lineHeightLoose,
  );

  static TextStyle bodyMedium = GoogleFonts.poppins(
    fontSize: fontSizeLG,
    fontWeight: regular,
    color: AppColors.textSecondary,
    height: lineHeightRelaxed,
  );

  static TextStyle bodySmall = GoogleFonts.poppins(
    fontSize: fontSizeMD,
    fontWeight: regular,
    color: AppColors.textSecondary,
    height: lineHeightNormal,
  );

  // Label styles (buttons, badges, etc.)
  static TextStyle labelLarge = GoogleFonts.poppins(
    fontSize: fontSizeLG,
    fontWeight: bold,
    color: AppColors.textPrimary,
    letterSpacing: letterSpacingWide,
  );

  static TextStyle labelMedium = GoogleFonts.poppins(
    fontSize: fontSizeMD,
    fontWeight: semiBold,
    color: AppColors.textPrimary,
  );

  static TextStyle labelSmall = GoogleFonts.poppins(
    fontSize: fontSizeSM,
    fontWeight: semiBold,
    color: AppColors.textPrimary,
  );

  // Caption styles
  static TextStyle caption = GoogleFonts.poppins(
    fontSize: fontSizeSM,
    fontWeight: medium,
    color: AppColors.textTertiary,
  );

  static TextStyle captionSmall = GoogleFonts.poppins(
    fontSize: fontSizeXS,
    fontWeight: semiBold,
    color: AppColors.textTertiary,
    letterSpacing: letterSpacingExtraWide,
  );

  // Button styles
  static TextStyle buttonLarge = GoogleFonts.poppins(
    fontSize: fontSizeXL,
    fontWeight: bold,
    letterSpacing: letterSpacingWide,
  );

  static TextStyle buttonMedium = GoogleFonts.poppins(
    fontSize: fontSizeLG,
    fontWeight: bold,
    letterSpacing: letterSpacingWide,
  );

  static TextStyle buttonSmall = GoogleFonts.poppins(
    fontSize: fontSizeMD,
    fontWeight: semiBold,
    letterSpacing: letterSpacingWide,
  );

  // Price styles
  static TextStyle priceLarge = GoogleFonts.poppins(
    fontSize: fontSizeMassive,
    fontWeight: bold,
    color: AppColors.textPrimary,
    height: lineHeightTight,
    letterSpacing: letterSpacingTight,
  );

  static TextStyle priceMedium = GoogleFonts.poppins(
    fontSize: fontSizeXXL,
    fontWeight: bold,
    color: AppColors.textPrimary,
  );

  static TextStyle priceSmall = GoogleFonts.poppins(
    fontSize: fontSizeLG,
    fontWeight: semiBold,
    color: AppColors.textPrimary,
  );
}
