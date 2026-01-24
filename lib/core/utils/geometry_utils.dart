import 'package:latlong2/latlong.dart';
import '../models/delivery_zone_model.dart';

/// Utility functions for geometric calculations
class GeometryUtils {
  /// Check if a point is inside a polygon using ray casting algorithm
  /// Returns true if the point is inside the polygon
  /// 
  /// This is a robust implementation that handles edge cases:
  /// - Points on edges/vertices
  /// - Horizontal edges
  /// - Ray passing through vertices
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    int intersections = 0;
    final n = polygon.length;

    for (int i = 0; i < n; i++) {
      final v1 = polygon[i];
      final v2 = polygon[(i + 1) % n];

      // Edge case: point is on a vertex
      if (_pointsEqual(point, v1) || _pointsEqual(point, v2)) {
        return true;
      }

      // Skip if edge is horizontal (parallel to ray)
      if (v1.latitude == v2.latitude) continue;

      // Skip if point is not between the edge's latitudes
      if (point.latitude < v1.latitude.min(v2.latitude) ||
          point.latitude > v1.latitude.max(v2.latitude)) {
        continue;
      }

      // Calculate intersection point's longitude
      final intersectionLng = (point.latitude - v1.latitude) *
              (v2.longitude - v1.longitude) /
              (v2.latitude - v1.latitude) +
          v1.longitude;

      // Point is on the edge
      if ((intersectionLng - point.longitude).abs() < 1e-9) {
        return true;
      }

      // Count intersections to the right of the point
      if (intersectionLng > point.longitude) {
        intersections++;
      }
    }

    // Odd number of intersections = inside
    return intersections.isOdd;
  }

  /// Find which zone a point belongs to (highest priority if overlapping)
  static DeliveryZoneModel? findZoneForPoint(
    LatLng point,
    List<DeliveryZoneModel> zones,
  ) {
    if (zones.isEmpty) return null;

    final matchingZones = zones
        .where((zone) => zone.isActive && isPointInPolygon(point, zone.polygon))
        .toList();

    if (matchingZones.isEmpty) return null;

    // Sort by display order (higher = priority) and return first
    matchingZones.sort((a, b) => b.displayOrder.compareTo(a.displayOrder));
    return matchingZones.first;
  }

  /// Calculate polygon area (for validation/ordering)
  static double calculatePolygonArea(List<LatLng> polygon) {
    if (polygon.length < 3) return 0;

    double area = 0;
    final n = polygon.length;

    for (int i = 0; i < n; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % n];
      area += (p1.longitude * p2.latitude) - (p2.longitude * p1.latitude);
    }

    return (area / 2).abs();
  }

  /// Calculate polygon centroid (center point)
  static LatLng calculatePolygonCentroid(List<LatLng> polygon) {
    if (polygon.isEmpty) return const LatLng(0, 0);
    if (polygon.length == 1) return polygon.first;

    double latSum = 0;
    double lngSum = 0;

    for (final point in polygon) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }

    return LatLng(
      latSum / polygon.length,
      lngSum / polygon.length,
    );
  }

  /// Simplify polygon by removing nearly collinear points
  /// Useful for reducing vertex count while maintaining shape
  static List<LatLng> simplifyPolygon(
    List<LatLng> polygon, {
    double tolerance = 0.00001,
  }) {
    if (polygon.length <= 3) return polygon;

    final simplified = <LatLng>[polygon.first];

    for (int i = 1; i < polygon.length - 1; i++) {
      final prev = simplified.last;
      final current = polygon[i];
      final next = polygon[i + 1];

      // Calculate if points are nearly collinear
      final cross = (current.latitude - prev.latitude) *
              (next.longitude - prev.longitude) -
          (current.longitude - prev.longitude) *
              (next.latitude - prev.latitude);

      // Keep point if not collinear
      if (cross.abs() > tolerance) {
        simplified.add(current);
      }
    }

    simplified.add(polygon.last);
    return simplified;
  }

  /// Check if two points are approximately equal
  static bool _pointsEqual(LatLng p1, LatLng p2, {double epsilon = 1e-9}) {
    return (p1.latitude - p2.latitude).abs() < epsilon &&
        (p1.longitude - p2.longitude).abs() < epsilon;
  }

  /// Calculate distance between two points in meters using Haversine formula
  static double calculateDistance(LatLng p1, LatLng p2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, p1, p2);
  }

  /// Check if polygon is clockwise
  static bool isClockwise(List<LatLng> polygon) {
    if (polygon.length < 3) return true;

    double sum = 0;
    final n = polygon.length;

    for (int i = 0; i < n; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % n];
      sum += (p2.longitude - p1.longitude) * (p2.latitude + p1.latitude);
    }

    return sum > 0;
  }

  /// Reverse polygon direction
  static List<LatLng> reversePolygon(List<LatLng> polygon) {
    return polygon.reversed.toList();
  }
}

extension on double {
  double min(double other) => this < other ? this : other;
  double max(double other) => this > other ? this : other;
}
