import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/promotional_banner_model.dart';
import '../../../core/models/banner_text_overlay.dart';
import '../../../core/widgets/cached_network_image.dart';
import 'banner_action_handler.dart';

/// Individual banner card with image, optional overlay, and sponsor badge
class BannerCard extends ConsumerWidget {
  final PromotionalBannerModel banner;
  final VoidCallback onTap;

  const BannerCard({super.key, required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textOverlay = BannerTextOverlay.fromJson(banner.textOverlay);
    // Use database title/description if text overlay doesn't have content
    final showDefaultOverlay =
        !textOverlay.hasContent &&
        (banner.titolo.isNotEmpty || banner.descrizione != null);

    return InkWell(
      onTap: () {
        onTap();
        BannerActionHandler.handle(context, banner, ref: ref);
      },
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              CachedNetworkImageWidget(
                imageUrl: banner.immagineUrl,
                fit: BoxFit.cover,
                placeholder: _buildPlaceholder(),
                errorWidget: _buildErrorWidget(),
              ),

              // Text Overlay (custom or default from banner)
              if (textOverlay.hasContent)
                _buildTextOverlay(context, textOverlay)
              else if (showDefaultOverlay)
                _buildDefaultOverlay(context),

              // Sponsor Badge (if sponsored)
              if (banner.isSponsorizzato) _buildSponsorBadge(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextOverlay(BuildContext context, BannerTextOverlay overlay) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: overlay.overlayGradient,
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 6), // Push content 60% down
          if (overlay.title != null)
            Text(
              overlay.title!,
              style: AppTypography.titleLarge.copyWith(
                color: overlay.textColor,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (overlay.subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              overlay.subtitle!,
              style: AppTypography.bodyMedium.copyWith(
                color: overlay.textColor.withValues(alpha: 0.9),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (overlay.ctaText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                overlay.ctaText!,
                style: AppTypography.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const Spacer(flex: 4), // Balance spacing
        ],
      ),
    );
  }

  Widget _buildDefaultOverlay(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.black.withValues(alpha: 0.3),
            Colors.transparent,
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 6), // Push content 60% down
          Text(
            banner.titolo,
            style: AppTypography.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (banner.descrizione != null && banner.descrizione!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              banner.descrizione!,
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.95),
                shadows: [
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Spacer(flex: 4), // Balance spacing
        ],
      ),
    );
  }

  Widget _buildSponsorBadge(BuildContext context) {
    return Positioned(
      top: AppSpacing.sm,
      right: AppSpacing.sm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              banner.sponsorNome ?? 'Sponsorizzato',
              style: AppTypography.captionSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary.withValues(alpha: 0.5),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: AppColors.textDisabled,
          size: 48,
        ),
      ),
    );
  }
}
