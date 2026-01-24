import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/models/menu_item_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/widgets/cached_network_image.dart';

class CashierProductCard extends StatefulWidget {
  final MenuItemModel item;
  final String? categoryName;
  final VoidCallback onTap;
  final bool isListView;
  final bool isGoldenHighlight;

  final VoidCallback? onQuickAdd;

  const CashierProductCard({
    super.key,
    required this.item,
    this.categoryName,
    required this.onTap,
    this.onQuickAdd,
    this.isListView = false,
    this.isGoldenHighlight = false,
  });

  @override
  State<CashierProductCard> createState() => _CashierProductCardState();
}

class _CashierProductCardState extends State<CashierProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _showSuccessIndicator = false;
  Timer? _indicatorTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _indicatorTimer?.cancel();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  void _handleQuickAdd() {
    if (widget.onQuickAdd != null) {
      widget.onQuickAdd!();
      _showSuccess();
    }
  }

  void _showSuccess() {
    setState(() {
      _showSuccessIndicator = true;
    });

    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showSuccessIndicator = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    // Determine color based on category for visual grouping
    final categoryColor = _getCategoryColor(item.categoriaId);
    final displayCategoryName =
        widget.categoryName ?? _getShortCategoryName(item.categoriaId);

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          widget.isListView
              ? _buildListLayout(item, categoryColor, displayCategoryName)
              : _buildGridLayout(item, categoryColor, displayCategoryName),

          // Golden star badge
          if (widget.isGoldenHighlight)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.goldGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),

          // Success Overlay
          if (_showSuccessIndicator)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: AppColors.success,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aggiunto!',
                        style: AppTypography.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) =>
          Transform.scale(scale: _scaleAnimation.value, child: child),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onLongPress: _handleQuickAdd,
        onSecondaryTap: _handleQuickAdd,
        child: cardContent,
      ),
    );
  }

  Widget _buildListLayout(
    MenuItemModel item,
    Color categoryColor,
    String displayCategoryName,
  ) {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          // Image Section (Left)
          Container(
            width: 100,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(15),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(15),
              ),
              child: item.immagineUrl != null && item.immagineUrl!.isNotEmpty
                  ? CachedNetworkImageWidget.pizzaCard(
                      imageUrl: item.immagineUrl!,
                      categoryId: item.categoriaId,
                    )
                  : Center(
                      child: Icon(
                        Icons.fastfood_rounded,
                        size: 32,
                        color: categoryColor.withValues(alpha: 0.5),
                      ),
                    ),
            ),
          ),

          // Content Section (Right)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.nome,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.hasSconto)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '-${item.percentualeSconto.toInt()}%',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Category
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          displayCategoryName,
                          style: AppTypography.captionSmall.copyWith(
                            color: categoryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      // Price and Add Button
                      Row(
                        children: [
                          Text(
                            Formatters.currency(item.prezzoEffettivo),
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridLayout(
    MenuItemModel item,
    Color categoryColor,
    String displayCategoryName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Image Section (Top 55%)
        Expanded(
          flex: 55,
          child: Stack(
            children: [
              // Image Container
              Container(
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child:
                      item.immagineUrl != null && item.immagineUrl!.isNotEmpty
                      ? CachedNetworkImageWidget.pizzaCard(
                          imageUrl: item.immagineUrl!,
                          categoryId: item.categoriaId,
                        )
                      : Center(
                          child: Icon(
                            Icons.fastfood_rounded,
                            size: 40,
                            color: categoryColor.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ),

              // Price Tag (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    Formatters.currency(item.prezzoEffettivo),
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              // Discount Badge (Top Left) if applicable - Hidden if Golden Highlight (Star shows there)
              if (item.hasSconto && !widget.isGoldenHighlight)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '-${item.percentualeSconto.toInt()}%',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Content Section (Bottom 45%)
        Expanded(
          flex: 45,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name - Big and Bold
                Text(
                  item.nome,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    fontSize: 15, // Slightly larger for readability
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                ),

                const Spacer(),

                // Bottom Row: Category indicator + Add button visual
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Category Dot
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: categoryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                displayCategoryName,
                                style: AppTypography.captionSmall.copyWith(
                                  color: categoryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Add Icon
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String? categoryId) {
    if (categoryId == null) return AppColors.primary;

    final id = categoryId.toLowerCase();
    if (id.contains('pizz')) {
      return const Color(0xFFFF6B6B);
    } // Red
    if (id.contains('fritt')) {
      return const Color(0xFFFFA726);
    } // Orange
    if (id.contains('bevand') || id.contains('drink')) {
      return const Color(0xFF42A5F5);
    } // Blue
    if (id.contains('dolc')) {
      return const Color(0xFFAB47BC);
    } // Purple
    if (id.contains('panin') || id.contains('burger')) {
      return const Color(0xFF8D6E63);
    } // Brown

    return AppColors.primary;
  }

  String _getShortCategoryName(String? categoryId) {
    if (categoryId == null) return 'Altro';
    // Capitalize first letter
    if (categoryId.isEmpty) return '';
    return categoryId[0].toUpperCase() + categoryId.substring(1).toLowerCase();
  }
}
