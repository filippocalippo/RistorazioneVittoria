import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rotante/features/manager/models/ingredient_consumption_rule.dart';
import 'package:rotante/features/manager/models/inventory_log.dart';

/// Service for managing ingredient inventory, consumption rules, and stock tracking.
class InventoryService {
  final SupabaseClient _supabase;

  InventoryService(this._supabase);

  // ============================================================
  // STOCK MANAGEMENT
  // ============================================================

  /// Updates the stock of an ingredient and logs the change.
  Future<void> updateStock({
    required String ingredientId,
    required double quantityChange,
    required String reason,
    String? referenceId,
  }) async {
    // Call atomic RPC that updates stock and logs in one transaction
    await _supabase.rpc(
      'adjust_ingredient_stock',
      params: {
        'p_ingredient_id': ingredientId,
        'p_delta': quantityChange,
        'p_reason': reason,
        'p_reference_id': referenceId,
      },
    );
  }

  /// Gets the current stock for an ingredient.
  Future<double> getStock(String ingredientId) async {
    final result = await _supabase
        .from('ingredients')
        .select('stock_quantity')
        .eq('id', ingredientId)
        .single();
    return (result['stock_quantity'] as num?)?.toDouble() ?? 0.0;
  }

  /// Sets the absolute stock value (for corrections/restocking).
  /// Uses atomic server-side locking to ensure log accuracy.
  Future<void> setStock({
    required String ingredientId,
    required double newQuantity,
    required String reason,
    String? referenceId,
  }) async {
    await _supabase.rpc(
      'set_ingredient_stock',
      params: {
        'p_ingredient_id': ingredientId,
        'p_new_quantity': newQuantity,
        'p_reason': reason,
        'p_reference_id': referenceId,
      },
    );
  }

  // ============================================================
  // CONSUMPTION RULES
  // ============================================================

