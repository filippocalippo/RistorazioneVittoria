import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/order_model.dart';
import '../core/services/realtime_service.dart';
import '../core/utils/enums.dart';
import '../core/utils/model_parsers.dart';
import '../core/config/supabase_config.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';
import '../core/utils/logger.dart';

part 'assign_delivery_provider.g.dart';

/// Provider for real-time unassigned delivery orders
/// Shows orders that are ready but not yet assigned to a delivery driver
@riverpod
Stream<List<OrderModel>> unassignedDeliveryOrders(Ref ref) {
  final user = ref.watch(authProvider).value;
  final orgIdAsync = ref.watch(currentOrganizationProvider);

  if (user == null) {
    return Stream.value([]);
  }

  // Wait for organization context
  if (orgIdAsync.isLoading || !orgIdAsync.hasValue) {
    return Stream.value([]);
  }

  final orgId = orgIdAsync.value;
  if (orgId == null) {
    Logger.warning('No organization context for unassigned delivery orders', tag: 'AssignDelivery');
    return Stream.value([]);
  }

  // Watch only ready orders (ready to be assigned)
  const watchedStatuses = [OrderStatus.ready];

  final realtime = RealtimeService();
  return realtime.watchOrdersByStatus(
    statuses: watchedStatuses,
    organizationId: orgId,
  ).map((orders) {
    Logger.debug(
      'AssignDelivery stream update: ${orders.length} orders received',
      tag: 'AssignDelivery',
    );

    // Filter only delivery orders that are NOT assigned
    final unassignedOrders = orders.where((order) {
      final isDelivery = order.tipo == OrderType.delivery;
      final isUnassigned = order.assegnatoDeliveryId == null;
      return isDelivery && isUnassigned;
    }).toList();

    Logger.debug(
      'AssignDelivery stream filtered: ${unassignedOrders.length} unassigned delivery orders',
      tag: 'AssignDelivery',
    );

    // Sort by creation time (newest first)
    final sorted = [...unassignedOrders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sorted;
  });
}

/// Provider for management delivery orders with date filtering
/// Filters by slot_prenotato_start (the booking/scheduled time)
@riverpod
Stream<List<OrderModel>> deliveryManagementOrders(Ref ref, DateTime date) {
  final user = ref.watch(authProvider).value;
  final orgIdAsync = ref.watch(currentOrganizationProvider);

  if (user == null) return Stream.value([]);

  // Wait for organization context
  if (orgIdAsync.isLoading || !orgIdAsync.hasValue) {
    return Stream.value([]);
  }

  final orgId = orgIdAsync.value;
  if (orgId == null) {
    Logger.warning('No organization context for delivery management orders', tag: 'AssignDelivery');
    return Stream.value([]);
  }

  final isToday =
      date.year == DateTime.now().year &&
      date.month == DateTime.now().month &&
      date.day == DateTime.now().day;

  if (isToday) {
    // For today, use realtime stream with high limit
    final realtime = RealtimeService();
    // Watch relevant statuses (active + completed for today)
    return realtime
        .watchOrdersByStatus(
          statuses: [
            OrderStatus.pending,
            OrderStatus.confirmed,
            OrderStatus.preparing,
            OrderStatus.ready,
            OrderStatus.delivering,
            OrderStatus.completed,
          ],
          organizationId: orgId,
          limit: 500, // High limit as requested
        )
        .map((orders) {
          // Filter for delivery orders for today
          // Check slotPrenotatoStart OR created_at if slot is null
          return orders.where((o) {
            final isDelivery = o.tipo == OrderType.delivery;
            if (!isDelivery) return false;

            // Use slot if available, otherwise use created_at
            final orderDate = o.slotPrenotatoStart ?? o.createdAt;
            final isSameDay =
                orderDate.year == date.year &&
                orderDate.month == date.month &&
                orderDate.day == date.day;
            return isSameDay;
          }).toList()..sort((a, b) {
            // Sort by slot time if available, otherwise by created_at
            final aSlot = a.slotPrenotatoStart ?? a.createdAt;
            final bSlot = b.slotPrenotatoStart ?? b.createdAt;
            return aSlot.compareTo(bSlot);
          });
        });
  } else {
    // For other dates, fetch once
    return Stream.fromFuture(() async {
      try {
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        Logger.info(
          'Fetching delivery orders for past date: $date\n'
          '  startOfDay (local): $startOfDay\n'
          '  endOfDay (local): $endOfDay\n'
          '  startOfDay.toUtc(): ${startOfDay.toUtc()}\n'
          '  endOfDay.toUtc(): ${endOfDay.toUtc()}\n'
          '  Query gte: ${startOfDay.toUtc().toIso8601String()}\n'
          '  Query lt: ${endOfDay.toUtc().toIso8601String()}',
          tag: 'AssignDelivery',
        );

        // SECURITY: Add organization filter to prevent cross-tenant data access
        final response = await SupabaseConfig.client
            .from('ordini')
            .select('*, ordini_items(*)')
            .eq('organization_id', orgId)
            .eq('tipo', 'delivery')
            .gte('slot_prenotato_start', startOfDay.toUtc().toIso8601String())
            .lt('slot_prenotato_start', endOfDay.toUtc().toIso8601String())
            .order('slot_prenotato_start', ascending: true);

        Logger.info(
          'Query returned ${(response as List).length} raw rows',
          tag: 'AssignDelivery',
        );

        final orders = (response as List)
            .map((json) {
              try {
                return ModelParsers.orderFromJson(Map<String, dynamic>.from(json));
              } catch (e) {
                Logger.warning('Failed to parse order: $e', tag: 'AssignDelivery');
                return null;
              }
            })
            .whereType<OrderModel>()
            .toList();

        Logger.info(
          'Parsed ${orders.length} delivery orders for $date',
          tag: 'AssignDelivery',
        );

        return orders;
      } catch (e, stack) {
        Logger.error(
          'Failed to fetch historical delivery orders',
          tag: 'AssignDelivery',
          error: e,
          stackTrace: stack,
        );
        return <OrderModel>[];
      }
    }());
  }
}
