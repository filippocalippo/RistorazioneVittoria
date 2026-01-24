import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/enums.dart';
import '../../../core/models/order_model.dart';
import '../../../providers/delivery_revenue_provider.dart';

class DeliveryRevenueScreen extends ConsumerStatefulWidget {
  const DeliveryRevenueScreen({super.key});

  @override
  ConsumerState<DeliveryRevenueScreen> createState() =>
      _DeliveryRevenueScreenState();
}

class _DeliveryRevenueScreenState extends ConsumerState<DeliveryRevenueScreen> {
  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(deliveryRevenueDateProvider);
    final revenueData = ref.watch(deliveryRevenueProvider);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isTablet = AppBreakpoints.isTablet(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => ref.read(deliveryRevenueProvider.notifier).refresh(),
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // Header with date selector
            SliverToBoxAdapter(
              child: _buildHeader(context, selectedDate, isDesktop),
            ),

            // Summary cards
            SliverToBoxAdapter(
              child: revenueData.when(
                data: (data) =>
                    _buildSummaryCards(context, data, isDesktop, isTablet),
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
              ),
            ),

            // Main content
            revenueData.when(
              data: (data) => SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppBreakpoints.responsive(
                    context: context,
                    mobile: AppSpacing.lg,
                    tablet: AppSpacing.xxl,
                    desktop: AppSpacing.massive,
                  ),
                ),
                sliver: data.personStats.isEmpty
                    ? SliverFillRemaining(child: _buildEmptyState())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xl,
                                bottom: AppSpacing.lg,
                              ),
                              child: Text(
                                'Dettaglio per Operatore',
                                style: AppTypography.titleLarge.copyWith(
                                  fontWeight: AppTypography.bold,
                                ),
                              ),
                            );
                          }
                          final person = data.personStats[index - 1];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _DeliveryPersonCard(
                              stats: person,
                              isDesktop: isDesktop,
                            ),
                          );
                        }, childCount: data.personStats.length + 1),
                      ),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (error, _) =>
                  SliverFillRemaining(child: _buildErrorState(error)),
            ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    DateTime selectedDate,
    bool isDesktop,
  ) {
    final dateFormat = DateFormat('EEEE d MMMM yyyy', 'it_IT');

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
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and title
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceLight,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fatturato Consegne',
                      style:
                          (isDesktop
                                  ? AppTypography.displaySmall
                                  : AppTypography.headlineMedium)
                              .copyWith(fontWeight: AppTypography.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Analisi dettagliata delle consegne per operatore',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Date selector
          Row(
            children: [
              // Previous day
              IconButton(
                onPressed: () {
                  final newDate = selectedDate.subtract(
                    const Duration(days: 1),
                  );
                  ref
                      .read(deliveryRevenueDateProvider.notifier)
                      .setDate(newDate);
                },
                icon: const Icon(Icons.chevron_left_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceLight,
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              // Date picker button
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, selectedDate),
                  borderRadius: AppRadius.radiusLG,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: AppRadius.radiusLG,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          dateFormat.format(selectedDate),
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: AppTypography.semiBold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              // Next day
              IconButton(
                onPressed:
                    selectedDate.isBefore(
                      DateTime.now().subtract(const Duration(days: 1)),
                    )
                    ? () {
                        final newDate = selectedDate.add(
                          const Duration(days: 1),
                        );
                        ref
                            .read(deliveryRevenueDateProvider.notifier)
                            .setDate(newDate);
                      }
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceLight,
                  disabledBackgroundColor: AppColors.surfaceLight.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              // Today button
              TextButton.icon(
                onPressed: () {
                  ref
                      .read(deliveryRevenueDateProvider.notifier)
                      .setDate(DateTime.now());
                },
                icon: const Icon(Icons.today_rounded, size: 18),
                label: const Text('Oggi'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusLG,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, DateTime currentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('it', 'IT'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(deliveryRevenueDateProvider.notifier).setDate(picked);
    }
  }

  Widget _buildSummaryCards(
    BuildContext context,
    DeliveryRevenueData data,
    bool isDesktop,
    bool isTablet,
  ) {
    final cards = [
      _SummaryCardData(
        label: 'Consegne Totali',
        value: data.totalDeliveries.toString(),
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF3B82F6),
        iconBgColor: const Color(0xFFDBEAFE),
      ),
      _SummaryCardData(
        label: 'Incasso Totale',
        value: Formatters.currency(data.totalRevenue),
        icon: Icons.euro_rounded,
        color: const Color(0xFF10B981),
        iconBgColor: const Color(0xFFD1FAE5),
      ),
      _SummaryCardData(
        label: 'Da Ritirare',
        value: Formatters.currency(data.totalEarnings),
        subtitle: '${data.totalDeliveries} × €3',
        icon: Icons.payments_rounded,
        color: const Color(0xFFF59E0B),
        iconBgColor: const Color(0xFFFEF3C7),
      ),
      _SummaryCardData(
        label: 'Puntuali',
        value: '${data.overallOnTimePercentage.toStringAsFixed(0)}%',
        subtitle: '${data.totalOnTime}/${data.totalDeliveries}',
        icon: Icons.schedule_rounded,
        color: data.overallOnTimePercentage >= 80
            ? const Color(0xFF10B981)
            : data.overallOnTimePercentage >= 60
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444),
        iconBgColor: data.overallOnTimePercentage >= 80
            ? const Color(0xFFD1FAE5)
            : data.overallOnTimePercentage >= 60
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEE2E2),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppBreakpoints.responsive(
          context: context,
          mobile: AppSpacing.lg,
          tablet: AppSpacing.xxl,
          desktop: AppSpacing.massive,
        ),
        vertical: AppSpacing.xl,
      ),
      child: isDesktop
          ? Row(
              children: [
                // First card - regular
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: _buildSummaryCard(cards[0], isDesktop),
                  ),
                ),
                // Second card - glassy incasso
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: _GlassyIncassoCard(
                      data: cards[1],
                      isDesktop: isDesktop,
                    ),
                  ),
                ),
                // Remaining cards - regular
                ...cards
                    .skip(2)
                    .map(
                      (card) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          child: _buildSummaryCard(card, isDesktop),
                        ),
                      ),
                    ),
              ],
            )
          : isTablet
          ? Wrap(
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
                  child: index == 1
                      ? _GlassyIncassoCard(data: card, isDesktop: false)
                      : _buildSummaryCard(card, false),
                );
              }).toList(),
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard(cards[0], false)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _GlassyIncassoCard(
                        data: cards[1],
                        isDesktop: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard(cards[2], false)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _buildSummaryCard(cards[3], false)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(_SummaryCardData data, bool isDesktop) {
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
          if (data.subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              data.subtitle!,
              style: AppTypography.captionSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Nessuna consegna',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: AppTypography.semiBold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Non ci sono consegne completate per questa data',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.lg),
          Text('Errore nel caricamento', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error.toString(),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            onPressed: () =>
                ref.read(deliveryRevenueProvider.notifier).refresh(),
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCardData {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Color iconBgColor;

  const _SummaryCardData({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.iconBgColor,
  });
}

/// A glassy/blurred summary card that reveals its content when tapped
/// Used for sensitive data like revenue that should be hidden by default
class _GlassyIncassoCard extends StatefulWidget {
  final _SummaryCardData data;
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
            child: Opacity(
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
                  if (data.subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    ClipRect(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: _blurAnimation.value * 0.5,
                          sigmaY: _blurAnimation.value * 0.5,
                        ),
                        child: Text(
                          data.subtitle!,
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Card widget for individual delivery person stats
class _DeliveryPersonCard extends StatefulWidget {
  final DeliveryPersonStats stats;
  final bool isDesktop;

  const _DeliveryPersonCard({required this.stats, required this.isDesktop});

  @override
  State<_DeliveryPersonCard> createState() => _DeliveryPersonCardState();
}

class _DeliveryPersonCardState extends State<_DeliveryPersonCard> {
  bool _isExpanded = false;
  bool _showAllOrders = false;

  @override
  Widget build(BuildContext context) {
    final isManager = widget.stats.role == UserRole.manager;
    final roleColor = isManager ? AppColors.warning : AppColors.info;
    final roleLabel = isManager ? 'Manager' : 'Fattorino';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        boxShadow: AppShadows.sm,
        border: Border.all(
          color: _isExpanded
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
          width: _isExpanded ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Main content - tappable
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: AppRadius.radiusXXL,
            child: Padding(
              padding: EdgeInsets.all(
                widget.isDesktop ? AppSpacing.xl : AppSpacing.lg,
              ),
              child: Column(
                children: [
                  // Header row
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              roleColor.withValues(alpha: 0.8),
                              roleColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: AppRadius.radiusLG,
                        ),
                        child: Center(
                          child: Text(
                            widget.stats.name.isNotEmpty
                                ? widget.stats.name[0].toUpperCase()
                                : '?',
                            style: AppTypography.headlineSmall.copyWith(
                              color: Colors.white,
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: AppSpacing.lg),

                      // Name and role
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.stats.name,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: AppTypography.semiBold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.12),
                                borderRadius: AppRadius.radiusSM,
                              ),
                              child: Text(
                                roleLabel,
                                style: AppTypography.captionSmall.copyWith(
                                  color: roleColor,
                                  fontWeight: AppTypography.semiBold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Expand icon
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Stats row
                  if (widget.isDesktop)
                    Row(
                      children: [
                        _buildStatChip(
                          icon: Icons.local_shipping_rounded,
                          label: 'Consegne',
                          value: widget.stats.totalDeliveries.toString(),
                          color: const Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _buildStatChip(
                          icon: Icons.euro_rounded,
                          label: 'Incassato',
                          value: Formatters.currency(
                            widget.stats.totalAmountInHand,
                          ),
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _buildStatChip(
                          icon: Icons.payments_rounded,
                          label: 'Da Ritirare',
                          value: Formatters.currency(
                            widget.stats.earningsFromDeliveries,
                          ),
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _buildStatChip(
                          icon: Icons.schedule_rounded,
                          label: 'Puntuali',
                          value:
                              '${widget.stats.onTimePercentage.toStringAsFixed(0)}%',
                          color: widget.stats.onTimePercentage >= 80
                              ? const Color(0xFF10B981)
                              : widget.stats.onTimePercentage >= 60
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFEF4444),
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _buildCompactStatChip(
                          icon: Icons.local_shipping_rounded,
                          value: widget.stats.totalDeliveries.toString(),
                          label: 'consegne',
                          color: const Color(0xFF3B82F6),
                        ),
                        _buildCompactStatChip(
                          icon: Icons.euro_rounded,
                          value: Formatters.currency(
                            widget.stats.totalAmountInHand,
                          ),
                          label: 'incassato',
                          color: const Color(0xFF10B981),
                        ),
                        _buildCompactStatChip(
                          icon: Icons.payments_rounded,
                          value: Formatters.currency(
                            widget.stats.earningsFromDeliveries,
                          ),
                          label: 'da ritirare',
                          color: const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Expanded details
          if (_isExpanded) ...[
            const Divider(height: 1),
            _buildExpandedDetails(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.radiusLG,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: AppTypography.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.radiusMD,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.labelMedium.copyWith(
              fontWeight: AppTypography.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails() {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance metrics
          Row(
            children: [
              Expanded(
                child: _buildDetailMetric(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Puntuali',
                  value: widget.stats.deliveriesOnTime.toString(),
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildDetailMetric(
                  icon: Icons.watch_later_outlined,
                  label: 'In Ritardo',
                  value: widget.stats.deliveriesLate.toString(),
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildDetailMetric(
                  icon: Icons.timer_outlined,
                  label: 'Tempo Medio',
                  value: widget.stats.averageDeliveryTime > 0
                      ? '${widget.stats.averageDeliveryTime.toStringAsFixed(0)} min'
                      : 'N/A',
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),

          if (widget.stats.orders.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),

            Text(
              'Ordini del giorno (${widget.stats.orders.length})',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: AppTypography.semiBold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Order list
            ...widget.stats.orders
                .take(_showAllOrders ? widget.stats.orders.length : 10)
                .map((order) {
                  final completedTime = order.completatoAt != null
                      ? timeFormat.format(order.completatoAt!.toLocal())
                      : '--:--';
                  final isLate =
                      order.slotPrenotatoStart != null &&
                      order.completatoAt != null &&
                      order.completatoAt!.isAfter(
                        order.slotPrenotatoStart!.add(
                          const Duration(minutes: 15),
                        ),
                      );
                  final slotTime = order.slotPrenotatoStart != null
                      ? dateFormat.format(order.slotPrenotatoStart!.toLocal())
                      : '--:--';

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: AppRadius.radiusMD,
                      border: Border.all(
                        color: isLate
                            ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Order number
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.radiusSM,
                          ),
                          child: Text(
                            '#${order.displayNumeroOrdine}',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),

                        // Customer and address
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.nomeCliente,
                                style: AppTypography.labelMedium.copyWith(
                                  fontWeight: AppTypography.medium,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (order.zone != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  order.zone!,
                                  style: AppTypography.captionSmall.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Time info
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                if (isLate)
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 14,
                                  ),
                                if (isLate)
                                  const SizedBox(width: AppSpacing.xs),
                                Text(
                                  completedTime,
                                  style: AppTypography.labelMedium.copyWith(
                                    fontWeight: AppTypography.semiBold,
                                    color: isLate
                                        ? const Color(0xFFEF4444)
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Slot: $slotTime',
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: AppSpacing.md),

                        // Amount
                        Text(
                          Formatters.currency(order.totale),
                          style: AppTypography.labelMedium.copyWith(
                            fontWeight: AppTypography.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

            if (!_showAllOrders && widget.stats.orders.length > 10) ...[
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: () => setState(() => _showAllOrders = true),
                borderRadius: AppRadius.radiusSM,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xs,
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(
                    'Mostra altri ${widget.stats.orders.length - 10} ordini',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDetailMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppRadius.radiusMD,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: AppTypography.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
