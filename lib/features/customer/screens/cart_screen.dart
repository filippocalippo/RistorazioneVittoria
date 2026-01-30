import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/pizzeria_settings_provider.dart';
import '../../../providers/menu_provider.dart';
import '../../../core/models/size_variant_model.dart';
import '../../../core/models/cart_item_model.dart';
import '../../../core/models/menu_item_size_assignment_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/enums.dart';
import '../../../core/utils/constants.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../features/auth/auth_utils.dart';
import '../../../core/widgets/cached_network_image.dart';
import '../../../core/widgets/error_boundary.dart';
import '../widgets/product_customization_modal.dart';
import '../widgets/dual_stack_split_modal.dart';
import '../../../providers/sizes_provider.dart';
import '../../../providers/ingredients_provider.dart';
import '../../../providers/product_sizes_provider.dart';
import '../../../providers/order_price_calculator_provider.dart';
import '../../../core/services/order_price_calculator.dart';
import '../../../core/models/ingredient_model.dart';

class CartScreenNew extends ConsumerWidget {
  const CartScreenNew({super.key});

  void _handleCheckout(BuildContext context, WidgetRef ref) {
    final user = ref.read(authProvider).value;
    if (user == null) {
      AuthUtils.showLoginBottomSheet(context);
    } else {
      _showOrderTypeSheet(context, ref);
    }
  }

