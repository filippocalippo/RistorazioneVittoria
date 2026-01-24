import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/delivery_zone_model.dart';
import '../../../providers/delivery_zones_provider.dart';
import 'zone_editor_screen.dart';

/// Screen for managing delivery zones
class ZoneManagementScreen extends ConsumerWidget {
  final LatLng? pizzeriaCenter;

  const ZoneManagementScreen({
    super.key,
    this.pizzeriaCenter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(deliveryZonesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Gestione Zone',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createZone(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_location_rounded, color: Colors.white),
        label: const Text(
          'Nuova Zona',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: zonesAsync.when(
        data: (zones) {
          if (zones.isEmpty) {
            return _buildEmptyState(context);
          }
          
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: zones.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final zone = zones[index];
              return _buildZoneCard(context, ref, zone);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text('Errore: $error'),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref.invalidate(deliveryZonesProvider),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.map_rounded,
              size: 50,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Nessuna Zona Definita',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Crea la prima zona di consegna\ntoccando il pulsante in basso',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(
    BuildContext context,
    WidgetRef ref,
    DeliveryZoneModel zone,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: zone.color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _editZone(context, zone),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Color indicator
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: zone.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: zone.color,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.place_rounded,
                  color: zone.color,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Zone info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zone.name,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${zone.polygon.length} punti',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _editZone(context, zone);
                      break;
                    case 'delete':
                      _deleteZone(context, ref, zone);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 20),
                        SizedBox(width: AppSpacing.sm),
                        Text('Modifica'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, size: 20, color: AppColors.error),
                        SizedBox(width: AppSpacing.sm),
                        Text('Elimina', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createZone(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ZoneEditorScreen(
          initialCenter: pizzeriaCenter,
        ),
      ),
    );
  }

  Future<void> _editZone(BuildContext context, DeliveryZoneModel zone) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ZoneEditorScreen(
          initialCenter: pizzeriaCenter,
          editingZone: zone,
        ),
      ),
    );
  }

  Future<void> _deleteZone(
    BuildContext context,
    WidgetRef ref,
    DeliveryZoneModel zone,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Zona'),
        content: Text('Sei sicuro di voler eliminare la zona "${zone.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(deliveryZonesServiceProvider).deleteZone(zone.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Zona "${zone.name}" eliminata'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore durante l\'eliminazione: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
