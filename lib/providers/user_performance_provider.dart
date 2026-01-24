import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/order_model.dart';
import 'user_orders_provider.dart';

/// Performance metrics for a regular user (customer)
class UserPerformance {
  final int totalOrders;
  final double totalSpent;
  final double averageOrderValue;

  const UserPerformance({
    required this.totalOrders,
    required this.totalSpent,
    required this.averageOrderValue,
  });

  factory UserPerformance.empty() => const UserPerformance(
    totalOrders: 0,
    totalSpent: 0,
    averageOrderValue: 0,
  );

  factory UserPerformance.fromOrders(List<OrderModel> orders) {
    if (orders.isEmpty) return UserPerformance.empty();

    final totalSpent = orders.fold<double>(0, (sum, o) => sum + o.totale);
    return UserPerformance(
      totalOrders: orders.length,
      totalSpent: totalSpent,
      averageOrderValue: totalSpent / orders.length,
    );
  }
}

/// Performance metrics for a delivery person
class DeliveryPerformance {
  final int totalDeliveries;
  final double averageDeliveryTimeMinutes;
  final int onTimeDeliveries;
  final int lateDeliveries;

  const DeliveryPerformance({
    required this.totalDeliveries,
    required this.averageDeliveryTimeMinutes,
    required this.onTimeDeliveries,
    required this.lateDeliveries,
  });

  factory DeliveryPerformance.empty() => const DeliveryPerformance(
    totalDeliveries: 0,
    averageDeliveryTimeMinutes: 0,
    onTimeDeliveries: 0,
    lateDeliveries: 0,
  );

  factory DeliveryPerformance.fromOrders(List<OrderModel> orders) {
    if (orders.isEmpty) return DeliveryPerformance.empty();

    // Calculate average delivery time (from in_consegna_at to completato_at)
    final deliveryTimes = <double>[];
    int onTime = 0;
    int late = 0;

    for (final order in orders) {
      if (order.inConsegnaAt != null && order.completatoAt != null) {
        final deliveryTime = order.completatoAt!
            .difference(order.inConsegnaAt!)
            .inMinutes
            .toDouble();
        deliveryTimes.add(deliveryTime);

        // Consider on-time if delivered within estimated time + 10 minutes buffer
        final estimatedTime = order.tempoStimatoMinuti ?? 30;
        if (deliveryTime <= estimatedTime + 10) {
          onTime++;
        } else {
          late++;
        }
      }
    }

    final avgTime = deliveryTimes.isEmpty
        ? 0.0
        : deliveryTimes.reduce((a, b) => a + b) / deliveryTimes.length;

    return DeliveryPerformance(
      totalDeliveries: orders.length,
      averageDeliveryTimeMinutes: avgTime,
      onTimeDeliveries: onTime,
      lateDeliveries: late,
    );
  }

  double get onTimePercentage =>
      totalDeliveries == 0 ? 0 : (onTimeDeliveries / totalDeliveries) * 100;
}

/// Provider for user performance metrics (for customers viewing their order history)
final userPerformanceProvider = FutureProvider.family
    .autoDispose<UserPerformance, String>((ref, userId) async {
      final orders = await ref.watch(
        userOrdersProvider(
          UserOrdersParams(userId: userId, deliveryMode: false),
        ).future,
      );
      return UserPerformance.fromOrders(orders);
    });

/// Provider for delivery performance metrics (for delivery personnel)
final deliveryPerformanceProvider = FutureProvider.family
    .autoDispose<DeliveryPerformance, String>((ref, userId) async {
      final orders = await ref.watch(
        userOrdersProvider(
          UserOrdersParams(userId: userId, deliveryMode: true),
        ).future,
      );
      return DeliveryPerformance.fromOrders(orders);
    });

/// Provider for cashier customer performance metrics
final cashierCustomerPerformanceProvider = FutureProvider.family
    .autoDispose<UserPerformance, String>((ref, customerId) async {
      final orders = await ref.watch(
        cashierCustomerAllOrdersProvider(customerId).future,
      );
      return UserPerformance.fromOrders(orders);
    });
