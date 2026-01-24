import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/supabase_config.dart';
import '../core/models/order_model.dart';
import '../core/utils/enums.dart';
import '../core/utils/logger.dart';
import '../core/utils/model_parsers.dart';

/// Parameters for fetching user orders
class UserOrdersParams {
  final String userId;
  final bool deliveryMode;

  const UserOrdersParams({required this.userId, this.deliveryMode = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserOrdersParams &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          deliveryMode == other.deliveryMode;

  @override
  int get hashCode => userId.hashCode ^ deliveryMode.hashCode;
}

/// Fetches ALL orders for a user - no pagination
/// When deliveryMode is true, fetches orders assigned to this user for delivery
/// When deliveryMode is false, fetches orders placed by this user (cliente_id)
final userOrdersProvider = FutureProvider.family
    .autoDispose<List<OrderModel>, UserOrdersParams>((ref, params) async {
      try {
        final selectColumns = [
          'id',
          'cliente_id',
          'numero_ordine',
          'stato',
          'tipo',
          'nome_cliente',
          'telefono_cliente',
          'email_cliente',
          'indirizzo_consegna',
          'citta_consegna',
          'cap_consegna',
          'latitude_consegna',
          'longitude_consegna',
          'note',
          'subtotale',
          'costo_consegna',
          'sconto',
          'totale',
          'metodo_pagamento',
          'pagato',
          'assegnato_cucina_id',
          'assegnato_delivery_id',
          'tempo_stimato_minuti',
          'valutazione',
          'recensione',
          'created_at',
          'confermato_at',
          'preparazione_at',
          'pronto_at',
          'in_consegna_at',
          'completato_at',
          'cancellato_at',
          'updated_at',
          'slot_prenotato_start',
          'ordini_items(id, ordine_id, menu_item_id, nome_prodotto, quantita, prezzo_unitario, subtotale, note, varianti, created_at)',
        ].join(', ');

        List<dynamic> data;

        if (params.deliveryMode) {
          // Fetch orders assigned to this user for delivery
          // Only get completed deliveries
          data = await SupabaseConfig.client
              .from('ordini')
              .select(selectColumns)
              .eq('assegnato_delivery_id', params.userId)
              .eq('stato', OrderStatus.completed.name)
              .order('created_at', ascending: false);
        } else {
          // Fetch orders placed by this user
          data = await SupabaseConfig.client
              .from('ordini')
              .select(selectColumns)
              .eq('cliente_id', params.userId)
              .order('created_at', ascending: false);
        }

        final orders = data
            .map((json) => ModelParsers.orderFromJson(json))
            .toList();

        Logger.debug(
          'Loaded ${orders.length} orders for user ${params.userId} (deliveryMode: ${params.deliveryMode})',
          tag: 'UserOrdersProvider',
        );

        return orders;
      } catch (e, stack) {
        Logger.error(
          'Failed to load user orders: $e',
          tag: 'UserOrdersProvider',
          error: e,
          stackTrace: stack,
        );
        rethrow;
      }
    });

/// Fetches ALL orders for a cashier customer (by cashier_customer_id)
final cashierCustomerAllOrdersProvider = FutureProvider.family
    .autoDispose<List<OrderModel>, String>((ref, customerId) async {
      try {
        final selectColumns = [
          'id',
          'cliente_id',
          'numero_ordine',
          'stato',
          'tipo',
          'nome_cliente',
          'telefono_cliente',
          'email_cliente',
          'indirizzo_consegna',
          'citta_consegna',
          'cap_consegna',
          'latitude_consegna',
          'longitude_consegna',
          'note',
          'subtotale',
          'costo_consegna',
          'sconto',
          'totale',
          'metodo_pagamento',
          'pagato',
          'assegnato_cucina_id',
          'assegnato_delivery_id',
          'tempo_stimato_minuti',
          'valutazione',
          'recensione',
          'created_at',
          'confermato_at',
          'preparazione_at',
          'pronto_at',
          'in_consegna_at',
          'completato_at',
          'cancellato_at',
          'updated_at',
          'slot_prenotato_start',
          'ordini_items(id, ordine_id, menu_item_id, nome_prodotto, quantita, prezzo_unitario, subtotale, note, varianti, created_at)',
        ].join(', ');

        final data = await SupabaseConfig.client
            .from('ordini')
            .select(selectColumns)
            .eq('cashier_customer_id', customerId)
            .order('created_at', ascending: false);

        final orders = data
            .map((json) => ModelParsers.orderFromJson(json))
            .toList();

        Logger.debug(
          'Loaded ${orders.length} orders for cashier customer $customerId',
          tag: 'UserOrdersProvider',
        );

        return orders;
      } catch (e, stack) {
        Logger.error(
          'Failed to load cashier customer orders: $e',
          tag: 'UserOrdersProvider',
          error: e,
          stackTrace: stack,
        );
        rethrow;
      }
    });
