import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/logger.dart';
import 'auth_provider.dart';

part 'heatmap_data_provider.g.dart';

/// Model for heatmap statistics
class HeatmapStats {
  final int totalOrders;
  final int geocodedOrders;
  final Map<String, int> ordersByZone;
  final Map<int, int> ordersByHour;
  final DateTime? oldestOrder;
  final DateTime? newestOrder;

  const HeatmapStats({
    required this.totalOrders,
    required this.geocodedOrders,
    required this.ordersByZone,
    required this.ordersByHour,
    this.oldestOrder,
    this.newestOrder,
  });

  /// Get the most popular delivery zone
  String? get topZone {
    if (ordersByZone.isEmpty) return null;
    return ordersByZone.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Get the peak delivery hour
  int? get peakHour {
    if (ordersByHour.isEmpty) return null;
    return ordersByHour.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Get coverage percentage (geocoded/total)
  double get coveragePercent {
    if (totalOrders == 0) return 0;
    return (geocodedOrders / totalOrders) * 100;
  }
}

/// Data class for heatmap result
class HeatmapData {
  final List<WeightedLatLng> points;
  final HeatmapStats stats;
  final LatLng? center;

  const HeatmapData({required this.points, required this.stats, this.center});

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;
}

/// Provider for fetching delivery heatmap data
/// Fetches orders from the last 2 months with geocoded positions
@riverpod
Future<HeatmapData> deliveryHeatmapData(Ref ref) async {
  final user = ref.watch(authProvider).value;
  if (user == null) {
    return const HeatmapData(
      points: [],
      stats: HeatmapStats(
        totalOrders: 0,
        geocodedOrders: 0,
        ordersByZone: {},
        ordersByHour: {},
      ),
    );
  }

  try {
    // Calculate date range (last 2 months)
    final now = DateTime.now();
    final twoMonthsAgo = DateTime(now.year, now.month - 2, now.day);

    Logger.info(
      'Fetching heatmap data from ${twoMonthsAgo.toIso8601String()} to ${now.toIso8601String()}',
      tag: 'HeatmapProvider',
    );

    // Query orders with geocoded positions only
    final response = await SupabaseConfig.client
        .from('ordini')
        .select('''
          id,
          tipo,
          latitude_consegna,
          longitude_consegna,
          citta_consegna,
          zone,
          created_at,
          slot_prenotato_start
        ''')
        .eq('tipo', 'delivery')
        .not('latitude_consegna', 'is', null)
        .not('longitude_consegna', 'is', null)
        .gte('created_at', twoMonthsAgo.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(2000); // Safety limit

    final orders = response as List<dynamic>;

    Logger.info(
      'Fetched ${orders.length} geocoded delivery orders for heatmap',
      tag: 'HeatmapProvider',
    );

    if (orders.isEmpty) {
      return const HeatmapData(
        points: [],
        stats: HeatmapStats(
          totalOrders: 0,
          geocodedOrders: 0,
          ordersByZone: {},
          ordersByHour: {},
        ),
      );
    }

    // Convert to weighted lat/lng points
    final points = <WeightedLatLng>[];
    final ordersByZone = <String, int>{};
    final ordersByHour = <int, int>{};
    DateTime? oldestOrder;
    DateTime? newestOrder;

    double latSum = 0;
    double lngSum = 0;

    for (final order in orders) {
      final lat = (order['latitude_consegna'] as num?)?.toDouble();
      final lng = (order['longitude_consegna'] as num?)?.toDouble();

      if (lat != null && lng != null) {
        // Add point with weight (default 1.0 for equal weight)
        points.add(WeightedLatLng(LatLng(lat, lng), 1.0));

        latSum += lat;
        lngSum += lng;

        // Track zone statistics
        final zone =
            order['zone'] as String? ??
            order['citta_consegna'] as String? ??
            'Sconosciuta';
        ordersByZone[zone] = (ordersByZone[zone] ?? 0) + 1;

        // Track hourly statistics
        final createdAt =
            order['slot_prenotato_start'] as String? ??
            order['created_at'] as String?;
        if (createdAt != null) {
          final date = DateTime.tryParse(createdAt);
          if (date != null) {
            final hour = date.toLocal().hour;
            ordersByHour[hour] = (ordersByHour[hour] ?? 0) + 1;

            // Track date range
            if (oldestOrder == null || date.isBefore(oldestOrder)) {
              oldestOrder = date;
            }
            if (newestOrder == null || date.isAfter(newestOrder)) {
              newestOrder = date;
            }
          }
        }
      }
    }

    // Calculate center point (average of all coordinates)
    final center = points.isNotEmpty
        ? LatLng(latSum / points.length, lngSum / points.length)
        : null;

    // Get total orders count for coverage calculation
    final totalCountResponse = await SupabaseConfig.client
        .from('ordini')
        .select('id')
        .eq('tipo', 'delivery')
        .gte('created_at', twoMonthsAgo.toUtc().toIso8601String())
        .count();

    final totalOrders = totalCountResponse.count;

    final stats = HeatmapStats(
      totalOrders: totalOrders,
      geocodedOrders: points.length,
      ordersByZone: ordersByZone,
      ordersByHour: ordersByHour,
      oldestOrder: oldestOrder,
      newestOrder: newestOrder,
    );

    Logger.info(
      'Heatmap data ready: ${points.length} points, coverage: ${stats.coveragePercent.toStringAsFixed(1)}%',
      tag: 'HeatmapProvider',
    );

    return HeatmapData(points: points, stats: stats, center: center);
  } catch (e, stack) {
    Logger.error(
      'Failed to fetch heatmap data',
      tag: 'HeatmapProvider',
      error: e,
      stackTrace: stack,
    );
    rethrow;
  }
}
