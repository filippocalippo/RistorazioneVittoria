import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/ingredient_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/ingredients_provider.dart';
import '../models/bulk_operation_state.dart';
import '../providers/bulk_operations_provider.dart';

class BulkIngredientSelector extends ConsumerStatefulWidget {
  final BulkOperationType operationType;
  final List<SelectedBulkIngredient> selectedIngredients;
  final VoidCallback onBack;
  final VoidCallback? onContinue;

  const BulkIngredientSelector({
    super.key,
    required this.operationType,
    required this.selectedIngredients,
    required this.onBack,
    this.onContinue,
  });

  @override
  ConsumerState<BulkIngredientSelector> createState() =>
      _BulkIngredientSelectorState();
}

class _BulkIngredientSelectorState
    extends ConsumerState<BulkIngredientSelector> {
  String _searchQuery = '';
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getCategories(List<IngredientModel> ingredients) {
    final categories = <String>{};
    for (final ing in ingredients) {
      if (ing.categoria != null && ing.categoria!.isNotEmpty) {
        categories.add(ing.categoria!);
      }
    }
    return categories.toList()..sort();
  }

  List<IngredientModel> _filterIngredients(List<IngredientModel> ingredients) {
    var filtered = ingredients.where((i) => i.attivo).toList();

    if (_selectedCategory != null) {
      filtered = filtered
          .where((i) => i.categoria == _selectedCategory)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((i) {
        return i.nome.toLowerCase().contains(query) ||
            (i.descrizione?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  void _selectAllInCategory(
    List<IngredientModel> ingredients,
    String? category,
  ) {
    final categoryIngredients = ingredients
        .where(
          (i) =>
              i.attivo && (category == null ? true : i.categoria == category),
        )
        .toList();

    for (final ing in categoryIngredients) {
      if (!widget.selectedIngredients.any((s) => s.ingredientId == ing.id)) {
        ref
            .read(bulkOperationsProvider.notifier)
            .addIngredient(
              ingredientId: ing.id,
              ingredientName: ing.nome,
              basePrice: ing.prezzo,
            );
      }
    }
  }

  void _deselectAllInCategory(
    List<IngredientModel> ingredients,
    String? category,
  ) {
    final categoryIngredientIds = ingredients
        .where((i) => category == null ? true : i.categoria == category)
        .map((i) => i.id)
        .toSet();

    for (final id in categoryIngredientIds) {
      ref.read(bulkOperationsProvider.notifier).removeIngredient(id);
    }
  }

  void _showBulkPriceOverrideDialog() {
    if (widget.selectedIngredients.isEmpty) return;

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Prezzo per tutti'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Imposta lo stesso prezzo per tutti i ${widget.selectedIngredients.length} ingredienti selezionati',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Prezzo override',
                hintText: '0.00',
                helperText: 'Lascia vuoto per rimuovere tutti gli override',
                prefixIcon: const Icon(Icons.euro_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              double? price;
              if (text.isNotEmpty) {
                price = double.tryParse(text.replaceAll(',', '.'));
              }
              // Apply to all selected ingredients
              for (final ing in widget.selectedIngredients) {
                ref
                    .read(bulkOperationsProvider.notifier)
                    .setPriceOverride(ing.ingredientId, price);
              }
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Applica a tutti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final isExtra = widget.operationType.isExtraOperation;
    final isAdd = widget.operationType.isAddOperation;
    final width = MediaQuery.of(context).size.width;

    return Column(
      children: [
        // Compact Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: (isAdd ? AppColors.success : AppColors.error).withValues(
              alpha: 0.05,
            ),
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isAdd ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isAdd
                          ? Icons.add_circle_rounded
                          : Icons.remove_circle_rounded,
                      color: isAdd ? AppColors.success : AppColors.error,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.operationType.displayName,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Bulk price override button (only for add extra)
                  if (isExtra && isAdd && widget.selectedIngredients.isNotEmpty)
                    TextButton.icon(
                      onPressed: _showBulkPriceOverrideDialog,
                      icon: const Icon(Icons.euro_rounded, size: 16),
                      label: const Text('Prezzo per tutti'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.info,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: widget.selectedIngredients.isNotEmpty
                          ? Colors.deepPurple.withValues(alpha: 0.1)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.selectedIngredients.isNotEmpty
                            ? Colors.deepPurple
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      '${widget.selectedIngredients.length} sel.',
                      style: AppTypography.labelSmall.copyWith(
                        color: widget.selectedIngredients.isNotEmpty
                            ? Colors.deepPurple
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Search bar - compact
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: AppTypography.bodySmall,
                  decoration: InputDecoration(
                    hintText: 'Cerca ingredienti...',
                    hintStyle: AppTypography.bodySmall,
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Category chips with quick select
        ingredientsAsync.when(
          data: (ingredients) {
            final categories = _getCategories(ingredients);
            if (categories.isEmpty) return const SizedBox();

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  // Category filter chips
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length + 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _CompactCategoryChip(
                              label: 'Tutti',
                              isSelected: _selectedCategory == null,
                              onTap: () =>
                                  setState(() => _selectedCategory = null),
                            );
                          }
                          final category = categories[index - 1];
                          final count = ingredients
                              .where((i) => i.attivo && i.categoria == category)
                              .length;
                          return _CompactCategoryChip(
                            label: '$category ($count)',
                            isSelected: _selectedCategory == category,
                            onTap: () =>
                                setState(() => _selectedCategory = category),
                            onLongPress: () {
                              // Quick select all in this category
                              _selectAllInCategory(ingredients, category);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Selezionati tutti in "$category"',
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  // Quick select buttons
                  const SizedBox(width: AppSpacing.sm),
                  if (_selectedCategory == null) ...[
                    // Buttons for "Tutti"
                    _QuickActionButton(
                      icon: Icons.select_all_rounded,
                      tooltip: 'Seleziona tutti gli ingredienti',
                      onTap: () => _selectAllInCategory(ingredients, null),
                    ),
                    const SizedBox(width: 4),
                    _QuickActionButton(
                      icon: Icons.deselect_rounded,
                      tooltip: 'Deseleziona tutti gli ingredienti',
                      onTap: () => _deselectAllInCategory(ingredients, null),
                    ),
                  ] else if (_selectedCategory != null) ...[
                    // Buttons for specific category
                    _QuickActionButton(
                      icon: Icons.select_all_rounded,
                      tooltip: 'Seleziona tutti in categoria',
                      onTap: () =>
                          _selectAllInCategory(ingredients, _selectedCategory!),
                    ),
                    const SizedBox(width: 4),
                    _QuickActionButton(
                      icon: Icons.deselect_rounded,
                      tooltip: 'Deseleziona tutti in categoria',
                      onTap: () => _deselectAllInCategory(
                        ingredients,
                        _selectedCategory!,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const SizedBox(),
          error: (e, s) => const SizedBox(),
        ),

        // Ingredients grid - compact
        Expanded(
          child: ingredientsAsync.when(
            data: (ingredients) {
              final filtered = _filterIngredients(ingredients);

              if (filtered.isEmpty) {
                return _buildEmptyState();
              }

              // More cards per row: 8 on large desktop, 6 on desktop, 4 on tablet, 2 on mobile
              final crossAxisCount = width > 1600
                  ? 8
                  : width > 1200
                  ? 6
                  : width > 800
                  ? 4
                  : 2;

              return GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 2.8,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final ingredient = filtered[index];
                  final selectedItem = widget.selectedIngredients
                      .where((i) => i.ingredientId == ingredient.id)
                      .firstOrNull;
                  final isSelected = selectedItem != null;

                  return _CompactIngredientCard(
                    ingredient: ingredient,
                    isSelected: isSelected,
                    showPriceOverride: isExtra && isAdd,
                    priceOverride: selectedItem?.priceOverride,
                    onTap: () {
                      ref
                          .read(bulkOperationsProvider.notifier)
                          .toggleIngredient(
                            ingredientId: ingredient.id,
                            ingredientName: ingredient.nome,
                            basePrice: ingredient.prezzo,
                          );
                    },
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
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Indietro'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const Spacer(),
              if (widget.selectedIngredients.isEmpty)
                Text(
                  'Seleziona almeno un ingrediente',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: widget.onContinue,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Anteprima'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nessun ingrediente trovato',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactCategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CompactCategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _CompactIngredientCard extends StatelessWidget {
  final IngredientModel ingredient;
  final bool isSelected;
  final bool showPriceOverride;
  final double? priceOverride;
  final VoidCallback onTap;

  const _CompactIngredientCard({
    required this.ingredient,
    required this.isSelected,
    required this.showPriceOverride,
    this.priceOverride,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurple.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? Colors.deepPurple : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ingredient.nome,
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        Formatters.currency(ingredient.prezzo),
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      if (showPriceOverride &&
                          isSelected &&
                          priceOverride != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '→ ${Formatters.currency(priceOverride!)}',
                            style: AppTypography.captionSmall.copyWith(
                              color: AppColors.info,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
