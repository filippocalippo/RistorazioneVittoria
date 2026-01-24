import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/order_model.dart';
import '../core/models/order_item_model.dart';
import '../core/utils/enums.dart';
import '../core/utils/logger.dart';
import 'categories_provider.dart';

/// Date range filter for dashboard
enum DashboardDateRange {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  custom;

  String get displayName {
    switch (this) {
      case DashboardDateRange.today:
        return 'Oggi';
      case DashboardDateRange.yesterday:
        return 'Ieri';
      case DashboardDateRange.thisWeek:
        return 'Questa Settimana';
      case DashboardDateRange.thisMonth:
        return 'Questo Mese';
      case DashboardDateRange.custom:
        return 'Personalizzato';
    }
  }

  // Backwards compatibility for other files
  DateTime get startDate {
    final now = DateTime.now();
    switch (this) {
      case DashboardDateRange.today:
        return DateTime(now.year, now.month, now.day, 16, 0, 0);
      case DashboardDateRange.yesterday:
        return DateTime(now.year, now.month, now.day - 1, 16, 0, 0);
      case DashboardDateRange.thisWeek:
        final weekday = now.weekday;
        return DateTime(now.year, now.month, now.day - weekday + 1);
      case DashboardDateRange.thisMonth:
        return DateTime(now.year, now.month, 1);
      case DashboardDateRange.custom:
        return DateTime(now.year, now.month, now.day, 0, 0, 0); // Default
    }
  }

  DateTime get endDate {
    final now = DateTime.now();
    switch (this) {
      case DashboardDateRange.today:
        return DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
      case DashboardDateRange.yesterday:
        return DateTime(now.year, now.month, now.day, 0, 0, 0);
      case DashboardDateRange.thisWeek:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case DashboardDateRange.thisMonth:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case DashboardDateRange.custom:
        return DateTime(now.year, now.month, now.day, 23, 59, 59); // Default
    }
  }
}

class DashboardDateFilter {
  final DashboardDateRange rangeType;
  final DateTime? customStart;
  final DateTime? customEnd;

  const DashboardDateFilter({
    required this.rangeType,
    this.customStart,
    this.customEnd,
  });

  factory DashboardDateFilter.preset(DashboardDateRange range) =>
      DashboardDateFilter(rangeType: range);

  factory DashboardDateFilter.custom(DateTime start, DateTime end) =>
      DashboardDateFilter(
        rangeType: DashboardDateRange.custom,
        customStart: start,
        customEnd: end,
      );

  DateTime get startDate {
    final now = DateTime.now();
    switch (rangeType) {
      case DashboardDateRange.today:
        // Shift starts at 16:00
        return DateTime(now.year, now.month, now.day, 16, 0, 0);
      case DashboardDateRange.yesterday:
        // Shift started yesterday at 16:00
        return DateTime(now.year, now.month, now.day - 1, 16, 0, 0);
      case DashboardDateRange.thisWeek:
        final weekday = now.weekday;
        return DateTime(now.year, now.month, now.day - weekday + 1);
      case DashboardDateRange.thisMonth:
        return DateTime(now.year, now.month, 1);
      case DashboardDateRange.custom:
        final start = customStart ?? now;
        return DateTime(start.year, start.month, start.day, 0, 0, 0);
    }
  }

  DateTime get endDate {
    final now = DateTime.now();
    switch (rangeType) {
      case DashboardDateRange.today:
        // Shift ends at 00:00 next day (Midnight)
        return DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
      case DashboardDateRange.yesterday:
        // Shift ended today at 00:00 (Midnight)
        return DateTime(now.year, now.month, now.day, 0, 0, 0);
      case DashboardDateRange.thisWeek:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case DashboardDateRange.thisMonth:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case DashboardDateRange.custom:
        final end = customEnd ?? now;
        return DateTime(end.year, end.month, end.day, 23, 59, 59);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardDateFilter &&
        other.rangeType == rangeType &&
        other.customStart == customStart &&
        other.customEnd == customEnd;
  }

  @override
  int get hashCode =>
      rangeType.hashCode ^ customStart.hashCode ^ customEnd.hashCode;
}

/// State notifier for date range selection
final dashboardDateFilterProvider =
    StateNotifierProvider<DashboardDateFilterNotifier, DashboardDateFilter>(
      (ref) => DashboardDateFilterNotifier(),
    );

class DashboardDateFilterNotifier extends StateNotifier<DashboardDateFilter> {
  DashboardDateFilterNotifier()
    : super(DashboardDateFilter.preset(DashboardDateRange.today));

