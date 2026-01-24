import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/config/supabase_config.dart';
import '../../../providers/auth_provider.dart';

/// Time range options for analytics
enum AnalyticsTimeRange {
  today('Oggi'),
  yesterday('Ieri'),
  week('Settimana'),
  month('Mese'),
  year('Anno');

  final String label;
  const AnalyticsTimeRange(this.label);
}

/// Simple order info for analytics list
class CompletedOrderInfo {
  final String id;
  final String numeroOrdine;
  final String nomeCliente;
  final double totale;
  final DateTime completatoAt;

  const CompletedOrderInfo({
    required this.id,
    required this.numeroOrdine,
    required this.nomeCliente,
    required this.totale,
    required this.completatoAt,
  });
}

/// Analytics data model
class DeliveryAnalyticsData {
  final int ordersCompleted;
  final double estimatedIncome;
  final Map<String, int> ordersByDay;
  final Map<int, int> ordersByHour;
  final List<CompletedOrderInfo> ordersList;

  const DeliveryAnalyticsData({
    required this.ordersCompleted,
    required this.estimatedIncome,
    required this.ordersByDay,
    required this.ordersByHour,
    required this.ordersList,
  });

  factory DeliveryAnalyticsData.empty() => const DeliveryAnalyticsData(
    ordersCompleted: 0,
    estimatedIncome: 0,
    ordersByDay: {},
    ordersByHour: {},
    ordersList: [],
  );
}

/// Provider for fetching delivery analytics
final deliveryAnalyticsProvider =
    FutureProvider.family<DeliveryAnalyticsData, AnalyticsTimeRange>((
      ref,
      timeRange,
    ) async {
      final user = ref.read(authProvider).value;
      if (user == null) return DeliveryAnalyticsData.empty();

      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;

      switch (timeRange) {
        case AnalyticsTimeRange.today:
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case AnalyticsTimeRange.yesterday:
          startDate = DateTime(now.year, now.month, now.day - 1);
          endDate = DateTime(now.year, now.month, now.day);
          break;
        case AnalyticsTimeRange.week:
          startDate = now.subtract(const Duration(days: 7));
          break;
        case AnalyticsTimeRange.month:
          startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case AnalyticsTimeRange.year:
          startDate = DateTime(now.year - 1, now.month, now.day);
          break;
      }

      try {
        // Fetch completed orders for this driver within the time range
        final response = await SupabaseConfig.client
            .from('ordini')
            .select(
              'id, numero_ordine, nome_cliente, totale, completato_at, created_at',
            )
            .eq('tipo', 'delivery')
            .eq('stato', 'completed')
            .eq('assegnato_delivery_id', user.id)
            .gte('completato_at', startDate.toIso8601String())
            .lte('completato_at', endDate.toIso8601String())
            .order('completato_at', ascending: false);

        final orders = response as List<dynamic>;

        // Process orders by day
        final Map<String, int> ordersByDay = {};
        final Map<int, int> ordersByHour = {};
        final List<CompletedOrderInfo> ordersList = [];

        for (final order in orders) {
          final completedAtStr = order['completato_at'] as String?;
          if (completedAtStr != null) {
            final completedAt = DateTime.parse(completedAtStr);

            // Group by day
            final dayKey = DateFormat('yyyy-MM-dd').format(completedAt);
            ordersByDay[dayKey] = (ordersByDay[dayKey] ?? 0) + 1;

            // Group by hour
            final hour = completedAt.hour;
            ordersByHour[hour] = (ordersByHour[hour] ?? 0) + 1;

            // Add to orders list
            ordersList.add(
              CompletedOrderInfo(
                id: order['id'] as String,
                numeroOrdine: order['numero_ordine'] as String? ?? '',
                nomeCliente: order['nome_cliente'] as String? ?? 'Cliente',
                totale: (order['totale'] as num?)?.toDouble() ?? 0.0,
                completatoAt: completedAt,
              ),
            );
          }
        }

        final ordersCompleted = orders.length;
        final estimatedIncome = ordersCompleted * 3.0; // €3 per order

        return DeliveryAnalyticsData(
          ordersCompleted: ordersCompleted,
          estimatedIncome: estimatedIncome,
          ordersByDay: ordersByDay,
          ordersByHour: ordersByHour,
          ordersList: ordersList,
        );
      } catch (e) {
        debugPrint('Error fetching delivery analytics: $e');
        return DeliveryAnalyticsData.empty();
      }
    });

/// State provider for selected time range
final selectedTimeRangeProvider = StateProvider<AnalyticsTimeRange>(
  (ref) => AnalyticsTimeRange.today,
);

