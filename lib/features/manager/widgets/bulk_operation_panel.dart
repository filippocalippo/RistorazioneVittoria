import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../models/bulk_operation_state.dart';
import '../providers/bulk_operations_provider.dart';

class BulkOperationPanel extends ConsumerWidget {
  final int selectedProductCount;
  final BulkOperationType? selectedOperationType;
  final VoidCallback onBack;
  final VoidCallback? onContinue;

  const BulkOperationPanel({
    super.key,
    required this.selectedProductCount,
    required this.selectedOperationType,
    required this.onBack,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Selected products summary - compact
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.05),
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, color: Colors.deepPurple, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$selectedProductCount prodotti selezionati',
                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                'Scegli operazione',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),

        // Operation cards - 4 in a row on desktop
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                
                if (isWide) {
                  // 4 cards in a row
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _CompactOperationCard(
                          type: BulkOperationType.addIncluded,
                          isSelected: selectedOperationType == BulkOperationType.addIncluded,
                          onTap: () => ref.read(bulkOperationsProvider.notifier)
                              .setOperationType(BulkOperationType.addIncluded),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _CompactOperationCard(
                          type: BulkOperationType.removeIncluded,
                          isSelected: selectedOperationType == BulkOperationType.removeIncluded,
                          onTap: () => ref.read(bulkOperationsProvider.notifier)
                              .setOperationType(BulkOperationType.removeIncluded),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _CompactOperationCard(
                          type: BulkOperationType.addExtra,
                          isSelected: selectedOperationType == BulkOperationType.addExtra,
                          onTap: () => ref.read(bulkOperationsProvider.notifier)
                              .setOperationType(BulkOperationType.addExtra),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _CompactOperationCard(
                          type: BulkOperationType.removeExtra,
                          isSelected: selectedOperationType == BulkOperationType.removeExtra,
                          onTap: () => ref.read(bulkOperationsProvider.notifier)
                              .setOperationType(BulkOperationType.removeExtra),
                        ),
                      ),
                    ],
                  );
                }
                
                // 2x2 grid for smaller screens
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INGREDIENTI INCLUSI', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 1)),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _CompactOperationCard(
                            type: BulkOperationType.addIncluded,
                            isSelected: selectedOperationType == BulkOperationType.addIncluded,
                            onTap: () => ref.read(bulkOperationsProvider.notifier)
                                .setOperationType(BulkOperationType.addIncluded),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _CompactOperationCard(
                            type: BulkOperationType.removeIncluded,
                            isSelected: selectedOperationType == BulkOperationType.removeIncluded,
                            onTap: () => ref.read(bulkOperationsProvider.notifier)
                                .setOperationType(BulkOperationType.removeIncluded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('INGREDIENTI EXTRA', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 1)),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _CompactOperationCard(
                            type: BulkOperationType.addExtra,
                            isSelected: selectedOperationType == BulkOperationType.addExtra,
                            onTap: () => ref.read(bulkOperationsProvider.notifier)
                                .setOperationType(BulkOperationType.addExtra),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _CompactOperationCard(
                            type: BulkOperationType.removeExtra,
                            isSelected: selectedOperationType == BulkOperationType.removeExtra,
                            onTap: () => ref.read(bulkOperationsProvider.notifier)
                                .setOperationType(BulkOperationType.removeExtra),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
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
                onPressed: onBack,
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
              if (selectedOperationType == null)
                Text(
                  'Seleziona un\'operazione',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Continua'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
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
    );
  }
}

class _CompactOperationCard extends StatelessWidget {
  final BulkOperationType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompactOperationCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAdd = type.isAddOperation;
    final isExtra = type.isExtraOperation;
    final color = isAdd ? AppColors.success : AppColors.error;
    final icon = _getIcon();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAdd ? 'Aggiungi' : 'Rimuovi',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected ? color : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        isExtra ? 'Extra' : 'Inclusi',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? color : AppColors.border, width: 2),
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                ),
              ],
            ),
            if (type == BulkOperationType.addExtra) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '€ Prezzo personalizzabile',
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (type) {
      case BulkOperationType.addIncluded:
        return Icons.add_circle_rounded;
      case BulkOperationType.removeIncluded:
        return Icons.remove_circle_rounded;
      case BulkOperationType.addExtra:
        return Icons.add_box_rounded;
      case BulkOperationType.removeExtra:
        return Icons.indeterminate_check_box_rounded;
    }
  }
}
