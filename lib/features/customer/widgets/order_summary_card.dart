import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/order_item_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/utils/enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/menu_provider.dart';

class OrderSummaryCard extends ConsumerWidget {
  const OrderSummaryCard({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimatedTime = _getEstimatedArrivalTime();
    final menuItemsAsync = ref.watch(menuProvider);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXL,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDeliveryHeader(estimatedTime),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.2)),
          _buildItemsList(order.items, menuItemsAsync),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.2)),
          _buildTotals(),
        ],
      ),
    );
  }

  String _getEstimatedArrivalTime() {
    // Show the raw scheduled time that the user selected
    if (order.slotPrenotatoStart != null) {
      return Formatters.time(order.slotPrenotatoStart!);
    }

    // Fallback to order creation time if no slot was selected
    return Formatters.time(order.createdAt);
  }

  Widget _buildDeliveryHeader(String estimatedTime) {
    final deliveryType = order.tipo == OrderType.delivery
        ? 'Consegna'
        : order.tipo == OrderType.takeaway
        ? 'Ritiro'
        : 'Al tavolo';

    return Padding(
      padding: AppSpacing.paddingLG,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deliveryType,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Arrivo stimato: $estimatedTime',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconForOrderType(order.tipo),
              color: AppColors.primary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(
    List<OrderItemModel> items,
    AsyncValue<List<MenuItemModel>> menuItemsAsync,
  ) {
    // Always display items immediately using data from OrderItemModel
    // Menu items are only used for images, which can load asynchronously
    final menuItems = menuItemsAsync.valueOrNull;

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _OrderItemRow(
            item: items[i],
            menuItem: items[i].menuItemId != null && menuItems != null
                ? menuItems
                      .where((m) => m.id == items[i].menuItemId)
                      .firstOrNull
                : null,
            showDivider: i != items.length - 1,
          ),
      ],
    );
  }

  Widget _buildTotals() {
    final hasAdditionalCosts = order.costoConsegna > 0 || order.sconto > 0;
    final showSubtotal = hasAdditionalCosts || order.subtotale != order.totale;

    return Padding(
      padding: AppSpacing.paddingLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSubtotal)
            _TotalRow(
              label: 'Subtotale',
              value: Formatters.currency(order.subtotale),
            ),
          if (order.costoConsegna > 0)
            _TotalRow(
              label: 'Costo di consegna',
              value: Formatters.currency(order.costoConsegna),
            ),
          if (order.sconto > 0)
            _TotalRow(
              label: 'Sconto',
              value: '-${Formatters.currency(order.sconto)}',
              valueColor: AppColors.success,
            ),
          if (showSubtotal || order.costoConsegna > 0 || order.sconto > 0)
            const SizedBox(height: AppSpacing.sm),
          _TotalRow(
            label: 'Totale',
            value: Formatters.currency(order.totale),
            isGrandTotal: true,
          ),
        ],
      ),
    );
  }

  static IconData _iconForOrderType(OrderType type) {
    switch (type) {
      case OrderType.delivery:
        return Icons.delivery_dining_rounded;
      case OrderType.takeaway:
        return Icons.shopping_bag_outlined;
      case OrderType.dineIn:
        return Icons.restaurant_rounded;
    }
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({
    required this.item,
    this.menuItem,
    required this.showDivider,
  });

  final OrderItemModel item;
  final MenuItemModel? menuItem;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final imageUrl = menuItem?.immagineUrl;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product image or placeholder - use split image for divided products
              item.isSplitProduct
                  ? _buildSplitImage()
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: AppRadius.radiusLG,
                        image: imageUrl != null && imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imageUrl == null || imageUrl.isEmpty
                          ? Icon(
                              Icons.fastfood_rounded,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.3,
                              ),
                              size: 28,
                            )
                          : null,
                    ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.quantita}x ${item.nomeProdotto}',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.note != null && item.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.note!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                Formatters.currency(item.subtotale),
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.normal,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: AppSpacing.lg,
            endIndent: AppSpacing.lg,
            color: AppColors.border.withValues(alpha: 0.2),
          ),
      ],
    );
  }

  Widget _buildSplitImage() {
    final (firstImage, secondImage) = item.splitProductImages;

    // Fallback: if no split images available (old orders), show placeholder with split indicator
    if (firstImage == null && secondImage == null) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: AppRadius.radiusLG,
          color: AppColors.surfaceLight,
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.fastfood_rounded,
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                size: 28,
              ),
            ),
            // Split indicator overlay
            Positioned(
              left: 27,
              top: 0,
              child: Container(
                width: 2,
                height: 56,
                color: AppColors.surface.withValues(alpha: 0.8),
              ),
            ),
            // Split badge
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.call_split_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show full-size images, each cropped to show its half
    // Left side: show LEFT half of first image
    // Right side: show RIGHT half of second image
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: AppRadius.radiusLG,
        color: AppColors.surfaceLight,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Left half - first image's LEFT portion
          SizedBox(
            width: 28,
            height: 56,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: 56,
                maxHeight: 56,
                alignment: Alignment.centerLeft, // Align to show left half
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: firstImage != null
                      ? Image.network(
                          firstImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.fastfood_rounded,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                            size: 24,
                          ),
                        )
                      : Icon(
                          Icons.fastfood_rounded,
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          size: 24,
                        ),
                ),
              ),
            ),
          ),
          // Divider
          Container(width: 1, height: 56, color: AppColors.surface),
          // Right half - second image's RIGHT portion
          SizedBox(
            width: 27, // 28 - 1 for divider
            height: 56,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: 56,
                maxHeight: 56,
                alignment: Alignment.centerRight, // Align to show right half
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: secondImage != null
                      ? Image.network(
                          secondImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.fastfood_rounded,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                            size: 24,
                          ),
                        )
                      : Icon(
                          Icons.fastfood_rounded,
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          size: 24,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isGrandTotal = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isGrandTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  (isGrandTotal
                          ? AppTypography.bodyMedium
                          : AppTypography.bodySmall)
                      .copyWith(
                        fontWeight: isGrandTotal
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isGrandTotal
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
            ),
          ),
          Text(
            value,
            style:
                (isGrandTotal
                        ? AppTypography.bodyMedium
                        : AppTypography.bodySmall)
                    .copyWith(
                      fontWeight: isGrandTotal
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: valueColor ?? AppColors.textPrimary,
                    ),
          ),
        ],
      ),
    );
  }
}