  /// Gets the consumption quantity for an ingredient given size and optional product.
  /// Uses optimized single query with fallback logic.
  Future<double> getConsumption({
    required String ingredientId,
    required String sizeId,
    String? productId,
  }) async {
    // Use optimized query: product-specific first, then general rule
    final query = _supabase
        .from('ingredient_consumption_rules')
        .select('quantity')
        .eq('ingredient_id', ingredientId)
        .eq('size_id', sizeId);

    List<Map<String, dynamic>> results;
    if (productId != null) {
      // Get both specific and general rules, order by specificity
      results = await query
          .or('product_id.eq.$productId,product_id.is.null')
          .order('product_id', ascending: false, nullsFirst: false)
          .limit(1);
    } else {
      // Only general rules
      results = await query.isFilter('product_id', null).limit(1);
    }

    if (results.isNotEmpty) {
      return (results.first['quantity'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  /// Sets or updates a consumption rule.
  Future<void> setConsumptionRule({
    required String ingredientId,
    required String sizeId,
    String? productId,
    required double quantity,
    String? organizationId,
  }) async {
    // Upsert based on (ingredient_id, size_id, product_id)
    final payload = <String, dynamic>{
      'ingredient_id': ingredientId,
      'size_id': sizeId,
      'product_id': productId,
      'quantity': quantity,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (organizationId != null) {
      payload['organization_id'] = organizationId;
    }
    await _supabase.from('ingredient_consumption_rules').upsert(
      payload,
      onConflict: 'ingredient_id,size_id,product_id',
    );
  }

  /// Deletes a consumption rule.
  Future<void> deleteConsumptionRule({
    required String ingredientId,
    required String sizeId,
    String? productId,
  }) async {
    var query = _supabase
        .from('ingredient_consumption_rules')
        .delete()
        .eq('ingredient_id', ingredientId)
        .eq('size_id', sizeId);

    if (productId != null) {
      await query.eq('product_id', productId);
    } else {
      await query.isFilter('product_id', null);
    }
  }

  /// Gets all consumption rules for an ingredient.
  Future<List<IngredientConsumptionRule>> getRulesForIngredient(
    String ingredientId,
  ) async {
    final results = await _supabase
        .from('ingredient_consumption_rules')
        .select()
        .eq('ingredient_id', ingredientId)
        .order('created_at');

    return results
        .map((json) => IngredientConsumptionRule.fromJson(json))
        .toList();
  }

  /// Gets all consumption rules for a product.
  Future<List<IngredientConsumptionRule>> getRulesForProduct(
    String productId,
  ) async {
    final results = await _supabase
        .from('ingredient_consumption_rules')
        .select()
        .eq('product_id', productId)
        .order('created_at');

    return results
        .map((json) => IngredientConsumptionRule.fromJson(json))
        .toList();
  }

  // ============================================================
  // ORDER PROCESSING
  // ============================================================

  /// Deducts stock for all ingredients in an order.
  /// Call this when order is CONFIRMED.
  Future<void> deductStockForOrder({
    required String orderId,
    required List<OrderItemIngredientInfo> items,
  }) async {
    // Aggregate consumption per ingredient
    final Map<String, double> totalConsumption = {};

    for (final item in items) {
      for (final ingredientId in item.ingredientIds) {
        final consumption = await getConsumption(
          ingredientId: ingredientId,
          sizeId: item.sizeId,
          productId: item.productId,
        );

        // Multiply by quantity (e.g., 2 pizzas = 2x consumption)
        final totalForItem = consumption * item.quantity;
        totalConsumption[ingredientId] =
            (totalConsumption[ingredientId] ?? 0) + totalForItem;
      }
    }

    // Deduct all
    for (final entry in totalConsumption.entries) {
      if (entry.value > 0) {
        await updateStock(
          ingredientId: entry.key,
          quantityChange: -entry.value, // Negative for deduction
          reason: 'order',
          referenceId: orderId,
        );
      }
    }
  }

  /// Restores stock for a cancelled order.
  /// Call this when order is CANCELLED.
  Future<void> restoreStockForOrder({
    required String orderId,
    required List<OrderItemIngredientInfo> items,
  }) async {
    // Same logic but positive change
    final Map<String, double> totalConsumption = {};

    for (final item in items) {
      for (final ingredientId in item.ingredientIds) {
        final consumption = await getConsumption(
          ingredientId: ingredientId,
          sizeId: item.sizeId,
          productId: item.productId,
        );

        final totalForItem = consumption * item.quantity;
        totalConsumption[ingredientId] =
            (totalConsumption[ingredientId] ?? 0) + totalForItem;
      }
    }

    for (final entry in totalConsumption.entries) {
      if (entry.value > 0) {
        await updateStock(
          ingredientId: entry.key,
          quantityChange: entry.value, // Positive for restoration
          reason: 'restock',
          referenceId: orderId,
        );
      }
    }
  }

  // ============================================================
  // HISTORY / LOGS
  // ============================================================

  /// Gets inventory logs for an ingredient.
  Future<List<InventoryLog>> getLogsForIngredient(
    String ingredientId, {
    int limit = 50,
    DateTime? from,
    DateTime? to,
  }) async {
    var query = _supabase
        .from('inventory_logs')
        .select()
        .eq('ingredient_id', ingredientId);

    if (from != null) {
      query = query.gte('created_at', from.toIso8601String());
    }
    if (to != null) {
      query = query.lte('created_at', to.toIso8601String());
    }

    final results = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return results.map((json) => InventoryLog.fromJson(json)).toList();
  }

  /// Gets all recent inventory logs.
  Future<List<InventoryLog>> getRecentLogs({int limit = 100}) async {
    final results = await _supabase
        .from('inventory_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return results.map((json) => InventoryLog.fromJson(json)).toList();
  }

  /// Gets logs by order reference.
  Future<List<InventoryLog>> getLogsForOrder(String orderId) async {
    final results = await _supabase
        .from('inventory_logs')
        .select()
        .eq('reference_id', orderId)
        .order('created_at');

    return results.map((json) => InventoryLog.fromJson(json)).toList();
  }
}

/// Helper class to pass order item info for stock calculations.
class OrderItemIngredientInfo {
  final String productId;
  final String sizeId;
  final List<String>
  ingredientIds; // All ingredients (included + extras - removed)
  final int quantity;

  OrderItemIngredientInfo({
    required this.productId,
    required this.sizeId,
    required this.ingredientIds,
    this.quantity = 1,
  });
}
