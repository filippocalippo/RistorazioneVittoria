import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/config/supabase_config.dart';
import '../core/models/order_model.dart';
import '../core/models/user_model.dart';
import '../core/utils/enums.dart';
import '../core/utils/model_parsers.dart';
import '../core/utils/logger.dart';
import 'users_provider.dart';

part 'delivery_revenue_provider.g.dart';

/// Model for individual delivery person stats
class DeliveryPersonStats {
  final String id;
  final String name;
  final UserRole role;
  final int totalDeliveries;
  final double totalAmountInHand;
  final double earningsFromDeliveries;
  final int deliveriesOnTime;
  final int deliveriesLate;
  final double averageDeliveryTime;
  final List<OrderModel> orders;

  const DeliveryPersonStats({
    required this.id,
    required this.name,
    required this.role,
    required this.totalDeliveries,
    required this.totalAmountInHand,
    required this.earningsFromDeliveries,
    required this.deliveriesOnTime,
    required this.deliveriesLate,
    required this.averageDeliveryTime,
    required this.orders,
  });

  double get onTimePercentage {
    if (totalDeliveries == 0) return 0;
    return (deliveriesOnTime / totalDeliveries) * 100;
  }

  double get latePercentage {
    if (totalDeliveries == 0) return 0;
    return (deliveriesLate / totalDeliveries) * 100;
  }
}

/// Model for all delivery revenue data for a specific date
class DeliveryRevenueData {
  final DateTime date;
  final List<DeliveryPersonStats> personStats;
  final int totalDeliveries;
  final double totalRevenue;
  final double totalEarnings;
  final int totalOnTime;
  final int totalLate;

  const DeliveryRevenueData({
    required this.date,
    required this.personStats,
    required this.totalDeliveries,
    required this.totalRevenue,
    required this.totalEarnings,
    required this.totalOnTime,
    required this.totalLate,
  });

  double get overallOnTimePercentage {
    if (totalDeliveries == 0) return 0;
    return (totalOnTime / totalDeliveries) * 100;
  }
}

/// Price per delivery in EUR
const double pricePerDelivery = 3.0;

/// Provider to track the selected date for delivery revenue
@riverpod
class DeliveryRevenueDate extends _$DeliveryRevenueDate {
  @override
  DateTime build() {
    return DateTime.now();
  }

  void setDate(DateTime date) {
    state = date;
  }
}

/// Provider for fetching delivery revenue data for a specific date
@riverpod
class DeliveryRevenue extends _$DeliveryRevenue {
  @override
  Future<DeliveryRevenueData> build() async {
    final date = ref.watch(deliveryRevenueDateProvider);
    return _fetchDataForDate(date);
  }

