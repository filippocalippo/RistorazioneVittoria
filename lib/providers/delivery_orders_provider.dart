import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/order_model.dart';
import '../core/services/database_service.dart';
import '../core/services/realtime_service.dart';
import '../core/utils/enums.dart';
import 'auth_provider.dart';
import '../core/exceptions/app_exceptions.dart';
import '../core/utils/logger.dart';
import 'organization_provider.dart';

part 'delivery_orders_provider.g.dart';

/// Provider for fetching orders ready for delivery
@riverpod
class DeliveryOrders extends _$DeliveryOrders {
  @override
  Future<List<OrderModel>> build() async {
    final user = ref.watch(authProvider).value;
    if (user == null) {
      return [];
    }

    final db = DatabaseService();
    final orgId = await ref.watch(currentOrganizationProvider.future);
    // Delivery sees ready and delivering orders
    return await db.getOrders(
      statuses: [OrderStatus.ready, OrderStatus.delivering],
      limit: 50,
      organizationId: orgId,
    );
  }

  /// Refresh orders list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Start delivering an order
  Future<void> startDelivering(String orderId) async {
    final db = DatabaseService();
    final user = ref.read(authProvider).value;
    if (user == null) {
      throw AuthException('Sessione non valida. Effettua di nuovo l\'accesso.');
    }

    await db.updateOrderStatus(
      orderId: orderId,
      status: OrderStatus.delivering,
    );

    // Assign to current delivery user
    await db.assignOrderToDelivery(orderId: orderId, deliveryUserId: user.id);

    await refresh();
  }

  /// Mark order as completed
  Future<void> completeDelivery(String orderId) async {
    final db = DatabaseService();
    final user = ref.read(authProvider).value;
    if (user == null) {
      throw AuthException('Sessione non valida. Effettua di nuovo l\'accesso.');
    }

    await db.updateOrderStatus(orderId: orderId, status: OrderStatus.completed);
    await refresh();
  }
}

/// Provider for real-time delivery orders subscription
/// This will auto-refresh when orders change in Supabase
/// Shows all orders assigned to the current delivery driver that are NOT completed or cancelled
@riverpod
Stream<List<OrderModel>> deliveryOrdersRealtime(Ref ref) {
  final user = ref.watch(authProvider).value;
  final userId = user?.id;

  if (userId == null) {
    return Stream.value([]);
  }

  // Include all active statuses - filter out only completed and cancelled
  const watchedStatuses = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.delivering,
  ];

  final realtime = RealtimeService();
  final orgIdFuture = ref.watch(currentOrganizationProvider.future);
  return Stream.fromFuture(orgIdFuture).asyncExpand((orgId) {
    return realtime
        .watchOrdersByStatus(
          statuses: watchedStatuses,
          limit: 200,
          organizationId: orgId,
        )
        .map((orders) {
    Logger.debug(
      'Delivery realtime update: ${orders.length} orders for filtering',
      tag: 'DeliveryOrders',
    );

    // Filter only delivery orders assigned to this delivery driver
    final myOrders = orders.where((order) {
      return order.tipo == OrderType.delivery &&
          order.assegnatoDeliveryId == userId;
    }).toList();

    Logger.debug(
      'Delivery realtime filtered to ${myOrders.length} assigned orders',
      tag: 'DeliveryOrders',
    );

    // Return orders sorted by createdAt (default order, user can reorder in UI)
    final sorted = [...myOrders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  });
  });
}

/// Provider for filtering delivery orders by status
@riverpod
List<OrderModel> filteredDeliveryOrders(Ref ref, OrderStatus? filterStatus) {
  final orders = ref.watch(deliveryOrdersRealtimeProvider).value ?? [];

  if (filterStatus == null) {
    return orders;
  }

  return orders.where((order) => order.stato == filterStatus).toList();
}

/// Provider for delivery statistics
@riverpod
Map<String, dynamic> deliveryStats(Ref ref) {
  final orders = ref.watch(deliveryOrdersRealtimeProvider).value ?? [];

  final readyOrders = orders.where((o) => o.stato == OrderStatus.ready).length;
  final deliveringOrders = orders
      .where((o) => o.stato == OrderStatus.delivering)
      .length;

  // Calculate average delivery time for completed orders today
  // Note: This would need to be async in a real implementation
  // For now, we'll just use the current orders

  return {
    'totalActive': orders.length,
    'ready': readyOrders,
    'delivering': deliveringOrders,
  };
}
