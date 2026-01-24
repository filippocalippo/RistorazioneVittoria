import 'package:flutter/material.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/delivery_zone_model.dart';
import '../../../core/utils/enums.dart';
import 'package:intl/intl.dart';

/// Modern order card matching HTML mockup design with enhanced assignment management
class ModernOrderCard extends StatelessWidget {
  final OrderModel order;
  final UserModel? assignedDriver;
  final DeliveryZoneModel? deliveryZone;
  final bool isSelected;
  final bool isAssigning;
  final VoidCallback onTap;
  final VoidCallback? onAssign;
  final VoidCallback? onUnassign;
  final VoidCallback? onReassign;
  final VoidCallback? onShowQr;

  const ModernOrderCard({
    super.key,
    required this.order,
    this.assignedDriver,
    this.deliveryZone,
    required this.isSelected,
    required this.isAssigning,
    required this.onTap,
    required this.onAssign,
    this.onUnassign,
    this.onReassign,
    this.onShowQr,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = order.assegnatoDeliveryId == null;
    final currencyFormat = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final timeFormat = DateFormat('HH:mm');

    // Determine status color and label
    final statusInfo = _getStatusInfo();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.05)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : isPending
                  ? AppColors.warning.withValues(alpha: 0.3)
                  : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? AppShadows.md : AppShadows.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with Order Number, Customer, and Status
              Row(
                children: [
                  // Order number badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '#${order.displayNumeroOrdine}',
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Customer name
                  Expanded(
                    child: Text(
                      order.nomeCliente.isNotEmpty
                          ? order.nomeCliente
                          : 'Cliente',
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusInfo.icon,
                          size: 12,
                          color: statusInfo.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusInfo.label,
                          style: AppTypography.captionSmall.copyWith(
                            color: statusInfo.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Delivery info section
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  children: [
                    // Address Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.indirizzoConsegna ??
                                    'Indirizzo non disponibile',
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (order.cittaConsegna != null)
                                Text(
                                  order.cittaConsegna!,
                                  style: AppTypography.captionSmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Time and Items Row
                    Row(
                      children: [
                        // Delivery time
                        if (order.slotPrenotatoStart != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 12,
                                  color: AppColors.info,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeFormat.format(order.slotPrenotatoStart!),
                                  style: AppTypography.captionSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.info,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        // Phone number
                        if (order.telefonoCliente.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.phone_rounded,
                                  size: 11,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  order.telefonoCliente,
                                  style: AppTypography.captionSmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        const Spacer(),
                        // Zone indicator
                        if (deliveryZone != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: deliveryZone!.color.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Text(
                              deliveryZone!.name,
                              style: AppTypography.captionSmall.copyWith(
                                color: deliveryZone!.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Items Preview Row
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _getItemsSummary(),
                      style: AppTypography.captionSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      currencyFormat.format(order.totale),
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Driver Assignment Section
              if (isAssigning)
                _buildLoadingState()
              else if (assignedDriver != null)
                _buildAssignedDriverSection()
              else if (onAssign != null)
                _buildAssignButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildAssignedDriverSection() {
    return Column(
      children: [
        // Assigned Driver Info
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.info,
                      AppColors.info.withValues(alpha: 0.7),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.info.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${assignedDriver!.nome?[0] ?? ''}${assignedDriver!.cognome?[0] ?? ''}',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${assignedDriver!.nome ?? ''} ${assignedDriver!.cognome ?? ''}'
                          .trim(),
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.delivery_dining_rounded,
                          size: 12,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Driver Assegnato',
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.info,
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Action Buttons Row
        Row(
          children: [
            // Modifica Assegnazione Button
            if (onReassign != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReassign,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                      horizontal: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: Text(
                    'Modifica',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),

            if (onReassign != null && onUnassign != null)
              const SizedBox(width: AppSpacing.sm),

            // Disassegna Button
            if (onUnassign != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUnassign,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                      horizontal: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  icon: const Icon(Icons.person_remove_rounded, size: 16),
                  label: Text(
                    'Disassegna',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssignButton() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onAssign ?? () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: Text(
              'Assegna Driver',
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (onShowQr != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: IconButton(
              onPressed: onShowQr,
              icon: const Icon(Icons.qr_code_rounded, size: 20),
              color: AppColors.textPrimary,
              tooltip: 'Mostra QR Code',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _getItemsSummary() {
    if (order.items.isEmpty) return 'Nessun articolo';

    final itemCount = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantita,
    );
    final firstItem = order.items.first.nomeProdotto;

    if (order.items.length == 1) {
      return '$itemCount× $firstItem';
    } else {
      return '$itemCount× $firstItem, +${order.items.length - 1} altri';
    }
  }

  _StatusInfo _getStatusInfo() {
    // Check assignment status first
    if (order.assegnatoDeliveryId != null) {
      // Check order state for assigned orders
      switch (order.stato) {
        case OrderStatus.delivering:
          return _StatusInfo(
            label: 'In Consegna',
            color: AppColors.info,
            icon: Icons.delivery_dining_rounded,
          );
        case OrderStatus.completed:
          return _StatusInfo(
            label: 'Completato',
            color: AppColors.success,
            icon: Icons.check_circle_rounded,
          );
        default:
          return _StatusInfo(
            label: 'Assegnato',
            color: AppColors.info,
            icon: Icons.person_rounded,
          );
      }
    }

    // Unassigned orders
    switch (order.stato) {
      case OrderStatus.ready:
        return _StatusInfo(
          label: 'Pronto',
          color: AppColors.success,
          icon: Icons.check_circle_outline_rounded,
        );
      case OrderStatus.preparing:
        return _StatusInfo(
          label: 'In Preparazione',
          color: AppColors.warning,
          icon: Icons.restaurant_rounded,
        );
      case OrderStatus.cancelled:
        return _StatusInfo(
          label: 'Annullato',
          color: AppColors.error,
          icon: Icons.cancel_rounded,
        );
      default:
        return _StatusInfo(
          label: 'Da Assegnare',
          color: AppColors.warning,
          icon: Icons.hourglass_empty_rounded,
        );
    }
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusInfo({
    required this.label,
    required this.color,
    required this.icon,
  });
}
