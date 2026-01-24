import 'organization_provider.dart';
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

  // Get organization context for multi-tenant filtering
  final orgId = await ref.read(currentOrganizationProvider.future);

  try {
    // Determine start date string (UTC)
    final startDateStr = thirtyDaysAgo.toUtc().toIso8601String();

    // Build base query with inner join to ordini
    var query = supabase
        .from('ordini_items')
        .select(
          'menu_item_id, quantita, ordini!inner(created_at, stato, organization_id)',
        );

    // Multi-tenant filter on the parent ordini table
    if (orgId != null) {
      query = query.or(
        'ordini.organization_id.eq.$orgId,ordini.organization_id.is.null',
      );
    }

    final response = await query
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
