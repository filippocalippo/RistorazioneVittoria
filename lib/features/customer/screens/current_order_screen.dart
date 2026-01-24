import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/order_model.dart';
import '../../../core/utils/enums.dart';
import '../../../core/utils/constants.dart';
import '../../../providers/customer_orders_provider.dart';
import '../../../providers/pizzeria_settings_provider.dart';
import '../widgets/order_status_timeline.dart';
import '../widgets/order_summary_card.dart';
import '../widgets/cancel_order_dialog.dart';

/// Screen that displays the customer's active orders and allows tracking.
class CurrentOrderScreen extends ConsumerStatefulWidget {
  const CurrentOrderScreen({super.key});

  @override
  ConsumerState<CurrentOrderScreen> createState() => _CurrentOrderScreenState();
}

class _CurrentOrderScreenState extends ConsumerState<CurrentOrderScreen> {
  String? _selectedOrderId;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(customerOrdersProvider);
    final pizzeriaSettings = ref.watch(pizzeriaSettingsProvider);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final pizzeriaName = pizzeriaSettings.when(
      data: (settings) => settings?.pizzeria.nome ?? 'Pizzeria',
      loading: () => 'Pizzeria',
      error: (e, s) => 'Pizzeria',
    );

    ordersAsync.whenData((orders) {
      if (orders.isNotEmpty && orders.every((o) => o.id != _selectedOrderId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _selectedOrderId = orders.first.id;
          });
        });
      }

      if (orders.isEmpty && _selectedOrderId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selectedOrderId = null);
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, AppColors.surface],
          ),
        ),
        child: ordersAsync.when(
          data: (orders) =>
              _buildContent(context, orders, pizzeriaName, isDesktop),
          loading: () => _buildLoadingState(context),
          error: (err, _) => _buildErrorState(context, err),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              height: 48,
              width: 48,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go(RouteNames.menu),
                style: IconButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ),
            Expanded(
              child: Text(
                'I tuoi ordini attivi',
                textAlign: TextAlign.center,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(
              height: 48,
              width: 48,
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  ref.read(customerOrdersProvider.notifier).refresh();
                },
                style: IconButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<OrderModel> orders,
    String pizzeriaName,
    bool isDesktop,
  ) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(customerOrdersProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(
            bottom: 130,
          ), // Added bottom padding for navbar
          child: Column(
            children: [
              // Show top app bar only on desktop (mobile has unified top bar)
              if (isDesktop) _buildTopAppBar(context),
              SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: _buildEmptyState(context),
              ),
            ],
          ),
        ),
      );
    }

    final selectedOrder = orders.firstWhere(
      (order) => order.id == _selectedOrderId,
      orElse: () => orders.first,
    );

    final canCancel = selectedOrder.stato == OrderStatus.confirmed;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(customerOrdersProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: isDesktop ? 0 : 100, // Added top padding for mobile top bar
          bottom: 100,
        ),
        child: Column(
          children: [
            // Show top app bar only on desktop (mobile has unified top bar)
            if (isDesktop) _buildTopAppBar(context),
            _buildOrderSwitcher(context, orders, selectedOrder, pizzeriaName),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: AnimatedSwitcher(
                duration: AppAnimations.medium,
                switchInCurve: AppAnimations.easeOut,
                switchOutCurve: AppAnimations.easeIn,
                child: Column(
                  key: ValueKey(selectedOrder.id),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OrderStatusTimeline(
                      currentStatus: selectedOrder.stato,
                      confirmedAt:
                          selectedOrder.confermatoAt ?? selectedOrder.createdAt,
                      preparingAt: selectedOrder.preparazioneAt,
                      deliveringAt:
                          selectedOrder.inConsegnaAt ?? selectedOrder.prontoAt,
                      completedAt: selectedOrder.completatoAt,
                      orderType: selectedOrder.tipo,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    OrderSummaryCard(order: selectedOrder),
                    const SizedBox(height: AppSpacing.lg),
                    _buildCancelButton(context, selectedOrder, canCancel),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSwitcher(
    BuildContext context,
    List<OrderModel> orders,
    OrderModel selectedOrder,
    String pizzeriaName,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppShadows.lg,
          ),
          padding: const EdgeInsets.only(left: AppSpacing.xl),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedOrder.id,
              icon: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  right: AppSpacing.lg,
                ),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
              dropdownColor: AppColors.surface,
              borderRadius: AppRadius.radiusXL,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              onChanged: (value) {
                if (value == null) return;
                HapticFeedback.selectionClick();
                setState(() => _selectedOrderId = value);
              },
              items: orders.map((order) {
                return DropdownMenuItem<String>(
                  value: order.id,
                  child: Text(
                    'Ordine #${order.displayNumeroOrdine}',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton(
    BuildContext context,
    OrderModel order,
    bool canCancel,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canCancel ? () => _handleCancelOrder(context, order) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canCancel
              ? AppColors.primary
              : AppColors.textDisabled,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
          elevation: 0,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textSecondary,
        ),
        child: Text(
          'Annulla Ordine',
          style: AppTypography.buttonLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        children: [
          SizedBox(
            height: 64,
            width: 64,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Carichiamo i tuoi ordini...',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXXL,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inbox_outlined,
                  size: 56,
                  color: AppColors.textDisabled,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Nessun ordine in corso',
                textAlign: TextAlign.center,
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Quando effettuerai un ordine potrai seguirlo qui in ogni fase.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: () => context.go(RouteNames.menu),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxxl,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusXL,
                  ),
                ),
                child: Text(
                  'Vai al menu',
                  style: AppTypography.buttonMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXXL,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Ops, qualcosa è andato storto',
                textAlign: TextAlign.center,
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: () =>
                    ref.read(customerOrdersProvider.notifier).refresh(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxxl,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusXL,
                  ),
                ),
                child: Text(
                  'Riprova',
                  style: AppTypography.buttonMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCancelOrder(
    BuildContext context,
    OrderModel order,
  ) async {
    final shouldCancel = await CancelOrderDialog.show(
      context,
      orderNumber: order.numeroOrdine,
    );

    if (shouldCancel != true) return;

    try {
      await ref.read(customerOrdersProvider.notifier).cancelOrder(order.id);
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ordine #${order.displayNumeroOrdine} annullato',
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
