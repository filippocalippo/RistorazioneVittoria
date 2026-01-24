import 'package:flutter/material.dart';
import '../../core/models/menu_item_model.dart';
import '../../core/utils/formatters.dart';
import '../../DesignSystem/design_tokens.dart';
import 'cached_network_image.dart';

/// Shared pizza card component matching pizza_card.md design exactly
/// Can be used for both customer menu and manager menu management
///
/// For customer use: Pass onTap callback, shows default add button
/// For manager use: Pass custom actionArea widget with edit/delete buttons
class PizzaCard extends StatefulWidget {
  final MenuItemModel item;
  final VoidCallback onTap;

  /// Optional custom action area (for manager view with multiple buttons)
  /// If null, shows default add button (for customer view)
  final Widget? actionArea;

  /// Show manager badges (availability, featured status)
  final bool showManagerBadges;

  /// Whether the product is available (has active ingredients/sizes)
  /// When false, shows elegant red "Esaurito" overlay
  final bool isAvailable;

  const PizzaCard({
    super.key,
    required this.item,
    required this.onTap,
    this.actionArea,
    this.showManagerBadges = false,
    this.isAvailable = true,
  });

  @override
  State<PizzaCard> createState() => _PizzaCardState();
}

class _PizzaCardState extends State<PizzaCard> {
  bool _isPressed = false;

