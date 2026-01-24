import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/order_model.dart';
import '../utils/enums.dart';
import '../utils/constants.dart';
import '../utils/model_parsers.dart';

class RealtimeService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Stream di ordini filtrati per stato
  /// SECURITY: For customer-facing streams, pass clienteId to filter server-side
  /// Staff streams (kitchen, delivery) can omit clienteId as RLS handles access control
  Stream<List<OrderModel>> watchOrdersByStatus({
    required List<OrderStatus> statuses,
    String? clienteId,
    String? organizationId,
    int? limit = 50,
  }) async* {
    List<OrderModel> lastGoodSnapshot = const [];

    Stream<List<Map<String, dynamic>>> streamToListen;

    if (clienteId != null) {
      var streamQuery = _client
          .from(AppConstants.tableOrdini)
          .stream(primaryKey: const ['id'])
          .eq('cliente_id', clienteId);

      streamToListen = streamQuery
          .order('created_at', ascending: false)
          .limit(limit ?? 50);
    } else {
      final querySteps = _client
          .from(AppConstants.tableOrdini)
          .stream(primaryKey: const ['id']);

      if (organizationId != null) {
        streamToListen = querySteps
            .eq('organization_id', organizationId)
            .order('created_at', ascending: false)
            .limit(limit ?? 50);
      } else {
        streamToListen = querySteps
            .order('created_at', ascending: false)
            .limit(limit ?? 50);
      }
    }

    await for (final ordersData in streamToListen) {
      try {
        if (ordersData.isEmpty) {
          lastGoodSnapshot = const [];
          yield lastGoodSnapshot;
          continue;
        }

        final orderIds = ordersData.map((o) => o['id'] as String).toList();

        var fullQueryBase = _client
            .from(AppConstants.tableOrdini)
            .select('*, ordini_items(*)');

        fullQueryBase = fullQueryBase.inFilter('id', orderIds);

        if (organizationId != null) {
          fullQueryBase = fullQueryBase.eq('organization_id', organizationId);
        }

        final fullOrdersData = await fullQueryBase.order(
          'created_at',
          ascending: false,
        );

        final parsed = <OrderModel>[];
        for (final json in (fullOrdersData as List)) {
          try {
            final order = ModelParsers.orderFromJson(
              Map<String, dynamic>.from(json as Map),
            );
            parsed.add(order);
          } catch (_) {
            continue;
          }
        }

        final filtered = statuses.isEmpty
            ? parsed
            : parsed.where((order) => statuses.contains(order.stato)).toList();

        lastGoodSnapshot = filtered;
        yield filtered;
      } catch (_) {
        yield lastGoodSnapshot;
        continue;
      }
    }
  }

  Stream<List<OrderModel>> watchKitchenOrders() {
    return watchOrdersByStatus(
      statuses: [OrderStatus.confirmed, OrderStatus.preparing],
    );
  }

  Stream<List<OrderModel>> watchDeliveryOrders() {
    return watchOrdersByStatus(
      statuses: [OrderStatus.ready, OrderStatus.delivering],
    );
  }

  Stream<OrderModel?> watchOrder(
    String orderId, {
    String? organizationId,
  }) async* {
    var streamQuery = _client
        .from(AppConstants.tableOrdini)
        .stream(primaryKey: const ['id'])
        .eq('id', orderId);

    await for (final ordersData in streamQuery) {
      if (ordersData.isEmpty) {
        yield null;
        continue;
      }

      var fullOrderQuery = _client
          .from(AppConstants.tableOrdini)
          .select('*, ordini_items(*)')
          .eq('id', orderId);
      if (organizationId != null) {
        fullOrderQuery = fullOrderQuery.eq('organization_id', organizationId);
      }
      final fullOrderData = await fullOrderQuery.maybeSingle();

      if (fullOrderData == null) {
        yield null;
        continue;
      }

      yield ModelParsers.orderFromJson(
        Map<String, dynamic>.from(fullOrderData as Map),
      );
    }
  }

  Stream<List<OrderModel>> watchActiveOrdersForCustomer(String clienteId) {
    return watchOrdersByStatus(
      clienteId: clienteId,
      statuses: [
        OrderStatus.pending,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.delivering,
        OrderStatus.completed,
      ],
    );
  }

  Stream<List<OrderModel>> watchActiveOrders() {
    return watchOrdersByStatus(
      statuses: [
        OrderStatus.pending,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.delivering,
        OrderStatus.completed,
      ],
    );
  }
}
