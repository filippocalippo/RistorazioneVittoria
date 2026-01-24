import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/enums.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/order_reminder_model.dart';
import '../../../providers/dashboard_analytics_provider.dart';
import '../../../providers/reminders_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/utils/constants.dart';
import '../widgets/premium_date_range_picker.dart';

import 'package:rotante/features/security/widgets/security_guard.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SecurityGuard(
      child: const _DashboardContent(),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsState = ref.watch(dashboardAnalyticsProvider);
    final dateFilter = ref.watch(dashboardDateFilterProvider);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isTablet = AppBreakpoints.isTablet(context);

    return Scaffold(

      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(dashboardAnalyticsProvider.notifier).refresh();
        },
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // Header with date selector
            SliverToBoxAdapter(
              child: _buildHeader(
                context,
                ref,
                dateFilter,
                analyticsState.valueOrNull?.currentPeriodLabel,
                analyticsState.valueOrNull?.previousPeriodLabel,
                isDesktop,
              ),
            ),

            // Content
            analyticsState.when(
              data: (analytics) => SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppBreakpoints.responsive(
                    context: context,
                    mobile: AppSpacing.lg,
                    tablet: AppSpacing.xxl,
                    desktop: AppSpacing.massive,
                  ),
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: AppSpacing.xl),

                    // Stats Cards Row
                    _buildStatsCards(context, analytics, isDesktop, isTablet),

                    const SizedBox(height: AppSpacing.xxl),

                    // Reminders Section
                    _buildRemindersSection(context, ref, isDesktop),

                    const SizedBox(height: AppSpacing.xxl),

                    // Charts Row (Revenue Timeline + Sales by Category)
                    if (isDesktop)
                      _buildChartsRowDesktop(context, ref, analytics)
                    else
                      _buildChartsRowMobile(context, ref, analytics),

                    const SizedBox(height: AppSpacing.xxl),

                    // Quick Actions Row
                    _buildQuickActionsRow(context),

                    const SizedBox(height: AppSpacing.xxl),

                    // Tables Row (Top Items + Live Orders)
                    if (isDesktop)
                      _buildTablesRowDesktop(context, analytics)
                    else
                      _buildTablesRowMobile(context, analytics),

                    const SizedBox(height: AppSpacing.xxxl),
                  ]),
                ),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Errore nel caricamento',
                        style: AppTypography.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: () {
                          ref
                              .read(dashboardAnalyticsProvider.notifier)
                              .refresh();
                        },
                        child: const Text('Riprova'),
                      ),
                    ],
                  ),
                ),
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
    DashboardDateFilter dateFilter,
    String? currentLabel,
    String? previousLabel,
    bool isDesktop,
  ) {
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE d MMMM', 'it_IT');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppBreakpoints.responsive(
          context: context,
          mobile: AppSpacing.lg,
          tablet: AppSpacing.xxl,
          desktop: AppSpacing.massive,
        ),
        vertical: isDesktop ? AppSpacing.xxl : AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Labels
          if (currentLabel != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Periodo corrente: $currentLabel',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: AppTypography.medium,
                  ),
                ),
                if (previousLabel != null)
                  Text(
                    'Periodo precedente: $previousLabel',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            )
          else
            Text(
              dateFormat.format(now),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
                fontWeight: AppTypography.medium,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),

          // Title and dropdown row
          if (isDesktop)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard',
                        style: AppTypography.displaySmall.copyWith(
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Analisi in tempo reale delle performance',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDateRangeDropdown(context, ref, dateFilter),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: AppTypography.headlineLarge.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Analisi in tempo reale delle performance',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: _buildDateRangeDropdown(context, ref, dateFilter),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDateRangeDropdown(
    BuildContext context,
    WidgetRef ref,
    DashboardDateFilter filter,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusLG,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DashboardDateRange>(
          value: filter.rangeType,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.textPrimary,
          ),
          isDense: true,
          dropdownColor: AppColors.surface,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          items: DashboardDateRange.values.map((range) {
            return DropdownMenuItem(
              value: range,
              child: Text(
                range.displayName,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: AppTypography.medium,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) async {
            if (value == null) return;

            if (value == DashboardDateRange.custom) {
              final DateTimeRange? result = await PremiumDateRangePicker.show(
                context,
                initialStart: filter.customStart,
                initialEnd: filter.customEnd,
              );

              if (result != null) {
                ref
                    .read(dashboardAnalyticsProvider.notifier)
                    .setCustomDateRange(result.start, result.end);
              }
            } else {
              ref.read(dashboardAnalyticsProvider.notifier).setDateRange(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildStatsCards(
    BuildContext context,
    DashboardAnalytics analytics,
    bool isDesktop,
    bool isTablet,
  ) {
    final cards = [
      _StatCardData(
        label: 'Incasso Totale',
        value: Formatters.currency(analytics.totalRevenue),
        change: analytics.revenueChange,
        changeLabel: 'vs periodo prec.',
        icon: Icons.euro_rounded,
        color: const Color(0xFF10B981), // Green
        iconBgColor: const Color(0xFFD1FAE5),
      ),
      _StatCardData(
        label: 'Ordini Totali',
        value: analytics.totalOrders.toString(),
        change: analytics.ordersChange,
        changeLabel: 'vs periodo prec.',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFF59E0B), // Orange
        iconBgColor: const Color(0xFFFEF3C7),
      ),
      _StatCardData(
        label: 'Valore Medio Ordine',
        value: Formatters.currency(analytics.avgOrderValue),
        change: analytics.avgValueChange,
        changeLabel: 'vs media',
        icon: Icons.analytics_rounded,
        color: const Color(0xFF8B5CF6), // Purple
        iconBgColor: const Color(0xFFEDE9FE),
      ),
      _StatCardData(
        label: 'Tempo Medio Consegna',
        value: '${analytics.avgDeliveryTimeMinutes}m',
        change: analytics.deliveryTimeChange.toDouble(),
        changeLabel: analytics.deliveryTimeChange > 0
            ? 'piÃ¹ lento'
            : 'piÃ¹ veloce',
        icon: Icons.schedule_rounded,
        color: const Color(0xFF3B82F6), // Blue
        iconBgColor: const Color(0xFFDBEAFE),
        isTimeMetric: true,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          // First card is the glassy incasso card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _GlassyIncassoCard(data: cards[0], isDesktop: isDesktop),
            ),
          ),
          // Other cards use the regular stat card
          ...cards
              .skip(1)
              .map(
                (card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: _buildStatCard(card, isDesktop),
                  ),
                ),
              ),
        ],
      );
    } else if (isTablet) {
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: cards.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;
          return SizedBox(
            width:
                (MediaQuery.of(context).size.width -
                    AppSpacing.xxl * 2 -
                    AppSpacing.md) /
                2,
            child: index == 0
                ? _GlassyIncassoCard(data: card, isDesktop: false)
                : _buildStatCard(card, false),
          );
        }).toList(),
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _GlassyIncassoCard(data: cards[0], isDesktop: false),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildStatCard(cards[1], false)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _buildStatCard(cards[2], false)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildStatCard(cards[3], false)),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildStatCard(_StatCardData data, bool isDesktop) {
    // For time metrics, negative change is good (faster)
    final isPositive = data.isTimeMetric ? data.change < 0 : data.change >= 0;

    final changeColor = isPositive ? AppColors.success : AppColors.error;
    // For time, if it's faster (negative change), show trending down but green.
    // If slower (positive change), show trending up but red.
    final displayIcon = data.isTimeMetric
        ? (data.change < 0
              ? Icons.trending_down_rounded
              : Icons.trending_up_rounded)
        : (data.change >= 0
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded);

    return Container(
      padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data.label,
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: AppTypography.medium,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: isDesktop ? 48 : 40,
                height: isDesktop ? 48 : 40,
                decoration: BoxDecoration(
                  color: data.iconBgColor,
                  borderRadius: AppRadius.radiusMD,
                ),
                child: Icon(
                  data.icon,
                  color: data.color,
                  size: isDesktop ? 24 : 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              style:
                  (isDesktop
                          ? AppTypography.headlineMedium
                          : AppTypography.headlineSmall)
                      .copyWith(
                        fontWeight: AppTypography.bold,
                        color: AppColors.textPrimary,
                      ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(displayIcon, color: changeColor, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${data.change > 0 ? '+' : ''}${data.change.toStringAsFixed(1)}% ${data.changeLabel}',
                  style: AppTypography.captionSmall.copyWith(
                    color: changeColor,
                    fontWeight: AppTypography.medium,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartsRowDesktop(
    BuildContext context,
    WidgetRef ref,
    DashboardAnalytics analytics,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Revenue Timeline (larger)
        Expanded(
          flex: 2,
          child: _buildRevenueTimelineCard(context, analytics, true),
        ),
        const SizedBox(width: AppSpacing.lg),

        // Sales by Category
        Expanded(
          flex: 1,
          child: _buildSalesByCategoryCard(context, ref, analytics, true),
        ),
      ],
    );
  }

  Widget _buildChartsRowMobile(
    BuildContext context,
    WidgetRef ref,
    DashboardAnalytics analytics,
  ) {
    return Column(
      children: [
        _buildRevenueTimelineCard(context, analytics, false),
        const SizedBox(height: AppSpacing.lg),
        _buildSalesByCategoryCard(context, ref, analytics, false),
      ],
    );
  }

  Widget _buildRevenueTimelineCard(
    BuildContext context,
    DashboardAnalytics analytics,
    bool isDesktop,
  ) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Timeline Incassi',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Oggi',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Sett. Scorsa',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: isDesktop ? 220 : 180,
            child: _RevenueChart(
              hourlyRevenue: analytics.hourlyRevenue,
              previousHourlyRevenue: analytics.previousHourlyRevenue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesByCategoryCard(
    BuildContext context,
    WidgetRef ref,
    DashboardAnalytics analytics,
    bool isDesktop,
  ) {
    final categories = analytics.salesByCategory.values.toList();
    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFF59E0B), // Orange
      const Color(0xFFEF4444), // Red
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF10B981), // Green
      const Color(0xFFEC4899), // Pink
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF14B8A6), // Teal
    ];

    return Container(
      padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vendite per Categoria',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.read(dashboardAnalyticsProvider.notifier).refresh();
                },
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: AppColors.textTertiary,
                tooltip: 'Aggiorna',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (categories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text(
                  'Nessun dato',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: isDesktop ? 200 : 300,
              child: isDesktop
                  ? Row(
                      children: [
                        // Donut chart
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: SizedBox(
                              width: 160,
                              height: 160,
                              child: _DonutChart(
                                categories: categories,
                                colors: colors,
                                totalItems: analytics.totalItemsSold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),

                        // Legend (Scrollable)
                        Expanded(
                          flex: 3,
                          child: ListView.builder(
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: colors[index % colors.length],
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        category.categoryName,
                                        style: AppTypography.captionSmall
                                            .copyWith(
                                              fontWeight: AppTypography.medium,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${category.percentage.toStringAsFixed(1)}%',
                                      style: AppTypography.captionSmall
                                          .copyWith(
                                            color: AppColors.textTertiary,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // Donut chart
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: _DonutChart(
                            categories: categories,
                            colors: colors,
                            totalItems: analytics.totalItemsSold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Legend
                        Expanded(
                          child: ListView.builder(
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: colors[index % colors.length],
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        category.categoryName,
                                        style: AppTypography.captionSmall
                                            .copyWith(
                                              fontWeight: AppTypography.medium,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${category.percentage.toStringAsFixed(1)}%',
                                      style: AppTypography.captionSmall
                                          .copyWith(
                                            color: AppColors.textTertiary,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildTablesRowDesktop(
    BuildContext context,
    DashboardAnalytics analytics,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Performing Items
        Expanded(child: _buildTopItemsCard(context, analytics, true)),
        const SizedBox(width: AppSpacing.lg),

        // Live Orders
        Expanded(child: _buildLiveOrdersCard(context, analytics, true)),
      ],
    );
  }

  Widget _buildTablesRowMobile(
    BuildContext context,
    DashboardAnalytics analytics,
  ) {
    return Column(
      children: [
        _buildTopItemsCard(context, analytics, false),
        const SizedBox(height: AppSpacing.lg),
        _buildLiveOrdersCard(context, analytics, false),
      ],
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(RouteNames.deliveryRevenue),
        borderRadius: AppRadius.radiusXXL,
        child: Container(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF3B82F6), const Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.radiusXXL,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: isDesktop ? 64 : 52,
                height: isDesktop ? 64 : 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: AppRadius.radiusLG,
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: isDesktop ? 32 : 28,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fatturato Consegne',
                      style:
                          (isDesktop
                                  ? AppTypography.titleLarge
                                  : AppTypography.titleMedium)
                              .copyWith(
                                color: Colors.white,
                                fontWeight: AppTypography.bold,
                              ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Visualizza incassi e statistiche per ogni fattorino',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: AppRadius.radiusMD,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopItemsCard(
    BuildContext context,
    DashboardAnalytics analytics,
    bool isDesktop,
  ) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prodotti PiÃ¹ Venduti',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () => context.push(RouteNames.productAnalytics),
                    borderRadius: AppRadius.radiusSM,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: AppRadius.radiusSM,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.analytics_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Dettagli',
                            style: AppTypography.captionSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.star_rounded, size: 20, color: AppColors.warning),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'PRODOTTO',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'QTÃ€',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: AppTypography.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'INCASSO',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: AppTypography.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Items
          if (analytics.topItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text(
                  'Nessun prodotto venduto',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            ...analytics.topItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: AppRadius.radiusSM,
                      ),
                      child: Center(
                        child: Text(
                          '#${index + 1}',
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.productName,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: AppTypography.medium,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.salesCount.toString(),
                        style: AppTypography.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        Formatters.currency(item.revenue),
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: AppTypography.semiBold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLiveOrdersCard(
    BuildContext context,
    DashboardAnalytics analytics,
    bool isDesktop,
  ) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.radiusXXL,
      elevation:
          0, // Using shadow from decoration usually, but here we use Material for InkWell
      child: InkWell(
        onTap: () => context.go(RouteNames.managerOrders),
        borderRadius: AppRadius.radiusXXL,
        child: Container(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusXXL,
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Ordini in Corso',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Vedi Tutti',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Table header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ID',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'CLIENTE',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'STATO',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'TOTALE',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: AppTypography.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Orders
              if (analytics.liveOrders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'Nessun ordine attivo',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                )
              else
                ...analytics.liveOrders.take(5).map((order) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '#${order.displayNumeroOrdine}',
                            style: AppTypography.captionSmall.copyWith(
                              color: AppColors.textTertiary,
                              fontWeight: AppTypography.medium,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  order.nomeCliente,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: AppTypography.medium,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (order.tipo == OrderType.delivery) ...[
                                const SizedBox(width: AppSpacing.xs),
                                Icon(
                                  Icons.delivery_dining,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Expanded(child: _OrderStatusBadge(status: order.stato)),
                        Expanded(
                          child: Text(
                            Formatters.currency(order.totale),
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: AppTypography.semiBold,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemindersSection(
    BuildContext context,
    WidgetRef ref,
    bool isDesktop,
  ) {
    final remindersAsync = ref.watch(activeRemindersProvider);

    return remindersAsync.when(
      data: (reminders) {
        if (reminders.isEmpty) {
          return const SizedBox.shrink();
        }

        // Sort by priority (urgent first) then by due date
        final sortedReminders = [...reminders]
          ..sort((a, b) {
            final priorityOrder = {
              ReminderPriority.urgent: 0,
              ReminderPriority.high: 1,
              ReminderPriority.normal: 2,
              ReminderPriority.low: 3,
            };
            final priorityCompare = priorityOrder[a.priorita]!.compareTo(
              priorityOrder[b.priorita]!,
            );
            if (priorityCompare != 0) return priorityCompare;

            // Overdue first
            if (a.isOverdue && !b.isOverdue) return -1;
            if (!a.isOverdue && b.isOverdue) return 1;

            return a.createdAt.compareTo(b.createdAt);
          });

        return Container(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.radiusXXL,
            boxShadow: AppShadows.sm,
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.warning,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Promemoria Attivi',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                        Text(
                          '${reminders.length} promemoria',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ref.read(activeRemindersProvider.notifier).refresh();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: AppColors.textTertiary,
                    tooltip: 'Aggiorna',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Reminders list
              ...sortedReminders.take(5).map((reminder) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _buildReminderCard(context, ref, reminder, isDesktop),
                );
              }),

              if (reminders.length > 5)
                Center(
                  child: TextButton(
                    onPressed: () => context.go(RouteNames.managerOrders),
                    child: Text(
                      'Vedi tutti (${reminders.length - 5} altri)',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildReminderCard(
    BuildContext context,
    WidgetRef ref,
    OrderReminderModel reminder,
    bool isDesktop,
  ) {
    final isOverdue = reminder.isOverdue;

    return Container(
      decoration: BoxDecoration(
        color: isOverdue
            ? AppColors.error.withValues(alpha: 0.05)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: reminder.priorita.color, width: 4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(RouteNames.managerOrders),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                // Priority indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: reminder.priorita.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    reminder.priorita.icon,
                    color: reminder.priorita.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reminder.titolo,
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: AppTypography.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (reminder.timeStatus != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? AppColors.error.withValues(alpha: 0.15)
                                    : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                reminder.timeStatus!,
                                style: AppTypography.captionSmall.copyWith(
                                  color: isOverdue
                                      ? AppColors.error
                                      : AppColors.textSecondary,
                                  fontWeight: AppTypography.medium,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (reminder.descrizione != null &&
                          reminder.descrizione!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          reminder.descrizione!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            reminder.numeroOrdine != null
                                ? 'Ordine #${reminder.numeroOrdine!.split('-').last}'
                                : 'Ordine',
                            style: AppTypography.captionSmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (reminder.nomeCliente != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'â€¢ ${reminder.nomeCliente}',
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                const SizedBox(width: AppSpacing.md),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Complete button
                    IconButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(activeRemindersProvider.notifier)
                              .complete(reminder.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Promemoria completato'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Errore: $e'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      color: AppColors.success,
                      tooltip: 'Completa',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.success.withValues(
                          alpha: 0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    // Go to order button
                    IconButton(
                      onPressed: () => context.go(RouteNames.managerOrders),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      color: AppColors.primary,
                      tooltip: 'Vai all\'ordine',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Data class for stat cards
class _StatCardData {
  final String label;
  final String value;
  final double change;
  final String changeLabel;
  final IconData icon;
  final Color color;
  final Color iconBgColor;
  final bool isTimeMetric;

  _StatCardData({
    required this.label,
    required this.value,
    required this.change,
    required this.changeLabel,
    required this.icon,
    required this.color,
    required this.iconBgColor,
    this.isTimeMetric = false,
  });
}

/// A glassy/blurred stat card that reveals its content when tapped
/// Used for sensitive data like revenue that should be hidden by default
class _GlassyIncassoCard extends StatefulWidget {
  final _StatCardData data;
  final bool isDesktop;

  const _GlassyIncassoCard({required this.data, required this.isDesktop});

  @override
  State<_GlassyIncassoCard> createState() => _GlassyIncassoCardState();
}

class _GlassyIncassoCardState extends State<_GlassyIncassoCard>
    with SingleTickerProviderStateMixin {
  bool _isRevealed = false;
  late AnimationController _controller;
  late Animation<double> _blurAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _blurAnimation = Tween<double>(
      begin: 8.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleReveal() {
    setState(() {
      _isRevealed = !_isRevealed;
      if (_isRevealed) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isDesktop = widget.isDesktop;

    // For time metrics, negative change is good (faster)
    final isPositive = data.isTimeMetric ? data.change < 0 : data.change >= 0;
    final changeColor = isPositive ? AppColors.success : AppColors.error;
    final displayIcon = data.isTimeMetric
        ? (data.change < 0
              ? Icons.trending_down_rounded
              : Icons.trending_up_rounded)
        : (data.change >= 0
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded);

    return GestureDetector(
      onTap: _toggleReveal,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.radiusXXL,
              boxShadow: AppShadows.sm,
              border: !_isRevealed
                  ? Border.all(
                      color: data.color.withValues(alpha: 0.3),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                // Content
                Opacity(
                  opacity: _opacityAnimation.value,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    data.label,
                                    style: AppTypography.captionSmall.copyWith(
                                      color: AppColors.textTertiary,
                                      fontWeight: AppTypography.medium,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!_isRevealed) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  Icon(
                                    Icons.visibility_off_rounded,
                                    size: 14,
                                    color: AppColors.textTertiary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            width: isDesktop ? 48 : 40,
                            height: isDesktop ? 48 : 40,
                            decoration: BoxDecoration(
                              color: data.iconBgColor,
                              borderRadius: AppRadius.radiusMD,
                            ),
                            child: Icon(
                              data.icon,
                              color: data.color,
                              size: isDesktop ? 24 : 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ClipRect(
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: _blurAnimation.value,
                            sigmaY: _blurAnimation.value,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              data.value,
                              style:
                                  (isDesktop
                                          ? AppTypography.headlineMedium
                                          : AppTypography.headlineSmall)
                                      .copyWith(
                                        fontWeight: AppTypography.bold,
                                        color: AppColors.textPrimary,
                                      ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRect(
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: _blurAnimation.value * 0.5,
                            sigmaY: _blurAnimation.value * 0.5,
                          ),
                          child: Row(
                            children: [
                              Icon(displayIcon, color: changeColor, size: 16),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  '${data.change > 0 ? '+' : ''}${data.change.toStringAsFixed(1)}% ${data.changeLabel}',
                                  style: AppTypography.captionSmall.copyWith(
                                    color: changeColor,
                                    fontWeight: AppTypography.medium,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Revenue chart widget
// Revenue chart widget using fl_chart
class _RevenueChart extends StatelessWidget {
  final Map<int, double> hourlyRevenue;
  final Map<int, double> previousHourlyRevenue;

  const _RevenueChart({
    required this.hourlyRevenue,
    required this.previousHourlyRevenue,
  });

  @override
  Widget build(BuildContext context) {
    if (hourlyRevenue.isEmpty && previousHourlyRevenue.isEmpty) {
      return Center(
        child: Text(
          'Nessun dato disponibile',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      );
    }

    final currentHours = hourlyRevenue.keys.toList();
    final prevHours = previousHourlyRevenue.keys.toList();
    final allHours = [...currentHours, ...prevHours]..sort();

    final minHour = allHours.isEmpty ? 0 : allHours.first;
    var maxHour = allHours.isEmpty ? 23 : allHours.last;
    if (minHour == maxHour) {
      maxHour = minHour + 1;
    }

    final maxCurrentRev = hourlyRevenue.values.isEmpty
        ? 0.0
        : hourlyRevenue.values.reduce(math.max);
    final maxPrevRev = previousHourlyRevenue.values.isEmpty
        ? 0.0
        : previousHourlyRevenue.values.reduce(math.max);

    final maxRevenue = math.max(maxCurrentRev, maxPrevRev);
    final displayMaxRevenue = maxRevenue == 0 ? 100.0 : maxRevenue;

    // Create spots for the chart
    final spots = <FlSpot>[];
    final prevSpots = <FlSpot>[];

    for (int i = minHour; i <= maxHour; i++) {
      if (hourlyRevenue.containsKey(i) || (i >= minHour && i <= maxHour)) {
        // Add explicit 0 for missing hours inside the range to keep the line continuous or meaningful
        // FlSpot requires contiguous X for nice lines, usually we iterate over all hours
        spots.add(FlSpot(i.toDouble(), hourlyRevenue[i] ?? 0));
      }
      if (previousHourlyRevenue.containsKey(i) ||
          (i >= minHour && i <= maxHour)) {
        prevSpots.add(FlSpot(i.toDouble(), previousHourlyRevenue[i] ?? 0));
      }
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: displayMaxRevenue > 0 ? displayMaxRevenue / 4 : 1,
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
              interval: 2, // Show every 2 hours
              getTitlesWidget: (value, meta) {
                final hour = value.toInt();
                if (hour < minHour || hour > maxHour) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
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
              reservedSize: 40,
              interval: displayMaxRevenue > 0 ? displayMaxRevenue / 4 : 1,
              getTitlesWidget: (value, meta) {
                if (value < 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    '€${value.toInt()}',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: minHour.toDouble(),
        maxX: maxHour.toDouble(),
        minY: 0,
        maxY: displayMaxRevenue * 1.1, // Add some padding on top
        lineBarsData: [
          // Previous Period Line (Gray)
          LineChartBarData(
            spots: prevSpots,
            isCurved: true,
            color: AppColors.textTertiary.withValues(alpha: 0.3),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
            dashArray: [5, 5],
          ),
          // Current Period Line (Red)
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFFEF4444),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFFEF4444),
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
                  const Color(0xFFEF4444).withValues(alpha: 0.2),
                  const Color(0xFFEF4444).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => AppColors.surface,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipBorder: BorderSide(color: AppColors.border),
            getTooltipItems: (touchedSpots) {
              // Sort spots so we know which is which (based on bar index order or we check color)
              // But FlChart gives us all spots for that X in touchedSpots
              return touchedSpots.map((spot) {
                final isCurrent = spot.barIndex == 1; // 1 is Red, 0 is Gray
                final label = isCurrent ? 'Oggi' : 'Sett. Scorsa';
                final color = isCurrent
                    ? const Color(0xFFEF4444)
                    : AppColors.textTertiary;

                // We can show time on the first item
                final showTime = spot == touchedSpots.first;

                return LineTooltipItem(
                  showTime ? '${spot.x.toInt()}:00\n' : '',
                  AppTypography.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: AppTypography.bold,
                  ),
                  children: [
                    TextSpan(
                      text: '$label: ${Formatters.currency(spot.y)}\n',
                      style: AppTypography.bodySmall.copyWith(
                        color: color,
                        fontWeight: AppTypography.bold,
                        fontSize: 12,
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
}

// Donut chart widget using fl_chart
class _DonutChart extends StatefulWidget {
  final List<CategorySalesData> categories;
  final List<Color> colors;
  final int totalItems;

  const _DonutChart({
    required this.categories,
    required this.colors,
    required this.totalItems,
  });

  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) {
      return const SizedBox();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse == null ||
                      pieTouchResponse.touchedSection == null) {
                    touchedIndex = -1;
                    return;
                  }
                  touchedIndex =
                      pieTouchResponse.touchedSection!.touchedSectionIndex;
                });
              },
            ),
            borderData: FlBorderData(show: false),
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: List.generate(widget.categories.length, (i) {
              final isTouched = i == touchedIndex;
              final fontSize = isTouched ? 16.0 : 0.0; // Hide labels by default
              final radius = isTouched ? 50.0 : 40.0;
              final category = widget.categories[i];
              final color = widget.colors[i % widget.colors.length];

              return PieChartSectionData(
                color: color,
                value: category.percentage,
                title: '${category.percentage.toStringAsFixed(1)}%',
                radius: radius,
                titleStyle: AppTypography.captionSmall.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.totalItems.toString(),
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: AppTypography.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'VENDUTI',
              style: AppTypography.captionSmall.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 1,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Order status badge
class _OrderStatusBadge extends StatelessWidget {
  final OrderStatus status;

  const _OrderStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case OrderStatus.pending:
        color = AppColors.warning;
        label = 'Attesa';
        break;
      case OrderStatus.confirmed:
        color = AppColors.info;
        label = 'Confermato';
        break;
      case OrderStatus.preparing:
        color = const Color(0xFFF59E0B);
        label = 'Cottura';
        break;
      case OrderStatus.ready:
        color = AppColors.success;
        label = 'Pronto';
        break;
      case OrderStatus.delivering:
        color = AppColors.accent;
        label = 'Consegna';
        break;
      case OrderStatus.completed:
        color = AppColors.success;
        label = 'Consegnato';
        break;
      case OrderStatus.cancelled:
        color = AppColors.error;
        label = 'Annullato';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.radiusSM,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: AppTypography.captionSmall.copyWith(
                color: color,
                fontWeight: AppTypography.semiBold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
