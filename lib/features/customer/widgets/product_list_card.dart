import 'package:flutter/material.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/widgets/cached_network_image.dart';

class ProductListCard extends StatefulWidget {
  final MenuItemModel item;
  final VoidCallback onTap;

  /// Whether the product is available (has active ingredients/sizes)
  /// When false, shows elegant red "Esaurito" overlay
  final bool isAvailable;

  const ProductListCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isAvailable = true,
  });

  @override
  State<ProductListCard> createState() => _ProductListCardState();
}

class _ProductListCardState extends State<ProductListCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${widget.item.nome}, ${Formatters.currency(widget.item.prezzoEffettivo)}',
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: widget.isAvailable
              ? (_) => _scaleController.forward()
              : null,
          onTapUp: widget.isAvailable
              ? (_) => _scaleController.reverse()
              : null,
          onTapCancel: widget.isAvailable
              ? () => _scaleController.reverse()
              : null,
          onTap: widget.isAvailable ? widget.onTap : null,
          child: Stack(
            children: [
              Container(
                constraints: const BoxConstraints(
                  minHeight: 120,
                ), // Flexible height with minimum
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border, width: 1),
                  boxShadow: AppShadows.sm,
                ),
                clipBehavior: Clip.antiAlias,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image Section (50%)
                      Expanded(
                        flex: 50,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Background color placeholder
                            Container(
                              color: _getImageColor(widget.item.categoriaId),
                            ),

                            // Image
                            if (widget.item.immagineUrl != null &&
                                widget.item.immagineUrl!.isNotEmpty)
                              CachedNetworkImageWidget.pizzaCard(
                                imageUrl: widget.item.immagineUrl!,
                                categoryId: widget.item.categoriaId,
                              )
                            else
                              Center(
                                child: Icon(
                                  Icons.local_pizza_rounded,
                                  size: 36,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),

                            // Badges (Top Left)
                            if (widget.item.inEvidenza || widget.item.hasSconto)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.item.inEvidenza)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'TOP',
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                                fontSize: 9,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                        ),
                                      ),
                                    if (widget.item.hasSconto)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.error,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '-${widget.item.percentualeSconto.toInt()}%',
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                                fontSize: 9,
                                                color: Colors.white,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Content Section (50%)
                      Expanded(
                        flex: 50,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Title and Description
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.item.nome,
                                      style: AppTypography.titleSmall.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      widget.item.ingredienti.isNotEmpty
                                          ? widget.item.ingredienti.join(', ')
                                          : (widget.item.descrizione ?? ''),
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: AppSpacing.sm),

                              // Price and Add Button
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Price
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.item.hasSconto)
                                        Text(
                                          Formatters.currency(
                                            widget.item.prezzo,
                                          ),
                                          style: AppTypography.captionSmall
                                              .copyWith(
                                                decoration:
                                                    TextDecoration.lineThrough,
                                                color: AppColors.textTertiary,
                                              ),
                                        ),
                                      Text(
                                        Formatters.currency(
                                          widget.item.prezzoEffettivo,
                                        ),
                                        style: AppTypography.titleSmall
                                            .copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                      ),
                                    ],
                                  ),

                                  // Add Button - Increased to 40x40 for better touch target
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: AppColors.redGradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.error.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Esaurito overlay when product is unavailable
              if (!widget.isAvailable)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      // Lighter overlay that "washes out" the product
                      color: AppColors.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ESAURITO',
                          style: AppTypography.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getImageColor(String? categoryId) {
    switch (categoryId?.toLowerCase()) {
      case 'pizze':
      case 'pizza':
        return const Color(0xFFFF6B6B); // Red
      case 'fritti':
        return const Color(0xFFFFA726); // Orange
      case 'bevande':
        return const Color(0xFF42A5F5); // Blue
      case 'dolci':
        return const Color(0xFFAB47BC); // Purple
      default:
        return AppColors.primary;
    }
  }
}
