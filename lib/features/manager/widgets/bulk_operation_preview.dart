import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/manager_menu_provider.dart';
import '../models/bulk_operation_state.dart';

class BulkOperationPreview extends ConsumerWidget {
  final Set<String> selectedProductIds;
  final BulkOperationType operationType;
  final List<SelectedBulkIngredient> selectedIngredients;
  final bool isProcessing;
  final VoidCallback onBack;
  final VoidCallback onApply;

  const BulkOperationPreview({
    super.key,
    required this.selectedProductIds,
    required this.operationType,
    required this.selectedIngredients,
    required this.isProcessing,
    required this.onBack,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(managerMenuProvider);
    final isAdd = operationType.isAddOperation;
    final isExtra = operationType.isExtraOperation;

    return Stack(
      children: [
        Column(
          children: [
            // Warning header
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conferma Operazione',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                        Text(
                          'Verifica le modifiche prima di applicarle',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Summary cards
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.restaurant_menu_rounded,
                      label: 'Prodotti',
                      value: selectedProductIds.length.toString(),
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.restaurant_rounded,
                      label: 'Ingredienti',
                      value: selectedIngredients.length.toString(),
                      color: isAdd ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _SummaryCard(
                      icon: isAdd
                          ? Icons.add_circle_rounded
                          : Icons.remove_circle_rounded,
                      label: 'Operazione',
                      value: isAdd ? 'Aggiungi' : 'Rimuovi',
                      color: isAdd ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),

            // Operation details
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: (isAdd ? AppColors.success : AppColors.error).withValues(
                  alpha: 0.05,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    operationType.displayName.toUpperCase(),
                    style: AppTypography.labelMedium.copyWith(
                      color: isAdd ? AppColors.success : AppColors.error,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: selectedIngredients.map((ing) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: (isAdd ? AppColors.success : AppColors.error)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (isAdd ? AppColors.success : AppColors.error)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAdd ? Icons.add : Icons.remove,
                              size: 14,
                              color: isAdd
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ing.ingredientName,
                              style: AppTypography.labelMedium.copyWith(
                                color: isAdd
                                    ? AppColors.success
                                    : AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isExtra &&
                                isAdd &&
                                ing.priceOverride != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  Formatters.currency(ing.priceOverride!),
                                  style: AppTypography.captionSmall.copyWith(
                                    color: AppColors.info,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Products list
            Expanded(
              child: menuAsync.when(
                data: (items) {
                  final selectedItems = items
                      .where((i) => selectedProductIds.contains(i.id))
                      .toList();

                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: selectedItems.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final item = selectedItems[index];
                      return _ProductPreviewCard(
                        item: item,
                        operationType: operationType,
                        ingredients: selectedIngredients,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Errore: $e')),
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: AppShadows.sm,
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: isProcessing ? null : onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Indietro'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: isProcessing ? null : onApply,
                    icon: isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      isProcessing ? 'Applicando...' : 'Applica Modifiche',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAdd
                          ? AppColors.success
                          : AppColors.error,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.surfaceLight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Processing overlay
        if (isProcessing)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Applicando modifiche...',
                        style: AppTypography.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${selectedProductIds.length} prodotti × ${selectedIngredients.length} ingredienti',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductPreviewCard extends StatelessWidget {
  final MenuItemModel item;
  final BulkOperationType operationType;
  final List<SelectedBulkIngredient> ingredients;

  const _ProductPreviewCard({
    required this.item,
    required this.operationType,
    required this.ingredients,
  });

  @override
  Widget build(BuildContext context) {
    final isAdd = operationType.isAddOperation;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 50,
              height: 50,
              color: AppColors.surfaceLight,
              child: item.immagineUrl != null
                  ? Image.network(
                      item.immagineUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.local_pizza_outlined,
                        color: AppColors.textTertiary,
                      ),
                    )
                  : const Icon(
                      Icons.local_pizza_outlined,
                      color: AppColors.textTertiary,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nome,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: ingredients.map((ing) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (isAdd ? AppColors.success : AppColors.error)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${isAdd ? '+' : '-'} ${ing.ingredientName}',
                        style: AppTypography.captionSmall.copyWith(
                          color: isAdd ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
