import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/category_model.dart';
import '../../../core/widgets/cached_network_image.dart';
import '../../../providers/categories_provider.dart';
import '../../../core/services/storage_service.dart';

/// V2 Categories Modal - Modern design matching category_modal_new.html mockup
/// Retains all functionality from the original categories_modal.dart
class CategoriesModalV2 extends ConsumerStatefulWidget {
  const CategoriesModalV2({super.key});

  @override
  ConsumerState<CategoriesModalV2> createState() => _CategoriesModalV2State();
}

class _CategoriesModalV2State extends ConsumerState<CategoriesModalV2> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoriesProvider);
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 900;
    final modalWidth = isDesktop ? 1100.0 : screenSize.width * 0.95;
    final maxModalHeight = screenSize.height * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: modalWidth,
          maxHeight: maxModalHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.radiusXL,
            boxShadow: AppShadows.lg,
          ),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: categoriesState.when(
                  data: (categories) =>
                      _buildContent(context, categories, isDesktop),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _buildErrorState(e),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                  'Gestione Categorie',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Organizza la struttura del tuo menu e gestisci i gruppi di prodotti.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Riordina button
          OutlinedButton.icon(
            onPressed: () => _showReorderDialog(context),
            icon: const Icon(Icons.sort, size: 18),
            label: const Text('Riordina'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          // Nuova Categoria button
          ElevatedButton.icon(
            onPressed: () => _showCategoryForm(context, null),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Nuova Categoria'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 2,
              shadowColor: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceLight,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<CategoryModel> categories,
    bool isDesktop,
  ) {
    // Apply filters
    var filtered = categories.where((cat) {
      if (_searchQuery.isNotEmpty) {
        final matchesSearch =
            cat.nome.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (cat.descrizione?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false);
        if (!matchesSearch) return false;
      }
      if (_statusFilter == 'active') return cat.attiva;
      if (_statusFilter == 'draft') return !cat.attiva;
      if (_statusFilter == 'scheduled') return cat.disattivazioneProgrammata;
      return true;
    }).toList();

    final activeCount = categories.where((c) => c.attiva).length;
    final draftCount = categories.where((c) => !c.attiva).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: isDesktop
          ? _buildDesktopLayout(
              context,
              filtered,
              categories.length,
              activeCount,
              draftCount,
            )
          : _buildMobileLayout(
              context,
              filtered,
              categories.length,
              activeCount,
              draftCount,
            ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    List<CategoryModel> categories,
    int total,
    int active,
    int draft,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left sidebar - Stats and Most Popular
        SizedBox(
          width: 280,
          child: Column(
            children: [
              _buildStatsCard(total, active, draft),
              const SizedBox(height: 16),
              if (categories.isNotEmpty)
                _buildMostPopularCard(categories.first),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right content - Filters and Table
        Expanded(
          child: Column(
            children: [
              _buildFiltersSection(),
              const SizedBox(height: 16),
              _buildCategoriesTable(context, categories),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    List<CategoryModel> categories,
    int total,
    int active,
    int draft,
  ) {
    return Column(
      children: [
        _buildStatsCard(total, active, draft),
        const SizedBox(height: 16),
        _buildFiltersSection(),
        const SizedBox(height: 16),
        _buildCategoriesTable(context, categories),
      ],
    );
  }

  Widget _buildStatsCard(int total, int active, int draft) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXL,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Panoramica',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.bar_chart, color: AppColors.textSecondary, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Totale Categorie',
                  '$total',
                  AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem('Attive', '$active', AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Bozze', '$draft', AppColors.warning),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Totale Articoli',
                  '-',
                  AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLG,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMostPopularCard(CategoryModel category) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXL,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Image header
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.3),
                  AppColors.primary,
                ],
              ),
            ),
            child: Stack(
              children: [
                if (category.iconaUrl != null)
                  Positioned.fill(
                    child: CachedNetworkImageWidget.app(
                      imageUrl: category.iconaUrl!,
                      fit: BoxFit.cover,
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PIÙ POPOLARE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.9),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.nome,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '- Articoli',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: category.attiva
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category.attiva ? 'Attiva' : 'Non attiva',
                          style: TextStyle(
                            fontSize: 12,
                            color: category.attiva
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showCategoryForm(context, category),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: const Text('Gestisci Articoli'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXL,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          // Search bar
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: AppRadius.radiusLG,
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Cerca categorie...',
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
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Status filter dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: AppRadius.radiusLG,
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Tutti gli stati'),
                  ),
                  DropdownMenuItem(value: 'active', child: Text('Attiva')),
                  DropdownMenuItem(value: 'draft', child: Text('Bozza')),
                  DropdownMenuItem(
                    value: 'scheduled',
                    child: Text('Programmata'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _statusFilter = value ?? 'all'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTable(
    BuildContext context,
    List<CategoryModel> categories,
  ) {
    if (categories.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXL,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 40), // Drag handle space
                Expanded(
                  flex: 3,
                  child: Text('NOME CATEGORIA', style: _headerStyle()),
                ),
                Expanded(
                  flex: 2,
                  child: Text('ARTICOLI', style: _headerStyle()),
                ),
                Expanded(flex: 2, child: Text('STATO', style: _headerStyle())),
                const SizedBox(width: 80), // Actions space
              ],
            ),
          ),
          // Table rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: AppColors.border.withValues(alpha: 0.5),
            ),
            itemBuilder: (context, index) =>
                _buildCategoryRow(context, categories[index]),
          ),
          // Footer
          _buildTableFooter(categories.length),
        ],
      ),
    );
  }

  TextStyle _headerStyle() {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      letterSpacing: 0.5,
    );
  }

  Widget _buildCategoryRow(BuildContext context, CategoryModel category) {
    return InkWell(
      onTap: () => _showCategoryForm(context, category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // Drag handle
            Icon(Icons.drag_indicator, color: AppColors.textTertiary, size: 20),
            const SizedBox(width: 16),
            // Category info with thumbnail
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: AppRadius.radiusMD,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: AppRadius.radiusMD,
                      child: category.iconaUrl != null
                          ? CachedNetworkImageWidget.app(
                              imageUrl: category.iconaUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Text(
                                category.icona ?? '📁',
                                style: const TextStyle(fontSize: 18),
                              ),
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
                                category.nome,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (category.disattivazioneProgrammata) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: AppColors.info,
                              ),
                            ],
                          ],
                        ),
                        if (category.descrizione != null &&
                            category.descrizione!.isNotEmpty)
                          Text(
                            category.descrizione!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
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
            // Articles count
            Expanded(
              flex: 2,
              child: Text(
                '- articoli',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            // Status badge
            Expanded(flex: 2, child: _buildStatusBadge(category)),
            // Actions
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => _showCategoryForm(context, category),
                    icon: Icon(
                      Icons.edit,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Modifica',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(context, category),
                    icon: Icon(
                      Icons.delete,
                      size: 18,
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

  Widget _buildStatusBadge(CategoryModel category) {
    Color bgColor;
    Color textColor;
    String label;

    if (category.disattivazioneProgrammata) {
      bgColor = AppColors.info.withValues(alpha: 0.1);
      textColor = AppColors.info;
      label = 'Programmata';
    } else if (category.attiva) {
      bgColor = AppColors.success.withValues(alpha: 0.1);
      textColor = AppColors.success;
      label = 'Attiva';
    } else {
      bgColor = AppColors.warning.withValues(alpha: 0.1);
      textColor = AppColors.warning;
      label = 'Bozza';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildTableFooter(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando $count categorie',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          // Check scheduled button
          TextButton.icon(
            onPressed: () async {
              try {
                await ref
                    .read(categoriesProvider.notifier)
                    .checkScheduledDeactivation();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Controllo disattivazione programmata completato',
                      ),
                      backgroundColor: AppColors.info,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Errore: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            icon: Icon(Icons.schedule, size: 16, color: AppColors.info),
            label: Text(
              'Controlla Programmazioni',
              style: TextStyle(color: AppColors.info),
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
              Icons.category_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nessuna categoria trovata',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea la prima categoria per organizzare il menu',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Errore caricamento categorie', style: AppTypography.bodyMedium),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.refresh(categoriesProvider),
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  void _showReorderDialog(BuildContext context) {
    final categories = ref.read(categoriesProvider).value ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Riordina Categorie'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: ReorderableListView.builder(
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) newIndex -= 1;
              final reordered = List<CategoryModel>.from(categories);
              final item = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, item);
              ref
                  .read(categoriesProvider.notifier)
                  .reorderCategories(reordered);
            },
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                key: ValueKey(category.id),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: AppRadius.radiusMD,
                  ),
                  child: Center(
                    child: Text(
                      category.icona ?? '📁',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                title: Text(category.nome),
                trailing: const Icon(Icons.drag_handle),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fatto'),
          ),
        ],
      ),
    );
  }

  void _showCategoryForm(BuildContext context, CategoryModel? category) {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryFormDialogV2(category: category),
    );
  }

  void _confirmDelete(BuildContext context, CategoryModel category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Categoria'),
        content: Text(
          'Sei sicuro di voler eliminare la categoria "${category.nome}"?\n\n'
          'I prodotti associati non verranno eliminati, ma perderanno la categoria.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(categoriesProvider.notifier)
                  .deleteCategory(category.id);
              if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Categoria eliminata'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
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
// CATEGORY FORM DIALOG V2 - Matches HTML mockup design
// ============================================================================
class _CategoryFormDialogV2 extends ConsumerStatefulWidget {
  final CategoryModel? category;

  const _CategoryFormDialogV2({this.category});

  @override
  ConsumerState<_CategoryFormDialogV2> createState() =>
      _CategoryFormDialogV2State();
}

class _CategoryFormDialogV2State extends ConsumerState<_CategoryFormDialogV2> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _descrizioneController;
  String _selectedIcon = '📁';
  String _selectedColor = '#9B8B7E';
  bool _isLoading = false;
  bool _disattivazioneProgrammata = false;
  List<String> _giorniDisattivazione = [];
  bool _permittiDivisioni = true;
  String _status = 'active';

  final _storageService = StorageService();
  String? _iconImageUrl;
  File? _selectedIconFile;

  final List<String> _giorniSettimana = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  final Map<String, String> _giorniItaliano = {
    'monday': 'Lunedì',
    'tuesday': 'Martedì',
    'wednesday': 'Mercoledì',
    'thursday': 'Giovedì',
    'friday': 'Venerdì',
    'saturday': 'Sabato',
    'sunday': 'Domenica',
  };

  // Full emoji icon options from v1
  static const List<String> _availableIcons = [
    '🍕',
    '🍟',
    '🥤',
    '🍰',
    '🍔',
    '🌮',
    '🍝',
    '🥗',
    '🍜',
    '🍱',
    '🍛',
    '🍲',
    '🥘',
    '🍳',
    '🥞',
    '🧇',
    '🥓',
    '🍗',
    '🍖',
    '🌭',
    '🥪',
    '🥙',
    '🧆',
    '🌯',
    '🥗',
    '🥫',
    '🍿',
    '🧈',
    '🧀',
    '🥚',
    '🍞',
    '🥐',
    '🥨',
    '🥯',
    '🥖',
    '🫓',
    '🥩',
    '🥟',
    '🍤',
    '🍣',
    '🦞',
    '🦀',
    '🐙',
    '🦑',
    '🍦',
    '🍧',
    '🍨',
    '🍩',
    '🍪',
    '🎂',
    '🍮',
    '🍭',
    '🍬',
    '🍫',
    '🍿',
    '🍩',
    '☕',
    '🍵',
    '🧃',
    '🥛',
    '🍷',
    '🍺',
    '🍻',
    '🥂',
    '🍾',
    '🍶',
    '🧉',
    '🧊',
    '📁',
    '🏷️',
    '⭐',
    '🔥',
  ];

  // Predefined color palette from v1
  static const List<String> _availableColors = [
    '#ACC7BE',
    '#F5E6D3',
    '#D4463C',
    '#C17B5C',
    '#5B8C5A',
    '#E8E0D5',
    '#9B8B7E',
    '#6B8CAF',
    '#8B7D70',
    '#E8D1D1',
  ];

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.category?.nome ?? '');
    _descrizioneController = TextEditingController(
      text: widget.category?.descrizione ?? '',
    );
    _selectedIcon = widget.category?.icona ?? '📁';
    _selectedColor = widget.category?.colore ?? '#9B8B7E';
    _iconImageUrl = widget.category?.iconaUrl;

    if (widget.category != null) {
      _disattivazioneProgrammata = widget.category!.disattivazioneProgrammata;
      _giorniDisattivazione = widget.category!.giorniDisattivazione ?? [];
      _permittiDivisioni = widget.category!.permittiDivisioni;
      _status = widget.category!.attiva
          ? 'active'
          : (_disattivazioneProgrammata ? 'scheduled' : 'draft');
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descrizioneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result != null && result.files.single.path != null) {
          setState(() {
            _selectedIconFile = File(result.files.single.path!);
            _iconImageUrl = null;
          });
        }
      } else {
        final picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 90,
        );
        if (image != null) {
          setState(() {
            _selectedIconFile = File(image.path);
            _iconImageUrl = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore selezione immagine: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.category == null
                          ? 'Nuova Categoria'
                          : 'Modifica Categoria',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceLight,
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome
                      _buildLabel('Nome Categoria'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nomeController,
                        decoration: _inputDecoration('Es. Pizze Speciali'),
                        validator: (v) => (v?.isEmpty ?? true)
                            ? 'Il nome è obbligatorio'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Descrizione
                      _buildLabel('Descrizione', optional: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descrizioneController,
                        decoration: _inputDecoration(
                          'Breve descrizione della categoria...',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      // Icon Picker (Emoji grid like v1)
                      _buildLabel('Icona', optional: true),
                      const SizedBox(height: 6),
                      Container(
                        height: 180,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: AppRadius.radiusLG,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 10,
                                mainAxisSpacing: 4,
                                crossAxisSpacing: 4,
                              ),
                          itemCount: _availableIcons.length,
                          itemBuilder: (context, index) {
                            final icon = _availableIcons[index];
                            final isSelected = icon == _selectedIcon;
                            return InkWell(
                              onTap: () => setState(() => _selectedIcon = icon),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    icon,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Color Picker Section
                      _buildLabel('Colore Categoria'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: AppRadius.radiusLG,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      int.parse(
                                            _selectedColor.substring(1),
                                            radix: 16,
                                          ) +
                                          0xFF000000,
                                    ),
                                    borderRadius: AppRadius.radiusMD,
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedColor.toUpperCase(),
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _availableColors.map((color) {
                                final isSelected = _selectedColor == color;
                                return InkWell(
                                  onTap: () =>
                                      setState(() => _selectedColor = color),
                                  borderRadius: AppRadius.radiusMD,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Color(
                                        int.parse(
                                              color.substring(1),
                                              radix: 16,
                                            ) +
                                            0xFF000000,
                                      ),
                                      borderRadius: AppRadius.radiusMD,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.border,
                                        width: isSelected ? 3 : 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 16,
                                          )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Image Upload Section
                      _buildLabel('Immagine Categoria', optional: true),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: AppRadius.radiusLG,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedIconFile != null ||
                                _iconImageUrl != null) ...[
                              ClipRRect(
                                borderRadius: AppRadius.radiusLG,
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 100,
                                  child: _selectedIconFile != null
                                      ? Image.file(
                                          _selectedIconFile!,
                                          fit: BoxFit.cover,
                                        )
                                      : CachedNetworkImageWidget.app(
                                          imageUrl: _iconImageUrl!,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(
                                      Icons.upload_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _selectedIconFile != null ||
                                              _iconImageUrl != null
                                          ? 'Cambia'
                                          : 'Carica',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: BorderSide(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_selectedIconFile != null ||
                                    _iconImageUrl != null) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => setState(() {
                                        _selectedIconFile = null;
                                        _iconImageUrl = null;
                                      }),
                                      icon: const Icon(
                                        Icons.delete_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Rimuovi'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: BorderSide(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Status
                      _buildLabel('Stato'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildRadioOption('Attiva', 'active'),
                          const SizedBox(width: 16),
                          _buildRadioOption('Bozza', 'draft'),
                          const SizedBox(width: 16),
                          _buildRadioOption('Programmata', 'scheduled'),
                        ],
                      ),

                      // Scheduled deactivation days (if scheduled)
                      if (_status == 'scheduled') ...[
                        const SizedBox(height: 20),
                        _buildLabel('Giorni di disattivazione'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _giorniSettimana.map((giorno) {
                            final isSelected = _giorniDisattivazione.contains(
                              giorno,
                            );
                            return FilterChip(
                              label: Text(_giorniItaliano[giorno]!),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _giorniDisattivazione.add(giorno);
                                  } else {
                                    _giorniDisattivazione.remove(giorno);
                                  }
                                });
                              },
                              backgroundColor: AppColors.surface,
                              selectedColor: AppColors.primary.withValues(
                                alpha: 0.2,
                              ),
                              checkmarkColor: AppColors.primary,
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Permetti divisioni
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: AppRadius.radiusLG,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.call_split,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Permetti Divisioni',
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Consenti ai clienti di dividere i prodotti',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _permittiDivisioni,
                              onChanged: (v) =>
                                  setState(() => _permittiDivisioni = v),
                              activeTrackColor: AppColors.primary,
                              activeThumbColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                border: Border(top: BorderSide(color: AppColors.border)),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: const Text('Annulla'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Salva Modifiche'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool optional = false}) {
    return Row(
      children: [
        Text(
          text,
          style: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        if (optional)
          Text(
            ' (Opzionale)',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: AppRadius.radiusLG,
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusLG,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusLG,
        borderSide: BorderSide(color: AppColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildRadioOption(String label, String value) {
    return InkWell(
      onTap: () => setState(() {
        _status = value;
        _disattivazioneProgrammata = value == 'scheduled';
      }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: _status,
            onChanged: (v) => setState(() {
              _status = v ?? 'active';
              _disattivazioneProgrammata = v == 'scheduled';
            }),
            activeColor: AppColors.primary,
          ),
          Text(label, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? finalIconaUrl = _iconImageUrl;

      if (_selectedIconFile != null) {
        finalIconaUrl = await _storageService.uploadCategoryIcon(
          imageFile: _selectedIconFile!,
          existingImageUrl: widget.category?.iconaUrl,
        );
      } else if (_iconImageUrl == null && widget.category?.iconaUrl != null) {
        try {
          await _storageService.deleteCategoryIcon(widget.category!.iconaUrl!);
        } catch (_) {}
        finalIconaUrl = null;
      }

      final isActive = _status == 'active';

      if (widget.category == null) {
        await ref
            .read(categoriesProvider.notifier)
            .createCategory(
              nome: _nomeController.text.trim(),
              descrizione: _descrizioneController.text.trim().isNotEmpty
                  ? _descrizioneController.text.trim()
                  : null,
              icona: _selectedIcon,
              iconaUrl: finalIconaUrl,
              colore: _selectedColor,
              disattivazioneProgrammata: _disattivazioneProgrammata,
              giorniDisattivazione: _disattivazioneProgrammata
                  ? _giorniDisattivazione
                  : null,
              permittiDivisioni: _permittiDivisioni,
            );
      } else {
        await ref
            .read(categoriesProvider.notifier)
            .updateCategory(
              id: widget.category!.id,
              nome: _nomeController.text.trim(),
              descrizione: _descrizioneController.text.trim().isNotEmpty
                  ? _descrizioneController.text.trim()
                  : null,
              icona: _selectedIcon,
              iconaUrl: finalIconaUrl,
              colore: _selectedColor,
              disattivazioneProgrammata: _disattivazioneProgrammata,
              giorniDisattivazione: _disattivazioneProgrammata
                  ? _giorniDisattivazione
                  : null,
              permittiDivisioni: _permittiDivisioni,
            );
        // Update active status separately if needed
        if (widget.category!.attiva != isActive) {
          await ref
              .read(categoriesProvider.notifier)
              .toggleActive(widget.category!.id, isActive);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.category == null
                  ? 'Categoria creata con successo'
                  : 'Categoria aggiornata con successo',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