  void setRange(DashboardDateRange range) {
    if (range == DashboardDateRange.custom) return;
    state = DashboardDateFilter.preset(range);
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = DashboardDateFilter.custom(start, end);
  }
}

/// Model for dashboard analytics
class DashboardAnalytics {
  final double totalRevenue;
  final int totalOrders;
  final double avgOrderValue;
  final int avgDeliveryTimeMinutes;
  final double revenueChange;
  final double ordersChange;
  final double avgValueChange;
  final int deliveryTimeChange;
  final Map<int, double> hourlyRevenue;
  final Map<int, double> previousHourlyRevenue;
  final Map<String, CategorySalesData> salesByCategory;
  final List<TopPerformingItem> topItems;
  final List<OrderModel> liveOrders;
  final int totalItemsSold;
  final String currentPeriodLabel;
  final String previousPeriodLabel;

  DashboardAnalytics({
    required this.totalRevenue,
    required this.totalOrders,
    required this.avgOrderValue,
    required this.avgDeliveryTimeMinutes,
    required this.revenueChange,
    required this.ordersChange,
    required this.avgValueChange,
    required this.deliveryTimeChange,
    required this.hourlyRevenue,
    required this.previousHourlyRevenue,
    required this.salesByCategory,
    required this.topItems,
    required this.liveOrders,
    required this.totalItemsSold,
    required this.currentPeriodLabel,
    required this.previousPeriodLabel,
  });

  factory DashboardAnalytics.empty() => DashboardAnalytics(
    totalRevenue: 0,
    totalOrders: 0,
    avgOrderValue: 0,
    avgDeliveryTimeMinutes: 0,
    revenueChange: 0,
    ordersChange: 0,
    avgValueChange: 0,
    deliveryTimeChange: 0,
    hourlyRevenue: {},
    previousHourlyRevenue: {},
    salesByCategory: {},
    topItems: [],
    liveOrders: [],
    totalItemsSold: 0,
    currentPeriodLabel: '',
    previousPeriodLabel: '',
  );
}

/// Model for category sales data
class CategorySalesData {
  final String categoryId;
  final String categoryName;
  final String? categoryColor;
  final double revenue;
  final int itemCount;
  final double percentage;

  CategorySalesData({
    required this.categoryId,
    required this.categoryName,
    this.categoryColor,
    required this.revenue,
    required this.itemCount,
    required this.percentage,
  });
}

/// Model for top performing items
class TopPerformingItem {
  final String productName;
  final int salesCount;
  final double revenue;
  final double growthPercentage;

  TopPerformingItem({
    required this.productName,
    required this.salesCount,
    required this.revenue,
    required this.growthPercentage,
  });
}

/// Main analytics provider
final dashboardAnalyticsProvider =
    StateNotifierProvider.autoDispose<
      DashboardAnalyticsNotifier,
      AsyncValue<DashboardAnalytics>
    >((ref) {
      return DashboardAnalyticsNotifier(ref);
    });

class DashboardAnalyticsNotifier
    extends StateNotifier<AsyncValue<DashboardAnalytics>> {
  final Ref _ref;

  DashboardAnalyticsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    final dateRange = _ref.read(dashboardDateFilterProvider);
    _fetchAnalytics(dateRange);
  }

