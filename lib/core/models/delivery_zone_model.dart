import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Model for delivery zones with polygon boundaries
class DeliveryZoneModel {
  final String id;
  final String name;
  final Color color;
  final List<LatLng> polygon;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeliveryZoneModel({
    required this.id,
    required this.name,
    required this.color,
    required this.polygon,
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from JSON (from Supabase)
  factory DeliveryZoneModel.fromJson(Map<String, dynamic> json) {
    // Parse color from hex string
    final colorHex = json['color_hex'] as String;
    final color = _parseColor(colorHex);

    // Parse polygon from JSONB array
    final polygonJson = json['polygon'] as List<dynamic>;
    final polygon = polygonJson.map((point) {
      final p = point as Map<String, dynamic>;
      return LatLng(
        (p['lat'] as num).toDouble(),
        (p['lng'] as num).toDouble(),
      );
    }).toList();

    return DeliveryZoneModel(
      id: json['id'] as String,
      name: json['name'] as String,
      color: color,
      polygon: polygon,
      displayOrder: (json['display_order'] as int?) ?? 0,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color_hex': _colorToHex(color),
      'polygon': polygon.map((point) => {
        'lat': point.latitude,
        'lng': point.longitude,
      }).toList(),
      'display_order': displayOrder,
      'is_active': isActive,
    };
  }

  /// Parse hex color string to Color
  static Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  /// Convert Color to hex string
  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  /// Create a copy with updated fields
  DeliveryZoneModel copyWith({
    String? id,
    String? name,
    Color? color,
    List<LatLng>? polygon,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryZoneModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      polygon: polygon ?? this.polygon,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Validate polygon (at least 3 points, no self-intersection)
  bool get isValidPolygon {
    if (polygon.length < 3) return false;
    
    // Check for self-intersection (simplified check)
    // For production, use a more robust algorithm
    return !_hasSelfIntersection();
  }

  /// Check if polygon has self-intersecting edges
  bool _hasSelfIntersection() {
    final n = polygon.length;
    
    for (int i = 0; i < n; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % n];
      
      for (int j = i + 2; j < n; j++) {
        // Skip adjacent edges
        if (j == (i + n - 1) % n) continue;
        
        final p3 = polygon[j];
        final p4 = polygon[(j + 1) % n];
        
        if (_segmentsIntersect(p1, p2, p3, p4)) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// Check if two line segments intersect
  static bool _segmentsIntersect(LatLng p1, LatLng p2, LatLng p3, LatLng p4) {
    final d1 = _direction(p3, p4, p1);
    final d2 = _direction(p3, p4, p2);
    final d3 = _direction(p1, p2, p3);
    final d4 = _direction(p1, p2, p4);
    
    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    
    return false;
  }

  /// Calculate direction for intersection test
  static double _direction(LatLng p1, LatLng p2, LatLng p3) {
    return (p3.latitude - p1.latitude) * (p2.longitude - p1.longitude) -
           (p2.latitude - p1.latitude) * (p3.longitude - p1.longitude);
  }

  @override
  String toString() => 'DeliveryZone(id: $id, name: $name, points: ${polygon.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeliveryZoneModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