/// Delivery Analytics Screen - Shows delivery performance stats
class DeliveryAnalyticsScreen extends ConsumerWidget {
  const DeliveryAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(selectedTimeRangeProvider);
    final analyticsAsync = ref.watch(deliveryAnalyticsProvider(selectedRange));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref, selectedRange),
            Expanded(
              child: analyticsAsync.when(
                data: (analytics) =>
                    _buildContent(context, analytics, selectedRange),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, _) => _buildErrorState(context, ref, error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AnalyticsTimeRange selectedRange,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.xs,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and title
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.textPrimary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANALITICHE',
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: AppTypography.extraBold,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Le tue statistiche di consegna',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Time range selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: AnalyticsTimeRange.values.map((range) {
                final isSelected = range == selectedRange;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Material(
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppRadius.circular),
                    child: InkWell(
                      onTap: () {
                        ref.read(selectedTimeRangeProvider.notifier).state =
                            range;
                      },
                      borderRadius: BorderRadius.circular(AppRadius.circular),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        child: Text(
                          range.label,
                          style: AppTypography.labelMedium.copyWith(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? AppTypography.bold
                                : AppTypography.medium,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DeliveryAnalyticsData analytics,
    AnalyticsTimeRange selectedRange,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          _buildStatsRow(context, analytics),
          const SizedBox(height: AppSpacing.xl),

          // Orders by hour chart (for today/yesterday)
          if (selectedRange == AnalyticsTimeRange.today ||
              selectedRange == AnalyticsTimeRange.yesterday)
            _buildHourlyChart(context, analytics),

          // Orders by day chart (for week/month/year)
          if (selectedRange == AnalyticsTimeRange.week ||
              selectedRange == AnalyticsTimeRange.month ||
              selectedRange == AnalyticsTimeRange.year)
            _buildDailyChart(context, analytics, selectedRange),

          const SizedBox(height: AppSpacing.xl),

          // Performance summary card
          _buildPerformanceSummary(context, analytics, selectedRange),

          const SizedBox(height: AppSpacing.xl),

          // Orders list
          if (analytics.ordersList.isNotEmpty)
            _buildOrdersList(context, analytics),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, DeliveryAnalyticsData analytics) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_shipping_rounded,
            iconColor: const Color(0xFF10B981),
            iconBgColor: const Color(0xFFD1FAE5),
            label: 'Consegne',
            value: analytics.ordersCompleted.toString(),
            subtitle: 'completate',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            icon: Icons.euro_rounded,
            iconColor: const Color(0xFFD4463C),
            iconBgColor: const Color(0xFFFEE2E2),
            label: 'Guadagni',
            value: '€${analytics.estimatedIncome.toStringAsFixed(0)}',
            subtitle: 'stimati',
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyChart(
    BuildContext context,
    DeliveryAnalyticsData analytics,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consegne per Ora',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Live',
                      style: AppTypography.captionSmall.copyWith(
                        color: const Color(0xFF10B981),
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 200,
            child: _HourlyBarChart(ordersByHour: analytics.ordersByHour),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyChart(
    BuildContext context,
    DeliveryAnalyticsData analytics,
    AnalyticsTimeRange selectedRange,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Andamento Consegne',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              Text(
                _getRangeLabel(selectedRange),
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 220,
            child: _DailyLineChart(
              ordersByDay: analytics.ordersByDay,
              timeRange: selectedRange,
            ),
          ),
        ],
      ),
    );
  }

  String _getRangeLabel(AnalyticsTimeRange range) {
    switch (range) {
      case AnalyticsTimeRange.week:
        return 'Ultimi 7 giorni';
      case AnalyticsTimeRange.month:
        return 'Ultimo mese';
      case AnalyticsTimeRange.year:
        return 'Ultimo anno';
      default:
        return '';
    }
  }

  Widget _buildPerformanceSummary(
    BuildContext context,
    DeliveryAnalyticsData analytics,
    AnalyticsTimeRange selectedRange,
  ) {
    final avgPerDay =
        analytics.ordersCompleted > 0 && analytics.ordersByDay.isNotEmpty
        ? (analytics.ordersCompleted / analytics.ordersByDay.length)
              .toStringAsFixed(1)
        : '0';

    final peakHour = analytics.ordersByHour.entries.isEmpty
        ? null
        : analytics.ordersByHour.entries.reduce(
            (a, b) => a.value > b.value ? a : b,
          );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.textPrimary,
            AppColors.textPrimary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: AppShadows.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Riepilogo Performance',
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Performance metrics
          Row(
            children: [
              Expanded(
                child: _PerformanceMetric(
                  label: 'Media/Giorno',
                  value: avgPerDay,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _PerformanceMetric(
                  label: 'Ora di Punta',
                  value: peakHour != null ? '${peakHour.key}:00' : '-',
                  icon: Icons.access_time_rounded,
                ),
              ),
            ],
          ),

          if (analytics.ordersCompleted > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: const Color(0xFFFFD700),
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _getMotivationalMessage(analytics.ordersCompleted),
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getMotivationalMessage(int orders) {
    if (orders >= 20) {
      return 'Incredibile! Sei un campione delle consegne! 🚀';
    } else if (orders >= 10) {
      return 'Ottimo lavoro! Continua così! 💪';
    } else if (orders >= 5) {
      return 'Buon ritmo! Stai facendo progressi! 👍';
    } else {
      return 'Ogni consegna conta! Avanti tutta! 🎯';
    }
  }

  Widget _buildOrdersList(
    BuildContext context,
    DeliveryAnalyticsData analytics,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ordini Completati',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  '${analytics.ordersList.length}',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Orders list
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: analytics.ordersList.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final order = analytics.ordersList[index];
              return _OrderListItem(order: order);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Errore nel caricamento',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: AppTypography.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error.toString(),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                final range = ref.read(selectedTimeRangeProvider);
                ref.invalidate(deliveryAnalyticsProvider(range));
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stat card widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String label;
  final String value;
  final String subtitle;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: AppTypography.extraBold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$label $subtitle',
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textTertiary,
              fontWeight: AppTypography.medium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Performance metric widget
class _PerformanceMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PerformanceMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 20),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: AppTypography.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.captionSmall.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// Order list item widget
class _OrderListItem extends StatelessWidget {
  final CompletedOrderInfo order;

  const _OrderListItem({required this.order});

  @override
  Widget build(BuildContext context) {
    // Get display number (last 4 digits)
    final displayNumber = order.numeroOrdine.split('-').last;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          // Order number badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text(
                '#$displayNumber',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Order details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.nomeCliente,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('HH:mm').format(order.completatoAt),
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Price
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              '€${order.totale.toStringAsFixed(2)}',
              style: AppTypography.labelMedium.copyWith(
                color: const Color(0xFF10B981),
                fontWeight: AppTypography.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hourly bar chart using fl_chart
class _HourlyBarChart extends StatelessWidget {
  final Map<int, int> ordersByHour;

  const _HourlyBarChart({required this.ordersByHour});

  @override
  Widget build(BuildContext context) {
    if (ordersByHour.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 48,
              color: AppColors.textTertiary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nessuna consegna',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    final maxOrders = ordersByHour.values.isEmpty
        ? 1.0
        : ordersByHour.values.reduce(math.max).toDouble();

    // Create bars for work hours (10:00 - 23:00)
    final List<BarChartGroupData> barGroups = [];
    for (int hour = 10; hour <= 23; hour++) {
      final count = ordersByHour[hour] ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: count > 0 ? const Color(0xFF10B981) : AppColors.border,
              width: 16,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxOrders * 1.1,
                color: AppColors.surfaceLight,
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxOrders * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppColors.textPrimary,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final count = rod.toY.toInt();
              return BarTooltipItem(
                '${group.x}:00\n',
                AppTypography.captionSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                children: [
                  TextSpan(
                    text: '$count ${count == 1 ? 'consegna' : 'consegne'}',
                    style: AppTypography.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final hour = value.toInt();
                // Show every 2 hours
                if (hour % 2 != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$hour',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxOrders > 4 ? (maxOrders / 4).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  value.toInt().toString(),
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxOrders > 4
              ? (maxOrders / 4).ceilToDouble()
              : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.border.withValues(alpha: 0.5),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }
}

/// Daily line chart using fl_chart
class _DailyLineChart extends StatelessWidget {
  final Map<String, int> ordersByDay;
  final AnalyticsTimeRange timeRange;

  const _DailyLineChart({required this.ordersByDay, required this.timeRange});

  @override
  Widget build(BuildContext context) {
    if (ordersByDay.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 48,
              color: AppColors.textTertiary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nessun dato disponibile',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    // Sort days and create spots
    final sortedDays = ordersByDay.keys.toList()..sort();
    final spots = <FlSpot>[];

    for (int i = 0; i < sortedDays.length; i++) {
      spots.add(FlSpot(i.toDouble(), ordersByDay[sortedDays[i]]!.toDouble()));
    }

    final maxOrders = ordersByDay.values.isEmpty
        ? 1.0
        : ordersByDay.values.reduce(math.max).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxOrders > 4
              ? (maxOrders / 4).ceilToDouble()
              : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.border.withValues(alpha: 0.5),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _getInterval(sortedDays.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedDays.length) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _formatDayLabel(sortedDays[index]),
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxOrders > 4 ? (maxOrders / 4).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  value.toInt().toString(),
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (sortedDays.length - 1).toDouble().clamp(0, double.infinity),
        minY: 0,
        maxY: maxOrders * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: const Color(0xFF10B981),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: const Color(0xFF10B981),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.3),
                  const Color(0xFF10B981).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => AppColors.textPrimary,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.spotIndex;
                final day = index < sortedDays.length ? sortedDays[index] : '';
                final count = spot.y.toInt();
                return LineTooltipItem(
                  '${_formatFullDate(day)}\n',
                  AppTypography.captionSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  children: [
                    TextSpan(
                      text: '$count ${count == 1 ? 'consegna' : 'consegne'}',
                      style: AppTypography.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }

  double _getInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 30) return 5;
    return 10;
  }

  String _formatDayLabel(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatFullDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMM', 'it_IT').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
