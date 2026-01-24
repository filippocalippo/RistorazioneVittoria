// Organization filtering handled by DatabaseService
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/order_model.dart';
import '../core/services/database_service.dart';
import '../core/services/inventory_service.dart';
import '../core/utils/enums.dart';
import 'organization_provider.dart';

part 'manager_orders_provider.g.dart';

/// Provider for fetching all orders for manager view
@riverpod
class ManagerOrders extends _$ManagerOrders {
  @override
  Future<List<OrderModel>> build() async {
    final db = DatabaseService();
    final orgId = await ref.watch(currentOrganizationProvider.future);
    return await db.getOrders(
      limit: 2000, // Increased limit to ensure all daily orders are visible
      organizationId: orgId,
    );
  }

  /// Refresh orders list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Update order status
  /// When status is changed to cancelled, restores inventory stock for trackable ingredients.
  Future<void> updateStatus(String orderId, OrderStatus newStatus) async {
    final db = DatabaseService();

    // If cancelling, restore inventory stock and use specialized cancel method
    if (newStatus == OrderStatus.cancelled) {
      await _restoreInventoryForCancelledOrder(orderId, db);
      await db.cancelOrder(orderId);
    } else {
      await db.updateOrderStatus(orderId: orderId, status: newStatus);
    }
    await refresh();
  }

  /// Restore inventory stock when an order is cancelled
  Future<void> _restoreInventoryForCancelledOrder(
    String orderId,
    DatabaseService db,
  ) async {
    try {
      // Fetch full order details to get items and ingredients
      final order = await db.getOrder(orderId);

      // Get trackable ingredients directly from Supabase
      final supabaseClient = Supabase.instance.client;
      final inventoryService = InventoryService(supabaseClient);

      final orgId = await ref.read(currentOrganizationProvider.future);
      var ingredientsQuery = supabaseClient
          .from('ingredients')
          .select('id, track_stock')
          .eq('track_stock', true);
      if (orgId != null) {
        ingredientsQuery = ingredientsQuery.eq('organization_id', orgId);
      }
      final ingredientsData = await ingredientsQuery;

      final trackableIngredientIds = (ingredientsData as List)
          .map((i) => i['id'] as String)
          .toSet();

      if (trackableIngredientIds.isEmpty) return;

      // Build OrderItemIngredientInfo from order items
      final items = <OrderItemIngredientInfo>[];
      for (final item in order.items) {
        final varianti = item.varianti;
        if (varianti == null) continue;

        final sizeMap = varianti['size'] as Map<String, dynamic>?;
        final sizeId = sizeMap?['id'] as String?;
        if (sizeId == null) continue;

        final productId = item.menuItemId;
        if (productId == null) continue;

        final ingredientIds = <String>[];
        final addedIngredients = varianti['addedIngredients'] as List<dynamic>?;
        if (addedIngredients != null) {
          for (final ing in addedIngredients) {
            if (ing is Map<String, dynamic>) {
              final ingId = ing['id'] as String?;
              if (ingId != null && trackableIngredientIds.contains(ingId)) {
                ingredientIds.add(ingId);
              }
            }
          }
        }

        if (ingredientIds.isNotEmpty) {
          items.add(
            OrderItemIngredientInfo(
              productId: productId,
              sizeId: sizeId,
              ingredientIds: ingredientIds,
              quantity: item.quantita,
            ),
          );
        }
      }

      if (items.isNotEmpty) {
        await inventoryService.restoreStockForOrder(
          orderId: orderId,
          items: items,
        );
        debugPrint('[Inventory] Restored stock for cancelled order $orderId');
      }
    } catch (e) {
      // Non-critical: log error but don't fail the cancellation
      debugPrint('[Inventory] Error restoring stock for cancelled order: $e');
    }
  }

  /// Assign order to kitchen staff
  Future<void> assignToKitchen(String orderId, String kitchenUserId) async {
    final db = DatabaseService();
    await db.assignOrderToKitchen(
      orderId: orderId,
      kitchenUserId: kitchenUserId,
    );
    await refresh();
  }

  /// Assign order to delivery staff
  Future<void> assignToDelivery(String orderId, String deliveryUserId) async {
    final db = DatabaseService();
    await db.assignOrderToDelivery(
      orderId: orderId,
      deliveryUserId: deliveryUserId,
    );
    await refresh();
  }
}

/// Provider for filtering orders by status
@riverpod
List<OrderModel> filteredManagerOrders(Ref ref, OrderStatus? filterStatus) {
  final orders = ref.watch(managerOrdersProvider).value ?? [];

  if (filterStatus == null) {
    return orders;
  }

  return orders.where((order) => order.stato == filterStatus).toList();
}

/// Provider for order statistics
@riverpod
class OrderStats extends _$OrderStats {
  @override
  Map<String, dynamic> build() {
    final orders = ref.watch(managerOrdersProvider).value ?? [];

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

    // Use slot_prenotato_start for scheduled orders, fall back to createdAt
    bool isOrderForToday(OrderModel o) {
      final orderDate = o.slotPrenotatoStart ?? o.createdAt;
      return !orderDate.isBefore(todayStart) && !orderDate.isAfter(todayEnd);
    }

    final todayOrders = orders.where(isOrderForToday).toList();

    final activeOrders = orders
        .where((o) => o.stato.isActive && o.stato != OrderStatus.completed)
        .toList();

    final completedToday = todayOrders
        .where((o) => o.stato == OrderStatus.completed)
        .toList();

    final totalRevenue = completedToday.fold<double>(
      0,
      (sum, order) => sum + order.totale,
    );

    final averageOrderValue = completedToday.isNotEmpty
        ? totalRevenue / completedToday.length
        : 0.0;

    return {
      'totalOrders': orders.length,
      'todayOrders': todayOrders.length,
      'activeOrders': activeOrders.length,
      'completedToday': completedToday.length,
      'totalRevenue': totalRevenue,
      'averageOrderValue': averageOrderValue,
      'pendingOrders': orders
          .where((o) => o.stato == OrderStatus.pending)
          .length,
      'preparingOrders': orders
          .where((o) => o.stato == OrderStatus.preparing)
          .length,
      'readyOrders': orders.where((o) => o.stato == OrderStatus.ready).length,
      'deliveringOrders': orders
          .where((o) => o.stato == OrderStatus.delivering)
          .length,
    };
  }
}
