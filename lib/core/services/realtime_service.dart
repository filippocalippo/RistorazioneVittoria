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
    int? limit = 50,
  }) async* {
    // Keep last good snapshot to avoid breaking UI on transient errors
    List<OrderModel> lastGoodSnapshot = const [];

    // Build the stream query
    // SECURITY: Apply cliente_id filter at stream level when provided
    // This ensures customers only receive their own orders in realtime
    Stream<List<Map<String, dynamic>>> streamToListen;
    
    if (clienteId != null) {
      // Customer stream: filter by cliente_id for security
      var query = _client
          .from(AppConstants.tableOrdini)
          .stream(primaryKey: const ['id'])
          .eq('cliente_id', clienteId)
          .order('created_at', ascending: false);
      
      if (limit != null) {
        query = query.limit(limit);
      }
      streamToListen = query;
    } else {
      // Staff stream: RLS handles access control at database level
      var query = _client
          .from(AppConstants.tableOrdini)
          .stream(primaryKey: const ['id'])
          .order('created_at', ascending: false);
      
      if (limit != null) {
        query = query.limit(limit);
      }
      streamToListen = query;
    }

    await for (final ordersData in streamToListen) {
      try {
        if (ordersData.isEmpty) {
          lastGoodSnapshot = const [];
          yield lastGoodSnapshot;
          continue;
        }

        // Fetch full order data with items for each order
        // Stream doesn't support joins, so we need to fetch separately
        final orderIds = ordersData.map((o) => o['id'] as String).toList();

        final fullOrdersData = await _client
            .from(AppConstants.tableOrdini)
            .select('*, ordini_items(*)')
            .inFilter('id', orderIds)
            .order('created_at', ascending: false);

        // Parse all orders (let provider handle status filtering)
        final parsed = <OrderModel>[];
        for (final json in fullOrdersData) {
          try {
            final order = ModelParsers.orderFromJson(
              Map<String, dynamic>.from(json),
            );
            parsed.add(order);
          } catch (_) {
            // Skip malformed orders rather than crashing the stream
            continue;
          }
        }

        final filtered = statuses.isEmpty
            ? parsed
            : parsed.where((order) => statuses.contains(order.stato)).toList();

        lastGoodSnapshot = filtered;
        yield filtered;
      } catch (_) {
        // Any unexpected error: yield last known good data instead of erroring
        yield lastGoodSnapshot;
        // continue to next iteration; the stream stays alive
        continue;
      }
    }
  }

  /// Stream di ordini per cucina (confirmed, preparing)
  /// Staff-only stream - RLS handles access control
  Stream<List<OrderModel>> watchKitchenOrders() {
    return watchOrdersByStatus(
      statuses: [OrderStatus.confirmed, OrderStatus.preparing],
    );
  }

  /// Stream di ordini per delivery (ready, delivering)
  /// Staff-only stream - RLS handles access control
  Stream<List<OrderModel>> watchDeliveryOrders() {
    return watchOrdersByStatus(
      statuses: [OrderStatus.ready, OrderStatus.delivering],
    );
  }

  /// Stream di un singolo ordine (per tracking cliente)
  Stream<OrderModel?> watchOrder(String orderId) async* {
    await for (final ordersData
        in _client
            .from(AppConstants.tableOrdini)
            .stream(primaryKey: ['id'])
            .eq('id', orderId)) {
      if (ordersData.isEmpty) {
        yield null;
        continue;
      }

      // Fetch full order data with items
      // Stream doesn't support joins, so we need to fetch separately
      final fullOrderData = await _client
          .from(AppConstants.tableOrdini)
          .select('*, ordini_items(*)')
          .eq('id', orderId)
          .maybeSingle();

      if (fullOrderData == null) {
        yield null;
        continue;
      }

      yield ModelParsers.orderFromJson(
        Map<String, dynamic>.from(fullOrderData),
      );
    }
  }

  /// Stream di ordini attivi per un cliente specifico
  /// SECURITY: clienteId is REQUIRED for customer-facing order tracking
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

  /// Stream di ordini attivi (for staff/manager use)
  /// @deprecated Use watchActiveOrdersForCustomer for customer-facing streams
  Stream<List<OrderModel>> watchActiveOrders() {
    return watchOrdersByStatus(
      statuses: [
        OrderStatus.pending,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.delivering,
        OrderStatus
            .completed, // Include completed to match customer orders provider
      ],
    );
  }
}
