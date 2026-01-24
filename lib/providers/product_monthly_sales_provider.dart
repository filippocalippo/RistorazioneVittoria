import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/logger.dart';

/// Provider for aggregated monthly sales stats per product.
/// Returns a `Map<String, int>` where Key is menu_item_id and Value is quantity sold in last 30 days.
final productMonthlySalesProvider = FutureProvider<Map<String, int>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));

  try {
    // Determine start date string (UTC)
    final startDateStr = thirtyDaysAgo.toUtc().toIso8601String();

    // Fetch order items from valid orders in the last 30 days
    // We use a direct query to join ordini_items with ordini
    // Since we can't easily do a join with aggregate in one step with the standard client without raw SQL or Views,
    // we'll fetch the relevant items and aggregate in Dart.
    // This is "performance effective" because we only select 2 columns.

    // Note: To filter by ordini.created_at, we need correct foreign key usage.
    // Assuming 'ordini' table has 'created_at' and 'stato'.
    // We use !inner join to filter ordini_items based on ordini properties.

    final response = await supabase
        .from('ordini_items')
        .select('menu_item_id, quantita, ordini!inner(created_at, stato)')
        .gte('ordini.created_at', startDateStr)
        .neq('ordini.stato', 'cancelled');

    final List<dynamic> data = response as List;
    final salesMap = <String, int>{};

    for (final row in data) {
      final menuItemId = row['menu_item_id'] as String?;
      final quantity = row['quantita'] as int? ?? 0;

      if (menuItemId != null && quantity > 0) {
        salesMap[menuItemId] = (salesMap[menuItemId] ?? 0) + quantity;
      }
    }

    Logger.info(
      'Fetched monthly sales stats for ${salesMap.length} products',
      tag: 'ProductMonthlySales',
    );

    return salesMap;
  } catch (e, stack) {
    Logger.error(
      'Failed to fetch monthly sales stats: $e',
      tag: 'ProductMonthlySales',
      error: e,
      stackTrace: stack,
    );
    // Return empty map on error to allow app to function without sorting
    return {};
  }
});