  Future<void> _fetchAnalytics(DashboardDateFilter filter) async {
    state = const AsyncValue.loading();
    try {
      final supabase = Supabase.instance.client;
      final startDate = filter.startDate;
      final endDate = filter.endDate;

      final ordersResponse = await supabase
          .from('ordini')
          .select('*, ordini_items(*)')
          .or(
            'and(slot_prenotato_start.gte.${startDate.toUtc().toIso8601String()},slot_prenotato_start.lte.${endDate.toUtc().toIso8601String()}),'
            'and(slot_prenotato_start.is.null,created_at.gte.${startDate.toUtc().toIso8601String()},created_at.lte.${endDate.toUtc().toIso8601String()})',
          )
          .order('created_at', ascending: false);

      final List<dynamic> ordersData = ordersResponse as List;
      final List<OrderModel> allOrders = [];

      for (final json in ordersData) {
        try {
          allOrders.add(_orderFromJson(json));
        } catch (e) {
          Logger.warning('Error parsing order: $e', tag: 'DashboardAnalytics');
        }
      }

      final validOrders = allOrders
          .where((o) => o.stato != OrderStatus.cancelled)
          .toList();

      double totalRevenue = 0;
      int totalOrders = 0;
      int totalDeliveryMinutes = 0;
      int deliveryCount = 0;
      final hourlyRevenue = <int, double>{};
      int totalItemsSold = 0;

      final categorySalesMap = <String, _CategoryAccumulator>{};
      final itemSalesMap = <String, _ItemAccumulator>{};

      final categoriesState = _ref.read(categoriesProvider);
      final categories = categoriesState.value ?? [];
      final categoryMap = {for (var c in categories) c.id: c};
      final categoryNameMap = {
        for (var c in categories) c.nome.toLowerCase(): c,
      };

      for (final cat in categories) {
        categorySalesMap[cat.id] = _CategoryAccumulator(
          id: cat.id,
          name: cat.nome,
          color: cat.colore,
        );
      }

      for (final order in validOrders) {
        totalRevenue += order.totale;
        totalOrders++;

        if (order.tipo == OrderType.delivery &&
            order.stato == OrderStatus.completed &&
            order.completatoAt != null) {
          final duration = order.completatoAt!.difference(order.createdAt);
          totalDeliveryMinutes += duration.inMinutes;
          deliveryCount++;
        }

        final hour = order.createdAt.toLocal().hour;
        hourlyRevenue[hour] = (hourlyRevenue[hour] ?? 0) + order.totale;

        for (final item in order.items) {
          totalItemsSold += item.quantita;

          String categoryId = 'uncategorized';
          String categoryName = '';

          if (item.varianti != null && item.varianti!.containsKey('category')) {
            categoryName = item.varianti!['category'] as String;
            final cat = categoryNameMap[categoryName.toLowerCase()];
            if (cat != null) {
              categoryId = cat.id;
            } else {
              categoryId = categoryName;
            }
          }

          categorySalesMap.putIfAbsent(
            categoryId,
            () => _CategoryAccumulator(
              id: categoryId,
              name: categoryId == 'uncategorized'
                  ? 'Altro'
                  : categoryMap[categoryId]?.nome ?? categoryName,
              color: categoryMap[categoryId]?.colore,
            ),
          );

          categorySalesMap[categoryId]!.revenue += item.subtotale;
          categorySalesMap[categoryId]!.itemCount += item.quantita;

          final name = item.nomeProdotto;
          itemSalesMap.putIfAbsent(name, () => _ItemAccumulator(name: name));
          itemSalesMap[name]!.salesCount += item.quantita;
          itemSalesMap[name]!.revenue += item.subtotale;
        }
      }

      final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
      final avgDeliveryTimeMinutes = deliveryCount > 0
          ? totalDeliveryMinutes ~/ deliveryCount
          : 0;

      final salesByCategory = categorySalesMap.map(
        (key, value) => MapEntry(
          key,
          CategorySalesData(
            categoryId: value.id,
            categoryName: value.name,
            categoryColor: value.color,
            revenue: value.revenue,
            itemCount: value.itemCount,
            percentage: totalRevenue > 0
                ? (value.revenue / totalRevenue * 100)
                : 0,
          ),
        ),
      );

      final topItems = itemSalesMap.values.toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      final topItemsList = topItems.take(5).map((item) {
        return TopPerformingItem(
          productName: item.name,
          salesCount: item.salesCount,
          revenue: item.revenue,
          growthPercentage: 0,
        );
      }).toList();

      final liveOrders = allOrders
          .where((o) => o.stato.isActive && o.stato != OrderStatus.completed)
          .take(10)
          .toList();

      final previousStart = _getPreviousPeriodStart(filter, startDate);
      final previousEnd = _getPreviousPeriodEnd(filter, endDate);

      final previousOrdersResponse = await supabase
          .from('ordini')
          .select(
            'totale, stato, tipo, created_at, completato_at, slot_prenotato_start',
          )
          .or(
            'and(slot_prenotato_start.gte.${previousStart.toUtc().toIso8601String()},slot_prenotato_start.lte.${previousEnd.toUtc().toIso8601String()}),'
            'and(slot_prenotato_start.is.null,created_at.gte.${previousStart.toUtc().toIso8601String()},created_at.lte.${previousEnd.toUtc().toIso8601String()})',
          );

      final List<dynamic> previousData = previousOrdersResponse as List;
      final previousOrders = previousData
          .where((o) => o['stato'] != 'cancelled')
          .toList();

      final previousHourlyRevenue = <int, double>{};
      for (final o in previousOrders) {
        final created = DateTime.parse(o['created_at']);
        final hour = created.toLocal().hour;
        previousHourlyRevenue[hour] =
            (previousHourlyRevenue[hour] ?? 0) +
            (o['totale'] as num).toDouble();
      }

      List<dynamic> comparablePreviousOrders = previousOrders;

      if (filter.rangeType == DashboardDateRange.today) {
        final now = DateTime.now();
        final cutoffTime = now.subtract(const Duration(days: 7));

        comparablePreviousOrders = previousOrders.where((o) {
          final orderTimeStr = o['slot_prenotato_start'] ?? o['created_at'];
          final orderTime = DateTime.parse(orderTimeStr);
          return orderTime.isBefore(cutoffTime);
        }).toList();
      }

      final previousRevenue = comparablePreviousOrders.fold<double>(
        0,
        (sum, o) => sum + (o['totale'] as num).toDouble(),
      );
      final previousOrderCount = comparablePreviousOrders.length;
      final previousAvgValue = previousOrderCount > 0
          ? previousRevenue / previousOrderCount
          : 0.0;

      final previousDeliveryOrders = comparablePreviousOrders.where(
        (o) =>
            o['tipo'] == 'delivery' &&
            o['stato'] == 'completed' &&
            o['completato_at'] != null,
      );

      int previousAvgDeliveryTime = 0;
      if (previousDeliveryOrders.isNotEmpty) {
        int totalPrevMinutes = 0;
        for (final o in previousDeliveryOrders) {
          final created = DateTime.parse(o['created_at']);
          final completed = DateTime.parse(o['completato_at']);
          totalPrevMinutes += completed.difference(created).inMinutes;
        }
        previousAvgDeliveryTime =
            totalPrevMinutes ~/ previousDeliveryOrders.length;
      }

      final revenueChange = previousRevenue > 0
          ? ((totalRevenue - previousRevenue) / previousRevenue * 100)
          : 0.0;
      final ordersChange = previousOrderCount > 0
          ? ((totalOrders - previousOrderCount) / previousOrderCount * 100)
          : 0.0;
      final avgValueChange = previousAvgValue > 0
          ? ((avgOrderValue - previousAvgValue) / previousAvgValue * 100)
          : 0.0;
      final deliveryTimeChange = previousAvgDeliveryTime > 0
          ? previousAvgDeliveryTime - avgDeliveryTimeMinutes
          : 0;

      state = AsyncValue.data(
        DashboardAnalytics(
          totalRevenue: totalRevenue,
          totalOrders: totalOrders,
          avgOrderValue: avgOrderValue,
          avgDeliveryTimeMinutes: avgDeliveryTimeMinutes,
          revenueChange: revenueChange,
          ordersChange: ordersChange,
          avgValueChange: avgValueChange,
          deliveryTimeChange: deliveryTimeChange,
          hourlyRevenue: hourlyRevenue,
          previousHourlyRevenue: previousHourlyRevenue,
          salesByCategory: salesByCategory,
          topItems: topItemsList,
          liveOrders: liveOrders,
          totalItemsSold: totalItemsSold,
          currentPeriodLabel: _formatDateRange(startDate, endDate),
          previousPeriodLabel: _formatDateRange(previousStart, previousEnd),
        ),
      );
    } catch (e, stack) {
      Logger.error(
        'Dashboard Analytics Error: $e',
        tag: 'DashboardAnalytics',
        error: e,
        stackTrace: stack,
      );
      state = AsyncValue.error(e, stack);
    }
  }

