import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/order_item_model.dart';
import '../../../core/utils/enums.dart';
import '../../../providers/delivery_orders_provider.dart';
import 'delivery_shell.dart';

/// Expandable order card for the delivery queue
class DeliveryOrderCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final int index;
  final bool isRecommendedNext;
  final bool showDragHandle;

  const DeliveryOrderCard({
    super.key,
    required this.order,
    required this.index,
    this.isRecommendedNext = false,
    this.showDragHandle = false,
  });

  @override
  ConsumerState<DeliveryOrderCard> createState() => _DeliveryOrderCardState();
}

class _DeliveryOrderCardState extends ConsumerState<DeliveryOrderCard> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isCash =
        widget.order.metodoPagamento == PaymentMethod.cash &&
        !widget.order.pagato;
    final isDelivering = widget.order.stato == OrderStatus.delivering;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: widget.isRecommendedNext
              ? AppColors.primary
              : AppColors.border,
          width: widget.isRecommendedNext ? 2 : 1,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          // Recommended badge
          if (widget.isRecommendedNext)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.xxl),
                  bottomRight: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Text(
                'CONSIGLIATO PROSSIMO',
                style: AppTypography.captionSmall.copyWith(
                  color: Colors.white,
                  fontWeight: AppTypography.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),

          // Main card content
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _isExpanded = !_isExpanded);
              },
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  widget.isRecommendedNext ? AppSpacing.sm : AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    // Drag handle for reordering
                    if (widget.showDragHandle)
                      ReorderableDragStartListener(
                        index: widget.index - 1,
                        child: Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: AppColors.textTertiary,
                            size: 24,
                          ),
                        ),
                      ),
                    // Index badge
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.isRecommendedNext
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isRecommendedNext
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.index}',
                          style: AppTypography.titleMedium.copyWith(
                            color: widget.isRecommendedNext
                                ? AppColors.primary
                                : AppColors.textTertiary,
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: AppSpacing.md),

                    // Order info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.order.indirizzoConsegna ??
                                'Indirizzo non disponibile',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: AppTypography.bold,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.order.nomeCliente,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: AppTypography.medium,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              if (isDelivering) ...[
                                Icon(
                                  Icons.local_shipping_outlined,
                                  size: 14,
                                  color: AppColors.info,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'IN CONSEGNA',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.info,
                                    fontWeight: AppTypography.bold,
                                  ),
                                ),
                              ] else ...[
                                Icon(
                                  Icons.timer_outlined,
                                  size: 14,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Pronto',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: AppTypography.medium,
                                  ),
                                ),
                              ],
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                '•',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                isCash ? 'CONTANTI' : 'PAGATO',
                                style: AppTypography.bodySmall.copyWith(
                                  color: isCash
                                      ? AppColors.warning
                                      : AppColors.success,
                                  fontWeight: AppTypography.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Chevron
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: AppAnimations.fast,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(isCash, isDelivering),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: AppAnimations.normal,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(bool isCash, bool isDelivering) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.xxl),
          bottomRight: Radius.circular(AppRadius.xxl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),

          // Order ID
          Row(
            children: [
              Text(
                'CODICE ORDINE:',
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: AppTypography.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '#${widget.order.id.toString().padLeft(6, '0')}',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Cash collection warning
          if (isCash) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'RITIRA CONTANTI: €${widget.order.totale.toStringAsFixed(2)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.warning,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Items List (Read-only)
          Text(
            'Riepilogo Ordine',
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textTertiary,
              fontWeight: AppTypography.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          ...widget.order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Text(
                        '${item.quantita}',
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      item.displayName,
                      style: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Start delivery button
          _buildActionButton(isDelivering),
        ],
      ),
    );
  }

  Widget _buildActionButton(bool isDelivering) {
    if (isDelivering) {
      // If already delivering, show button to view active delivery
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            ref.read(activeDeliveryOrderProvider.notifier).state = widget.order;
            ref.read(deliveryViewProvider.notifier).state = DeliveryView.active;
          },
          icon: const Icon(Icons.location_on_outlined),
          label: const Text('VISUALIZZA CONSEGNA ATTIVA'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            elevation: 0,
          ),
        ),
      );
    }

    // If ready, show start delivery button
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _startDelivery(),
        icon: const Icon(Icons.near_me_rounded),
        label: const Text('INIZIA VIAGGIO'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Future<void> _startDelivery() async {
    try {
      // Update order status to delivering
      await ref
          .read(deliveryOrdersProvider.notifier)
          .startDelivering(widget.order.id);

      // Set as active order and switch to active view
      ref.read(activeDeliveryOrderProvider.notifier).state = widget.order;
      ref.read(deliveryViewProvider.notifier).state = DeliveryView.active;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nell\'avvio della consegna: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
