import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../DesignSystem/app_colors.dart';
import '../../../DesignSystem/app_typography.dart';
import '../../../DesignSystem/app_spacing.dart';

class WelcomePopup extends StatefulWidget {
  final String nome;
  final String cognome;

  const WelcomePopup({
    super.key,
    required this.nome,
    required this.cognome,
  });

  static Future<void> show(BuildContext context, String nome, String cognome) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => WelcomePopup(nome: nome, cognome: cognome),
    );
  }

  @override
  State<WelcomePopup> createState() => _WelcomePopupState();
}

class _WelcomePopupState extends State<WelcomePopup>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late AnimationController _floatController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // Main popup scale animation
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    // Shimmer effect animation (subtle)
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    // Floating animation for decorative icons
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    _floatAnimation = CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    );

    // Start animation
    _scaleController.forward();

    // Auto dismiss after 8.5 seconds
    Future.delayed(const Duration(milliseconds: 8500), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallMobile = screenWidth < 400;
    
    // Responsive sizing
    final maxWidth = isMobile ? screenWidth * 0.9 : 400.0;
    final cardPadding = isSmallMobile ? AppSpacing.xl : (isMobile ? AppSpacing.xxl : AppSpacing.xxxl);
    final titleFontSize = isSmallMobile ? 28.0 : (isMobile ? 34.0 : 42.0);
    final nameFontSize = isSmallMobile ? 20.0 : (isMobile ? 24.0 : 28.0);
    final iconScale = isSmallMobile ? 0.6 : (isMobile ? 0.75 : 1.0);
    
    return ScaleTransition(
      scale: _scaleAnimation,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Decorative floating icon - Top Right (Shield)
                if (!isSmallMobile)
                  _buildFloatingIcon(
                    icon: Icons.shield_outlined,
                    top: -24 * iconScale,
                    right: -40 * iconScale,
                    size: 80 * iconScale,
                    rotation: 0.2,
                    gradient: [
                      AppColors.champagne,
                      AppColors.beigeLight,
                    ],
                    withBorder: true,
                    zIndex: 0,
                  ),

                // Decorative floating icon - Bottom Right (Trending Up)
                if (!isSmallMobile)
                  _buildFloatingIcon(
                    icon: Icons.trending_up,
                    bottom: -40 * iconScale,
                    right: 16 * iconScale,
                    size: 112 * iconScale,
                    rotation: 0.1,
                    gradient: [
                      AppColors.primarySubtle,
                      AppColors.champagne,
                    ],
                    withBlur: false,
                    zIndex: 0,
                  ),

                // Decorative floating icon - Bottom Left (Lightbulb)
                if (!isSmallMobile)
                  _buildFloatingIcon(
                    icon: Icons.lightbulb_outline,
                    bottom: -64 * iconScale,
                    left: -24 * iconScale,
                    size: 64 * iconScale,
                    rotation: -0.2,
                    gradient: [
                      AppColors.champagne,
                      AppColors.beigeLight,
                    ],
                    withBorder: true,
                    zIndex: 0,
                  ),

                // Main light-themed card
                ClipRRect(
                  borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: EdgeInsets.all(cardPadding),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.surface.withValues(alpha: 0.95),
                            AppColors.beigeLight.withValues(alpha: 0.95),
                            AppColors.champagne.withValues(alpha: 0.9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                            spreadRadius: -5,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: isMobile ? AppSpacing.xs : AppSpacing.md),

                          // BENVENUTO text with shimmer
                          AnimatedBuilder(
                            animation: _shimmerController,
                            builder: (context, child) {
                              return ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.textPrimary,
                                      AppColors.textSecondary,
                                      AppColors.textPrimary,
                                    ],
                                    stops: [
                                      0.0,
                                      _shimmerController.value,
                                      1.0,
                                    ],
                                  ).createShader(bounds);
                                },
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'BENVENUTO',
                                    style: AppTypography.headlineLarge.copyWith(
                                      color: Colors.white,
                                      letterSpacing: isSmallMobile ? 2.0 : (isMobile ? 3.0 : 4.0),
                                      fontWeight: FontWeight.w900,
                                      fontSize: titleFontSize,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xxl),

                          // User name with enhanced styling
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallMobile ? AppSpacing.md : (isMobile ? AppSpacing.lg : AppSpacing.xl),
                              vertical: isSmallMobile ? AppSpacing.sm : AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primaryLight.withValues(alpha: 0.15),
                                  AppColors.primary.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${widget.nome} ${widget.cognome}',
                                style: AppTypography.titleLarge.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: nameFontSize,
                                  letterSpacing: isSmallMobile ? 0.5 : 1.0,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ),

                          SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xxl),

                          SizedBox(height: isMobile ? 0 : AppSpacing.sm),
                        ],
                      ),
                    ),
                  ),
                ),

                // Decorative floating icon - Top Left (Premium Medal) - Rendered on top
                _buildFloatingIcon(
                  icon: Icons.workspace_premium,
                  top: -48 * iconScale,
                  left: -32 * iconScale,
                  size: 96 * iconScale,
                  rotation: -0.2,
                  gradient: [
                    AppColors.primaryLight,
                    AppColors.primary,
                  ],
                  zIndex: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingIcon({
    required IconData icon,
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required double rotation,
    required List<Color> gradient,
    bool withBorder = false,
    bool withBlur = false,
    required double zIndex,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value * 10 - 5),
            child: Transform.rotate(
              angle: rotation,
              child: Container(
                height: size,
                width: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  border: withBorder
                      ? Border.all(
                          color: AppColors.border.withValues(alpha: 0.4),
                          width: 1.5,
                        )
                      : null,
                  boxShadow: [
                    if (withBlur)
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                  ],
                ),
                child: withBlur
                    ? ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: _iconContent(icon, size),
                        ),
                      )
                    : _iconContent(icon, size),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _iconContent(IconData icon, double containerSize) {
    return Center(
      child: Icon(
        icon,
        size: containerSize * 0.5,
        color: icon == Icons.workspace_premium 
            ? AppColors.textPrimary.withValues(alpha: 0.9)
            : AppColors.textTertiary.withValues(alpha: 0.4),
      ),
    );
  }
}