  DateTime _getPreviousPeriodStart(
    DashboardDateFilter filter,
    DateTime currentStart,
  ) {
    if (filter.rangeType == DashboardDateRange.custom) {
      if (filter.customStart != null && filter.customEnd != null) {
        final duration = filter.customEnd!.difference(filter.customStart!);
        if (duration.inDays <= 7) {
          return currentStart.subtract(const Duration(days: 7));
        }
        return currentStart.subtract(Duration(days: duration.inDays + 1));
      }
      return currentStart.subtract(const Duration(days: 7));
    }

    switch (filter.rangeType) {
      case DashboardDateRange.today:
      case DashboardDateRange.yesterday:
      case DashboardDateRange.thisWeek:
        return currentStart.subtract(const Duration(days: 7));
      case DashboardDateRange.thisMonth:
        final now = DateTime.now();
        return DateTime(now.year, now.month - 1, 1);
      default:
        return currentStart.subtract(const Duration(days: 7));
    }
  }

  DateTime _getPreviousPeriodEnd(
    DashboardDateFilter filter,
    DateTime currentEnd,
  ) {
    if (filter.rangeType == DashboardDateRange.custom) {
      if (filter.customStart != null && filter.customEnd != null) {
        final duration = filter.customEnd!.difference(filter.customStart!);
        if (duration.inDays <= 7) {
          return currentEnd.subtract(const Duration(days: 7));
        }
        return currentEnd.subtract(Duration(days: duration.inDays + 1));
      }
      return currentEnd.subtract(const Duration(days: 7));
    }

    switch (filter.rangeType) {
      case DashboardDateRange.today:
      case DashboardDateRange.yesterday:
      case DashboardDateRange.thisWeek:
        return currentEnd.subtract(const Duration(days: 7));
      case DashboardDateRange.thisMonth:
        final now = DateTime.now();
        return DateTime(now.year, now.month, 0, 23, 59, 59);
      default:
        return currentEnd.subtract(const Duration(days: 7));
    }
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final startStr = '${start.day}/${start.month}';
    final endStr = '${end.day}/${end.month}';
    if (start.day == end.day &&
        start.month == end.month &&
        start.year == end.year) {
      return startStr;
    }
    return '$startStr - $endStr';
  }

