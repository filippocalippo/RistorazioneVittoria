import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/product_analytics_provider.dart';
import '../../../providers/dashboard_analytics_provider.dart';
import '../widgets/premium_date_range_picker.dart';

/// State provider for selected time range in product analytics
final productAnalyticsTimeRangeProvider = StateProvider<DashboardDateFilter>(
  (ref) => DashboardDateFilter.preset(DashboardDateRange.today),
);

/// Product Analytics Screen - Detailed product performance analysis
class ProductAnalyticsScreen extends ConsumerWidget {
  const ProductAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(productAnalyticsTimeRangeProvider);
    final analyticsAsync = ref.watch(productAnalyticsProvider(filter));
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header with back button and date filter
          SliverToBoxAdapter(
            child: _buildHeader(context, ref, filter, isDesktop),
          ),

          // Content
          analyticsAsync.when(
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

                  // Summary Stats
                  _buildSummaryStats(context, analytics, isDesktop),

                  const SizedBox(height: AppSpacing.xxl),

                  // Top Products Section
                  if (isDesktop)
                    _buildProductsRowDesktop(context, analytics)
                  else
                    _buildProductsRowMobile(context, analytics),

                  const SizedBox(height: AppSpacing.xxl),

                  // Ingredients Analysis Section
                  if (isDesktop)
                    _buildIngredientsRowDesktop(context, analytics)
                  else
                    _buildIngredientsRowMobile(context, analytics),

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
              child: _buildErrorState(context, ref, error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    DashboardDateFilter filter,
    bool isDesktop,
  ) {
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
          // Back button and title row
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.radiusMD,
                    boxShadow: AppShadows.xs,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
                tooltip: 'Indietro',
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analisi Prodotti',
                      style:
                          (isDesktop
                                  ? AppTypography.displaySmall
                                  : AppTypography.headlineLarge)
                              .copyWith(fontWeight: AppTypography.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Analisi dettagliata delle vendite e preferenze',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDateRangeDropdown(context, ref, filter),
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
                ref.read(productAnalyticsTimeRangeProvider.notifier).state =
                    DashboardDateFilter.custom(result.start, result.end);
              }
            } else {
              ref.read(productAnalyticsTimeRangeProvider.notifier).state =
                  DashboardDateFilter.preset(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSummaryStats(
    BuildContext context,
    ProductAnalyticsData analytics,
    bool isDesktop,
  ) {
    // Incasso card (using glassy effect)
    final incassoCard = _SummaryCard(
      label: 'Incasso Totale',
      value: Formatters.currency(analytics.totalRevenue),
      icon: Icons.euro_rounded,
      color: const Color(0xFF10B981),
      bgColor: const Color(0xFFD1FAE5),
    );

    // Other non-expandable cards
    final otherCards = [
      _SummaryCard(
        label: 'Top Prodotti',
        value: analytics.topSellingProducts.length.toString(),
        icon: Icons.trending_up_rounded,
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFEF3C7),
      ),
      _SummaryCard(
        label: 'Extra Aggiunti',
        value: analytics.mostAddedIngredients
            .fold<int>(0, (sum, i) => sum + i.count)
            .toString(),
        icon: Icons.add_circle_rounded,
        color: const Color(0xFF8B5CF6),
        bgColor: const Color(0xFFEDE9FE),
      ),
    ];

    // Expandable "Prodotti Venduti" card data
    final prodottiVendutiCard = _SummaryCard(
      label: 'Prodotti Venduti',
      value: analytics.totalProductsSold.toString(),
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFF3B82F6),
      bgColor: const Color(0xFFDBEAFE),
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expandable Prodotti Venduti card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _ExpandableSummaryCard(
                data: prodottiVendutiCard,
                isDesktop: isDesktop,
                salesBySize: analytics.salesBySize,
              ),
            ),
          ),
          // Glassy Incasso card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _GlassyIncassoCard(
                data: incassoCard,
                isDesktop: isDesktop,
              ),
            ),
          ),
          // Other regular cards
          ...otherCards.map(
            (card) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: _buildSummaryCard(card, isDesktop),
              ),
            ),
          ),
        ],
      );
    }

    final halfWidth =
        (MediaQuery.of(context).size.width -
            AppSpacing.lg * 2 -
            AppSpacing.md) /
        2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full-width expandable card for Prodotti Venduti
        _ExpandableSummaryCard(
          data: prodottiVendutiCard,
          isDesktop: isDesktop,
          salesBySize: analytics.salesBySize,
        ),
        const SizedBox(height: AppSpacing.md),
        // Glassy incasso card - full width on mobile
        _GlassyIncassoCard(data: incassoCard, isDesktop: false),
        const SizedBox(height: AppSpacing.md),
        // Other cards in a 2-column wrap layout
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: otherCards.map((card) {
            return SizedBox(
              width: halfWidth,
              child: _buildSummaryCard(card, false),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(_SummaryCard data, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Container(
            width: isDesktop ? 56 : 44,
            height: isDesktop ? 56 : 44,
            decoration: BoxDecoration(
              color: data.bgColor,
              borderRadius: AppRadius.radiusMD,
            ),
            child: Icon(
              data.icon,
              color: data.color,
              size: isDesktop ? 28 : 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: AppTypography.medium,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.value,
                    style:
                        (isDesktop
                                ? AppTypography.headlineSmall
                                : AppTypography.titleLarge)
                            .copyWith(fontWeight: AppTypography.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsRowDesktop(
    BuildContext context,
    ProductAnalyticsData analytics,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildProductsCard(
            context,
            'Prodotti Più Venduti',
            Icons.trending_up_rounded,
            const Color(0xFF10B981),
            analytics.topSellingProducts,
            true,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _buildProductsCard(
            context,
            'Prodotti Meno Venduti',
            Icons.trending_down_rounded,
            const Color(0xFFEF4444),
            analytics.leastSellingProducts,
            true,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsRowMobile(
    BuildContext context,
    ProductAnalyticsData analytics,
  ) {
    return Column(
      children: [
        _buildProductsCard(
          context,
          'Prodotti Più Venduti',
          Icons.trending_up_rounded,
          const Color(0xFF10B981),
          analytics.topSellingProducts,
          false,
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildProductsCard(
          context,
          'Prodotti Meno Venduti',
          Icons.trending_down_rounded,
          const Color(0xFFEF4444),
          analytics.leastSellingProducts,
          false,
        ),
      ],
    );
  }

  Widget _buildProductsCard(
    BuildContext context,
    String title,
    IconData icon,
    Color iconColor,
    List<ProductAnalyticsItem> products,
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
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: Text(
                  'Nessun dato disponibile',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            ...products.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return _ExpandableProductTile(
                index: index + 1,
                product: product,
                isDesktop: isDesktop,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildIngredientsRowDesktop(
    BuildContext context,
    ProductAnalyticsData analytics,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildIngredientsCard(
            context,
            'Extra Più Aggiunti',
            Icons.add_circle_rounded,
            const Color(0xFF10B981),
            analytics.mostAddedIngredients,
            true,
            showRevenue: true,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _buildIngredientsCard(
            context,
            'Ingredienti Più Rimossi',
            Icons.remove_circle_rounded,
            const Color(0xFFEF4444),
            analytics.mostRemovedIngredients,
            true,
            showRevenue: false,
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsRowMobile(
    BuildContext context,
    ProductAnalyticsData analytics,
  ) {
    return Column(
      children: [
        _buildIngredientsCard(
          context,
          'Extra Più Aggiunti',
          Icons.add_circle_rounded,
          const Color(0xFF10B981),
          analytics.mostAddedIngredients,
          false,
          showRevenue: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildIngredientsCard(
          context,
          'Ingredienti Più Rimossi',
          Icons.remove_circle_rounded,
          const Color(0xFFEF4444),
          analytics.mostRemovedIngredients,
          false,
          showRevenue: false,
        ),
      ],
    );
  }

  Widget _buildIngredientsCard(
    BuildContext context,
    String title,
    IconData icon,
    Color iconColor,
    List<IngredientAnalytics> ingredients,
    bool isDesktop, {
    bool showRevenue = false,
  }) {
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
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.titleMedium.copyWith(
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
                const SizedBox(width: 32), // Rank width
                Expanded(
                  flex: 3,
                  child: Text(
                    'INGREDIENTE',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'QTÀ',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: AppTypography.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (showRevenue)
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

          if (ingredients.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text(
                  'Nessun dato',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            ...ingredients.asMap().entries.map((entry) {
              final index = entry.key;
              final ingredient = entry.value;
              return _buildIngredientRow(index + 1, ingredient, showRevenue);
            }),
        ],
      ),
    );
  }

  Widget _buildIngredientRow(
    int rank,
    IngredientAnalytics ingredient,
    bool showRevenue,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? AppColors.primarySubtle
                  : AppColors.surfaceLight,
              borderRadius: AppRadius.radiusSM,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: AppTypography.captionSmall.copyWith(
                  color: rank <= 3
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(
              ingredient.name,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: AppTypography.medium,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              ingredient.count.toString(),
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          if (showRevenue)
            Expanded(
              flex: 2,
              child: Text(
                Formatters.currency(ingredient.totalRevenue),
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: AppTypography.semiBold,
                  color: const Color(0xFF10B981),
                ),
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.error.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Errore nel caricamento',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Si è verificato un errore durante il caricamento dei dati.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(productAnalyticsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Riprova'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for summary cards
class _SummaryCard {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

/// A glassy/blurred summary card that reveals its content when tapped
/// Used for sensitive data like revenue that should be hidden by default
class _GlassyIncassoCard extends StatefulWidget {
  final _SummaryCard data;
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
                  child: Row(
                    children: [
                      Container(
                        width: isDesktop ? 56 : 44,
                        height: isDesktop ? 56 : 44,
                        decoration: BoxDecoration(
                          color: data.bgColor,
                          borderRadius: AppRadius.radiusMD,
                        ),
                        child: Icon(
                          data.icon,
                          color: data.color,
                          size: isDesktop ? 28 : 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                if (!_isRevealed)
                                  Icon(
                                    Icons.visibility_off_rounded,
                                    size: 14,
                                    color: AppColors.textTertiary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
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
                                                ? AppTypography.headlineSmall
                                                : AppTypography.titleLarge)
                                            .copyWith(
                                              fontWeight: AppTypography.bold,
                                            ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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

/// Expandable summary card with size breakdown
class _ExpandableSummaryCard extends StatefulWidget {
  final _SummaryCard data;
  final bool isDesktop;
  final Map<String, int> salesBySize;

  const _ExpandableSummaryCard({
    required this.data,
    required this.isDesktop,
    required this.salesBySize,
  });

  @override
  State<_ExpandableSummaryCard> createState() => _ExpandableSummaryCardState();
}

class _ExpandableSummaryCardState extends State<_ExpandableSummaryCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _expansionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _expansionAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header (always visible, tappable)
          InkWell(
            onTap: widget.salesBySize.isNotEmpty ? _toggleExpansion : null,
            child: Padding(
              padding: EdgeInsets.all(
                isDesktop ? AppSpacing.xl : AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Container(
                    width: isDesktop ? 56 : 44,
                    height: isDesktop ? 56 : 44,
                    decoration: BoxDecoration(
                      color: data.bgColor,
                      borderRadius: AppRadius.radiusMD,
                    ),
                    child: Icon(
                      data.icon,
                      color: data.color,
                      size: isDesktop ? 28 : 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.label,
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: AppTypography.medium,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            data.value,
                            style:
                                (isDesktop
                                        ? AppTypography.headlineSmall
                                        : AppTypography.titleLarge)
                                    .copyWith(fontWeight: AppTypography.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.salesBySize.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    RotationTransition(
                      turns: _rotationAnimation,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expanded content - Size breakdown
          SizeTransition(
            sizeFactor: _expansionAnimation,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: EdgeInsets.all(
                isDesktop ? AppSpacing.xl : AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.pie_chart_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Vendite per Dimensione',
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: AppTypography.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...widget.salesBySize.entries.map((entry) {
                    final sizeName = entry.key;
                    final count = entry.value;
                    final percentage = widget.salesBySize.values.isEmpty
                        ? 0.0
                        : (count /
                                  widget.salesBySize.values.reduce(
                                    (a, b) => a + b,
                                  )) *
                              100;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          // Size name
                          Expanded(
                            flex: 2,
                            child: Text(
                              sizeName,
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: AppTypography.medium,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Progress bar
                          Expanded(
                            flex: 3,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: AppRadius.radiusXS,
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: percentage / 100,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        widget.data.color,
                                        widget.data.color.withValues(
                                          alpha: 0.7,
                                        ),
                                      ],
                                    ),
                                    borderRadius: AppRadius.radiusXS,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          // Count badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.data.bgColor,
                              borderRadius: AppRadius.radiusSM,
                            ),
                            child: Text(
                              '$count',
                              style: AppTypography.captionSmall.copyWith(
                                color: widget.data.color,
                                fontWeight: AppTypography.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          // Percentage
                          SizedBox(
                            width: 45,
                            child: Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.textTertiary,
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
        ],
      ),
    );
  }
}

/// Expandable product tile with charts
class _ExpandableProductTile extends StatefulWidget {
  final int index;
  final ProductAnalyticsItem product;
  final bool isDesktop;

  const _ExpandableProductTile({
    required this.index,
    required this.product,
    required this.isDesktop,
  });

  @override
  State<_ExpandableProductTile> createState() => _ExpandableProductTileState();
}

class _ExpandableProductTileState extends State<_ExpandableProductTile>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _expansionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _expansionAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.radiusLG,
        border: Border.all(
          color: _isExpanded
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // Header row (always visible)
          InkWell(
            onTap: _toggleExpansion,
            borderRadius: AppRadius.radiusLG,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: widget.index <= 3
                          ? LinearGradient(
                              colors: _getRankGradient(widget.index),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: widget.index > 3 ? AppColors.surfaceLight : null,
                      borderRadius: AppRadius.radiusSM,
                    ),
                    child: Center(
                      child: Text(
                        '#${widget.index}',
                        style: AppTypography.captionSmall.copyWith(
                          color: widget.index <= 3
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Product name
                  Expanded(
                    flex: 3,
                    child: Text(
                      widget.product.productName,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: AppTypography.semiBold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Quantity
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: AppRadius.radiusSM,
                    ),
                    child: Text(
                      '${widget.product.salesCount}',
                      style: AppTypography.captionSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: AppSpacing.md),

                  // Revenue
                  Text(
                    Formatters.currency(widget.product.revenue),
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: AppTypography.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // Expand icon
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          SizeTransition(
            sizeFactor: _expansionAnimation,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Daily sales chart
                  if (widget.product.salesByDay.isNotEmpty) ...[
                    Text(
                      'Vendite Giornaliere',
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: AppTypography.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 120,
                      child: _DailySalesChart(
                        salesByDay: widget.product.salesByDay,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // Ingredients section
                  if (widget.product.topAddedIngredients.isNotEmpty ||
                      widget.product.topRemovedIngredients.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.product.topAddedIngredients.isNotEmpty)
                          Expanded(
                            child: _buildIngredientsList(
                              'Extra Aggiunti',
                              Icons.add_circle_rounded,
                              const Color(0xFF10B981),
                              widget.product.topAddedIngredients,
                            ),
                          ),
                        if (widget.product.topAddedIngredients.isNotEmpty &&
                            widget.product.topRemovedIngredients.isNotEmpty)
                          const SizedBox(width: AppSpacing.lg),
                        if (widget.product.topRemovedIngredients.isNotEmpty)
                          Expanded(
                            child: _buildIngredientsList(
                              'Ingredienti Rimossi',
                              Icons.remove_circle_rounded,
                              const Color(0xFFEF4444),
                              widget.product.topRemovedIngredients,
                            ),
                          ),
                      ],
                    ),

                  if (widget.product.topAddedIngredients.isEmpty &&
                      widget.product.topRemovedIngredients.isEmpty &&
                      widget.product.salesByDay.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'Nessun dato dettagliato disponibile',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getRankGradient(int rank) {
    switch (rank) {
      case 1:
        return [const Color(0xFFFFC700), const Color(0xFFFFAA00)]; // Gold
      case 2:
        return [const Color(0xFFC0C0C0), const Color(0xFF909090)]; // Silver
      case 3:
        return [const Color(0xFFCD7F32), const Color(0xFF8B4513)]; // Bronze
      default:
        return [AppColors.surfaceLight, AppColors.surfaceLight];
    }
  }

  Widget _buildIngredientsList(
    String title,
    IconData icon,
    Color color,
    Map<String, dynamic> ingredients,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(
              title,
              style: AppTypography.labelSmall.copyWith(
                fontWeight: AppTypography.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...ingredients.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: AppTypography.captionSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: AppRadius.radiusXS,
                  ),
                  child: Text(
                    '×${entry.value}',
                    style: AppTypography.captionSmall.copyWith(
                      color: color,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Daily sales bar chart
class _DailySalesChart extends StatelessWidget {
  final Map<String, int> salesByDay;

  const _DailySalesChart({required this.salesByDay});

  @override
  Widget build(BuildContext context) {
    if (salesByDay.isEmpty) {
      return Center(
        child: Text(
          'Nessun dato',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      );
    }

    final sortedDays = salesByDay.keys.toList()..sort();
    final maxSales = salesByDay.values.reduce(math.max).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxSales * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppColors.textPrimary,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = sortedDays[groupIndex];
              final count = salesByDay[day] ?? 0;
              return BarTooltipItem(
                '${_formatDate(day)}\n',
                AppTypography.captionSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                children: [
                  TextSpan(
                    text: '$count vendite',
                    style: AppTypography.labelSmall.copyWith(
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
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedDays.length) return const SizedBox();
                final day = sortedDays[value.toInt()];
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatShortDate(day),
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                    ),
                  ),
                );
              },
              reservedSize: 20,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: sortedDays.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          final count = salesByDay[day] ?? 0;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: sortedDays.length > 7 ? 12 : 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(String dayKey) {
    try {
      final date = DateTime.parse(dayKey);
      return DateFormat('d MMMM', 'it_IT').format(date);
    } catch (_) {
      return dayKey;
    }
  }

  String _formatShortDate(String dayKey) {
    try {
      final date = DateTime.parse(dayKey);
      return DateFormat('d/M', 'it_IT').format(date);
    } catch (_) {
      return dayKey;
    }
  }
}
