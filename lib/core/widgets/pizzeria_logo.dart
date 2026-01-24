import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../DesignSystem/design_tokens.dart';
import '../../providers/pizzeria_settings_provider.dart';
import '../services/app_cache_service.dart';
import 'cached_network_image.dart';

/// Reusable pizzeria logo widget that displays the logo from database
/// Falls back to a gradient icon if no logo is available
class PizzeriaLogo extends ConsumerWidget {
  final double size;
  final bool showGradient;
  final IconData fallbackIcon;
  final BorderRadius? borderRadius;

  const PizzeriaLogo({
    super.key,
    this.size = 48,
    this.showGradient = true,
    this.fallbackIcon = Icons.local_pizza,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pizzeriaState = ref.watch(pizzeriaSettingsProvider);

    return pizzeriaState.when(
      data: (settings) {
        final logoUrl = settings?.pizzeria.logoUrl;
        final hasLogo = logoUrl != null && logoUrl.isNotEmpty;

        if (hasLogo) {
          return ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.circular(size * 0.2),
            child: CachedNetworkImageWidget.logo(
              imageUrl: logoUrl,
              size: size,
              borderRadius: borderRadius ?? BorderRadius.circular(size * 0.2),
            ),
          );
        }

        return _buildFallback();
      },
      loading: () => _buildFallback(),
      error: (_, _) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(size * 0.2),
      child: Image.asset(
        'assets/icons/LOGO.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // If asset fails to load, show gradient fallback
          return _buildGradientFallback();
        },
      ),
    );
  }

  Widget _buildGradientFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: showGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.orangeGradient,
              )
            : null,
        color: showGradient ? null : AppColors.surfaceLight,
        borderRadius: borderRadius ?? BorderRadius.circular(size * 0.2),
        boxShadow: showGradient ? AppShadows.primaryShadow(alpha: 0.2) : null,
      ),
      child: Icon(
        fallbackIcon,
        color: showGradient ? Colors.white : AppColors.textTertiary,
        size: size * 0.58,
      ),
    );
  }
}

/// Logo with pizzeria name
/// Uses cached data during loading to prevent flashing
class PizzeriaLogoWithName extends ConsumerStatefulWidget {
  final double logoSize;
  final TextStyle? nameStyle;
  final bool showGradient;

  const PizzeriaLogoWithName({
    super.key,
    this.logoSize = 48,
    this.nameStyle,
    this.showGradient = true,
  });

  @override
  ConsumerState<PizzeriaLogoWithName> createState() => _PizzeriaLogoWithNameState();
}

class _PizzeriaLogoWithNameState extends ConsumerState<PizzeriaLogoWithName> {
  String? _cachedName;
  bool _cacheLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    final name = await AppCacheService.getCachedPizzeriaName();
    if (mounted) {
      setState(() {
        _cachedName = name;
        _cacheLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pizzeriaState = ref.watch(pizzeriaSettingsProvider);

    return pizzeriaState.when(
      data: (pizzeria) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PizzeriaLogo(size: widget.logoSize, showGradient: widget.showGradient),
            SizedBox(width: widget.logoSize * 0.25),
            Text(
              pizzeria?.pizzeria.nome ?? 'Rotante',
              style:
                  widget.nameStyle ??
                  AppTypography.titleLarge.copyWith(
                    fontWeight: AppTypography.black,
                    color: AppColors.primary,
                  ),
            ),
          ],
        );
      },
      loading: () {
        // Show cached name during loading if available, otherwise show default
        final displayName = _cacheLoaded && _cachedName != null ? _cachedName! : 'Rotante';
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PizzeriaLogo(size: widget.logoSize, showGradient: widget.showGradient),
            SizedBox(width: widget.logoSize * 0.25),
            Text(
              displayName,
              style:
                  widget.nameStyle ??
                  AppTypography.titleLarge.copyWith(
                    fontWeight: AppTypography.black,
                    color: AppColors.primary,
                  ),
            ),
          ],
        );
      },
      error: (_, _) {
        // Show cached name on error if available, otherwise show default
        final displayName = _cacheLoaded && _cachedName != null ? _cachedName! : 'Rotante';
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PizzeriaLogo(size: widget.logoSize, showGradient: widget.showGradient),
            SizedBox(width: widget.logoSize * 0.25),
            Text(
              displayName,
              style:
                  widget.nameStyle ??
                  AppTypography.titleLarge.copyWith(
                    fontWeight: AppTypography.black,
                    color: AppColors.primary,
                  ),
            ),
          ],
        );
      },
    );
  }
}
