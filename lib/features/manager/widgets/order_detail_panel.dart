import 'package:flutter/material.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/enums.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/order_item_model.dart';

/// Modern order detail panel matching the reference design
/// Features a two-column layout with items on left and status/customer/payment on right
class OrderDetailPanel extends StatelessWidget {
  final OrderModel order;
  final ScrollController? scrollController;
  final VoidCallback onModify;
  final Function(OrderStatus) onStatusChange;
  final VoidCallback onCancel;
  final VoidCallback onPrint;
  final VoidCallback onTogglePagato;
  final VoidCallback onClose;
  final VoidCallback? onCreateReminder;

  const OrderDetailPanel({
    super.key,
    required this.order,
    this.scrollController,
    required this.onModify,
    required this.onStatusChange,
    required this.onCancel,
    required this.onPrint,
    required this.onTogglePagato,
    required this.onClose,
    this.onCreateReminder,
  });

  Color get _statusColor {
    switch (order.stato) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.preparing:
        return AppColors.primary;
      case OrderStatus.ready:
        return AppColors.success;
      case OrderStatus.delivering:
        return AppColors.accent;
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  bool get _canModify =>
      order.stato != OrderStatus.completed &&
      order.stato != OrderStatus.cancelled;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1200;

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Header with order number and actions
          _buildHeader(context),

          // Content
          Expanded(
            child: isDesktop
                ? _buildDesktopLayout(context)
                : _buildMobileLayout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Breadcrumb
          Row(
            children: [
              GestureDetector(
                onTap: onClose,
                child: Text(
                  'Ordini',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  '/',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.border,
                  ),
                ),
              ),
              Text(
                'Ordine #${order.displayNumeroOrdine}',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: AppTypography.medium,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          _buildOrderHeader(),
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column - Order info and items
              Expanded(
                flex: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (order.slotPrenotatoStart != null) ...[
                      _buildScheduledTimeBanner(),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    _buildItemsCard(),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              // Right column - Status, Customer, Payment
              SizedBox(
                width: 380,
                child: Column(
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildCustomerCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _buildOrderHeader(),
        if (order.slotPrenotatoStart != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _buildScheduledTimeBanner(),
        ],
        const SizedBox(height: AppSpacing.lg),
        _buildStatusCard(),
        const SizedBox(height: AppSpacing.lg),
        _buildItemsCard(),
        const SizedBox(height: AppSpacing.lg),
        _buildCustomerCard(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildOrderHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ordine #${order.displayNumeroOrdine}',
                style: AppTypography.headlineLarge.copyWith(
                  fontWeight: AppTypography.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    Formatters.dateTime(order.createdAt),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    order.tipo.displayName,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Action buttons
        Row(
          children: [
            if (_canModify) ...[
              if (onCreateReminder != null) ...[
                _buildActionButton(
                  icon: Icons.notification_add_rounded,
                  label: 'Promemoria',
                  onTap: onCreateReminder!,
                  isPrimary: false,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              _buildActionButton(
                icon: Icons.print_rounded,
                label: 'Stampa',
                onTap: onPrint,
                isPrimary: false,
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildActionButton(
                icon: Icons.edit_rounded,
                label: 'Modifica',
                onTap: onModify,
                isPrimary: true,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: isPrimary ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: isPrimary ? null : Border.all(color: AppColors.border),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? Colors.white : AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: isPrimary ? Colors.white : AppColors.textPrimary,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prodotti',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                Text(
                  '${order.totalItems} articoli',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Items list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Column(
              children: order.items.map((item) => _buildItemRow(item)).toList(),
            ),
          ),
          // Kitchen note
          if (order.note != null && order.note!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nota cucina',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            order.note!,
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Pricing summary footer
          _buildPricingSummary(),
        ],
      ),
    );
  }

  /// Prominent scheduled time banner - visible at a glance
  Widget _buildScheduledTimeBanner() {
    final isDelivery = order.tipo == OrderType.delivery;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isDelivery
                  ? Icons.delivery_dining_rounded
                  : Icons.shopping_bag_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDelivery ? 'CONSEGNA PREVISTA' : 'RITIRO PREVISTO',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Formatters.time(order.slotPrenotatoStart!),
                  style: AppTypography.headlineLarge.copyWith(
                    fontWeight: AppTypography.bold,
                    color: AppColors.primary,
                    fontSize: 36,
                  ),
                ),
                Text(
                  Formatters.fullDate(order.slotPrenotatoStart!),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pricing summary integrated into items card footer
  Widget _buildPricingSummary() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Column(
        children: [
          // Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotale',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                Formatters.currency(order.subtotale),
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: AppTypography.medium,
                ),
              ),
            ],
          ),
          if (order.costoConsegna > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Consegna',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  Formatters.currency(order.costoConsegna),
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: AppTypography.medium,
                  ),
                ),
              ],
            ),
          ],
          if (order.sconto > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sconto',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.success,
                  ),
                ),
                Text(
                  '-${Formatters.currency(order.sconto)}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.success,
                    fontWeight: AppTypography.medium,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          // Total with prominent styling
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Totale',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Payment status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: order.pagato
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          order.pagato
                              ? Icons.check_circle_rounded
                              : Icons.pending_rounded,
                          size: 14,
                          color: order.pagato
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.pagato ? 'Pagato' : 'Da pagare',
                          style: AppTypography.labelSmall.copyWith(
                            color: order.pagato
                                ? AppColors.success
                                : AppColors.warning,
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                Formatters.currency(order.totale),
                style: AppTypography.headlineLarge.copyWith(
                  fontWeight: AppTypography.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          // Toggle payment button
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onTogglePagato,
              icon: Icon(
                order.pagato ? Icons.money_off_rounded : Icons.payments_rounded,
                size: 20,
              ),
              label: Text(
                order.pagato ? 'Segna come NON Pagato' : 'Segna come Pagato',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: order.pagato
                    ? AppColors.warning
                    : AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Product image placeholder
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.local_pizza_rounded,
              color: AppColors.textTertiary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.isSplitProduct
                      ? item.splitProductNames
                      : item.nomeProdotto,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                if (item.sizeName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.sizeName,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (item.removedIngredients.isNotEmpty ||
                    item.addedIngredients.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...item.removedIngredients.map(
                        (ing) => _buildIngredientBadge(
                          ing['name'] ?? '',
                          isRemoved: true,
                        ),
                      ),
                      ...item.addedIngredients.map(
                        (ing) => _buildIngredientBadge(
                          ing['name'] ?? '',
                          isRemoved: false,
                          price: (ing['price'] as num?)?.toDouble(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Price and quantity
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.currency(item.subtotale),
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.medium,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'x${item.quantita}',
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: AppTypography.medium,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientBadge(
    String name, {
    required bool isRemoved,
    double? price,
  }) {
    final color = isRemoved ? AppColors.error : AppColors.warning;
    final bgColor = isRemoved
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFFEF3C7);
    final borderColor = isRemoved
        ? const Color(0xFFFECACA)
        : const Color(0xFFFDE68A);

    String text = isRemoved ? 'No $name' : 'Extra $name';
    if (price != null && price > 0) {
      text += ' (+${Formatters.currency(price)})';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: AppTypography.captionSmall.copyWith(
          color: color,
          fontWeight: AppTypography.medium,
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stato Ordine',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Status badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getStatusIcon(), color: _statusColor, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    order.stato.displayName,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: AppTypography.bold,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Next action button
          if (_getNextStatus() != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => onStatusChange(_getNextStatus()!),
                icon: Icon(_getNextStatusIcon(), size: 22),
                label: Text(
                  _getNextStatusLabel(),
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: AppTypography.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getNextStatusColor(),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
          // Cancel button
          if (_canModify) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Annulla Ordine',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.error,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cliente',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Customer avatar and name
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(
                    order.nomeCliente.isNotEmpty
                        ? order.nomeCliente[0].toUpperCase()
                        : '?',
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.nomeCliente,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Contact info
          _buildContactRow(Icons.call_rounded, order.telefonoCliente),
          if (order.emailCliente != null && order.emailCliente!.isNotEmpty)
            _buildContactRow(Icons.mail_rounded, order.emailCliente!),
          if (order.tipo == OrderType.delivery &&
              order.indirizzoConsegna != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildContactRow(
              Icons.location_on_rounded,
              '${order.indirizzoConsegna}${order.cittaConsegna != null ? ', ${order.cittaConsegna}' : ''}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: AppTypography.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (order.stato) {
      case OrderStatus.pending:
        return Icons.schedule_rounded;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.preparing:
        return Icons.restaurant_rounded;
      case OrderStatus.ready:
        return Icons.check_circle_rounded;
      case OrderStatus.delivering:
        return Icons.delivery_dining_rounded;
      case OrderStatus.completed:
        return Icons.done_all_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  OrderStatus? _getNextStatus() {
    switch (order.stato) {
      case OrderStatus.pending:
        return OrderStatus.confirmed;
      case OrderStatus.confirmed:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      case OrderStatus.ready:
        return order.tipo == OrderType.delivery
            ? OrderStatus.delivering
            : OrderStatus.completed;
      case OrderStatus.delivering:
        return OrderStatus.completed;
      default:
        return null;
    }
  }

  String _getNextStatusLabel() {
    switch (order.stato) {
      case OrderStatus.pending:
        return 'Conferma Ordine';
      case OrderStatus.confirmed:
        return 'Inizia Preparazione';
      case OrderStatus.preparing:
        return 'Segna come Pronto';
      case OrderStatus.ready:
        return order.tipo == OrderType.delivery
            ? 'In Consegna'
            : 'Completa Ordine';
      case OrderStatus.delivering:
        return 'Consegnato';
      default:
        return '';
    }
  }

  IconData _getNextStatusIcon() {
    switch (order.stato) {
      case OrderStatus.pending:
        return Icons.check_rounded;
      case OrderStatus.confirmed:
        return Icons.restaurant_rounded;
      case OrderStatus.preparing:
        return Icons.check_circle_rounded;
      case OrderStatus.ready:
        return order.tipo == OrderType.delivery
            ? Icons.delivery_dining_rounded
            : Icons.done_all_rounded;
      case OrderStatus.delivering:
        return Icons.done_all_rounded;
      default:
        return Icons.arrow_forward_rounded;
    }
  }

  Color _getNextStatusColor() {
    switch (order.stato) {
      case OrderStatus.pending:
        return AppColors.info;
      case OrderStatus.confirmed:
        return AppColors.primary;
      case OrderStatus.preparing:
        return AppColors.success;
      case OrderStatus.ready:
        return order.tipo == OrderType.delivery
            ? AppColors.accent
            : AppColors.success;
      case OrderStatus.delivering:
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }
}
