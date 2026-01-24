import 'package:flutter/material.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/category_model.dart';
import '../../../core/widgets/cached_network_image.dart';

/// Modern category card matching design concept
/// Features: Image background with overlay, icon badge, hover effects
class CategoryCard extends StatefulWidget {
  final CategoryModel category;
  final bool isDeactivated;
  final VoidCallback onTap;
  final int? itemCount;

  const CategoryCard({
    super.key,
    required this.category,
    required this.isDeactivated,
    required this.onTap,
    this.itemCount,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        widget.category.iconaUrl != null &&
        widget.category.iconaUrl!.isNotEmpty;

    return Semantics(
      button: true,
      label: widget.isDeactivated
          ? '${widget.category.nome}, non disponibile'
          : widget.itemCount != null
              ? '${widget.category.nome}, ${widget.itemCount} prodotti'
              : widget.category.nome,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.isDeactivated ? null : widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background Image or Color
                  if (hasImage)
                    CachedNetworkImageWidget(
                      imageUrl: widget.category.iconaUrl!,
                      fit: BoxFit.cover,
                      placeholder: Container(color: AppColors.surfaceLight),
                      errorWidget: Container(color: AppColors.surfaceLight),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),

                  // Dark overlay gradient (stronger at bottom for text readability)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.4),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // Deactivated overlay
                  if (widget.isDeactivated)
                    Container(color: Colors.black.withValues(alpha: 0.5)),

                  // Item count badge (top right)
                  if (widget.itemCount != null && widget.itemCount! > 0 && !widget.isDeactivated)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '${widget.itemCount}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),

                  // Category name (bottom left)
                  Positioned(
                    left: 14,
                    bottom: 14,
                    right: 14,
                    child: Text(
                      widget.category.nome,
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 6,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Deactivated label
                  if (widget.isDeactivated)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Non disponibile',
                          style: AppTypography.captionSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