  Future<DeliveryRevenueData> _fetchDataForDate(DateTime date) async {
    try {
      // Get start and end of the selected date
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      Logger.debug(
        'Fetching delivery revenue for ${date.toIso8601String().split('T')[0]}',
        tag: 'DeliveryRevenue',
      );

      // Fetch all completed delivery orders for the selected date
      final ordersResponse = await SupabaseConfig.client
          .from('ordini')
          .select('*, ordini_items(*)')
          .eq('tipo', 'delivery')
          .eq('stato', 'completed')
          .gte('slot_prenotato_start', startOfDay.toUtc().toIso8601String())
          .lte('slot_prenotato_start', endOfDay.toUtc().toIso8601String())
          .order('slot_prenotato_start', ascending: false);

      final List<dynamic> ordersData = ordersResponse as List;
      final orders = ordersData
          .map(
            (json) => ModelParsers.orderFromJson(json as Map<String, dynamic>),
          )
          .toList();

      Logger.debug(
        'Found ${orders.length} completed delivery orders',
        tag: 'DeliveryRevenue',
      );

      // Get all staff users
      final users = ref.read(staffUsersProvider);
      final deliveryUsers = users
          .where(
            (u) => u.ruolo == UserRole.delivery || u.ruolo == UserRole.manager,
          )
          .toList();

      // Group orders by assegnato_delivery_id
      final ordersByDeliveryPerson = <String, List<OrderModel>>{};
      for (final order in orders) {
        final deliveryId = order.assegnatoDeliveryId;
        if (deliveryId != null && deliveryId.isNotEmpty) {
          ordersByDeliveryPerson.putIfAbsent(deliveryId, () => []).add(order);
        }
      }

      // Calculate stats for each delivery person
      final personStats = <DeliveryPersonStats>[];

      for (final entry in ordersByDeliveryPerson.entries) {
        final userId = entry.key;
        final userOrders = entry.value;

        // Find user info
        UserModel? user;
        try {
          user = deliveryUsers.firstWhere((u) => u.id == userId);
        } catch (_) {
          // User not found in staff list, try to fetch from DB
          try {
            final userData = await SupabaseConfig.client
                .from('profiles')
                .select()
                .eq('id', userId)
                .maybeSingle();
            if (userData != null) {
              user = UserModel.fromJson(userData);
            }
          } catch (e) {
            Logger.debug(
              'Failed to fetch user $userId: $e',
              tag: 'DeliveryRevenue',
            );
          }
        }

        final userName = user?.nomeCompleto ?? 'Utente sconosciuto';
        final userRole = user?.ruolo ?? UserRole.delivery;

        // Calculate delivery stats
        int onTime = 0;
        int late = 0;
        double totalDeliveryTimeMinutes = 0;
        int validDeliveryTimes = 0;

        for (final order in userOrders) {
          // Check if on time or late based on slot
          if (order.slotPrenotatoStart != null && order.completatoAt != null) {
            // Give 15 minutes grace period after slot
            final deadline = order.slotPrenotatoStart!.add(
              const Duration(minutes: 15),
            );
            if (order.completatoAt!.isBefore(deadline) ||
                order.completatoAt!.isAtSameMomentAs(deadline)) {
              onTime++;
            } else {
              late++;
            }
          } else {
            // No slot, consider on time
            onTime++;
          }

          // Calculate delivery time (from inConsegnaAt to completatoAt)
          if (order.inConsegnaAt != null && order.completatoAt != null) {
            final deliveryDuration = order.completatoAt!.difference(
              order.inConsegnaAt!,
            );
            totalDeliveryTimeMinutes += deliveryDuration.inMinutes;
            validDeliveryTimes++;
          }
        }

        final avgDeliveryTime = validDeliveryTimes > 0
            ? totalDeliveryTimeMinutes / validDeliveryTimes
            : 0.0;

        // Calculate money stats
        final totalAmount = userOrders.fold<double>(
          0,
          (sum, o) => sum + o.totale,
        );
        final earnings = userOrders.length * pricePerDelivery;

        personStats.add(
          DeliveryPersonStats(
            id: userId,
            name: userName,
            role: userRole,
            totalDeliveries: userOrders.length,
            totalAmountInHand: totalAmount,
            earningsFromDeliveries: earnings,
            deliveriesOnTime: onTime,
            deliveriesLate: late,
            averageDeliveryTime: avgDeliveryTime,
            orders: userOrders,
          ),
        );
      }

      // Sort by total deliveries descending
      personStats.sort(
        (a, b) => b.totalDeliveries.compareTo(a.totalDeliveries),
      );

      // Calculate totals
      final totalDeliveries = personStats.fold<int>(
        0,
        (sum, p) => sum + p.totalDeliveries,
      );
      final totalRevenue = personStats.fold<double>(
        0,
        (sum, p) => sum + p.totalAmountInHand,
      );
      final totalEarnings = personStats.fold<double>(
        0,
        (sum, p) => sum + p.earningsFromDeliveries,
      );
      final totalOnTime = personStats.fold<int>(
        0,
        (sum, p) => sum + p.deliveriesOnTime,
      );
      final totalLate = personStats.fold<int>(
        0,
        (sum, p) => sum + p.deliveriesLate,
      );

      return DeliveryRevenueData(
        date: date,
        personStats: personStats,
        totalDeliveries: totalDeliveries,
        totalRevenue: totalRevenue,
        totalEarnings: totalEarnings,
        totalOnTime: totalOnTime,
        totalLate: totalLate,
      );
    } catch (e, stack) {
      Logger.error(
        'Failed to fetch delivery revenue: $e',
        tag: 'DeliveryRevenue',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}
