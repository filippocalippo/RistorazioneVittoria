import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../providers/ingredients_provider.dart';
import '../../../providers/inventory_ui_providers.dart';
import '../../../core/models/ingredient_model.dart';
import '../widgets/inventory_edit_modal.dart';

/// Modern Inventory & Ingredients screen with sortable table, bulk actions, and quick stock updates
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  String _stockFilter = 'all';

  // Sorting state
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  // Selection state
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context, isDesktop),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 32 : 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsCards(context, isDesktop),
                    const SizedBox(height: 24),
                    _buildFiltersSection(context, isDesktop),
                    const SizedBox(height: 16),
                    _buildIngredientsTable(context, isDesktop),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: isDesktop ? 20 : 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestione Ingredienti',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scorte e gestione prezzi',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            // Bulk Actions when items are selected
            if (_selectedIds.isNotEmpty) ...[
              Text(
                '${_selectedIds.length} selezionati',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              // Bulk Deactivate
              OutlinedButton.icon(
                onPressed: () => _bulkToggleActive(false),
                icon: const Icon(Icons.visibility_off_rounded, size: 18),
                label: const Text('Disattiva'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: BorderSide(
                    color: AppColors.warning.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bulk Activate
              OutlinedButton.icon(
                onPressed: () => _bulkToggleActive(true),
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('Attiva'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: BorderSide(
                    color: AppColors.success.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bulk Delete
              OutlinedButton.icon(
                onPressed: () => _bulkDelete(),
                icon: const Icon(Icons.delete_rounded, size: 18),
                label: const Text('Elimina'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() => _selectedIds.clear()),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Deseleziona'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ],
          ElevatedButton.icon(
            onPressed: () => _showEditModal(context, null),
            icon: const Icon(Icons.add, size: 20),
            label: Text(isDesktop ? 'Aggiungi Ingrediente' : 'Aggiungi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 16,
                vertical: 12,
              ),
              elevation: 2,
              shadowColor: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  // Bulk Toggle Active
  Future<void> _bulkToggleActive(bool active) async {
    final count = _selectedIds.length;
    for (final id in _selectedIds) {
      await ref.read(ingredientsProvider.notifier).toggleActive(id, active);
    }
    setState(() => _selectedIds.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$count ingredienti ${active ? "attivati" : "disattivati"}',
          ),
          backgroundColor: active ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  // Bulk Delete
  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Ingredienti'),
        content: Text(
          'Sei sicuro di voler eliminare $count ingredienti selezionati?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina Tutti'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final id in _selectedIds.toList()) {
        await ref.read(ingredientsProvider.notifier).deleteIngredient(id);
      }
      setState(() => _selectedIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count ingredienti eliminati'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildStatsCards(BuildContext context, bool isDesktop) {
    final summaryAsync = ref.watch(stockSummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        final cards = [
          _StatCard(
            title: 'Totale Ingredienti',
            value: '${summary.totalIngredients}',
            icon: Icons.inventory_2_rounded,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primary.withValues(alpha: 0.1),
          ),
          _StatCard(
            title: 'Scorte Basse',
            value: '${summary.lowStockCount}',
            icon: Icons.warning_rounded,
            iconColor: AppColors.warning,
            iconBgColor: AppColors.warning.withValues(alpha: 0.1),
            hasBorder: summary.lowStockCount > 0,
            borderColor: AppColors.warning,
          ),
          _StatCard(
            title: 'Critici',
            value: '${summary.criticalStockCount}',
            icon: Icons.error_rounded,
            iconColor: AppColors.error,
            iconBgColor: AppColors.error.withValues(alpha: 0.1),
            hasBorder: summary.criticalStockCount > 0,
            borderColor: AppColors.error,
          ),
          _StatCard(
            title: 'Monitorati',
            value: '${summary.trackedIngredients}',
            icon: Icons.track_changes_rounded,
            iconColor: AppColors.info,
            iconBgColor: AppColors.info.withValues(alpha: 0.1),
          ),
        ];

        return GridView.count(
          crossAxisCount: isDesktop ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: isDesktop ? 2.2 : 1.6,
          children: cards,
        );
      },
      loading: () => GridView.count(
        crossAxisCount: isDesktop ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: isDesktop ? 2.2 : 1.6,
        children: List.generate(4, (_) => _StatCardSkeleton()),
      ),
      error: (e, _) => Center(child: Text('Errore: $e')),
    );
  }

  Widget _buildFiltersSection(BuildContext context, bool isDesktop) {
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final categories = ingredientsAsync.maybeWhen(
      data: (list) =>
          list.map((i) => i.categoria).whereType<String>().toSet().toList()
            ..sort(),
      orElse: () => <String>[],
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: isDesktop ? 2 : 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.radiusLG,
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.xs,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Cerca ingredienti...',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.radiusLG,
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.xs,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Tutti',
                      isSelected: _stockFilter == 'all',
                      onTap: () => setState(() => _stockFilter = 'all'),
                    ),
                    _FilterChip(
                      label: 'Scorta Bassa',
                      isSelected: _stockFilter == 'low',
                      onTap: () => setState(() => _stockFilter = 'low'),
                    ),
                    _FilterChip(
                      label: 'Esaurito',
                      isSelected: _stockFilter == 'out',
                      onTap: () => setState(() => _stockFilter = 'out'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _CategoryPill(
                label: 'Tutte',
                isSelected: _selectedCategory == null,
                onTap: () => setState(() => _selectedCategory = null),
              ),
              ...categories.map(
                (cat) => _CategoryPill(
                  label: cat,
                  isSelected: _selectedCategory == cat,
                  onTap: () => setState(() => _selectedCategory = cat),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<IngredientModel> _getSortedIngredients(
    List<IngredientModel> ingredients,
  ) {
    final sorted = List<IngredientModel>.from(ingredients);
    sorted.sort((a, b) {
      int result;
      switch (_sortColumnIndex) {
        case 0:
          result = a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        case 1:
          result = (a.categoria ?? '').compareTo(b.categoria ?? '');
        case 2:
          result = a.stockQuantity.compareTo(b.stockQuantity);
        case 3:
          result = _getDisplayPrice(a).compareTo(_getDisplayPrice(b));
        default:
          result = 0;
      }
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  double _getDisplayPrice(IngredientModel ing) {
    if (ing.sizePrices.isNotEmpty) {
      return ing.sizePrices
          .map((sp) => sp.prezzo)
          .reduce((a, b) => a < b ? a : b);
    }
    return ing.prezzo;
  }

  String _formatPrice(IngredientModel ing) {
    if (ing.sizePrices.isNotEmpty) {
      final prices = ing.sizePrices.map((sp) => sp.prezzo).toList()..sort();
      if (prices.length == 1) return '+€${prices.first.toStringAsFixed(2)}';
      return 'da €${prices.first.toStringAsFixed(2)}';
    }
    if (ing.prezzo == 0) return 'Gratis';
    return '+€${ing.prezzo.toStringAsFixed(2)}';
  }

  Widget _buildIngredientsTable(BuildContext context, bool isDesktop) {
    final ingredientsAsync = ref.watch(ingredientsProvider);

    return ingredientsAsync.when(
      data: (ingredients) {
        var filtered = ingredients.where((i) {
          final matchesSearch =
              _searchQuery.isEmpty ||
              i.nome.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (i.categoria?.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ??
                  false);
          final matchesCategory =
              _selectedCategory == null || i.categoria == _selectedCategory;
          bool matchesStock = true;
          if (_stockFilter == 'low') {
            matchesStock =
                i.trackStock &&
                i.lowStockThreshold > 0 &&
                i.stockQuantity <= i.lowStockThreshold &&
                i.stockQuantity > 0;
          } else if (_stockFilter == 'out') {
            matchesStock = i.trackStock && i.stockQuantity <= 0;
          }
          return matchesSearch && matchesCategory && matchesStock;
        }).toList();

        final sorted = _getSortedIngredients(filtered);
        if (sorted.isEmpty) return _buildEmptyState();

        final allSelected = sorted.every((i) => _selectedIds.contains(i.id));

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.radiusXL,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            children: [
              if (isDesktop) _buildSortableHeader(allSelected, sorted),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                itemCount: sorted.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
                itemBuilder: (context, index) =>
                    _buildIngredientRow(sorted[index], isDesktop),
              ),
              _buildTableFooter(sorted.length, ingredients.length),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(child: Text('Errore: $e')),
    );
  }

  Widget _buildSortableHeader(bool allSelected, List<IngredientModel> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: allSelected && items.isNotEmpty,
              tristate: true,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedIds.addAll(items.map((i) => i.id));
                  } else {
                    _selectedIds.removeAll(items.map((i) => i.id));
                  }
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: _SortableColumnHeader(
              label: 'INGREDIENTE',
              isActive: _sortColumnIndex == 0,
              ascending: _sortAscending,
              onTap: () => _onSort(0),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _SortableColumnHeader(
              label: 'CATEGORIA',
              isActive: _sortColumnIndex == 1,
              ascending: _sortAscending,
              onTap: () => _onSort(1),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _SortableColumnHeader(
              label: 'SCORTE',
              isActive: _sortColumnIndex == 2,
              ascending: _sortAscending,
              onTap: () => _onSort(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _SortableColumnHeader(
              label: 'PREZZO',
              isActive: _sortColumnIndex == 3,
              ascending: _sortAscending,
              onTap: () => _onSort(3),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 32),
          const SizedBox(
            width: 50,
            child: Center(
              child: Text(
                'STATO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 100), // Actions
        ],
      ),
    );
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex)
        _sortAscending = !_sortAscending;
      else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  Widget _buildIngredientRow(IngredientModel ingredient, bool isDesktop) {
    final stockColor = _getStockColor(ingredient);
    final stockLabel = _getStockLabel(ingredient);
    final stockPercent = _getStockPercent(ingredient);
    final isSelected = _selectedIds.contains(ingredient.id);

    if (!isDesktop) return _buildMobileRow(ingredient, stockColor, stockLabel);

    return InkWell(
      onTap: () => _showEditModal(context, ingredient),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : null,
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 40,
              child: Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedIds.add(ingredient.id);
                    } else {
                      _selectedIds.remove(ingredient.id);
                    }
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 16),
            // Name + Icon
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(
                        ingredient,
                      ).withValues(alpha: 0.1),
                      borderRadius: AppRadius.radiusMD,
                    ),
                    child: Icon(
                      _getCategoryIcon(ingredient),
                      color: _getCategoryColor(ingredient),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ingredient.nome,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (ingredient.allergeni.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 12,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  ingredient.allergeni.join(', '),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 16),
            // Category
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(ingredient).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getCategoryColor(
                        ingredient,
                      ).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    ingredient.categoria ?? 'Altro',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getCategoryColor(ingredient),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Stock Level
            Expanded(
              flex: 2,
              child: ingredient.trackStock
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              stockLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: stockColor,
                              ),
                            ),
                            Text(
                              '${(stockPercent * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: stockPercent.clamp(0.0, 1.0),
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation(stockColor),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ingredient.stockQuantity.toStringAsFixed(1)} ${ingredient.unitOfMeasurement}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Non tracciato',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            // Price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatPrice(ingredient),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (ingredient.sizePrices.isNotEmpty)
                    Text(
                      '${ingredient.sizePrices.length} taglie',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            // Inline Active Toggle
            const SizedBox(width: 32),
            SizedBox(
              width: 50,
              child: Switch(
                value: ingredient.attivo,
                onChanged: (value) => ref
                    .read(ingredientsProvider.notifier)
                    .toggleActive(ingredient.id, value),
                activeTrackColor: AppColors.success,
                activeColor: Colors.white,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            // Actions
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    onPressed: () => _showEditModal(context, ingredient),
                    tooltip: 'Modifica',
                    color: AppColors.textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    onPressed: () =>
                        _showDeleteConfirmation(context, ingredient),
                    tooltip: 'Elimina',
                    color: AppColors.textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(
    IngredientModel ingredient,
    Color stockColor,
    String stockLabel,
  ) {
    return InkWell(
      onTap: () => _showEditModal(context, ingredient),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getCategoryColor(ingredient).withValues(alpha: 0.1),
                borderRadius: AppRadius.radiusMD,
              ),
              child: Icon(
                _getCategoryIcon(ingredient),
                color: _getCategoryColor(ingredient),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ingredient.nome,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Switch(
                        value: ingredient.attivo,
                        onChanged: (value) => ref
                            .read(ingredientsProvider.notifier)
                            .toggleActive(ingredient.id, value),
                        activeTrackColor: AppColors.success,
                        activeColor: Colors.white,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(
                            ingredient,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ingredient.categoria ?? 'Altro',
                          style: TextStyle(
                            fontSize: 11,
                            color: _getCategoryColor(ingredient),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (ingredient.trackStock)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: stockColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${ingredient.stockQuantity.toStringAsFixed(0)} ${ingredient.unitOfMeasurement}',
                            style: TextStyle(
                              fontSize: 11,
                              color: stockColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              _formatPrice(ingredient),
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableFooter(int showing, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando $showing di $total',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (_selectedIds.isNotEmpty)
            Text(
              '${_selectedIds.length} selezionati',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXL,
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nessun ingrediente trovato',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Prova a modificare i filtri di ricerca',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getStockColor(IngredientModel ing) {
    if (!ing.trackStock || ing.lowStockThreshold <= 0) {
      return AppColors.success;
    }
    if (ing.stockQuantity <= 0) return AppColors.error;
    if (ing.stockQuantity <= ing.lowStockThreshold * 0.2) {
      return AppColors.error;
    }
    if (ing.stockQuantity <= ing.lowStockThreshold) return AppColors.warning;
    return AppColors.success;
  }

  String _getStockLabel(IngredientModel ing) {
    if (!ing.trackStock) return 'Non tracciato';
    if (ing.stockQuantity <= 0) return 'Esaurito';
    if (ing.lowStockThreshold > 0 &&
        ing.stockQuantity <= ing.lowStockThreshold * 0.2) {
      return 'Critico';
    }
    if (ing.lowStockThreshold > 0 && ing.stockQuantity <= ing.lowStockThreshold) {
      return 'Bassa';
    }
    return 'OK';
  }

  double _getStockPercent(IngredientModel ing) {
    if (!ing.trackStock || ing.lowStockThreshold <= 0) return 1.0;
    return (ing.stockQuantity / ing.lowStockThreshold).clamp(0.0, 1.0);
  }

  Color _getCategoryColor(IngredientModel ing) {
    switch (ing.categoria?.toLowerCase()) {
      case 'carne':
      case 'meat':
      case 'salumi':
        return Colors.red.shade600;
      case 'formaggio':
      case 'formaggi':
      case 'cheese':
      case 'dairy':
        return Colors.amber.shade700;
      case 'verdura':
      case 'verdure':
      case 'veg':
      case 'vegetable':
        return Colors.green.shade600;
      case 'pesce':
      case 'fish':
        return Colors.blue.shade600;
      case 'salsa':
      case 'salse':
      case 'sauce':
        return Colors.orange.shade600;
      default:
        return AppColors.primary;
    }
  }

  IconData _getCategoryIcon(IngredientModel ing) {
    switch (ing.categoria?.toLowerCase()) {
      case 'carne':
      case 'meat':
      case 'salumi':
        return Icons.kebab_dining_rounded;
      case 'formaggio':
      case 'formaggi':
      case 'cheese':
      case 'dairy':
        return Icons.egg_rounded;
      case 'verdura':
      case 'verdure':
      case 'veg':
      case 'vegetable':
        return Icons.eco_rounded;
      case 'pesce':
      case 'fish':
        return Icons.set_meal_rounded;
      case 'salsa':
      case 'salse':
      case 'sauce':
        return Icons.water_drop_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  void _showEditModal(BuildContext context, IngredientModel? ingredient) {
    showDialog(
      context: context,
      builder: (ctx) => InventoryEditModal(
        ingredient: ingredient,
        onSave: () {
          ref.invalidate(ingredientsProvider);
          ref.invalidate(stockSummaryProvider);
        },
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    IngredientModel ingredient,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Ingrediente'),
        content: Text('Sei sicuro di voler eliminare "${ingredient.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(ingredientsProvider.notifier)
                  .deleteIngredient(ingredient.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STAT CARD WIDGETS
// ============================================================================
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final bool hasBorder;
  final Color? borderColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.hasBorder = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXL,
        border: Border.all(
          color: hasBorder ? borderColor! : AppColors.border,
          width: hasBorder ? 2 : 1,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: AppTypography.medium,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: AppRadius.radiusMD,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          Text(
            value,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: AppTypography.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXL,
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// ============================================================================
// FILTER CHIPS
// ============================================================================
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceLight : Colors.transparent,
          borderRadius: AppRadius.radiusMD,
          boxShadow: isSelected ? AppShadows.xs : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SORTABLE COLUMN HEADER
// ============================================================================
class _SortableColumnHeader extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool ascending;
  final VoidCallback onTap;
  final TextAlign textAlign;

  const _SortableColumnHeader({
    required this.label,
    required this.isActive,
    required this.ascending,
    required this.onTap,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: textAlign == TextAlign.right
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? AppColors.primary : Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isActive
                  ? (ascending ? Icons.arrow_upward : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: isActive ? AppColors.primary : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