  void _handleTap() async {
    setState(() => _isPressed = true);
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) {
      setState(() => _isPressed = false);
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive sizing based on card width (matching pizza_card.md exactly)
        final cardWidth = constraints.maxWidth;
        final isSmallCard = cardWidth < 160;
        final isMediumCard = cardWidth >= 160 && cardWidth < 200;

        // Adaptive spacing and sizing (exact values from pizza_card.md)
        final imageMargin = isSmallCard ? 6.0 : (isMediumCard ? 8.0 : 10.0);
        final contentPadding = isSmallCard ? 8.0 : (isMediumCard ? 10.0 : 14.0);
        final borderRadius = isSmallCard ? 16.0 : (isMediumCard ? 20.0 : 24.0);
        final imageBorderRadius = isSmallCard
            ? 12.0
            : (isMediumCard ? 14.0 : 16.0);

        // Font sizes (exact values from pizza_card.md)
        final titleFontSize = isSmallCard ? 14.0 : (isMediumCard ? 16.0 : 18.0);
        final descriptionFontSize = isSmallCard
            ? 10.0
            : (isMediumCard ? 11.0 : 12.0);
        final priceFontSize = isSmallCard ? 16.0 : (isMediumCard ? 18.0 : 20.0);
        final tagFontSize = isSmallCard ? 8.0 : (isMediumCard ? 9.0 : 10.0);

        return GestureDetector(
          onTap: widget.isAvailable ? _handleTap : null,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image section with tag - Expanded to take available space
                    Expanded(
                      flex: 3, // Give more space to the image
                      child: Stack(
                        children: [
                          Container(
                            margin: EdgeInsets.all(imageMargin),
                            decoration: BoxDecoration(
                              color: _getImageColor(item.categoriaId),
                              borderRadius: BorderRadius.circular(
                                imageBorderRadius,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                imageBorderRadius,
                              ),
                              child: Stack(
                                children: [
                                  // Background color
                                  Container(
                                    color: _getImageColor(item.categoriaId),
                                  ),

                                  // Product image
                                  Positioned.fill(
                                    child:
                                        item.immagineUrl != null &&
                                            item.immagineUrl!.isNotEmpty
                                        ? CachedNetworkImageWidget.pizzaCard(
                                            imageUrl: item.immagineUrl!,
                                            categoryId: item.categoriaId,
                                          )
                                        : Container(
                                            color: _getImageColor(
                                              item.categoriaId,
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.local_pizza,
                                                size: isSmallCard
                                                    ? 40
                                                    : (isMediumCard ? 50 : 64),
                                                color: Colors.white.withValues(
                                                  alpha: 0.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),

                                  // Gradient overlay for better text readability
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.2),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Tag badges - Customer view: discount/featured, Manager view: status badges
                          if (widget.showManagerBadges)
                            // Manager badges (top-right corner)
                            Positioned(
                              top: imageMargin + 8,
                              right: imageMargin + 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (item.inEvidenza)
                                    _StatusBadge(
                                      label: isSmallCard
                                          ? 'Top'
                                          : 'In evidenza',
                                      icon: Icons.star_rounded,
                                      color: AppColors.accent,
                                      fontSize: tagFontSize,
                                      isSmall: isSmallCard,
                                    ),
                                  if (!item.disponibile) ...[
                                    if (item.inEvidenza)
                                      const SizedBox(height: 4),
                                    _StatusBadge(
                                      label: isSmallCard
                                          ? 'Off'
                                          : 'Non disponibile',
                                      icon: Icons.visibility_off_rounded,
                                      color: AppColors.error,
                                      fontSize: tagFontSize,
                                      isSmall: isSmallCard,
                                    ),
                                  ],
                                  if (item.hasSconto) ...[
                                    if (item.inEvidenza || !item.disponibile)
                                      const SizedBox(height: 4),
                                    _StatusBadge(
                                      label:
                                          '-${item.percentualeSconto.toInt()}%',
                                      icon: Icons.local_offer_rounded,
                                      color: AppColors.success,
                                      fontSize: tagFontSize,
                                      isSmall: isSmallCard,
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else
                          // Customer badges (top-left corner)
                          if (item.hasSconto)
                            Positioned(
                              top: imageMargin + 8,
                              left: imageMargin + 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallCard ? 6 : 8,
                                  vertical: isSmallCard ? 3 : 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(
                                    isSmallCard ? 8 : 12,
                                  ),
                                ),
                                child: Text(
                                  '-${item.percentualeSconto.toInt()}%',
                                  style: TextStyle(
                                    fontSize: tagFontSize,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            )
                          else if (item.inEvidenza)
                            Positioned(
                              top: imageMargin + 8,
                              left: imageMargin + 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallCard ? 6 : 8,
                                  vertical: isSmallCard ? 3 : 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(
                                    isSmallCard ? 8 : 12,
                                  ),
                                ),
                                child: Text(
                                  'TOP',
                                  style: TextStyle(
                                    fontSize: tagFontSize,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Content section (matching pizza_card.md)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: contentPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          Text(
                            item.nome,
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmallCard ? 2 : 4),

                          // Ingredients (shown instead of description)
                          if (item.ingredienti.isNotEmpty)
                            Text(
                              item.ingredienti.join(', '),
                              style: TextStyle(
                                fontSize:
                                    descriptionFontSize * 1.35, // ~35% larger
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                              maxLines:
                                  3, // give ~35% more space vs previous 2 lines
                              overflow: TextOverflow.ellipsis,
                            )
                          else if (item.descrizione != null &&
                              item.descrizione!.isNotEmpty)
                            Text(
                              item.descrizione!,
                              style: TextStyle(
                                fontSize: descriptionFontSize,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: isSmallCard ? 6 : 8),

                    // Price row
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: contentPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Price
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.hasSconto)
                                  Text(
                                    Formatters.currency(item.prezzo),
                                    style: TextStyle(
                                      fontSize: descriptionFontSize,
                                      color: AppColors.textTertiary,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  Formatters.currency(item.prezzoEffettivo),
                                  style: TextStyle(
                                    fontSize: priceFontSize,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Customer mode: show add button on same row as price
                          if (!widget.showManagerBadges) ...[
                            SizedBox(width: isSmallCard ? 4 : 8),
                            AnimatedScale(
                              scale: _isPressed ? 0.85 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeInOut,
                              child: Container(
                                padding: EdgeInsets.all(isSmallCard ? 8 : 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: AppColors.redGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    isSmallCard ? 10 : 14,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.error.withValues(
                                        alpha: _isPressed ? 0.2 : 0.4,
                                      ),
                                      blurRadius: _isPressed ? 4 : 8,
                                      offset: Offset(0, _isPressed ? 2 : 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: isSmallCard ? 18 : 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Manager mode: dedicated action buttons row
                    if (widget.showManagerBadges &&
                        widget.actionArea != null) ...[
                      SizedBox(height: isSmallCard ? 8 : 12),
                      Padding(
                        padding: EdgeInsets.only(
                          left: contentPadding,
                          right: contentPadding,
                          bottom: isSmallCard ? 8 : 10,
                        ),
                        child: widget.actionArea!,
                      ),
                    ] else if (!widget.showManagerBadges)
                      // Bottom padding for customer cards
                      SizedBox(height: isSmallCard ? 8 : 10),
                  ],
                ),
              ),
              // Esaurito overlay when product is unavailable
              if (!widget.isAvailable)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            color: AppColors.error,
                            size: isSmallCard ? 32 : 40,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallCard ? 12 : 16,
                              vertical: isSmallCard ? 6 : 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Esaurito',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: isSmallCard ? 12 : 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _getImageColor(String? categoryId) {
    // Return vibrant colors based on category (matching pizza_card.md)
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

/// Status badge for manager view
class _StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double fontSize;
  final bool isSmall;

  const _StatusBadge({
    required this.label,
    required this.icon,
    required this.color,
    required this.fontSize,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
