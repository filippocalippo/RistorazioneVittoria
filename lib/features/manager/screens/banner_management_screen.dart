import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../providers/banner_management_provider.dart';
import '../../../core/models/promotional_banner_model.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/utils/logger.dart';
import '../widgets/banner_list_card.dart';

/// Manager screen for viewing and managing promotional banners
class BannerManagementScreen extends ConsumerStatefulWidget {
  const BannerManagementScreen({super.key});

  @override
  ConsumerState<BannerManagementScreen> createState() =>
      _BannerManagementScreenState();
}

class _BannerManagementScreenState
    extends ConsumerState<BannerManagementScreen> {
  String _filterStatus = 'all'; // all, active, inactive, scheduled

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gestione Banner'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allBannersProvider);
            },
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildBannersList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/manager/banners/new'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo Banner'),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'Tutti',
              isSelected: _filterStatus == 'all',
              onTap: () => setState(() => _filterStatus = 'all'),
            ),
            const SizedBox(width: AppSpacing.sm),
            _FilterChip(
              label: 'Attivi',
              isSelected: _filterStatus == 'active',
              onTap: () => setState(() => _filterStatus = 'active'),
            ),
            const SizedBox(width: AppSpacing.sm),
            _FilterChip(
              label: 'Inattivi',
              isSelected: _filterStatus == 'inactive',
              onTap: () => setState(() => _filterStatus = 'inactive'),
            ),
            const SizedBox(width: AppSpacing.sm),
            _FilterChip(
              label: 'Programmati',
              isSelected: _filterStatus == 'scheduled',
              onTap: () => setState(() => _filterStatus = 'scheduled'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannersList() {
    final bannersAsync = ref.watch(allBannersProvider);

    return bannersAsync.when(
      data: (banners) {
        if (banners.isEmpty) {
          return _buildEmptyState();
        }

        // Filter banners based on selected filter
        final filteredBanners = _filterBanners(banners);

        if (filteredBanners.isEmpty) {
          return _buildNoResultsState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allBannersProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: filteredBanners.length,
            itemBuilder: (context, index) {
              return BannerListCard(
                banner: filteredBanners[index],
                onEdit: () => _editBanner(filteredBanners[index]),
                onDelete: () => _deleteBanner(filteredBanners[index]),
                onToggleActive: () => _toggleActive(filteredBanners[index]),
                onDuplicate: () => _duplicateBanner(filteredBanners[index]),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error),
    );
  }

  List<PromotionalBannerModel> _filterBanners(
    List<PromotionalBannerModel> banners,
  ) {
    final now = DateTime.now();

    switch (_filterStatus) {
      case 'active':
        return banners.where((b) {
          return b.attivo &&
              (b.dataInizio == null || b.dataInizio!.isBefore(now)) &&
              (b.dataFine == null || b.dataFine!.isAfter(now));
        }).toList();

      case 'inactive':
        return banners.where((b) => !b.attivo).toList();

      case 'scheduled':
        return banners.where((b) {
          return b.attivo &&
              b.dataInizio != null &&
              b.dataInizio!.isAfter(now);
        }).toList();

      default:
        return banners;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 80,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Nessun banner creato',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Crea il primo banner per iniziare',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off,
            size: 80,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Nessun banner trovato',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Prova a cambiare filtro',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Errore nel caricamento',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              error.toString(),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textDisabled,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(allBannersProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  void _editBanner(PromotionalBannerModel banner) {
    context.push('/manager/banners/edit/${banner.id}');
  }

  Future<void> _deleteBanner(PromotionalBannerModel banner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text(
          'Sei sicuro di voler eliminare il banner "${banner.titolo}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await SupabaseConfig.client
          .from('promotional_banners')
          .delete()
          .eq('id', banner.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banner eliminato con successo'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.invalidate(allBannersProvider);
      }
    } catch (e) {
      Logger.error('Failed to delete banner', tag: 'BannerManagement', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleActive(PromotionalBannerModel banner) async {
    try {
      await SupabaseConfig.client
          .from('promotional_banners')
          .update({'attivo': !banner.attivo})
          .eq('id', banner.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              banner.attivo
                  ? 'Banner disattivato'
                  : 'Banner attivato',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        ref.invalidate(allBannersProvider);
      }
    } catch (e) {
      Logger.error('Failed to toggle banner', tag: 'BannerManagement', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _duplicateBanner(PromotionalBannerModel banner) async {
    try {
      await SupabaseConfig.client.rpc('duplicate_banner', params: {
        'source_banner_id': banner.id,
        'new_title': '${banner.titolo} (Copia)',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banner duplicato con successo'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.invalidate(allBannersProvider);
      }
    } catch (e) {
      Logger.error('Failed to duplicate banner', tag: 'BannerManagement', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
