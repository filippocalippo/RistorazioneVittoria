import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/delivery_zone_model.dart';
import '../../../core/utils/enums.dart';
import '../../../core/utils/geometry_utils.dart';

/// Reusable delivery map widget component
class DeliveryMapWidget extends StatelessWidget {
  final LatLng? pizzeriaCenter;
  final Map<String, LatLng> orderLocations;
  final List<OrderModel> orders;
  final List<DeliveryZoneModel> zones;
  final String? selectedOrderId;
  final Function(OrderModel)? onOrderTap;
  final bool showPizzeriaMarker;
  final bool showZones;
  final MapController? mapController;

  /// Radial zone tiers: list of {"km": double, "price": double}
  final List<Map<String, dynamic>> radialZones;

  const DeliveryMapWidget({
    super.key,
    this.pizzeriaCenter,
    required this.orderLocations,
    required this.orders,
    this.zones = const [],
    this.selectedOrderId,
    this.onOrderTap,
    this.showPizzeriaMarker = true,
    this.showZones = true,
    this.mapController,
    this.radialZones = const [],
  });

  @override
  Widget build(BuildContext context) {
    final center = pizzeriaCenter ?? const LatLng(37.507877, 15.083012);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 13.0,
          minZoom: 10.0,
          maxZoom: 18.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.rotante.app',
            retinaMode: RetinaMode.isHighDensity(context),
          ),
          // Radial zone circles
          if (radialZones.isNotEmpty && pizzeriaCenter != null)
            CircleLayer(circles: _buildRadialZoneCircles()),
          // Zone polygons
          if (showZones && zones.isNotEmpty)
            PolygonLayer(
              polygons: zones.map((zone) {
                return Polygon(
                  points: zone.polygon,
                  color: zone.color.withValues(alpha: 0.2),
                  borderColor: zone.color,
                  borderStrokeWidth: 2,
                  label: zone.name,
                  labelStyle: TextStyle(
                    color: zone.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          MarkerLayer(markers: _buildMarkers()),
        ],
      ),
    );
  }

  List<CircleMarker> _buildRadialZoneCircles() {
    if (pizzeriaCenter == null || radialZones.isEmpty) return [];

    // Sort radial zones by km descending so larger circles are drawn first
    final sortedZones = List<Map<String, dynamic>>.from(radialZones)
      ..sort(
        (a, b) => ((b['km'] as num?) ?? 0).compareTo((a['km'] as num?) ?? 0),
      );

    // Use a color gradient from green (close) to red (far)
    final colors = [
      const Color(0xFF10b981), // Green (innermost)
      const Color(0xFF3b82f6), // Blue
      const Color(0xFFf59e0b), // Amber
      const Color(0xFFef4444), // Red (outermost)
    ];

    return sortedZones.asMap().entries.map((entry) {
      final index = entry.key;
      final zone = entry.value;
      final km = (zone['km'] as num?)?.toDouble() ?? 0;

      // Pick color based on index (cycling through available colors)
      final colorIndex = (sortedZones.length - 1 - index) % colors.length;
      final color = colors[colorIndex];

      return CircleMarker(
        point: pizzeriaCenter!,
        radius: km * 1000, // Convert km to meters
        useRadiusInMeter: true,
        color: color.withValues(alpha: 0.15),
        borderColor: color,
        borderStrokeWidth: 2,
      );
    }).toList();
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Add pizzeria marker
    if (showPizzeriaMarker && pizzeriaCenter != null) {
      markers.add(
        Marker(
          point: pizzeriaCenter!,
          width: 60,
          height: 60,
          child: _buildPizzeriaMarker(),
        ),
      );
    }

    // Add order markers
    for (final order in orders) {
      final position = orderLocations[order.id];
      if (position == null) continue;

      final isSelected = selectedOrderId == order.id;

      // Determine color: zone color takes priority over status color
      final zone = GeometryUtils.findZoneForPoint(position, zones);
      final color = zone?.color ?? _getOrderColor(order);
      final icon = _getOrderIcon(order);

      markers.add(
        Marker(
          point: position,
          width: 52,
          height: 52,
          child: GestureDetector(
            onTap: onOrderTap != null ? () => onOrderTap!(order) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: zone != null
                      ? zone.color.withValues(alpha: 0.3)
                      : Colors.white,
                  width: isSelected ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: isSelected ? 14 : 10,
                    spreadRadius: isSelected ? 2.5 : 1.5,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: isSelected ? 26 : 22,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildPizzeriaMarker() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.storefront_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Color _getOrderColor(OrderModel order) {
    switch (order.stato) {
      case OrderStatus.ready:
        return AppColors.success;
      case OrderStatus.delivering:
        return AppColors.info;
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getOrderIcon(OrderModel order) {
    switch (order.stato) {
      case OrderStatus.ready:
        return Icons.shopping_bag_rounded;
      case OrderStatus.delivering:
        return Icons.delivery_dining_rounded;
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
        return Icons.restaurant_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }
}
