import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/order_model.dart';
import '../core/models/user_model.dart';
import '../core/services/database_service.dart';
import '../core/services/realtime_service.dart';
import '../core/utils/enums.dart';
import '../core/utils/logger.dart';
import 'auth_provider.dart';

/// Active order statuses considered for customer tracking.
/// Completed orders are included but filtered out if older than 12 hours.
const List<OrderStatus> _activeOrderStatuses = [
  OrderStatus.pending,
  OrderStatus.confirmed,
  OrderStatus.preparing,
  OrderStatus.ready,
  OrderStatus.delivering,
  OrderStatus.completed, // Will be filtered by age in _isCompletedOrderTooOld
];

/// Terminal order statuses that should be filtered out
const List<OrderStatus> _terminalOrderStatuses = [
  OrderStatus.cancelled, // Only cancelled is truly terminal
];

/// Provider that exposes the customer's in-progress orders with realtime updates.
final customerOrdersProvider = AutoDisposeAsyncNotifierProvider<
    CustomerOrdersNotifier, List<OrderModel>>(CustomerOrdersNotifier.new);

/// Provider that exposes customer order statistics.
final customerOrderStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final ordersAsync = ref.watch(customerOrdersProvider);
  
  return ordersAsync.when(
    data: (orders) {
      final totalOrders = orders.length;
      final totalSpent = orders
          .where((order) => order.stato.isCompleted)
          .fold<double>(0.0, (sum, order) => sum + order.totale);
      final activeOrders = orders
          .where((order) => !order.stato.isCompleted && order.stato != OrderStatus.cancelled)
          .length;
      
      return {
        'totalOrders': totalOrders,
        'totalSpent': totalSpent,
        'activeOrders': activeOrders,
      };
    },
    loading: () => {},
    error: (_, _) => {},
  );
});

class CustomerOrdersNotifier extends AutoDisposeAsyncNotifier<List<OrderModel>> {
  final DatabaseService _database = DatabaseService();
  final RealtimeService _realtime = RealtimeService();

  StreamSubscription<List<OrderModel>>? _ordersSubscription;
  bool _initialLoadComplete = false;

  @override
  FutureOr<List<OrderModel>> build() async {
    // Watch authProvider directly to ensure rebuild on auth changes
    final authState = ref.watch(authProvider);
    
    // If auth is still loading, return empty list and wait for rebuild
    if (authState.isLoading) {
      Logger.debug('Auth still loading, returning empty list', tag: 'CustomerOrders');
      return [];
    }
    
    final user = authState.value;
    
    // Filter to only customers and staff
    final isValidUser = user != null && (user.isCustomer || user.isStaff);

    Logger.debug(
      'Customer orders rebuild (has user: ${user != null}, valid: $isValidUser)',
      tag: 'CustomerOrders',
    );

    // Cancel any previous realtime subscription when rebuilding.
    await _ordersSubscription?.cancel();
    _ordersSubscription = null;
    _initialLoadComplete = false;

    if (!isValidUser) {
      Logger.debug('No authenticated customer available', tag: 'CustomerOrders');
      return [];
    }

    _startRealtimeListener(user);

    final orders = await _fetchOrders(user);
    Logger.debug(
      'Fetched ${orders.length} active orders for current customer',
      tag: 'CustomerOrders',
    );

    _initialLoadComplete = true;
    return orders;
  }

  UserModel? get _currentCustomer {
    final authState = ref.watch(authProvider);
    final user = authState.value;
    if (user == null) {
      return null;
    }
    
    // Allow both customers and staff (managers, kitchen, delivery) to see their own orders
    // Staff might place orders for testing or personal use
    if (!user.isCustomer && !user.isStaff) {
      return null;
    }
    
    return user;
  }

  Future<List<OrderModel>> _fetchOrders(UserModel user) async {
    // Now fetch with status filter
    final orders = await _database.getOrders(
      clienteId: user.id,
      statuses: _activeOrderStatuses,
      limit: 50,
    );

    final filtered = orders
        .where((order) => !_isTerminalStatus(order.stato) && !_isCompletedOrderTooOld(order))
        .toList();

    Logger.debug(
      'Customer orders filtered to ${filtered.length} active entries',
      tag: 'CustomerOrders',
    );

    return filtered;
  }

