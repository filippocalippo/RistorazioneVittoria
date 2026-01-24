import 'organization_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/enums.dart';
import '../core/utils/logger.dart';
import 'dashboard_analytics_provider.dart';

/// Extended product analytics data with detailed information
class ProductAnalyticsItem {
  final String productName;
  final int salesCount;
  final double revenue;
  final Map<String, int> salesByDay; // Day string -> count
  final Map<String, dynamic> topAddedIngredients; // ingredient name -> count
  final Map<String, dynamic> topRemovedIngredients; // ingredient name -> count

  ProductAnalyticsItem({
    required this.productName,
    required this.salesCount,
    required this.revenue,
    required this.salesByDay,
    required this.topAddedIngredients,
    required this.topRemovedIngredients,
  });
}

/// Global ingredient analytics
class IngredientAnalytics {
  final String name;
  final int count;
  final double totalRevenue;

  IngredientAnalytics({
    required this.name,
    required this.count,
    required this.totalRevenue,
  });
}

/// Complete product analytics data
class ProductAnalyticsData {
  final List<ProductAnalyticsItem> topSellingProducts;
  final List<ProductAnalyticsItem> leastSellingProducts;
  final List<IngredientAnalytics> mostAddedIngredients;
  final List<IngredientAnalytics> mostRemovedIngredients;
  final int totalProductsSold;
  final double totalRevenue;
  final Map<String, int> salesBySize; // Size name -> count

  ProductAnalyticsData({
    required this.topSellingProducts,
    required this.leastSellingProducts,
    required this.mostAddedIngredients,
    required this.mostRemovedIngredients,
    required this.totalProductsSold,
    required this.totalRevenue,
    required this.salesBySize,
  });

  factory ProductAnalyticsData.empty() => ProductAnalyticsData(
    topSellingProducts: [],
    leastSellingProducts: [],
    mostAddedIngredients: [],
    mostRemovedIngredients: [],
    totalProductsSold: 0,
    totalRevenue: 0,
    salesBySize: {},
  );
}

