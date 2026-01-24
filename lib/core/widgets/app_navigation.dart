import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../DesignSystem/design_tokens.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/menu_navigation_provider.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../features/auth/auth_utils.dart';
import 'pizzeria_logo.dart';

/// Modern responsive navigation bar for desktop
class DesktopNavBar extends ConsumerWidget {
  const DesktopNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.path;
    final user = ref.watch(authProvider).value;
    final cartCount = ref.watch(cartItemCountProvider);
    final hideCart = currentPath.startsWith(RouteNames.cart) ||
        currentPath.startsWith(RouteNames.checkout) ||
        currentPath.startsWith('/cart-new') ||
        currentPath.startsWith('/checkout-time-selection') ||
        currentPath.startsWith('/checkout-new');

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.sm,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppBreakpoints.responsive(
            context: context,
            mobile: AppSpacing.lg,
            tablet: AppSpacing.xxl,
            desktop: AppSpacing.massive,
          ),
        ),
        child: Row(
          children: [
            // Logo
            _buildLogo(context),
            const SizedBox(width: AppSpacing.massive),

            // Navigation items
            Expanded(
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.restaurant_menu_rounded,
                    label: 'Menu',
                    isActive: currentPath == RouteNames.menu,
                    onTap: () {
                      // Trigger menu reset to category grid
                      ref.read(menuResetTriggerProvider.notifier).state++;
                      context.go(RouteNames.menu);
                    },
                  ),
                  if (user != null) ...[
                    const SizedBox(width: AppSpacing.lg),
                    _NavItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'I miei ordini',
                      isActive: currentPath == RouteNames.currentOrder,
                      onTap: () => context.go(RouteNames.currentOrder),
                    ),
                  ],
                ],
              ),
            ),

            // Right side actions
            if (!hideCart) ...[
              _buildCartButton(context, ref, cartCount),
              const SizedBox(width: AppSpacing.lg),
            ],
            _buildUserMenu(context, user),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return const PizzeriaLogoWithName(logoSize: 48);
  }

  Widget _buildCartButton(BuildContext context, WidgetRef ref, int cartCount) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(RouteNames.cart),
        borderRadius: AppRadius.radiusCircular,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border, width: 1.5),
            borderRadius: AppRadius.radiusCircular,
          ),
          child: Row(
            children: [
              Badge(
                isLabelVisible: cartCount > 0,
                label: Text(cartCount.toString()),
                backgroundColor: AppColors.primary,
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Carrello', style: AppTypography.labelMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserMenu(BuildContext context, user) {
    // Show login button if user is not authenticated
    if (user == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => AuthUtils.showLoginBottomSheet(context),
          borderRadius: AppRadius.radiusCircular,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadius.radiusCircular,
            ),
            child: Text(
              'Accedi',
              style: AppTypography.labelMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    // Show user menu if authenticated
    return PopupMenuButton(
      offset: const Offset(0, 56),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: AppRadius.radiusCircular,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              child: Text(
                user.nome?.substring(0, 1).toUpperCase() ?? 'U',
                style: AppTypography.labelMedium.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(user.nome ?? 'Utente', style: AppTypography.labelMedium),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          onTap: () => context.go(RouteNames.customerProfile),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 20),
              const SizedBox(width: AppSpacing.md),
              Text('Profilo', style: AppTypography.bodyMedium),
            ],
          ),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.settings_outlined, size: 20),
              const SizedBox(width: AppSpacing.md),
              Text('Impostazioni', style: AppTypography.bodyMedium),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () {
            // TODO: Implement logout
          },
          child: Row(
            children: [
              const Icon(Icons.logout, size: 20, color: AppColors.error),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Esci',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: AppRadius.radiusLG,
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : _isHovered
                  ? AppColors.surfaceLight
                  : Colors.transparent,
              borderRadius: AppRadius.radiusLG,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: widget.isActive
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  widget.label,
                  style: AppTypography.labelMedium.copyWith(
                    color: widget.isActive
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating glassmorphism bottom navigation for mobile
class MobileBottomNav extends ConsumerStatefulWidget {
  const MobileBottomNav({super.key});

  @override
  ConsumerState<MobileBottomNav> createState() => _MobileBottomNavState();
}

class _MobileBottomNavState extends ConsumerState<MobileBottomNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _bubbleController;
  late Animation<double> _bubbleScale;
  late Animation<double> _bubbleOpacity;
  late Animation<Offset> _bubbleSlide;
  bool _showBubble = false;

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(
      duration: const Duration(milliseconds: 1040), // 30% slower
      vsync: this,
    );

    _bubbleScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.8,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_bubbleController);

    _bubbleOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_bubbleController);

    _bubbleSlide =
        Tween<Offset>(
          begin: const Offset(0, 0),
          end: const Offset(0, -1.5),
        ).animate(
          CurvedAnimation(parent: _bubbleController, curve: Curves.easeOut),
        );

    _bubbleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showBubble = false);
        _bubbleController.reset();
      }
    });
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    super.dispose();
  }

  void _triggerBubbleAnimation() {
    setState(() => _showBubble = true);
    // Delay animation start by 200ms
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _bubbleController.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartItemCountProvider);
    final cartSubtotal = ref.watch(cartSubtotalProvider);
    final isCartEmpty = ref.watch(isCartEmptyProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    final hideCart = currentPath.startsWith(RouteNames.cart) ||
        currentPath.startsWith(RouteNames.checkout) ||
        currentPath.startsWith('/cart-new') ||
        currentPath.startsWith('/checkout-time-selection') ||
        currentPath.startsWith('/checkout-new');

    // Track cart count changes to trigger animation
    ref.listen(cartItemCountProvider, (previous, next) {
      if (previous != null && next > previous) {
        _triggerBubbleAnimation();
      }
    });

    if (isCartEmpty || hideCart) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.md,
        ),
        child: Stack(
          clipBehavior: Clip.none, // Allow bubble to overflow
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.massive),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppRadius.massive),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _GlassCartSection(
                    itemCount: cartCount,
                    subtotal: cartSubtotal,
                  ),
                ),
              ),
            ),
            // +1 Bubble animation - positioned outside main container
            if (_showBubble)
              Positioned(
                bottom: 80, // Above the container
                left: 40,
                child: AnimatedBuilder(
                  animation: _bubbleController,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _bubbleSlide,
                      child: ScaleTransition(
                        scale: _bubbleScale,
                        child: Opacity(
                          opacity: _bubbleOpacity.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, // 50% smaller
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.error,
                                  AppColors.error.withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '+1',
                              style: AppTypography.labelMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11, // 50% smaller
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Glass cart section matching HTML design
class _GlassCartSection extends ConsumerWidget {
  final int itemCount;
  final double subtotal;

  const _GlassCartSection({required this.itemCount, required this.subtotal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(RouteNames.cart),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Shopping bag icon with badge + "Carrello" label
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.shopping_bag_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              itemCount.toString(),
                              style: AppTypography.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Carrello',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Right: Price button with red accent and arrow
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.massive),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Formatters.currency(subtotal),
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.error,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