  OrderModel _orderFromJson(Map<String, dynamic> json) {
    final itemsList = json['ordini_items'] as List? ?? [];
    final items = itemsList.map((e) {
      final itemJson = e as Map<String, dynamic>;
      return OrderItemModel(
        id: itemJson['id'] as String,
        ordineId: itemJson['ordine_id'] as String,
        menuItemId: itemJson['menu_item_id'] as String?,
        nomeProdotto: itemJson['nome_prodotto'] as String? ?? '',
        quantita: itemJson['quantita'] as int? ?? 1,
        prezzoUnitario: (itemJson['prezzo_unitario'] as num?)?.toDouble() ?? 0,
        subtotale: (itemJson['subtotale'] as num?)?.toDouble() ?? 0,
        note: itemJson['note'] as String?,
        varianti: itemJson['varianti'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(itemJson['created_at'] as String),
      );
    }).toList();

    return OrderModel(
      id: json['id'] as String,
      clienteId: json['cliente_id'] as String?,
      numeroOrdine: json['numero_ordine'] as String? ?? '',
      stato: OrderStatus.fromString(json['stato'] as String? ?? 'pending'),
      tipo: OrderType.fromString(json['tipo'] as String? ?? 'delivery'),
      nomeCliente: json['nome_cliente'] as String? ?? '',
      telefonoCliente: json['telefono_cliente'] as String? ?? '',
      emailCliente: json['email_cliente'] as String?,
      indirizzoConsegna: json['indirizzo_consegna'] as String?,
      cittaConsegna: json['citta_consegna'] as String?,
      capConsegna: json['cap_consegna'] as String?,
      latitudeConsegna: (json['latitude_consegna'] as num?)?.toDouble(),
      longitudeConsegna: (json['longitude_consegna'] as num?)?.toDouble(),
      note: json['note'] as String?,
      subtotale: (json['subtotale'] as num?)?.toDouble() ?? 0,
      costoConsegna: (json['costo_consegna'] as num?)?.toDouble() ?? 0,
      sconto: (json['sconto'] as num?)?.toDouble() ?? 0,
      totale: (json['totale'] as num?)?.toDouble() ?? 0,
      metodoPagamento: json['metodo_pagamento'] != null
          ? PaymentMethod.fromString(json['metodo_pagamento'] as String)
          : null,
      pagato: json['pagato'] as bool? ?? false,
      assegnatoCucinaId: json['assegnato_cucina_id'] as String?,
      assegnatoDeliveryId: json['assegnato_delivery_id'] as String?,
      tempoStimatoMinuti: json['tempo_stimato_minuti'] as int?,
      valutazione: json['valutazione'] as int?,
      recensione: json['recensione'] as String?,
      items: items,
      createdAt: DateTime.parse(json['created_at'] as String),
      confermatoAt: json['confermato_at'] != null
          ? DateTime.parse(json['confermato_at'] as String)
          : null,
      preparazioneAt: json['preparazione_at'] != null
          ? DateTime.parse(json['preparazione_at'] as String)
          : null,
      prontoAt: json['pronto_at'] != null
          ? DateTime.parse(json['pronto_at'] as String)
          : null,
      inConsegnaAt: json['in_consegna_at'] != null
          ? DateTime.parse(json['in_consegna_at'] as String)
          : null,
      completatoAt: json['completato_at'] != null
          ? DateTime.parse(json['completato_at'] as String)
          : null,
      cancellatoAt: json['cancellato_at'] != null
          ? DateTime.parse(json['cancellato_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      slotPrenotatoStart: json['slot_prenotato_start'] != null
          ? DateTime.parse(json['slot_prenotato_start'] as String)
          : null,
    );
  }

  Future<void> refresh() async {
    final filter = _ref.read(dashboardDateFilterProvider);
    await _fetchAnalytics(filter);
  }

  void setDateRange(DashboardDateRange range) {
    if (range == DashboardDateRange.custom) return;
    _ref.read(dashboardDateFilterProvider.notifier).setRange(range);
    final filter = _ref.read(dashboardDateFilterProvider);
    _fetchAnalytics(filter);
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    _ref.read(dashboardDateFilterProvider.notifier).setCustomRange(start, end);
    final filter = _ref.read(dashboardDateFilterProvider);
    _fetchAnalytics(filter);
  }
}

/// Helper class for category accumulation
class _CategoryAccumulator {
  final String id;
  final String name;
  final String? color;
  double revenue = 0;
  int itemCount = 0;

  _CategoryAccumulator({required this.id, required this.name, this.color});
}

/// Helper class for item accumulation
class _ItemAccumulator {
  final String name;
  int salesCount = 0;
  double revenue = 0;

  _ItemAccumulator({required this.name});
}
