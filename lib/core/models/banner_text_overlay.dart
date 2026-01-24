import 'package:flutter/material.dart';

/// Helper class to parse and handle banner text overlay configuration
class BannerTextOverlay {
  final bool enabled;
  final String? title;
  final String? subtitle;
  final String? ctaText;
  final Color textColor;
  final List<Color> overlayGradient;

  const BannerTextOverlay({
    required this.enabled,
    this.title,
    this.subtitle,
    this.ctaText,
    this.textColor = Colors.white,
    this.overlayGradient = const [
      Color(0x99000000), // rgba(0,0,0,0.6)
      Color(0x00000000), // rgba(0,0,0,0)
    ],
  });

  /// Parse from JSONB data stored in database
  factory BannerTextOverlay.fromJson(Map<String, dynamic>? json) {
    if (json == null || json['enabled'] != true) {
      return const BannerTextOverlay(enabled: false);
    }

    return BannerTextOverlay(
      enabled: true,
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      ctaText: json['cta_text'] as String?,
      textColor: _parseColor(json['text_color'] as String?),
      overlayGradient: _parseGradient(json['overlay_gradient'] as List?),
    );
  }

  /// Parse hex color string to Color object
  static Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return Colors.white;
    
    try {
      // Remove # if present and add FF for full opacity
      final hexColor = colorStr.replaceFirst('#', '').padLeft(6, '0');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }

  /// Parse gradient array from JSONB (rgba strings) to Color list
  static List<Color> _parseGradient(List? gradientList) {
    if (gradientList == null || gradientList.isEmpty) {
      return const [Color(0x99000000), Color(0x00000000)];
    }
    
    return gradientList.map((str) {
      // Parse rgba(r,g,b,a) format
      final match = RegExp(r'rgba\((\d+),(\d+),(\d+),([\d.]+)\)')
          .firstMatch(str.toString());
      
      if (match != null) {
        final r = int.parse(match.group(1)!);
        final g = int.parse(match.group(2)!);
        final b = int.parse(match.group(3)!);
        final a = (double.parse(match.group(4)!) * 255).toInt();
        return Color.fromARGB(a, r, g, b);
      }
      
      // Fallback to semi-transparent black
      return const Color(0x99000000);
    }).toList();
  }

  /// Whether this overlay has any content to display
  bool get hasContent {
    return enabled && (title != null || subtitle != null || ctaText != null);
  }
}