  void _showOrderTypeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => const _OrderTypeBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);
    final subtotalAsync = ref.watch(cartSubtotalProvider);
    final isEmptyAsync = ref.watch(isCartEmptyProvider);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isMobile = AppBreakpoints.isMobile(context);
    final topPadding = isMobile
        ? kToolbarHeight + MediaQuery.of(context).padding.top + AppSpacing.sm
        : 0.0;

    return cartAsync.when(
      data: (cart) {
        final subtotal = subtotalAsync;
        final isEmpty = isEmptyAsync;

        if (isEmpty) {
          return ErrorBoundaryWithLogger(
            contextTag: 'CartScreenNew.Empty',
            child: Scaffold(
              backgroundColor: AppColors.background,
              body: Padding(
                padding: EdgeInsets.only(top: topPadding),
                child: _buildEmptyState(context),
              ),
            ),
          );
        }

        return ErrorBoundaryWithLogger(
          contextTag: 'CartScreenNew',
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: Column(
                children: [
                  Expanded(
                    child: isDesktop
                        ? _buildDesktopLayout(context, ref, cart, subtotal)
                        : _buildMobileLayout(context, ref, cart, subtotal),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('Errore nel caricamento del carrello'),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    List<CartItem> cart,
    double subtotal,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Il Tuo Carrello', style: AppTypography.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${cart.length} ${cart.length == 1 ? "prodotto" : "prodotti"}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _buildCartItems(context, ref, cart),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xxl),
        SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xxl,
              right: AppSpacing.xxl,
              bottom: AppSpacing.xxl,
            ),
            child: _buildDesktopSummaryCard(context, ref, subtotal, cart),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    List<CartItem> cart,
    double subtotal,
  ) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                _buildCartItems(context, ref, cart),
                const SizedBox(height: AppSpacing.xl),
                _buildAddMoreItemsButton(context),
                const SizedBox(height: 140),
              ],
            ),
          ),
        ),
        _buildBottomActionBar(context, ref, subtotal),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isSecondary = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: isSecondary
              ? AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)
              : AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDesktopSummaryCard(
    BuildContext context,
    WidgetRef ref,
    double subtotal,
    List<CartItem> cart,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        boxShadow: AppShadows.lg,
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: AppRadius.radiusMD,
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Riepilogo',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Divider(color: AppColors.borderLight),
          const SizedBox(height: AppSpacing.xl),
          _buildSummaryRow('Subtotale', Formatters.currency(subtotal)),
          const SizedBox(height: AppSpacing.xl),
          Divider(color: AppColors.borderLight),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Totale',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                Formatters.currency(subtotal),
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _handleCheckout(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ordina Ora',
                    style: AppTypography.buttonLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMoreItemsButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(RouteNames.menu), // Navigate to menu screen
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.5),
              width: 2,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                size: 24,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Aggiungi più prodotti',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 400,
              height: 350,
              child: Image.asset(
                'assets/icons/illlustrations/Cart_empty_state.jpeg',
                fit: BoxFit.cover,
              ),
            ).animate().fadeIn(duration: 600.ms),
            const SizedBox(height: AppSpacing.xxxl),
            Text(
              'Il carrello è vuoto',
              style: AppTypography.headlineMedium,
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: AppSpacing.xxxl),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.massive,
                  vertical: AppSpacing.lg,
                ),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
                elevation: 0,
              ),
              child: Text(
                'Vai al Menu',
                style: AppTypography.buttonLarge.copyWith(color: Colors.white),
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItems(
    BuildContext context,
    WidgetRef ref,
    List<CartItem> cart,
  ) {
    return Column(
      children: cart.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _CartItemCardNew(item: item, index: index)
              .animate(delay: (index * 50).ms)
              .fadeIn()
              .slideX(begin: 0.05, end: 0),
        );
      }).toList(),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    WidgetRef ref,
    double subtotal,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xxl),
          topRight: Radius.circular(AppRadius.xxl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTALE',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.currency(subtotal),
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => _handleCheckout(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ordina',
                    style: AppTypography.buttonLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Order Type Bottom Sheet
class _OrderTypeBottomSheet extends ConsumerStatefulWidget {
  const _OrderTypeBottomSheet();

  @override
  ConsumerState<_OrderTypeBottomSheet> createState() =>
      _OrderTypeBottomSheetState();
}

class _OrderTypeBottomSheetState extends ConsumerState<_OrderTypeBottomSheet> {
  OrderType _selectedType = OrderType.delivery;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(pizzeriaSettingsProvider).value;
    final orderManagement = settings?.orderManagement;
    final deliveryActive = orderManagement?.ordiniConsegnaAttivi ?? true;
    final takeAwayActive = orderManagement?.ordiniAsportoAttivi ?? true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.huge),
          topRight: Radius.circular(AppRadius.huge),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Come preferisci ricevere il tuo ordine?',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              if (deliveryActive)
                Expanded(
                  child: _buildOrderTypeOption(
                    type: OrderType.delivery,
                    icon: Icons.delivery_dining_rounded,
                    label: 'Consegna',
                    subtitle: '~35 min',
                    isSelected: _selectedType == OrderType.delivery,
                    onTap: () =>
                        setState(() => _selectedType = OrderType.delivery),
                  ),
                ),
              if (deliveryActive && takeAwayActive)
                const SizedBox(width: AppSpacing.md),
              if (takeAwayActive)
                Expanded(
                  child: _buildOrderTypeOption(
                    type: OrderType.takeaway,
                    icon: Icons.shopping_bag_rounded,
                    label: 'Asporto',
                    subtitle: '~15 min',
                    isSelected: _selectedType == OrderType.takeaway,
                    onTap: () =>
                        setState(() => _selectedType = OrderType.takeaway),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/checkout-time-selection', extra: _selectedType);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continua',
                    style: AppTypography.buttonLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeOption({
    required OrderType type,
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySubtle : AppColors.surfaceLight,
          borderRadius: AppRadius.radiusXXL,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? AppShadows.primaryShadow(alpha: 0.2)
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagonalSplitClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DiagonalDividerPainter extends CustomPainter {
  final Color color;
  final double width;

  _DiagonalDividerPainter({required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant _DiagonalDividerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.width != width;
  }
}

// Cart Item Card New
class _CartItemCardNew extends ConsumerStatefulWidget {
  final CartItem item;
  final int index;

  const _CartItemCardNew({required this.item, required this.index});

  @override
  ConsumerState<_CartItemCardNew> createState() => _CartItemCardNewState();
}

class _CartItemCardNewState extends ConsumerState<_CartItemCardNew> {
  bool _isExpanded = false;

  bool get _hasCustomizations =>
      widget.item.cartItem.addedIngredients.isNotEmpty ||
      widget.item.cartItem.removedIngredients.isNotEmpty ||
      (widget.item.cartItem.note != null &&
          widget.item.cartItem.note!.isNotEmpty);

  // Check if this is a split product
  bool get _isSplitProduct => widget.item.cartItem.nome.contains('(Diviso)');

  // Get split product images from specialOptions
  (String?, String?) get _splitProductImages {
    if (!_isSplitProduct) return (null, null);
    final options = widget.item.cartItem.specialOptions;
    String? firstImage;
    String? secondImage;
    for (var opt in options) {
      if (opt.id == 'split_first') {
        firstImage = opt.imageUrl;
      } else if (opt.id == 'split_second') {
        secondImage = opt.imageUrl;
      }
    }
    return (firstImage, secondImage);
  }

  // Get split product IDs from specialOptions
  (String?, String?) get _splitProductIds {
    if (!_isSplitProduct) return (null, null);
    final options = widget.item.cartItem.specialOptions;
    String? firstId;
    String? secondId;
    for (var opt in options) {
      if (opt.id == 'split_first') {
        firstId = opt.productId;
      } else if (opt.id == 'split_second') {
        secondId = opt.productId;
      }
    }
    return (firstId, secondId);
  }

  Widget _buildSplitImage() {
    final (firstImage, secondImage) = _splitProductImages;

    // Fallback: if no split images available (old cart items), show regular image with split indicator
    if (firstImage == null && secondImage == null) {
      return Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.surfaceLight,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Show first product's image as fallback
            if (widget.item.menuItem.immagineUrl != null)
              CachedNetworkImageWidget.pizzaCard(
                imageUrl: widget.item.menuItem.immagineUrl!,
                categoryId: widget.item.menuItem.categoriaId,
              )
            else
              Center(
                child: Icon(
                  Icons.local_pizza_rounded,
                  color: AppColors.primary.withValues(alpha: 0.5),
                  size: 40,
                ),
              ),
            // Split indicator overlay
            Positioned(
              left: 47,
              top: 0,
              child: Container(
                width: 2,
                height: 96,
                color: AppColors.surface.withValues(alpha: 0.8),
              ),
            ),
            // Split badge
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.call_split_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show full-size images, each cropped to show its half
    // Layered stack with diagonal clip
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surfaceLight,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: First Image (Full, behind) - Acts as Left side
          firstImage != null
              ? CachedNetworkImageWidget.pizzaCard(
                  imageUrl: firstImage,
                  categoryId: widget.item.menuItem.categoriaId,
                )
              : Center(
                  child: Icon(
                    Icons.local_pizza_rounded,
                    color: AppColors.primary.withValues(alpha: 0.3),
                    size: 40,
                  ),
                ),

          // Layer 2: Second Image (Clipped diagonally) - Acts as Right side
          ClipPath(
            clipper: _DiagonalSplitClipper(),
            child: Container(
              color: AppColors.surfaceLight, // Background for the second half
              child: secondImage != null
                  ? CachedNetworkImageWidget.pizzaCard(
                      imageUrl: secondImage,
                      categoryId: widget.item.menuItem.categoriaId,
                    )
                  : Center(
                      child: Icon(
                        Icons.local_pizza_rounded,
                        color: AppColors.primary.withValues(alpha: 0.3),
                        size: 40,
                      ),
                    ),
            ),
          ),

          // Layer 3: Diagonal Divider Line (White/Border color)
          CustomPaint(
            painter: _DiagonalDividerPainter(
              color: AppColors.surface,
              width: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  void _handleEditItem() async {
    if (_isSplitProduct) {
      // Edit split product using DualStackSplitModal
      final (firstId, secondId) = _splitProductIds;
      if (firstId == null || secondId == null) {
        // Fallback: can't edit without product IDs (old cart items before update)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossibile modificare questo prodotto. Rimuovilo e aggiungilo di nuovo.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      // Get menu items for both products
      final menuItemsAsync = ref.read(menuProvider);
      final menuItems = menuItemsAsync.valueOrNull;
      if (menuItems == null || menuItems.isEmpty) {
        // Menu not loaded yet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Caricamento menu in corso...'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      final firstProduct = menuItems.where((m) => m.id == firstId).firstOrNull;
      final secondProduct = menuItems
          .where((m) => m.id == secondId)
          .firstOrNull;

      if (firstProduct == null || secondProduct == null) {
        // Products not found (might have been removed from menu)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prodotto non più disponibile nel menu'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Helper function to safely extract base name
      String stripSuffix(String text, String suffix) {
        if (text.endsWith(suffix)) {
          return text.substring(0, text.length - suffix.length);
        }
        return text;
      }

      final p1Suffix = ': ${firstProduct.nome}';
      final p2Suffix = ': ${secondProduct.nome}';
      // Check longer suffix first to avoid partial matches (e.g. "Pizza" vs "Super Pizza")
      final checkP2First = p2Suffix.length > p1Suffix.length;
      final isSameProduct = firstProduct.nome == secondProduct.nome;

      final firstAddedIngredients = <SelectedIngredient>[];
      final secondAddedIngredients = <SelectedIngredient>[];

      // Distribute Added Ingredients
      for (final ing in widget.item.cartItem.addedIngredients) {
        final name = ing.ingredientName;
        bool added = false;

        // Block to process P2
        void tryAddP2() {
          if (!added && name.endsWith(p2Suffix)) {
            secondAddedIngredients.add(
              SelectedIngredient(
                ingredientId: ing.ingredientId,
                ingredientName: stripSuffix(name, p2Suffix),
                unitPrice: ing.unitPrice * 2, // Un-halve the price
                quantity: ing.quantity,
              ),
            );
            added = true;
          }
        }

        // Block to process P1
        void tryAddP1() {
          if (!added && name.endsWith(p1Suffix)) {
            firstAddedIngredients.add(
              SelectedIngredient(
                ingredientId: ing.ingredientId,
                ingredientName: stripSuffix(name, p1Suffix),
                unitPrice: ing.unitPrice * 2, // Un-halve the price
                quantity: ing.quantity,
              ),
            );
            added = true;
          }
        }

        if (isSameProduct) {
          // If products are identical, assign all to P1 to avoid duplication.
          // User can re-distribute in the modal if needed.
          tryAddP1();
        } else {
          if (checkP2First) {
            tryAddP2();
            tryAddP1();
          } else {
            tryAddP1();
            tryAddP2();
          }
        }
      }

      // Distribute Removed Ingredients
      final firstRemovedIngredients = <IngredientModel>[];
      final secondRemovedIngredients = <IngredientModel>[];

      for (final ing in widget.item.cartItem.removedIngredients) {
        final name = ing.nome;
        bool added = false;

        void tryAddP2() {
          if (!added && name.endsWith(p2Suffix)) {
            secondRemovedIngredients.add(
              ing.copyWith(nome: stripSuffix(name, p2Suffix)),
            );
            added = true;
          }
        }

        void tryAddP1() {
          if (!added && name.endsWith(p1Suffix)) {
            firstRemovedIngredients.add(
              ing.copyWith(nome: stripSuffix(name, p1Suffix)),
            );
            added = true;
          }
        }

        if (isSameProduct) {
          tryAddP1();
        } else {
          if (checkP2First) {
            tryAddP2();
            tryAddP1();
          } else {
            tryAddP1();
            tryAddP2();
          }
        }
      }

      if (!mounted) return;

      // Get the correct size assignment for the modal
      MenuItemSizeAssignmentModel? initialSizeAssignment;
      try {
        final sizeAssignments = await ref.read(
          productSizesProvider(firstProduct.id).future,
        );
        final currentSizeId = widget.item.cartItem.selectedSize?.id;
        initialSizeAssignment = sizeAssignments
            .where((s) => s.sizeId == currentSizeId)
            .firstOrNull;
      } catch (e) {
        debugPrint('Error loading size assignment for split edit: $e');
      }

      if (!mounted) return;

      await DualStackSplitModal.showForEdit(
        context,
        ref,
        firstProduct: firstProduct,
        secondProduct: secondProduct,
        editIndex: widget.index,
        initialSize: initialSizeAssignment,
        firstAddedIngredients: firstAddedIngredients.isNotEmpty
            ? firstAddedIngredients
            : null,
        firstRemovedIngredients: firstRemovedIngredients.isNotEmpty
            ? firstRemovedIngredients
            : null,
        secondAddedIngredients: secondAddedIngredients.isNotEmpty
            ? secondAddedIngredients
            : null,
        secondRemovedIngredients: secondRemovedIngredients.isNotEmpty
            ? secondRemovedIngredients
            : null,
        initialNote: widget.item.cartItem.note,
      );

      if (mounted) _validateAndCorrectPrices();
    } else {
      // Edit regular product using ProductCustomizationModal
      await ProductCustomizationModal.showForEdit(
        context,
        widget.item.menuItem,
        editIndex: widget.index,
        initialQuantity: widget.item.quantity,
        initialSize: widget.item.cartItem.selectedSize,
        initialAddedIngredients:
            widget.item.cartItem.addedIngredients.isNotEmpty
            ? widget.item.cartItem.addedIngredients
            : null,
        initialRemovedIngredients:
            widget.item.cartItem.removedIngredients.isNotEmpty
            ? widget.item.cartItem.removedIngredients
            : null,
        initialNote: widget.item.cartItem.note,
      );

      if (mounted) _validateAndCorrectPrices();
    }
  }

  /// Validate and correct prices using the OrderPriceCalculator.
  /// Call this after items are added/modified to ensure UI shows correct prices.
  Future<void> _validateAndCorrectPrices() async {
    try {
      // Load all required data
      final menuItems = await ref.read(menuProvider.future);
      final sizes = await ref.read(sizesProvider.future);
      final ingredients = await ref.read(ingredientsProvider.future);
      final sizeAssignments = await ref.read(allSizeAssignmentsProvider.future);
      final settings = ref.read(pizzeriaSettingsProvider).valueOrNull;

      // Create delivery config if available
      DeliveryFeeConfig? deliveryConfig;
      if (settings != null) {
        final dc = settings.deliveryConfiguration;
        final pizzeria = settings.pizzeria;
        deliveryConfig = DeliveryFeeConfig(
          costoConsegnaBase: dc.costoConsegnaBase,
          consegnaGratuitaSopra: dc.consegnaGratuitaSopra,
          tipoCalcoloConsegna: dc.tipoCalcoloConsegna,
          radialTiers: dc.costoConsegnaRadiale
              .map((m) => RadialDeliveryTier.fromJson(m))
              .toList(),
          prezzoFuoriRaggio: dc.prezzoFuoriRaggio,
          shopLatitude: pizzeria.latitude,
          shopLongitude: pizzeria.longitude,
        );
      }

      // Create calculator and validate
      final calculator = OrderPriceCalculator(
        menuItems: menuItems,
        sizeAssignments: sizeAssignments,
        sizes: sizes,
        ingredients: ingredients,
        deliveryConfig: deliveryConfig,
      );

      // Run validation - this will log and correct any discrepancies
      final correctedCount = await ref
          .read(cartProvider.notifier)
          .validateAndCorrectPrices(calculator);

      if (correctedCount > 0 && mounted) {
        // Force UI refresh to show corrected prices
        setState(() {});
      }
    } catch (e) {
      debugPrint('[PriceValidator] Error during validation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.sm,
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image - 96x96 rounded-2xl like reference
                // For split products, show half/half image
                _isSplitProduct
                    ? _buildSplitImage()
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 96,
                          height: 96,
                          color: AppColors.surfaceLight,
                          child:
                              widget.item.menuItem.immagineUrl != null &&
                                  widget.item.menuItem.immagineUrl!.isNotEmpty
                              ? CachedNetworkImageWidget.pizzaCard(
                                  imageUrl: widget.item.menuItem.immagineUrl!,
                                  categoryId: widget.item.menuItem.categoriaId,
                                )
                              : Icon(
                                  Icons.local_pizza_rounded,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                  size: 40,
                                ),
                        ),
                      ),
                const SizedBox(width: AppSpacing.md),
                // Content
                Expanded(
                  child: SizedBox(
                    height: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top: Title and subtitle with edit button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.item.menuItem.nome,
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                      fontSize: 17,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget
                                            .item
                                            .cartItem
                                            .selectedSize
                                            ?.displayName ??
                                        'Standard',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textTertiary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Edit button - show for all products including splits
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _handleEditItem,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Bottom: Price and quantity controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              Formatters.currency(widget.item.subtotal),
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 17,
                              ),
                            ),
                            _buildQuantityControls(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_hasCustomizations) _buildCustomizationsSection(),
        ],
      ),
    );
  }

  Widget _buildQuantityControls() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus button - white bg
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ref
                    .read(cartProvider.notifier)
                    .updateQuantityAtIndex(
                      widget.index,
                      widget.item.quantity - 1,
                    );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AppShadows.xs,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.remove,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            alignment: Alignment.center,
            child: Text(
              '${widget.item.quantity}',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Plus button - brand color bg
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ref
                    .read(cartProvider.notifier)
                    .updateQuantityAtIndex(
                      widget.index,
                      widget.item.quantity + 1,
                    );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AppShadows.xs,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add, size: 14, color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationsSection() {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Modifiche',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: AppAnimations.fast,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...widget.item.cartItem.addedIngredients.map((ing) {
                  final qty = ing.quantity > 1 ? ' x${ing.quantity}' : '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${ing.ingredientName}$qty',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (ing.unitPrice > 0)
                          Text(
                            '+ ${Formatters.currency(ing.unitPrice * ing.quantity)}',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                ...widget.item.cartItem.removedIngredients.map((ing) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 14,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Senza ${ing.nome}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textDisabled,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (widget.item.cartItem.note != null &&
                    widget.item.cartItem.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.item.cartItem.note!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: AppAnimations.medium,
        ),
      ],
    );
  }
}