/// Product analytics provider
final productAnalyticsProvider =
    FutureProvider.family<ProductAnalyticsData, DashboardDateFilter>((
      ref,
      filter,
    ) async {
      try {
        final supabase = Supabase.instance.client;
        final startDate = filter.startDate;
        final endDate = filter.endDate;

        // Get organization context for multi-tenant filtering
        final orgId = await ref.read(currentOrganizationProvider.future);

        // Build base query
        var query = supabase.from('ordini').select('*, ordini_items(*)');

        // Multi-tenant filter: org-specific or global (null)
        if (orgId != null) {
          query = query.or('organization_id.eq.$orgId,organization_id.is.null');
        }

        // Fetch orders with items for the selected period
        final ordersResponse = await query
            .or(
              'and(slot_prenotato_start.gte.${startDate.toUtc().toIso8601String()},slot_prenotato_start.lte.${endDate.toUtc().toIso8601String()}),'
              'and(slot_prenotato_start.is.null,created_at.gte.${startDate.toUtc().toIso8601String()},created_at.lte.${endDate.toUtc().toIso8601String()})',
            )
            .neq('stato', OrderStatus.cancelled.name);

        final List<dynamic> ordersData = ordersResponse as List;

        // Accumulators
        final productMap = <String, _ProductAccumulator>{};
        final addedIngredientsMap = <String, _IngredientAccumulator>{};
        final removedIngredientsMap = <String, _IngredientAccumulator>{};
        final salesBySizeMap = <String, int>{}; // Global size tracking

        int totalProductsSold = 0;
        double totalRevenue = 0;

        for (final orderJson in ordersData) {
          final items = orderJson['ordini_items'] as List? ?? [];
          final orderDate = _parseOrderDate(orderJson);
          final dayKey = _formatDayKey(orderDate);

          for (final itemJson in items) {
            final productName =
                itemJson['nome_prodotto'] as String? ?? 'Sconosciuto';
            final quantity = itemJson['quantita'] as int? ?? 1;
            final subtotale =
                (itemJson['subtotale'] as num?)?.toDouble() ?? 0.0;
            final varianti =
                itemJson['varianti'] as Map<String, dynamic>? ?? {};

            totalProductsSold += quantity;
            totalRevenue += subtotale;

            // Accumulate product data
            productMap.putIfAbsent(
              productName,
              () => _ProductAccumulator(name: productName),
            );
            productMap[productName]!.salesCount += quantity;
            productMap[productName]!.revenue += subtotale;
            productMap[productName]!.salesByDay[dayKey] =
                (productMap[productName]!.salesByDay[dayKey] ?? 0) + quantity;

            // Process size
            final sizeData = varianti['size'] as Map<String, dynamic>?;
            if (sizeData != null) {
              final sizeName = sizeData['name'] as String? ?? 'Standard';
              salesBySizeMap[sizeName] =
                  (salesBySizeMap[sizeName] ?? 0) + quantity;
            } else {
              // No size specified, count as "Standard"
              salesBySizeMap['Standard'] =
                  (salesBySizeMap['Standard'] ?? 0) + quantity;
            }

            // Process added ingredients
            final addedIngredients =
                varianti['addedIngredients'] as List? ?? [];
            for (final ing in addedIngredients) {
              final ingMap = ing as Map<String, dynamic>;
              final ingName = ingMap['name'] as String? ?? 'Sconosciuto';
              final ingPrice = (ingMap['price'] as num?)?.toDouble() ?? 0.0;

              // Global accumulator
              addedIngredientsMap.putIfAbsent(
                ingName,
                () => _IngredientAccumulator(name: ingName),
              );
              addedIngredientsMap[ingName]!.count += quantity;
              addedIngredientsMap[ingName]!.totalRevenue +=
                  (ingPrice * quantity);

              // Per-product accumulator
              productMap[productName]!.addedIngredients[ingName] =
                  (productMap[productName]!.addedIngredients[ingName] ?? 0) +
                  quantity;
            }

            // Process removed ingredients
            final removedIngredients =
                varianti['removedIngredients'] as List? ?? [];
            for (final ing in removedIngredients) {
              final ingMap = ing as Map<String, dynamic>;
              final ingName = ingMap['name'] as String? ?? 'Sconosciuto';

              // Global accumulator
              removedIngredientsMap.putIfAbsent(
                ingName,
                () => _IngredientAccumulator(name: ingName),
              );
              removedIngredientsMap[ingName]!.count += quantity;

              // Per-product accumulator
              productMap[productName]!.removedIngredients[ingName] =
                  (productMap[productName]!.removedIngredients[ingName] ?? 0) +
                  quantity;
            }
          }
        }

        // Sort products by sales
        final sortedProducts = productMap.values.toList()
          ..sort((a, b) => b.salesCount.compareTo(a.salesCount));

        // Create top and least selling products lists
        final topProducts = sortedProducts
            .take(15)
            .map(
              (p) => ProductAnalyticsItem(
                productName: p.name,
                salesCount: p.salesCount,
                revenue: p.revenue,
                salesByDay: p.salesByDay,
                topAddedIngredients: _getTopIngredients(p.addedIngredients, 5),
                topRemovedIngredients: _getTopIngredients(
                  p.removedIngredients,
                  5,
                ),
              ),
            )
            .toList();

        final leastProducts = sortedProducts.reversed
            .take(10)
            .map(
              (p) => ProductAnalyticsItem(
                productName: p.name,
                salesCount: p.salesCount,
                revenue: p.revenue,
                salesByDay: p.salesByDay,
                topAddedIngredients: _getTopIngredients(p.addedIngredients, 5),
                topRemovedIngredients: _getTopIngredients(
                  p.removedIngredients,
                  5,
                ),
              ),
            )
            .toList();

        // Sort ingredients
        final sortedAddedIngredients = addedIngredientsMap.values.toList()
          ..sort((a, b) => b.count.compareTo(a.count));

        final sortedRemovedIngredients = removedIngredientsMap.values.toList()
          ..sort((a, b) => b.count.compareTo(a.count));

        final mostAddedIngredients = sortedAddedIngredients
            .take(15)
            .map(
              (i) => IngredientAnalytics(
                name: i.name,
                count: i.count,
                totalRevenue: i.totalRevenue,
              ),
            )
            .toList();

        final mostRemovedIngredients = sortedRemovedIngredients
            .take(15)
            .map(
              (i) => IngredientAnalytics(
                name: i.name,
                count: i.count,
                totalRevenue: 0,
              ),
            )
            .toList();

        // Sort salesBySize by count descending
        final sortedSalesBySize = Map.fromEntries(
          salesBySizeMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)),
        );

        return ProductAnalyticsData(
          topSellingProducts: topProducts,
          leastSellingProducts: leastProducts,
          mostAddedIngredients: mostAddedIngredients,
          mostRemovedIngredients: mostRemovedIngredients,
          totalProductsSold: totalProductsSold,
          totalRevenue: totalRevenue,
          salesBySize: sortedSalesBySize,
        );
      } catch (e, stack) {
        Logger.error(
          'Product Analytics Error: $e',
          tag: 'ProductAnalytics',
          error: e,
          stackTrace: stack,
        );
        return ProductAnalyticsData.empty();
      }
    });

// Helper functions
DateTime _parseOrderDate(Map<String, dynamic> orderJson) {
  final slotStr = orderJson['slot_prenotato_start'] as String?;
  final createdStr = orderJson['created_at'] as String?;

  if (slotStr != null) {
    return DateTime.parse(slotStr).toLocal();
  }
  return DateTime.parse(
    createdStr ?? DateTime.now().toIso8601String(),
  ).toLocal();
}

String _formatDayKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _getTopIngredients(
  Map<String, int> ingredients,
  int limit,
) {
  final sorted = ingredients.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Map.fromEntries(sorted.take(limit));
}

// Private accumulator classes
class _ProductAccumulator {
  final String name;
  int salesCount = 0;
  double revenue = 0;
  final Map<String, int> salesByDay = {};
  final Map<String, int> addedIngredients = {};
  final Map<String, int> removedIngredients = {};

  _ProductAccumulator({required this.name});
}

class _IngredientAccumulator {
  final String name;
  int count = 0;
  double totalRevenue = 0;

  _IngredientAccumulator({required this.name});
}
