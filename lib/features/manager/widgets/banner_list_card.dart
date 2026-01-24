import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/promotional_banner_model.dart';
import '../../../core/widgets/cached_network_image.dart';

/// Card displaying banner info in management list
class BannerListCard extends StatelessWidget {
  final PromotionalBannerModel banner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onDuplicate;

  const BannerListCard({
    super.key,
    required this.banner,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = _isCurrentlyActive();
    final bool isScheduled = _isScheduledFuture();
    final bool isExpired = _isExpired();

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: SizedBox(
                      width: 120,
                      height: 70,
                      child: CachedNetworkImageWidget(
                        imageUrl: banner.immagineUrl,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: AppColors.surfaceLight,
                          child: const Center(
                            child: Icon(Icons.image_outlined, size: 32),
                          ),
                        ),
                        errorWidget: Container(
                          color: AppColors.surfaceLight,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined, size: 32),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                banner.titolo,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _buildStatusChip(isActive, isScheduled, isExpired),
                          ],
                        ),
                        if (banner.descrizione != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            banner.descrizione!,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        _buildMetadata(),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              
              // Actions and Analytics
              Row(
                children: [
                  // Analytics
                  _buildAnalyticsChip(
                    Icons.visibility_outlined,
                    banner.visualizzazioni.toString(),
                    'Visualizzazioni',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _buildAnalyticsChip(
                    Icons.touch_app_outlined,
                    banner.click.toString(),
                    'Click',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _buildAnalyticsChip(
                    Icons.percent,
                    _calculateCTR(),
                    'CTR',
                  ),
                  const Spacer(),
                  
                  // Action buttons
                  IconButton(
                    icon: Icon(
                      banner.attivo
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
                    onPressed: onToggleActive,
                    tooltip: banner.attivo ? 'Disattiva' : 'Attiva',
                    color: banner.attivo ? AppColors.warning : AppColors.success,
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_copy_outlined),
                    onPressed: onDuplicate,
                    tooltip: 'Duplica',
                    color: AppColors.textSecondary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                    tooltip: 'Modifica',
                    color: AppColors.primary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                    tooltip: 'Elimina',
                    color: AppColors.error,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive, bool isScheduled, bool isExpired) {
    Color color;
    String label;
    IconData icon;

    if (!banner.attivo) {
      color = AppColors.textDisabled;
      label = 'Inattivo';
      icon = Icons.pause_circle_outline;
    } else if (isExpired) {
      color = AppColors.error;
      label = 'Scaduto';
      icon = Icons.event_busy;
    } else if (isScheduled) {
      color = AppColors.warning;
      label = 'Programmato';
      icon = Icons.schedule;
    } else if (isActive) {
      color = AppColors.success;
      label = 'Attivo';
      icon = Icons.check_circle_outline;
    } else {
      color = AppColors.textDisabled;
      label = 'Inattivo';
      icon = Icons.pause_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.captionSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata() {
    final items = <String>[];

    // Action type
    items.add('Tipo: ${_getActionTypeLabel()}');

    // Priority
    items.add('Priorità: ${banner.priorita}');

    // Device targeting
    if (banner.mostraSoloMobile) {
      items.add('Solo Mobile');
    } else if (banner.mostraSoloDesktop) {
      items.add('Solo Desktop');
    }

    // Date range
    if (banner.dataInizio != null || banner.dataFine != null) {
      final formatter = DateFormat('dd/MM/yyyy');
      if (banner.dataInizio != null && banner.dataFine != null) {
        items.add(
          'Dal ${formatter.format(banner.dataInizio!)} al ${formatter.format(banner.dataFine!)}',
        );
      } else if (banner.dataInizio != null) {
        items.add('Da: ${formatter.format(banner.dataInizio!)}');
      } else if (banner.dataFine != null) {
        items.add('Fino: ${formatter.format(banner.dataFine!)}');
      }
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            item,
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnalyticsChip(IconData icon, String value, String label) {
    return Tooltip(
      message: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getActionTypeLabel() {
    final type = BannerActionType.fromString(banner.actionType);
    switch (type) {
      case BannerActionType.externalLink:
        return 'Link Esterno';
      case BannerActionType.internalRoute:
        return 'Navigazione App';
      case BannerActionType.product:
        return 'Prodotto';
      case BannerActionType.category:
        return 'Categoria';
      case BannerActionType.specialOffer:
        return 'Offerta Speciale';
      case BannerActionType.none:
        return 'Informativo';
    }
  }

  String _calculateCTR() {
    if (banner.visualizzazioni == 0) return '0%';
    final ctr = (banner.click / banner.visualizzazioni) * 100;
    return '${ctr.toStringAsFixed(1)}%';
  }

  bool _isCurrentlyActive() {
    if (!banner.attivo) return false;
    final now = DateTime.now();
    if (banner.dataInizio != null && banner.dataInizio!.isAfter(now)) {
      return false;
    }
    if (banner.dataFine != null && banner.dataFine!.isBefore(now)) {
      return false;
    }
    return true;
  }

  bool _isScheduledFuture() {
    if (!banner.attivo) return false;
    final now = DateTime.now();
    return banner.dataInizio != null && banner.dataInizio!.isAfter(now);
  }

  bool _isExpired() {
    if (!banner.attivo) return false;
    final now = DateTime.now();
    return banner.dataFine != null && banner.dataFine!.isBefore(now);
  }
}
