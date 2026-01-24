import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../models/bulk_operation_state.dart';
import '../providers/bulk_operations_provider.dart';
import '../widgets/bulk_product_selector.dart';
import '../widgets/bulk_operation_panel.dart';
import '../widgets/bulk_ingredient_selector.dart';
import '../widgets/bulk_operation_preview.dart';

class BulkOperationsScreen extends ConsumerWidget {
  const BulkOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bulkOperationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Compact header with step indicator
          _buildHeader(context, ref, state),

          // Main Content
          Expanded(
            child: _buildCurrentStep(context, ref, state),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, BulkOperationState state) {
    final steps = ['Prodotti', 'Operazione', 'Ingredienti', 'Conferma'];
    final currentIndex = BulkOperationStep.values.indexOf(state.currentStep);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Title
          Icon(Icons.dynamic_feed_rounded, color: Colors.deepPurple, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text('Bulk', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: AppSpacing.lg),
          
          // Step pills
          Expanded(
            child: Row(
              children: List.generate(steps.length, (index) {
                final isActive = index == currentIndex;
                final isCompleted = index < currentIndex;

                return Expanded(
                  child: Row(
                    children: [
                      if (index > 0)
                        Expanded(child: Container(height: 2, color: isCompleted ? Colors.deepPurple : AppColors.border)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.deepPurple : isCompleted ? Colors.deepPurple.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isActive || isCompleted ? Colors.deepPurple : AppColors.border),
                        ),
                        child: Text(
                          '${index + 1}. ${steps[index]}',
                          style: AppTypography.captionSmall.copyWith(
                            color: isActive ? Colors.white : isCompleted ? Colors.deepPurple : AppColors.textTertiary,
                            fontWeight: isActive || isCompleted ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (index < steps.length - 1)
                        Expanded(child: Container(height: 2, color: isCompleted ? Colors.deepPurple : AppColors.border)),
                    ],
                  ),
                );
              }),
            ),
          ),
          
          // Reset button
          if (state.currentStep != BulkOperationStep.selectProducts)
            TextButton.icon(
              onPressed: () => ref.read(bulkOperationsProvider.notifier).reset(),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(
    BuildContext context,
    WidgetRef ref,
    BulkOperationState state,
  ) {
    switch (state.currentStep) {
      case BulkOperationStep.selectProducts:
        return BulkProductSelector(
          selectedProductIds: state.selectedProductIds,
          onContinue: state.selectedProductIds.isNotEmpty
              ? () => ref.read(bulkOperationsProvider.notifier).nextStep()
              : null,
        );

      case BulkOperationStep.selectOperation:
        return BulkOperationPanel(
          selectedProductCount: state.selectedProductIds.length,
          selectedOperationType: state.operationType,
          onBack: () => ref.read(bulkOperationsProvider.notifier).previousStep(),
          onContinue: state.operationType != null
              ? () => ref.read(bulkOperationsProvider.notifier).nextStep()
              : null,
        );

      case BulkOperationStep.selectIngredients:
        return BulkIngredientSelector(
          operationType: state.operationType!,
          selectedIngredients: state.selectedIngredients,
          onBack: () => ref.read(bulkOperationsProvider.notifier).previousStep(),
          onContinue: state.selectedIngredients.isNotEmpty
              ? () => ref.read(bulkOperationsProvider.notifier).nextStep()
              : null,
        );

      case BulkOperationStep.preview:
        return BulkOperationPreview(
          selectedProductIds: state.selectedProductIds,
          operationType: state.operationType!,
          selectedIngredients: state.selectedIngredients,
          isProcessing: state.isProcessing,
          onBack: () => ref.read(bulkOperationsProvider.notifier).previousStep(),
          onApply: () async {
            final result = await ref
                .read(bulkOperationsProvider.notifier)
                .applyChanges();

            if (context.mounted) {
              result.when(
                success: (products, ingredients) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Operazione completata: $products prodotti aggiornati',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  ref.read(bulkOperationsProvider.notifier).reset();
                  context.pop();
                },
                partialSuccess: (products, ingredients, skipped) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Operazione parziale: $products prodotti, $skipped duplicati ignorati',
                      ),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  ref.read(bulkOperationsProvider.notifier).reset();
                  context.pop();
                },
                failure: (message) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Errore: $message'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                },
              );
            }
          },
        );
    }
  }
}
