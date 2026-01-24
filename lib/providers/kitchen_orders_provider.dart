import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/order_model.dart';
import '../core/services/database_service.dart';
import '../core/services/realtime_service.dart';
import '../core/utils/enums.dart';
import 'auth_provider.dart';
import '../core/exceptions/app_exceptions.dart';

part 'kitchen_orders_provider.g.dart';

/// Provider for fetching active orders for kitchen staff
@riverpod
class KitchenOrders extends _$KitchenOrders {
  @override
  Future<List<OrderModel>> build() async {
    final user = ref.watch(authProvider).value;
    if (user == null) {
      return [];
    }

    final db = DatabaseService();
    // Kitchen sees confirmed, preparing, and ready orders
    return await db.getOrders(
      statuses: [
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.ready,
      ],
      limit: 50,
    );
  }

  /// Refresh orders list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Start preparing an order
  Future<void> startPreparing(String orderId) async {
    final db = DatabaseService();
    final user = ref.read(authProvider).value;
    if (user == null) {
      throw AuthException('Sessione non valida. Effettua di nuovo l\'accesso.');
    }

    await db.updateOrderStatus(
      orderId: orderId,
      status: OrderStatus.preparing,
    );

    // Assign to current user
    await db.assignOrderToKitchen(
      orderId: orderId,
      kitchenUserId: user.id,
    );

    await refresh();
  }

  /// Mark order as ready
  Future<void> markAsReady(String orderId) async {
    final db = DatabaseService();
    final user = ref.read(authProvider).value;
    if (user == null) {
      throw AuthException('Sessione non valida. Effettua di nuovo l\'accesso.');
    }

    await db.updateOrderStatus(
      orderId: orderId,
      status: OrderStatus.ready,
    );
    await refresh();
  }
}

/// Provider for real-time kitchen orders subscription
/// This will auto-refresh when orders change in Supabase
@riverpod
Stream<List<OrderModel>> kitchenOrdersRealtime(Ref ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) {
    return Stream.value([]);
  }

  const watchedStatuses = [
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.ready,
  ];

  final realtime = RealtimeService();
  return realtime
      .watchOrdersByStatus(statuses: watchedStatuses)
      .map((orders) {
        final sorted = [...orders]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return sorted.take(50).toList();
      });
}

/// Provider for filtering kitchen orders by status
@riverpod
List<OrderModel> filteredKitchenOrders(Ref ref, OrderStatus? filterStatus) {
  final orders = ref.watch(kitchenOrdersRealtimeProvider).value ?? [];

  if (filterStatus == null) {
    return orders;
  }

  return orders.where((order) => order.stato == filterStatus).toList();
}

/// Provider that pre-groups orders by status for efficient rendering
/// Prevents repeated filtering on every rebuild
/// Filters orders to show only today's orders
@riverpod
Map<OrderStatus, List<OrderModel>> groupedKitchenOrders(Ref ref) {
  final orders = ref.watch(kitchenOrdersRealtimeProvider).value ?? [];

  // Filter orders to show only today's orders
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  final todayOrders = orders.where((order) {
    // Check if order is for today based on slot_prenotato_start or created_at
    final orderDate = order.slotPrenotatoStart ?? order.createdAt;
    return orderDate.isAfter(todayStart.subtract(const Duration(minutes: 1))) && 
           orderDate.isBefore(todayEnd);
  }).toList();

  final confirmed = <OrderModel>[];
  final preparing = <OrderModel>[];
  final ready = <OrderModel>[];

  // Single pass through today's orders - much more efficient than multiple .where() calls
  // Explicitly exclude cancelled orders
  for (final order in todayOrders) {
    // Skip cancelled orders
    if (order.stato == OrderStatus.cancelled) {
      continue;
    }
    
    switch (order.stato) {
      case OrderStatus.confirmed:
        confirmed.add(order);
        break;
      case OrderStatus.preparing:
        preparing.add(order);
        break;
      case OrderStatus.ready:
        ready.add(order);
        break;
      default:
        break;
    }
  }

  // Sort each group by different criteria
  confirmed.sort((a, b) => _compareByRemainingTime(a, b));
  preparing.sort((a, b) => _compareByStatusChangeTime(a, b, (order) => order.preparazioneAt));
  ready.sort((a, b) => _compareByStatusChangeTime(a, b, (order) => order.prontoAt));

  return {
    OrderStatus.confirmed: confirmed,
    OrderStatus.preparing: preparing,
    OrderStatus.ready: ready,
  };
}

// Helper function to compare orders by remaining time
// ASAP orders (null slot) should come FIRST as they need immediate attention
int _compareByRemainingTime(OrderModel a, OrderModel b) {
  final aTime = a.slotPrenotatoStart;
  final bTime = b.slotPrenotatoStart;
  
  // ASAP orders (no scheduled time) should come FIRST - they need immediate attention
  if (aTime == null && bTime == null) return 0;
  if (aTime == null) return -1;  // a is ASAP, goes to the FRONT
  if (bTime == null) return 1;   // b is ASAP, goes to the FRONT
  
  return aTime.compareTo(bTime); // Earlier time first (less remaining time)
}

// Helper function to compare orders by status change time
int _compareByStatusChangeTime(OrderModel a, OrderModel b, DateTime? Function(OrderModel) getTimeFn) {
  final aTime = getTimeFn(a);
  final bTime = getTimeFn(b);
  
  if (aTime == null && bTime == null) return 0;
  if (aTime == null) return 1;  // a goes to the end
  if (bTime == null) return -1; // b goes to the end
  
  return aTime.compareTo(bTime); // Earlier time first (been in status longer)
}

/// Provider for kitchen statistics
@riverpod
Map<String, dynamic> kitchenStats(Ref ref) {
  final grouped = ref.watch(groupedKitchenOrdersProvider);

  final confirmedOrders = grouped[OrderStatus.confirmed]?.length ?? 0;
  final preparingOrders = grouped[OrderStatus.preparing]?.length ?? 0;
  final readyOrders = grouped[OrderStatus.ready]?.length ?? 0;

  // Calculate average preparation time for completed orders today
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);

  final allOrders = [
    ...grouped[OrderStatus.confirmed] ?? [],
    ...grouped[OrderStatus.preparing] ?? [],
    ...grouped[OrderStatus.ready] ?? [],
  ];

  final completedToday = allOrders
      .where((o) => o.prontoAt != null && o.prontoAt!.isAfter(todayStart))
      .toList();

  double avgPrepTime = 0;
  if (completedToday.isNotEmpty) {
    var totalMinutes = 0.0;
    for (final order in completedToday) {
      if (order.preparazioneAt != null && order.prontoAt != null) {
        totalMinutes += order.prontoAt!.difference(order.preparazioneAt!).inMinutes;
      }
    }
    avgPrepTime = totalMinutes / completedToday.length;
  }

  return {
    'totalActive': allOrders.length,
    'confirmed': confirmedOrders,
    'preparing': preparingOrders,
    'ready': readyOrders,
    'completedToday': completedToday.length,
    'avgPrepTime': avgPrepTime,
  };
}
