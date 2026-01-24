import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/manager_menu_provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../core/widgets/cached_network_image.dart';
import '../providers/bulk_operations_provider.dart';

class BulkProductSelector extends ConsumerStatefulWidget {
  final Set<String> selectedProductIds;
  final VoidCallback? onContinue;

  const BulkProductSelector({
    super.key,
    required this.selectedProductIds,
    this.onContinue,
  });

  @override
  ConsumerState<BulkProductSelector> createState() =>
      _BulkProductSelectorState();
}

class _BulkProductSelectorState extends ConsumerState<BulkProductSelector> {
  String _searchQuery = '';
  String? _selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(managerMenuProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Column(
      children: [
        // Header with search and filters
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Cerca prodotti...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.radiusXL,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Category chips
              categoriesAsync.when(
                data: (categories) => _buildCategoryChips(categories),
                loading: () => const SizedBox(height: 40),
                error: (e, s) => const SizedBox(),
              ),

              const SizedBox(height: AppSpacing.md),

              // Quick actions
              Row(
                children: [
                  _QuickActionChip(
                    label: 'Seleziona Tutti',
                    icon: Icons.select_all_rounded,
                    onTap: () {
                      final items = menuAsync.value ?? [];
                      final filtered = _filterItems(items);
                      ref
                          .read(bulkOperationsProvider.notifier)
                          .selectProducts(filtered.map((e) => e.id).toList());
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _QuickActionChip(
                    label: 'Deseleziona Tutti',
                    icon: Icons.deselect_rounded,
                    onTap: () {
                      ref
                          .read(bulkOperationsProvider.notifier)
                          .clearProductSelection();
                    },
                  ),
                  if (_selectedCategoryId != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _QuickActionChip(
                      label: 'Seleziona Categoria',
                      icon: Icons.category_rounded,
                      color: Colors.deepPurple,
                      onTap: () {
                        final items = menuAsync.value ?? [];
                        final categoryItems = items
                            .where((i) => i.categoriaId == _selectedCategoryId)
                            .map((e) => e.id)
                            .toList();
                        ref
                            .read(bulkOperationsProvider.notifier)
                            .selectProducts(categoryItems);
                      },
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: widget.selectedProductIds.isNotEmpty
                          ? Colors.deepPurple.withValues(alpha: 0.1)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.selectedProductIds.isNotEmpty
                            ? Colors.deepPurple
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      '${widget.selectedProductIds.length} selezionati',
                      style: AppTypography.labelMedium.copyWith(
                        color: widget.selectedProductIds.isNotEmpty
                            ? Colors.deepPurple
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Product grid
        Expanded(
          child: menuAsync.when(
            data: (items) {
              final filteredItems = _filterItems(items);

              if (filteredItems.isEmpty) {
                return _buildEmptyState();
              }

              // More cards per row: 8 on large desktop, 6 on desktop, 4 on tablet, 2 on mobile
              final width = MediaQuery.of(context).size.width;
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
                  childAspectRatio: 2.2, // Wider cards
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                ),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  final isSelected = widget.selectedProductIds.contains(
                    item.id,
                  );

                  return _SelectableProductCard(
                    item: item,
                    isSelected: isSelected,
                    onTap: () {
                      ref
                          .read(bulkOperationsProvider.notifier)
                          .toggleProduct(item.id);
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.selectedProductIds.isEmpty
                      ? 'Seleziona almeno un prodotto per continuare'
                      : '${widget.selectedProductIds.length} prodotti selezionati',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: widget.onContinue,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Continua'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.surfaceLight,
                  disabledForegroundColor: AppColors.textDisabled,
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

  Widget _buildCategoryChips(List<CategoryModel> categories) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedCategoryId == null;
            return _CategoryChip(
              label: 'Tutte',
              isSelected: isSelected,
              onTap: () => setState(() => _selectedCategoryId = null),
            );
          }

          final category = categories[index - 1];
          final isSelected = _selectedCategoryId == category.id;

          return _CategoryChip(
            label: category.nome,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedCategoryId = category.id),
          );
        },
      ),
    );
  }

  List<MenuItemModel> _filterItems(List<MenuItemModel> items) {
    var filtered = items;

    // Filter by category
    if (_selectedCategoryId != null) {
      filtered = filtered
          .where((item) => item.categoriaId == _selectedCategoryId)
          .toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.nome.toLowerCase().contains(query) ||
            (item.descrizione?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Nessun prodotto trovato',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Prova a modificare i filtri di ricerca',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: chipColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: chipColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(color: chipColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableProductCard extends StatelessWidget {
  final MenuItemModel item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableProductCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurple.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Selection checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? Colors.deepPurple : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),

            // Image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 40,
                height: 40,
                child: item.immagineUrl != null
                    ? CachedNetworkImageWidget.app(
                        imageUrl: item.immagineUrl!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: AppColors.surfaceLight,
                        child: const Icon(
                          Icons.local_pizza_outlined,
                          size: 20,
                          color: AppColors.textTertiary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.nome,
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.descrizione != null && item.descrizione!.isNotEmpty)
                    Text(
                      item.descrizione!,
                      style: AppTypography.captionSmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    Formatters.currency(item.prezzoEffettivo),
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            // Unavailable badge
            if (!item.disponibile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'N/D',
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.error,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
