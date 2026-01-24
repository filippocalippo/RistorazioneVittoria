import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/constants.dart';
import '../../../core/widgets/cached_network_image.dart';
import '../../../providers/manager_menu_provider.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../providers/categories_provider.dart';
import '../../../core/models/category_model.dart';
import '../../../core/services/bulk_menu_import_service.dart';
import '../../../core/services/json_menu_import_service.dart';
import '../widgets/product_edit_modal.dart';
import '../widgets/categories_modal_v2.dart';

/// V2 Manager Menu Screen - Table-based layout matching inventory_screen.dart
class ManagerMenuScreen extends ConsumerStatefulWidget {
  const ManagerMenuScreen({super.key});

  @override
  ConsumerState<ManagerMenuScreen> createState() => _ManagerMenuScreenState();
}

class _ManagerMenuScreenState extends ConsumerState<ManagerMenuScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  // Sorting state (matching inventory_screen.dart pattern)
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
                    _buildProductsTable(context, isDesktop),
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
                  'Gestione Menu',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prodotti, prezzi e disponibilità',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Config buttons (only on desktop when nothing selected)
          if (isDesktop && _selectedIds.isEmpty) ...[
            OutlinedButton.icon(
              onPressed: () => _showCategoriesModal(context),
              icon: const Icon(Icons.category_rounded, size: 18),
              label: const Text('Categorie'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/manager/sizes'),
              icon: const Icon(Icons.straighten_rounded, size: 18),
              label: const Text('Dimensioni'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.info,
                side: const BorderSide(color: AppColors.info),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _showBulkImportDialog,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Importa Lista'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _showJsonImportDialog,
              icon: const Icon(Icons.data_object_rounded, size: 18),
              label: const Text('Importa JSON'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple,
                side: const BorderSide(color: Colors.purple),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => context.push(RouteNames.bulkOperations),
              icon: const Icon(Icons.dynamic_feed_rounded, size: 18),
              label: const Text('Bulk'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: const BorderSide(color: Colors.deepPurple),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          if (isDesktop && _selectedIds.isNotEmpty) ...[
            Text(
              '${_selectedIds.length} selezionati',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _bulkToggleAvailability(false),
              icon: const Icon(Icons.visibility_off_rounded, size: 18),
              label: const Text('Nascondi'),
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
            OutlinedButton.icon(
              onPressed: () => _bulkToggleAvailability(true),
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('Mostra'),
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
          ElevatedButton.icon(
            onPressed: () => _showProductModal(null),
            icon: const Icon(Icons.add, size: 20),
            label: Text(isDesktop ? 'Aggiungi Prodotto' : 'Aggiungi'),
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

  Future<void> _bulkToggleAvailability(bool available) async {
    final count = _selectedIds.length;
    for (final id in _selectedIds) {
      await ref
          .read(managerMenuProvider.notifier)
          .toggleAvailability(id, available);
    }
    setState(() => _selectedIds.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$count prodotti ${available ? "mostrati" : "nascosti"}',
          ),
          backgroundColor: available ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  Widget _buildStatsCards(BuildContext context, bool isDesktop) {
    final stats = ref.watch(menuStatsProvider);
    final menuAsync = ref.watch(managerMenuProvider);
    final unavailable =
        menuAsync.value?.where((i) => !i.disponibile).length ?? 0;

    final cards = [
      _StatCard(
        title: 'Totale Prodotti',
        value: '${stats['totalItems']}',
        icon: Icons.inventory_2_rounded,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primary.withValues(alpha: 0.1),
      ),
      _StatCard(
        title: 'Media Prezzo',
        value: Formatters.currency(stats['averagePrice']),
        icon: Icons.euro_rounded,
        iconColor: AppColors.info,
        iconBgColor: AppColors.info.withValues(alpha: 0.1),
      ),
      _StatCard(
        title: 'In Sconto',
        value: '${stats['itemsWithDiscount']}',
        icon: Icons.local_offer_rounded,
        iconColor: AppColors.success,
        iconBgColor: AppColors.success.withValues(alpha: 0.1),
      ),
      _StatCard(
        title: 'Non Disponibili',
        value: '$unavailable',
        icon: Icons.visibility_off_rounded,
        iconColor: AppColors.warning,
        iconBgColor: AppColors.warning.withValues(alpha: 0.1),
        hasBorder: unavailable > 0,
        borderColor: AppColors.warning,
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
  }

  Widget _buildFiltersSection(BuildContext context, bool isDesktop) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.maybeWhen(
      data: (list) => list.map((c) => c).toList(),
      orElse: () => [],
    );

    return Column(
      children: [
        Row(
          children: [
            // Search bar (matching inventory_screen.dart)
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
                    hintText: 'Cerca prodotti...',
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
              // Status filter chips (matching inventory pattern)
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
                      isSelected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                    ),
                    _FilterChip(
                      label: 'In Evidenza',
                      isSelected: _selectedCategory == '__featured__',
                      onTap: () =>
                          setState(() => _selectedCategory = '__featured__'),
                    ),
                    _FilterChip(
                      label: 'Nascosti',
                      isSelected: _selectedCategory == '__hidden__',
                      onTap: () =>
                          setState(() => _selectedCategory = '__hidden__'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Category pills (matching inventory_screen.dart)
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _CategoryPill(
                label: 'Tutte le Categorie',
                isSelected:
                    _selectedCategory == null ||
                    _selectedCategory == '__featured__' ||
                    _selectedCategory == '__hidden__',
                onTap: () => setState(() => _selectedCategory = null),
              ),
              ...categories.map(
                (cat) => _CategoryPill(
                  label: cat.nome,
                  isSelected: _selectedCategory == cat.id,
                  onTap: () => setState(() => _selectedCategory = cat.id),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTable(BuildContext context, bool isDesktop) {
    final menuAsync = ref.watch(managerMenuProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    // Build category lookup map once for O(1) access in rows
    final categoryMap = <String, CategoryModel>{};
    categoriesAsync.whenData((cats) {
      for (final cat in cats) {
        categoryMap[cat.id] = cat;
      }
    });

    return menuAsync.when(
      data: (items) {
        var filtered = items.where((item) {
          final matchesSearch =
              _searchQuery.isEmpty ||
              item.nome.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (item.descrizione?.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ??
                  false);

          bool matchesCategory = true;
          if (_selectedCategory == '__featured__') {
            matchesCategory = item.inEvidenza;
          } else if (_selectedCategory == '__hidden__') {
            matchesCategory = !item.disponibile;
          } else if (_selectedCategory != null) {
            matchesCategory = item.categoriaId == _selectedCategory;
          }

          return matchesSearch && matchesCategory;
        }).toList();

        final sorted = _getSortedItems(filtered);
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
                    _buildProductRow(sorted[index], isDesktop, categoryMap),
              ),
              _buildTableFooter(sorted.length, items.length),
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

  List<MenuItemModel> _getSortedItems(List<MenuItemModel> items) {
    final sorted = List<MenuItemModel>.from(items);
    sorted.sort((a, b) {
      int result;
      switch (_sortColumnIndex) {
        case 0:
          result = a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        case 1:
          result = (a.categoriaId ?? '').compareTo(b.categoriaId ?? '');
        case 2:
          result = a.prezzo.compareTo(b.prezzo);
        case 3:
          result = (a.disponibile ? 1 : 0).compareTo(b.disponibile ? 1 : 0);
        default:
          result = 0;
      }
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  Widget _buildSortableHeader(bool allSelected, List<MenuItemModel> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Checkbox
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
          // Product column
          Expanded(
            flex: 3,
            child: _SortableColumnHeader(
              label: 'PRODOTTO',
              isActive: _sortColumnIndex == 0,
              ascending: _sortAscending,
              onTap: () => _onSort(0),
            ),
          ),
          const SizedBox(width: 16),
          // Category column
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
          // Price column
          Expanded(
            child: _SortableColumnHeader(
              label: 'PREZZO',
              isActive: _sortColumnIndex == 2,
              ascending: _sortAscending,
              onTap: () => _onSort(2),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          // Status column
          Expanded(
            child: _SortableColumnHeader(
              label: 'STATO',
              isActive: _sortColumnIndex == 3,
              ascending: _sortAscending,
              onTap: () => _onSort(3),
            ),
          ),
          const SizedBox(width: 120), // Actions space
        ],
      ),
    );
  }

  Widget _buildProductRow(
    MenuItemModel item,
    bool isDesktop,
    Map<String, CategoryModel> categoryMap,
  ) {
    // Use cached category map for O(1) lookup instead of watching provider
    String categoryName = '';
    Color categoryColor = AppColors.primary;

    final cat = categoryMap[item.categoriaId];
    if (cat != null) {
      categoryName = cat.nome;
      final colorHex = cat.colore;
      if (colorHex != null && colorHex.isNotEmpty) {
        try {
          categoryColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
        } catch (_) {}
      }
    }

    final isSelected = _selectedIds.contains(item.id);

    return InkWell(
      onTap: () => _showProductModal(item),
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
                      _selectedIds.add(item.id);
                    } else {
                      _selectedIds.remove(item.id);
                    }
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 16),
            // Product info with image
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: AppRadius.radiusMD,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: AppRadius.radiusMD,
                      child: item.immagineUrl != null
                          ? CachedNetworkImageWidget.app(
                              imageUrl: item.immagineUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              Icons.local_pizza_rounded,
                              color: AppColors.textTertiary,
                              size: 24,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.nome,
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.inEvidenza) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (item.descrizione != null &&
                            item.descrizione!.isNotEmpty)
                          Text(
                            item.descrizione!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Category badge
            if (isDesktop)
              Expanded(
                flex: 2,
                child: categoryName.isEmpty
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: categoryColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            categoryName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: categoryColor,
                            ),
                          ),
                        ),
                      ),
              ),
            const SizedBox(width: 16),
            // Price
            Expanded(
              child: Align(
                alignment: isDesktop
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: isDesktop
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.currency(item.prezzoEffettivo),
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.hasSconto)
                      Text(
                        Formatters.currency(item.prezzo),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Status
            if (isDesktop)
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.disponibile
                            ? AppColors.success
                            : AppColors.error,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (item.disponibile
                                        ? AppColors.success
                                        : AppColors.error)
                                    .withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.disponibile ? 'Disponibile' : 'Nascosto',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            // Actions
            SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => _showProductModal(item),
                    icon: Icon(
                      Icons.edit_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Modifica',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleAvailability(item),
                    icon: Icon(
                      item.disponibile
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: item.disponibile ? 'Nascondi' : 'Mostra',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(item),
                    icon: Icon(
                      Icons.delete_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Elimina',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
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
              'Nessun prodotto trovato',
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

  void _showProductModal(MenuItemModel? item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProductEditModal(
        item: item,
        onSave: (data) async {
          if (item == null) {
            await ref.read(managerMenuProvider.notifier).createItem(data);
          } else {
            await ref
                .read(managerMenuProvider.notifier)
                .updateItem(item.id, data.toJson());
          }
        },
      ),
    );
  }

  Future<void> _toggleAvailability(MenuItemModel item) async {
    await ref
        .read(managerMenuProvider.notifier)
        .toggleAvailability(item.id, !item.disponibile);
  }

  void _confirmDelete(MenuItemModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Prodotto'),
        content: Text('Sei sicuro di voler eliminare "${item.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(managerMenuProvider.notifier)
                  .deleteItemWithImage(item);
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

  // ============================================================================
  // CONFIGURATION MODALS & IMPORT DIALOGS
  // ============================================================================

  void _showCategoriesModal(BuildContext dialogContext) {
    showDialog(
      context: dialogContext,
      builder: (ctx) => const CategoriesModalV2(),
    );
  }

  void _showBulkImportDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
        title: Row(
          children: [
            Icon(Icons.upload_file_rounded, color: AppColors.warning),
            const SizedBox(width: AppSpacing.md),
            const Text('Importa da Lista'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Incolla la lista dei prodotti nel formato:',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: AppRadius.radiusMD,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'CATEGORIA\n'
                  'Nome Prodotto, (ingredienti), taglie, prezzo1, prezzo2\n'
                  'Nome Prodotto, (ingredienti), taglia, prezzo\n'
                  'Nome Prodotto, (ingredienti), prezzo\n\n'
                  'CATEGORIA 2\n'
                  'Nome Prodotto, (ingredienti), taglie, prezzo1, prezzo2',
                  style: AppTypography.bodySmall.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: textController,
                maxLines: 15,
                decoration: InputDecoration(
                  hintText: 'Incolla qui la lista...',
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusMD),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Inserisci una lista valida'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              await _performBulkImport(text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Importa'),
          ),
        ],
      ),
    );
  }

  void _showJsonImportDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
        title: Row(
          children: [
            const Icon(Icons.data_object_rounded, color: Colors.purple),
            const SizedBox(width: AppSpacing.md),
            const Text('Importa da JSON'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Incolla il JSON con la struttura corretta:',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: AppRadius.radiusMD,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Supporta categorie, ingredienti, taglie, allergeni e prodotti complessi.\n'
                  'Prodotti possono includere "extra_ingredients": "ALL" o liste specifiche.\n'
                  'Supporta "price_override" per taglie e ingredienti.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: textController,
                maxLines: 15,
                decoration: InputDecoration(
                  hintText: '{ "products": [ ... ] }',
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusMD),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              await _performJsonImport(text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Importa JSON'),
          ),
        ],
      ),
    );
  }

  Future<void> _performBulkImport(String text) async {
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: AppColors.warning,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Importazione in corso...',
                  style: AppTypography.titleMedium,
                ),
              ],
            ),
          ),
        );
      }

      final service = BulkMenuImportService();
      final result = await service.importFromText(text);

      if (mounted) Navigator.pop(context);
      await ref.read(managerMenuProvider.notifier).refresh();
      await ref.read(categoriesProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Importazione completata: ${result.productsCreated} prodotti, ${result.categoriesCreated} categorie',
            ),
            backgroundColor: result.hasErrors
                ? AppColors.warning
                : AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _performJsonImport(String jsonText) async {
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: Colors.purple,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Importazione JSON...', style: AppTypography.titleMedium),
              ],
            ),
          ),
        );
      }

      final service = JsonMenuImportService();
      final result = await service.importFromJson(jsonText);

      if (mounted) Navigator.pop(context);
      await ref.read(managerMenuProvider.notifier).refresh();
      await ref.read(categoriesProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Importato: ${result.productsCreated} prodotti, ${result.categoriesCreated} categorie, ${result.ingredientsCreated} ingredienti',
            ),
            backgroundColor: result.hasErrors
                ? AppColors.warning
                : AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ============================================================================
// STAT CARD WIDGET (matching inventory_screen.dart)
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

// ============================================================================
// FILTER CHIPS (matching inventory_screen.dart)
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
// SORTABLE COLUMN HEADER (matching inventory_screen.dart)
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
