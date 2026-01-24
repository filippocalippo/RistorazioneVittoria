import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../providers/sizes_master_provider.dart';
import '../../../core/models/size_variant_model.dart';
import '../widgets/size_variant_form_modal.dart';

/// Manager screen for pizzeria-scoped size management
class SizeVariantsScreen extends ConsumerStatefulWidget {
  const SizeVariantsScreen({super.key});

  @override
  ConsumerState<SizeVariantsScreen> createState() => _SizeVariantsScreenState();
}

class _SizeVariantsScreenState extends ConsumerState<SizeVariantsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizesAsync = ref.watch(sizesMasterProvider);
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gestione Dimensioni'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: AppSpacing.paddingXL,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Cerca dimensioni...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.radiusXL,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.radiusXL,
                  borderSide: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.radiusXL,
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: sizesAsync.when(
              data: (sizes) {
                // Filter sizes based on search query
                final filteredSizes = _searchQuery.isEmpty
                    ? sizes
                    : sizes.where((size) {
                        final nameLower = size.nome.toLowerCase();
                        final descLower = size.descrizione?.toLowerCase() ?? '';
                        return nameLower.contains(_searchQuery) ||
                            descLower.contains(_searchQuery);
                      }).toList();

                if (filteredSizes.isEmpty) {
                  return _buildNoResultsState(context);
                }
                return _buildSizesList(context, filteredSizes, isDesktop);
              },
        loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Errore: $error'),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: () => ref.refresh(sizesMasterProvider),
                      child: const Text('Riprova'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: sizesAsync.maybeWhen(
        data: (_) => FloatingActionButton.extended(
          onPressed: () => _showSizeModal(context, null),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Aggiungi Dimensione',
            style: TextStyle(color: Colors.white),
          ),
        ),
        orElse: () => null,
      ),
    );
  }

  
  Widget _buildNoResultsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXXL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off,
                size: 64,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            Text('Nessun risultato trovato', style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Prova a modificare i termini di ricerca',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Cancella ricerca'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.lg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizesList(
    BuildContext context,
    List<SizeVariantModel> sizes,
    bool isDesktop,
  ) {
    return ListView.builder(
      padding: AppSpacing.paddingXL,
      itemCount: sizes.length,
      itemBuilder: (context, index) {
        final size = sizes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusLG,
            side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: ListTile(
            contentPadding: AppSpacing.paddingLG,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.straighten, color: AppColors.primary),
            ),
            title: Text(
              size.nome,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (size.descrizione != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(size.descrizione!),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: AppRadius.radiusSM,
                      ),
                      child: Text(
                        'Moltiplicatore: ${size.priceMultiplier}x',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (size.permittiDivisioni)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: AppRadius.radiusSM,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.call_split_rounded,
                              size: 14,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Divisioni',
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showSizeModal(context, size),
                  tooltip: 'Modifica',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, size),
                  tooltip: 'Elimina',
                  color: AppColors.error,
                ),
                Switch(
                  value: size.attivo,
                  onChanged: (value) {
                    ref
                        .read(sizesMasterProvider.notifier)
                        .toggleActive(size.id, value);
                  },
                  activeTrackColor: AppColors.success,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSizeModal(
    BuildContext context,
    SizeVariantModel? size,
  ) {
    showDialog(
      context: context,
      builder: (context) => SizeVariantFormModal(
        size: size,
        onSave: (savedSize) async {
          if (size == null) {
            await ref
                .read(sizesMasterProvider.notifier)
                .createSize(savedSize);
          } else {
            await ref
                .read(sizesMasterProvider.notifier)
                .updateSize(size.id, savedSize.toJson());
          }
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  size == null
                      ? 'Dimensione creata con successo'
                      : 'Dimensione aggiornata con successo',
                ),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    SizeVariantModel size,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text(
          'Sei sicuro di voler eliminare la dimensione "${size.nome}"?\nQuesta azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(sizesMasterProvider.notifier)
                    .deleteSize(size.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Dimensione eliminata con successo'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Errore: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}
