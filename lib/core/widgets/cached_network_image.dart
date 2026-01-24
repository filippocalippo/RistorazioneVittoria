import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../DesignSystem/design_tokens.dart';

/// A comprehensive cached network image widget that provides consistent
/// image loading, error handling, and placeholder styling across the app.
class CachedNetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Alignment alignment;
  final ImageRepeat repeat;
  final bool matchTextDirection;
  final FilterQuality filterQuality;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final String? cacheKey;
  final Map<String, String>? httpHeaders;

  const CachedNetworkImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.color,
    this.colorBlendMode,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.matchTextDirection = false,
    this.filterQuality = FilterQuality.medium,
    this.memCacheWidth,
    this.memCacheHeight,
    this.cacheKey,
    this.httpHeaders,
  });

  /// Creates a cached image with default app styling
  factory CachedNetworkImageWidget.app({
    Key? key,
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedNetworkImageWidget(
      key: key,
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder ?? _defaultPlaceholder(),
      errorWidget: errorWidget ?? _defaultErrorWidget(),
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
    );
  }

  /// Creates a cached image for pizza cards with specific styling
  factory CachedNetworkImageWidget.pizzaCard({
    Key? key,
    required String imageUrl,
    double? width,
    double? height,
    String? categoryId,
  }) {
    return CachedNetworkImageWidget(
      key: key,
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: _pizzaCardPlaceholder(categoryId),
      errorWidget: _pizzaCardErrorWidget(categoryId),
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
    );
  }

  /// Creates a cached image for logos with circular styling
  factory CachedNetworkImageWidget.logo({
    Key? key,
    required String imageUrl,
    double size = 48,
    BorderRadius? borderRadius,
  }) {
    return CachedNetworkImageWidget(
      key: key,
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: _logoPlaceholder(size, borderRadius),
      errorWidget: _logoPlaceholder(size, borderRadius),
      memCacheWidth: size.toInt(),
      memCacheHeight: size.toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorWidget ?? _defaultErrorWidget();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _defaultErrorWidget(),
      color: color,
      colorBlendMode: colorBlendMode,
      alignment: alignment,
      repeat: repeat,
      matchTextDirection: matchTextDirection,
      filterQuality: filterQuality,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      cacheKey: cacheKey,
      httpHeaders: httpHeaders,
      fadeInDuration: Duration.zero,
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  /// Default placeholder with app styling
  static Widget _defaultPlaceholder() {
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

  /// Default error widget with app styling
  static Widget _defaultErrorWidget() {
    return Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: AppColors.textDisabled,
          size: 32,
        ),
      ),
    );
  }

  /// Pizza card specific placeholder with category color
  static Widget _pizzaCardPlaceholder(String? categoryId) {
    return Container(
      color: _getCategoryColor(categoryId),
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.white.withValues(alpha: 0.5),
          strokeWidth: 2,
        ),
      ),
    );
  }

  /// Pizza card specific error widget with category color
  static Widget _pizzaCardErrorWidget(String? categoryId) {
    return Container(
      color: _getCategoryColor(categoryId),
      child: Center(
        child: Icon(
          Icons.local_pizza,
          color: Colors.white.withValues(alpha: 0.5),
          size: 64,
        ),
      ),
    );
  }

  /// Logo specific placeholder with local asset fallback
  static Widget _logoPlaceholder(double size, BorderRadius? borderRadius) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(size * 0.2),
      child: Image.asset(
        'assets/icons/LOGO.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // If asset fails to load, show gradient fallback
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.orangeGradient,
              ),
              borderRadius: borderRadius ?? BorderRadius.circular(size * 0.2),
              boxShadow: AppShadows.primaryShadow(alpha: 0.2),
            ),
            child: Icon(
              Icons.local_pizza,
              color: Colors.white,
              size: size * 0.58,
            ),
          );
        },
      ),
    );
  }

  /// Returns category-specific colors for pizza cards
  static Color _getCategoryColor(String? categoryId) {
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
