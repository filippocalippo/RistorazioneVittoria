import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../DesignSystem/design_tokens.dart';
import 'pizzeria_logo.dart';

/// Splash screen overlay that shows while critical app data loads
/// Displays the pizzeria logo with a loading indicator and smooth fade-out
class AppSplashOverlay extends ConsumerStatefulWidget {
  final bool isLoading;
  final Widget child;

  const AppSplashOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  ConsumerState<AppSplashOverlay> createState() => _AppSplashOverlayState();
}

class _AppSplashOverlayState extends ConsumerState<AppSplashOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    // Start with splash visible
    _fadeController.value = 1.0;
  }

  @override
  void didUpdateWidget(AppSplashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // When loading completes, trigger fade-out animation
    if (oldWidget.isLoading && !widget.isLoading) {
      _fadeController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showSplash = false;
          });
        }
      });
    } else if (!oldWidget.isLoading && widget.isLoading) {
      // If loading starts again, show splash
      setState(() {
        _showSplash = true;
      });
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        // Main app content
        widget.child,
        
        // Splash overlay with fade animation
        if (_showSplash)
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  color: AppColors.surface,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Pizzeria logo
                        PizzeriaLogo(
                          size: 120,
                          showGradient: true,
                        ),
                        
                        const SizedBox(height: AppSpacing.massive),
                        
                        // Loading indicator
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 3,
                          ),
                        ),
                        
                        const SizedBox(height: AppSpacing.lg),
                        
                        // Loading text
                        Text(
                          'Caricamento...',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
