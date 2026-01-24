import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/enums.dart';
import 'delivery_orders_provider.dart';

part 'delivery_stats_provider.g.dart';

/// Model for delivery driver money statistics
class DeliveryMoneyStats {
  final double cashInHand;

  const DeliveryMoneyStats({
    required this.cashInHand,
  });
}

/// Provider for delivery driver money statistics
/// Calculates cash in hand from unpaid cash orders
@riverpod
DeliveryMoneyStats deliveryMoneyStats(Ref ref) {
  final orders = ref.watch(deliveryOrdersRealtimeProvider).value ?? [];

  double cashInHand = 0.0;

  for (final order in orders) {
    // Cash in hand: unpaid cash orders that are ready or delivering
    if (order.metodoPagamento == PaymentMethod.cash &&
        !order.pagato &&
        (order.stato == OrderStatus.ready || order.stato == OrderStatus.delivering)) {
      cashInHand += order.totale;
    }
  }

  return DeliveryMoneyStats(
    cashInHand: cashInHand,
  );
}