  void _startRealtimeListener(UserModel user) {
    Logger.debug(
      'Starting customer orders realtime listener',
      tag: 'CustomerOrders',
    );
    
    _ordersSubscription = _realtime
        .watchActiveOrders()
        .listen((orders) async {
      // Ignore realtime updates until initial load completes
      if (!_initialLoadComplete) {
        Logger.debug(
          'Ignoring realtime update (initial load not complete)',
          tag: 'CustomerOrders',
        );
        return;
      }
      
      final filtered = orders.where((order) {
        return order.clienteId == user.id &&
            !_isTerminalStatus(order.stato) &&
            !_isCompletedOrderTooOld(order);
      }).toList();

      Logger.debug(
        'Realtime update received (${filtered.length} orders for customer)',
        tag: 'CustomerOrders',
      );
      
      // Realtime streams don't include order items, so we merge with existing state
      // to preserve the items array while updating order status and other fields
      final currentOrders = state.value ?? [];
      final currentOrderIds = currentOrders.map((o) => o.id).toSet();
      
      // Check if there are new orders we haven't seen before
      final newOrderIds = filtered
          .where((o) => !currentOrderIds.contains(o.id))
          .map((o) => o.id)
          .toList();
      
      // If there are new orders, refetch to get their items
      if (newOrderIds.isNotEmpty) {
        Logger.debug(
          'New orders detected (${newOrderIds.length}), refetching all',
          tag: 'CustomerOrders',
        );
        try {
          final fullOrders = await _fetchOrders(user);
          state = AsyncValue.data(fullOrders);
          return;
        } catch (e) {
          Logger.debug('Error refetching new orders: $e', tag: 'CustomerOrders');
          // Fall through to merge logic
        }
      }
      
      // Merge realtime updates with existing orders to preserve items
      final mergedOrders = filtered.map((realtimeOrder) {
        final existingOrder = currentOrders.firstWhere(
          (o) => o.id == realtimeOrder.id,
          orElse: () => realtimeOrder,
        );
        
        // If items are empty in realtime update but exist in current state, preserve them
        if (realtimeOrder.items.isEmpty && existingOrder.items.isNotEmpty) {
          return realtimeOrder.copyWith(items: existingOrder.items);
        }
        
        return realtimeOrder;
      }).toList();
      
      state = AsyncValue.data(mergedOrders);
    });

    ref.onDispose(() async {
      await _ordersSubscription?.cancel();
      _ordersSubscription = null;
    });
  }

  bool _isTerminalStatus(OrderStatus status) {
    return _terminalOrderStatuses.contains(status);
  }

  bool _isCompletedOrderTooOld(OrderModel order) {
    // Only check age for completed orders
    if (order.stato != OrderStatus.completed) {
      return false;
    }
    
    // If no completion time, consider it too old
    final completedAt = order.completatoAt;
    if (completedAt == null) {
      return true;
    }
    
    // Check if completed more than 12 hours ago
    final twelveHoursAgo = DateTime.now().subtract(const Duration(hours: 12));
    return completedAt.isBefore(twelveHoursAgo);
  }

  Future<void> refresh() async {
    final user = _currentCustomer;
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchOrders(user));
  }

  Future<void> cancelOrder(String orderId) async {
    final user = _currentCustomer;
    if (user == null) {
      return;
    }

    final currentOrders = state.value ?? await _fetchOrders(user);
    final order = currentOrders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw StateError('Ordine non trovato'),
    );

    if (order.stato != OrderStatus.confirmed) {
      throw StateError('L\'ordine non può più essere annullato');
    }

    await _database.updateOrderStatus(
      orderId: orderId,
      status: OrderStatus.cancelled,
    );

    // Optimistically remove the order; realtime listener will sync afterwards.
    final updatedOrders = currentOrders.where((o) => o.id != orderId).toList();
    state = AsyncValue.data(updatedOrders);
  }
}
