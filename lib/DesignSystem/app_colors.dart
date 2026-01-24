import 'package:flutter/material.dart';

/// Elegant Design System - Sophisticated color palette with warm beige tones and refined red
class AppColors {
  AppColors._();

  // Background colors (elegant warm light theme)
  static const Color background = Color(0xFFFAF8F5); // warm cream
  static const Color surface = Color(0xFFFFFFFE); // pure white with warmth
  static const Color surfaceLight = Color(0xFFF5F1ED); // soft beige
  static const Color surfaceElevated = Color(0xFFFFFFFF); // elevated white
  static const Color surfaceDark = Color(
    0xFF2C2420,
  ); // warm charcoal (for strong contrast)

  // Beige & Neutral tones (sophisticated warmth)
  static const Color beigeLight = Color(0xFFF5F1ED); // soft linen
  static const Color beige = Color(0xFFE8E0D5); // elegant beige
  static const Color beigeMedium = Color(0xFFD4C5B3); // warm sand
  static const Color beigeDark = Color(0xFFB8A391); // toasted beige
  static const Color taupe = Color(0xFF9B8B7E); // sophisticated taupe
  static const Color warmGray = Color(0xFF6B5F56); // refined warm gray

  // Text colors (refined hierarchy)
  static const Color textPrimary = Color(0xFF2C2420); // warm charcoal
  static const Color textSecondary = Color(0xFF5C4F45); // rich brown
  static const Color textTertiary = Color(0xFF8B7D70); // muted earth
  static const Color textDisabled = Color(0xFFB8A391); // soft taupe

  // Primary color (elegant muted green)
  static const Color primary = Color(0xFFACC7BE); // elegant muted green
  static const Color primaryDark = Color(0xFF8BA89E); // darker muted green
  static const Color primaryLight = Color(0xFFC4D9D2); // lighter muted green
  static const Color primarySubtle = Color(
    0xFFE3EDE9,
  ); // very light muted green

  // Accent colors (elegant & refined)
  static const Color accent = Color(0xFF6B8CAF); // muted slate blue
  static const Color accentLight = Color(0xFF8FA9C3); // light sky blue
  static const Color success = Color(0xFF5B8C5A); // sage green
  static const Color successLight = Color(0xFFE8F3E8); // mint cream
  static const Color error = Color(
    0xFFD4463C,
  ); // refined red (for error states)
  static const Color warning = Color(0xFFCE7B6D); // warm terracotta
  static const Color info = Color(0xFF4A6FA5); // elegant slate blue
  static const Color price = Color(0xFFD4463C); // refined red (for prices)

  // Border colors (subtle & elegant)
  static const Color border = Color(0xFFE8E0D5); // soft beige border
  static const Color borderLight = Color(0xFFF5F1ED); // barely there
  static const Color borderMedium = Color(0xFFD4C5B3); // defined but soft

  // Specialty colors (sophisticated accents)
  static const Color terracotta = Color(0xFFCE7B6D); // warm terracotta
  static const Color terracottaLight = Color(0xFFFAF0EE); // pale terracotta
  static const Color sageGreen = Color(0xFF5B8C5A); // earthy sage
  static const Color sageLight = Color(0xFFE8F3E8); // soft sage
  static const Color warmWhite = Color(0xFFFEF9E7); // golden white
  static const Color ivory = Color(0xFFFFFAF5); // elegant ivory
  static const Color champagne = Color(0xFFF5E6D3); // luxurious champagne
  static const Color rose = Color(0xFFE8D1D1); // dusty rose
  static const Color roseLight = Color(0xFFF8F0F0); // pale rose

  // Gold colors (premium accents for best sellers)
  static const Color gold = Color(0xFFD4AF37); // classic gold
  static const Color goldLight = Color(0xFFF5E6CC); // soft gold
  static const Color goldDark = Color(0xFFB8972E); // deep gold

  // Gradient colors (elegant transitions)
  static List<Color> primaryGradient = [
    const Color(0xFFACC7BE), // elegant muted green
    const Color(0xFFC4D9D2), // lighter muted green
    const Color(0xFFE3EDE9), // very light muted green
  ];

  static List<Color> beigeGradient = [
    const Color(0xFFE8E0D5), // elegant beige
    const Color(0xFFF5F1ED), // soft linen
    const Color(0xFFFEF9E7), // golden white
  ];

  static List<Color> warmGradient = [
    const Color(0xFFF5E6D3), // champagne
    const Color(0xFFE8D1BA), // creamy gold
    const Color(0xFFD4A574), // warm caramel
  ];

  static List<Color> earthGradient = [
    const Color(0xFF9B8B7E), // taupe
    const Color(0xFFB8A391), // toasted beige
    const Color(0xFFD4C5B3), // warm sand
  ];

  static List<Color> successGradient = [
    const Color(0xFF5B8C5A), // sage green
    const Color(0xFF6FA06E), // light sage
    const Color(0xFF8BB88A), // soft sage
  ];

  static List<Color> redGradient = [
    const Color(0xFFD4463C), // refined red
    const Color(0xFFE85D4A), // lighter red
    const Color(0xFFFA8072), // soft red
  ];

  static List<Color> elegantGradient = [
    const Color(0xFFACC7BE), // elegant muted green
    const Color(0xFFC4D9D2), // lighter muted green
    const Color(0xFF6B8CAF), // muted slate blue
    const Color(0xFF8FA9C3), // light sky blue
  ];

  // Backward compatibility aliases
  static List<Color> get orangeGradient => primaryGradient;
  static List<Color> get stoneGradient => beigeGradient;
  static List<Color> get greenGradient => successGradient;
  static List<Color> purpleGradient = [
    const Color(0xFF9B8B7E), // taupe
    const Color(0xFF8B7D70), // muted earth
    const Color(0xFF6B5F56), // warm gray
    const Color(0xFF5C4F45), // rich brown
  ];

  static List<Color> goldGradient = [
    const Color(0xFFD4AF37), // classic gold
    const Color(0xFFF9D857), // bright gold
  ];
}
