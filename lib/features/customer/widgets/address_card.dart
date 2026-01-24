import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/app_colors.dart';
import '../../../DesignSystem/app_typography.dart';
import '../../../DesignSystem/app_spacing.dart';
import '../../../DesignSystem/app_radius.dart';
import '../../../DesignSystem/app_shadows.dart';
import '../../../DesignSystem/app_icons.dart';
import '../../../core/models/user_address_model.dart';
import '../../../providers/addresses_provider.dart';
import 'address_form_sheet.dart';

/// Card singolo indirizzo con design pulito
class AddressCard extends ConsumerWidget {
  final UserAddressModel address;

  const AddressCard({super.key, required this.address});

  IconData _getLabelIcon(String? label) {
    final lowerLabel = (label ?? '').toLowerCase();
    if (lowerLabel.contains('casa') || lowerLabel.contains('home')) {
      return Icons.home_outlined;
    } else if (lowerLabel.contains('lavoro') || lowerLabel.contains('ufficio') || lowerLabel.contains('work')) {
      return Icons.business_outlined;
    } else if (lowerLabel.contains('palestra') || lowerLabel.contains('gym')) {
      return Icons.fitness_center_outlined;
    }
    return Icons.location_on_outlined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = address.isDefault;

    return GestureDetector(
      onTap: () => _setDefault(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusLG,
          border: Border.all(
            color: isSelected ? AppColors.warning : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: AppShadows.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icona etichetta
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.warning.withValues(alpha: 0.1)
                    : AppColors.surfaceLight,
                borderRadius: AppRadius.radiusMD,
              ),
              child: Icon(
                _getLabelIcon(address.etichetta),
                color: isSelected ? AppColors.warning : AppColors.textSecondary,
                size: AppIcons.sizeLG,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Info indirizzo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.displayLabel,
                    style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    address.indirizzo,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  Text(
                    '${address.citta}, ${address.cap}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  if (address.note != null && address.note!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '"${address.note}"',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Azioni
            Column(
              children: [
                GestureDetector(
                  onTap: () => _showEditForm(context),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: const Icon(AppIcons.edit, color: AppColors.textTertiary, size: AppIcons.sizeMD),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                GestureDetector(
                  onTap: () => _deleteAddress(context, ref),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: const Icon(AppIcons.delete, color: AppColors.error, size: AppIcons.sizeMD),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      useSafeArea: false,
      builder: (context) => AddressFormSheet(address: address),
    );
  }

  Future<void> _setDefault(BuildContext context, WidgetRef ref) async {
    if (address.isDefault) return;

    try {
      await ref.read(userAddressesProvider.notifier).setDefaultAddress(address.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Indirizzo predefinito aggiornato',
              style: AppTypography.bodySmall.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMD),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e', style: AppTypography.bodySmall.copyWith(color: Colors.white)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMD),
          ),
        );
      }
    }
  }

  Future<void> _deleteAddress(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
        title: Text('Elimina Indirizzo', style: AppTypography.titleMedium),
        content: Text('Sei sicuro di voler eliminare questo indirizzo?', style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annulla', style: AppTypography.buttonSmall.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Elimina', style: AppTypography.buttonSmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(userAddressesProvider.notifier).deleteAddress(address.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Indirizzo eliminato', style: AppTypography.bodySmall.copyWith(color: Colors.white)),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMD),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore: $e', style: AppTypography.bodySmall.copyWith(color: Colors.white)),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMD),
            ),
          );
        }
      }
    }
  }
}
