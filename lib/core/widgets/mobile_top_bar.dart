import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../DesignSystem/design_tokens.dart';
import '../../core/providers/top_bar_scroll_provider.dart';
import '../../core/providers/global_search_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/menu_navigation_provider.dart';
import '../../providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../core/utils/constants.dart';

class MobileTopBar extends ConsumerStatefulWidget {
  const MobileTopBar({super.key});

  @override
  ConsumerState<MobileTopBar> createState() => _MobileTopBarState();
}

class _MobileTopBarState extends ConsumerState<MobileTopBar>
    with TickerProviderStateMixin {
  late AnimationController _menuController;
  late Animation<double> _menuAnimation;
  late AnimationController _cartBadgeController;
  late Animation<double> _cartBadgeAnimation;
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  int _previousCartCount = 0;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _menuAnimation = CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeInOut,
    );

    // Cart badge animation controller
    _cartBadgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _cartBadgeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
        ]).animate(
          CurvedAnimation(
            parent: _cartBadgeController,
            curve: Curves.easeInOut,
          ),
        );

    // Initialize search controller from current global search state
    final initialQuery = ref.read(globalSearchQueryProvider);
    _searchController = TextEditingController(text: initialQuery);
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _menuController.dispose();
    _cartBadgeController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _animateCartBadge(int newCount) {
    if (newCount > _previousCartCount && newCount > 0) {
      _cartBadgeController.forward(from: 0);
    }
    _previousCartCount = newCount;
  }

  @override
  Widget build(BuildContext context) {
    final scrollProgress = ref.watch(topBarScrollProvider);
    final cartCount = ref.watch(cartItemCountProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    String title = "PIZZERIA ROTANTE";
    if (currentPath == RouteNames.cart || currentPath == '/cart-new') {
      title = "CARRELLO";
    } else if (currentPath == RouteNames.checkout || currentPath == '/checkout-time-selection' || currentPath == '/checkout-new') {
      title = "CHECKOUT";
    }
    final isCheckoutFlow = currentPath == RouteNames.cart || currentPath == RouteNames.checkout || 
        currentPath == '/cart-new' || currentPath == '/checkout-time-selection' || currentPath == '/checkout-new';
    final hideCartActions = isCheckoutFlow;
    final isMenuScreen =
        currentPath == RouteNames.menu ||
        currentPath == '/'; // Assuming menu is home or /menu
    final isProductView = ref.watch(isMenuProductViewProvider);

    // Animate cart badge when count changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateCartBadge(cartCount);
    });

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 8 * scrollProgress,
              sigmaY: 8 * scrollProgress,
            ),
            child: Container(
              height: kToolbarHeight + MediaQuery.of(context).padding.top + 4,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85 * scrollProgress),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: scrollProgress > 0
                    ? Border(
                        bottom: BorderSide(
                          color: Colors.black.withValues(
                            alpha: 0.05 * scrollProgress,
                          ),
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  _AnimatedCircleButton(
                    icon: (isMenuScreen && isProductView) || isCheckoutFlow
                        ? Icons.arrow_back_rounded
                        : AnimatedIcons.menu_close,
                    isAnimated: !(isMenuScreen && isProductView) && !isCheckoutFlow,
                    progress: _menuAnimation,
                    semanticLabel: (isMenuScreen && isProductView)
                        ? 'Torna alle categorie'
                        : (currentPath == RouteNames.cart || currentPath == '/cart-new')
                            ? 'Torna al menu'
                            : isCheckoutFlow
                                ? 'Indietro'
                                : 'Apri menu navigazione',
                    onTap: () {
                      if (isMenuScreen && isProductView) {
                        ref.read(menuResetTriggerProvider.notifier).state++;
                      } else if (isCheckoutFlow) {
                        context.pop();
                      } else {
                        _menuController.forward();
                        _showNavigationMenu(context);
                      }
                    },
                    scrollProgress: scrollProgress,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: isMenuScreen
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: _buildSearchBar(scrollProgress, ref),
                          )
                        : Center(
                            child: Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (hideCartActions)
                    // Placeholder to keep title centered when cart button is hidden
                    const SizedBox(width: 44)
                  else
                    Semantics(
                      button: true,
                      label: cartCount > 0
                          ? 'Carrello, $cartCount articoli'
                          : 'Carrello vuoto',
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _AnimatedCircleButton(
                            icon: Icons.shopping_bag_outlined,
                            semanticLabel: '',
                            onTap: () => context.push(RouteNames.cart),
                            scrollProgress: scrollProgress,
                          ),
                          if (cartCount > 0)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: ScaleTransition(
                                scale: _cartBadgeAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.error.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Center(
                                    child: Text(
                                      cartCount > 99 ? '99+' : '$cartCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showNavigationMenu(BuildContext context) {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    final buttonRect = Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );

    final RelativeRect position = RelativeRect.fromLTRB(
      buttonRect.left,
      buttonRect.bottom + 10,
      buttonRect.right,
      buttonRect.bottom + 200,
    );

    final List<PopupMenuItem<String>> menuItems = [];
    
    // Always show Menu item
    menuItems.add(
      _buildMenuItem(
        value: RouteNames.menu,
        icon: Icons.restaurant_menu_rounded,
        label: 'Menu',
        isActive: currentPath == RouteNames.menu || currentPath == '/',
      ),
    );

    // Add authenticated-only items
    if (isAuthenticated) {
      menuItems.add(
        _buildMenuItem(
          value: RouteNames.currentOrder,
          icon: Icons.receipt_long_rounded,
          label: 'Ordini in corso',
          isActive: currentPath == RouteNames.currentOrder,
        ),
      );
      menuItems.add(
        _buildMenuItem(
          value: RouteNames.customerProfile,
          icon: Icons.person_rounded,
          label: 'Profilo',
          isActive: currentPath == RouteNames.customerProfile,
        ),
      );
    } else {
      // Add Login button for non-authenticated users
      menuItems.add(
        PopupMenuItem<String>(
          value: 'login',
          height: 48,
          child: Row(
            children: [
              const Icon(Icons.login_rounded, color: AppColors.textPrimary, size: 22),
              const SizedBox(width: 12),
              Text(
                'Login',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      elevation: 10,
      items: menuItems,
    ).then((value) {
      _menuController.reverse();
      if (value != null && context.mounted) {
        if (value == 'login') {
          // Show login bottom sheet
          LoginBottomSheet.show(context);
        } else {
          context.push(value);
        }
      }
    });
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required String label,
    bool isActive = false,
  }) {
    return PopupMenuItem(
      value: value,
      height: 48, // Increased touch target
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(
          children: [
            Icon(
              icon, 
              color: isActive ? AppColors.primary : AppColors.textPrimary, 
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: isActive ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(double scrollProgress, WidgetRef ref) {
    // Interpolate background opacity: 0.9 (not scrolled) -> 0.5 (scrolled)
    final bgOpacity = 0.9 - (0.4 * scrollProgress);

    return Semantics(
      textField: true,
      label: 'Cerca nel menu',
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: bgOpacity),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (context, value, child) {
            return TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (text) {
                ref.read(globalSearchQueryProvider.notifier).state = text;
              },
              onTapOutside: (event) {
                FocusScope.of(context).unfocus();
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Cerca pizze, ingredienti...",
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
                suffixIcon: value.text.isNotEmpty
                    ? AnimatedOpacity(
                        opacity: value.text.isNotEmpty ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(globalSearchQueryProvider.notifier).state =
                                '';
                            FocusScope.of(context).unfocus();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              cursorColor: AppColors.primary,
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedCircleButton extends StatefulWidget {
  final dynamic icon;
  final VoidCallback onTap;
  final double scrollProgress;
  final bool isAnimated;
  final Animation<double>? progress;
  final String? semanticLabel;

  const _AnimatedCircleButton({
    required this.icon,
    required this.onTap,
    required this.scrollProgress,
    this.isAnimated = false,
    this.progress,
    this.semanticLabel,
  });

  @override
  State<_AnimatedCircleButton> createState() => _AnimatedCircleButtonState();
}

class _AnimatedCircleButtonState extends State<_AnimatedCircleButton>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
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
    final bgOpacity = 0.9 - (0.4 * widget.scrollProgress);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel?.isEmpty ?? true,
      child: GestureDetector(
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) => _scaleController.reverse(),
        onTapCancel: () => _scaleController.reverse(),
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 44, // Increased touch target (iOS minimum)
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: bgOpacity),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.isAnimated
                ? AnimatedIcon(
                    icon: widget.icon as AnimatedIconData,
                    progress: widget.progress!,
                    size: 22,
                    color: AppColors.textPrimary,
                  )
                : Icon(
                    widget.icon as IconData,
                    size: 22,
                    color: AppColors.textPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}
