import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/menu_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/pizzeria_settings_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/enums.dart';
import '../../../core/utils/constants.dart';
import '../../../core/models/user_address_model.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/services/order_price_calculator.dart';
import '../../../core/services/stripe_service.dart';
import '../../../core/models/settings/pizzeria_settings_model.dart';
import '../../../core/widgets/error_boundary.dart';

class CheckoutScreenNew extends ConsumerStatefulWidget {
  final OrderType orderType;
  final DateTime selectedSlot;
  final UserAddressModel? selectedAddress;
  final DateTime selectedDate;

  const CheckoutScreenNew({
    super.key,
    required this.orderType,
    required this.selectedSlot,
    this.selectedAddress,
    required this.selectedDate,
  });

  @override
  ConsumerState<CheckoutScreenNew> createState() => _CheckoutScreenNewState();
}

class _CheckoutScreenNewState extends ConsumerState<CheckoutScreenNew> {
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _isProcessing = false;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _setDefaultPaymentMethod(),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _setDefaultPaymentMethod() {
    final settings = ref.read(pizzeriaSettingsProvider).value;
    final om = settings?.orderManagement;
    final acceptsCash = om?.accettaPagamentiContanti ?? true;
    final acceptsCard = om?.accettaPagamentiCarta ?? true;
    if (_paymentMethod == PaymentMethod.cash && !acceptsCash && acceptsCard) {
      setState(() => _paymentMethod = PaymentMethod.card);
    } else if (_paymentMethod == PaymentMethod.card &&
        !acceptsCard &&
        acceptsCash) {
      setState(() => _paymentMethod = PaymentMethod.cash);
    }
  }

  /// Create delivery config for calculator from settings
  DeliveryFeeConfig? _createDeliveryConfig(PizzeriaSettingsModel? settings) {
    if (settings == null) return null;
    final dc = settings.deliveryConfiguration;
    final pizzeria = settings.pizzeria;

    return DeliveryFeeConfig(
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

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final subtotalAsync = ref.watch(cartSubtotalProvider);
    final settingsAsync = ref.watch(pizzeriaSettingsProvider);
    final isMobile = AppBreakpoints.isMobile(context);
    final topPadding = isMobile
        ? kToolbarHeight + MediaQuery.of(context).padding.top + AppSpacing.sm
        : 0.0;

    return cartAsync.when(
      data: (cart) {
        final subtotal = subtotalAsync;

        // Calculate delivery fee using centralized calculator logic
        double deliveryCost = 0.0;
        if (widget.orderType == OrderType.delivery) {
          final deliveryFeeConfig = _createDeliveryConfig(settingsAsync.value);
          if (deliveryFeeConfig != null) {
            // Check free delivery first
            if (subtotal >= deliveryFeeConfig.consegnaGratuitaSopra) {
              deliveryCost = 0.0;
            } else {
              // Try radial calculation
              final radialFee = deliveryFeeConfig.calculateRadialFee(
                widget.selectedAddress?.latitude,
                widget.selectedAddress?.longitude,
              );

              if (radialFee != null) {
                deliveryCost = radialFee;
              } else {
                // Fallback to fixed fee
                deliveryCost = deliveryFeeConfig.costoConsegnaBase;
              }
            }
          } else {
            deliveryCost = AppConstants.defaultDeliveryCost;
          }
        }
        final total = subtotal + deliveryCost;

        // Minimum order validation
        final minimumOrder = settingsAsync.value?.orderManagement.ordineMinimo ?? 10.0;
        final isMinimumMet = subtotal >= minimumOrder;

        return ErrorBoundaryWithLogger(
          contextTag: 'CheckoutScreenNew',
          child: Scaffold(
            backgroundColor: AppColors.surface,
            body: Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDeliveryInfoCard(),
                          const SizedBox(height: AppSpacing.xxl),
                          _buildPaymentSection(),
                          const SizedBox(height: AppSpacing.xxl),
                          _buildOrderSummary(cart, subtotal, deliveryCost, total),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomBar(total, isMinimumMet, minimumOrder),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Text('Errore nel caricamento del carrello'),
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoCard() {
    const dayNames = [
      'Domenica',
      'Lunedì',
      'Martedì',
      'Mercoledì',
      'Giovedì',
      'Venerdì',
      'Sabato',
    ];
    final dayName = dayNames[widget.selectedDate.weekday % 7];
    final dateStr =
        '$dayName ${widget.selectedDate.day}/${widget.selectedDate.month}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.orderType == OrderType.delivery
                      ? Icons.location_on_rounded
                      : Icons.storefront_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.orderType == OrderType.delivery
                          ? 'CONSEGNA A'
                          : 'RITIRO PRESSO',
                      style: AppTypography.captionSmall.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.orderType == OrderType.delivery
                          ? (widget.selectedAddress?.etichetta ??
                                widget.selectedAddress?.indirizzo ??
                                'Indirizzo')
                          : 'Pizzeria Rotante',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.orderType == OrderType.delivery &&
                        widget.selectedAddress != null)
                      Text(
                        widget.selectedAddress!.fullAddress,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(Icons.check_circle_rounded, color: AppColors.success),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(height: 1, color: AppColors.borderLight),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: AppRadius.radiusMD,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayNames[widget.selectedDate.weekday % 7].substring(0, 3),
                      style: AppTypography.captionSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      '${widget.selectedDate.day}',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.time(widget.selectedSlot),
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: AppRadius.radiusMD,
                  ),
                  child: Text(
                    'MODIFICA',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    final settings = ref.watch(pizzeriaSettingsProvider).value;
    final om = settings?.orderManagement;
    final acceptsCash = om?.accettaPagamentiContanti ?? true;
    final acceptsCard = om?.accettaPagamentiCarta ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: AppRadius.radiusMD,
              ),
              child: Icon(
                Icons.payment_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Pagamento',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (acceptsCard)
          _buildPaymentOption(
            PaymentMethod.card,
            Icons.credit_card_rounded,
            'Carta di Credito',
            'Paga con carta',
          ),
        if (acceptsCash) ...[
          if (acceptsCard) const SizedBox(height: AppSpacing.sm),
          _buildPaymentOption(
            PaymentMethod.cash,
            Icons.payments_outlined,
            'Contanti',
            'Paga alla ${widget.orderType == OrderType.delivery ? "consegna" : "cassa"}',
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentOption(
    PaymentMethod method,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = _paymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = method),
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySubtle : AppColors.surface,
          borderRadius: AppRadius.radiusXL,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(
    List<CartItem> cart,
    double subtotal,
    double deliveryCost,
    double total,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primarySubtle.withValues(alpha: 0.5),
        borderRadius: AppRadius.radiusXXL,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RIEPILOGO ORDINE',
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...cart.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.radiusSM,
                    ),
                    child: Text(
                      '${item.quantity}x',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      item.menuItem.nome,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.currency(item.subtotal),
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashedLinePainter(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
            ),
          ),
          _buildSummaryRow('Subtotale', Formatters.currency(subtotal)),
          if (widget.orderType == OrderType.delivery) ...[
            const SizedBox(height: AppSpacing.xs),
            _buildSummaryRow(
              'Consegna',
              deliveryCost == 0
                  ? 'Gratuita'
                  : Formatters.currency(deliveryCost),
              highlight: deliveryCost == 0,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.radiusMD,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Totale',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  Formatters.currency(total),
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool highlight = false,
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
          style: AppTypography.bodyMedium.copyWith(
            color: highlight ? AppColors.success : AppColors.textPrimary,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(
    double total,
    bool isMinimumMet,
    double minimumOrder,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMinimumMet)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.error, size: 16),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Ordine minimo non raggiunto (${Formatters.currency(minimumOrder)})',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing || !isMinimumMet ? null : _completeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textPrimary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Conferma Ordine',
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
      ),
    );
  }

  Future<void> _completeOrder() async {
    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final cart = ref.read(cartProvider).value ?? [];
      final user = ref.read(authProvider).value;
      if (user == null) throw Exception('Utente non autenticato');

      final telefonoCliente = user.telefono?.trim() ?? '';
      if (telefonoCliente.isEmpty) {
        setState(() => _isProcessing = false);
        final phoneAdded = await _showPhoneNumberModal();
        if (phoneAdded != true) {
          return;
        }
        return _completeOrder();
      }

      if (cart.isEmpty) {
        throw Exception('Il carrello è vuoto');
      }

      final db = ref.read(databaseServiceProvider);
      final settingsAsync = ref.read(pizzeriaSettingsProvider);

      if (!mounted) return;

      // Calculate prices (same as build method)
      final subtotal = ref.read(cartSubtotalProvider);

      double deliveryCost = 0.0;
      if (widget.orderType == OrderType.delivery) {
        final deliveryFeeConfig = _createDeliveryConfig(settingsAsync.value);
        if (deliveryFeeConfig != null) {
          if (subtotal >= deliveryFeeConfig.consegnaGratuitaSopra) {
            deliveryCost = 0.0;
          } else {
            final radialFee = deliveryFeeConfig.calculateRadialFee(
              widget.selectedAddress?.latitude,
              widget.selectedAddress?.longitude,
            );
            if (radialFee != null) {
              deliveryCost = radialFee;
            } else {
              deliveryCost = deliveryFeeConfig.costoConsegnaBase;
            }
          }
        } else {
          deliveryCost = AppConstants.defaultDeliveryCost;
        }
      }
      final total = subtotal + deliveryCost;

      // 1. Prepare complete order items (same structure as cashier)
      final orderItems = cart.map((item) {
        // Build complete variants structure
        final variants = <String, dynamic>{};

        // Category
        if (item.menuItem.categoriaId != null) {
          variants['category'] = 'Menu';
        } else {
          variants['category'] = 'Altro';
        }

        // Size
        if (item.cartItem.selectedSize != null) {
          final size = item.cartItem.selectedSize!;
          variants['size'] = {
            'id': size.id,
            'name': size.nome,
            'priceMultiplier': size.priceMultiplier,
          };
        }

        // Added ingredients
        if (item.cartItem.addedIngredients.isNotEmpty) {
          variants['addedIngredients'] = item.cartItem.addedIngredients
              .map((ing) => {
                    'id': ing.ingredientId,
                    'name': ing.ingredientName,
                    'price': ing.unitPrice,
                    'quantity': ing.quantity,
                  })
              .toList();
        }

        // Removed ingredients
        if (item.cartItem.removedIngredients.isNotEmpty) {
          variants['removedIngredients'] = item.cartItem.removedIngredients
              .map((ing) => {'id': ing.id, 'name': ing.nome})
              .toList();
        }

        // Calculate item prices from CartItem
        // Use discounted price if available, otherwise regular price
        final basePrice = item.menuItem.prezzoScontato ?? item.menuItem.prezzo;
        double itemPrice = basePrice;

        // Apply size multiplier if selected
        if (item.cartItem.selectedSize != null) {
          itemPrice *= item.cartItem.selectedSize!.priceMultiplier;
        }

        // Add ingredient costs
        for (final ing in item.cartItem.addedIngredients) {
          itemPrice += ing.unitPrice * ing.quantity;
        }

        final itemSubtotal = itemPrice * item.quantity;

        // Return complete item matching database structure
        return {
          'menu_item_id': item.menuItem.id,
          'nome_prodotto': item.menuItem.nome,
          'quantita': item.quantity,
          'prezzo_unitario': itemPrice,
          'subtotale': itemSubtotal,
          'note': item.note,
          'varianti': variants,
        };
      }).toList();

      final orgId = await ref.read(currentOrganizationProvider.future);

      // 2. Call Place Order (with complete items and totals)
      final requestData = {
        'items': orderItems,
        'orderType': widget.orderType.dbValue,
        'paymentMethod': _paymentMethod.name,
        if (orgId != null) 'organizationId': orgId,
        'nomeCliente': '${user.nome ?? ''} ${user.cognome ?? ''}'.trim(),
        'telefonoCliente': telefonoCliente,
        'emailCliente': user.email,
        'indirizzoConsegna': widget.orderType == OrderType.delivery
            ? widget.selectedAddress?.indirizzo
            : null,
        'cittaConsegna': widget.orderType == OrderType.delivery
            ? widget.selectedAddress?.citta
            : null,
        'capConsegna': widget.orderType == OrderType.delivery
            ? widget.selectedAddress?.cap
            : null,
        'deliveryLatitude': widget.orderType == OrderType.delivery
            ? widget.selectedAddress?.latitude
            : null,
        'deliveryLongitude': widget.orderType == OrderType.delivery
            ? widget.selectedAddress?.longitude
            : null,
        'note': _noteController.text.isEmpty ? null : _noteController.text,
        'slotPrenotatoStart': widget.selectedSlot.toIso8601String(),
        'subtotale': subtotal,
        'costoConsegna': deliveryCost,
        'sconto': 0,
        'totale': total,
      };

      final response = await db.placeOrder(requestData: requestData);
      
      if (response['success'] != true) {
        throw Exception('Errore nella creazione dell\'ordine');
      }

      final orderId = response['orderId'] as String;

      // 3. Handle Card Payment
      if (_paymentMethod == PaymentMethod.card) {
        final clientSecret = response['clientSecret'] as String?;
        final paymentIntentId = response['paymentIntentId'] as String?;

        if (clientSecret == null || paymentIntentId == null) {
          throw Exception('Errore configurazione pagamento');
        }

        final success = await StripeService.presentPaymentSheet(
          clientSecret: clientSecret,
          customerEmail: user.email,
        );

        if (!success) {
          // Payment cancelled or failed
          setState(() => _isProcessing = false);
          return;
        }

        // Verify Payment Server-Side
        await db.verifyOrderPayment(
          orderId: orderId,
          paymentIntentId: paymentIntentId,
          organizationId: orgId,
        );
      }

      // 4. Post-Order Cleanup
      ref.read(cartProvider.notifier).clear();

      // Deduct inventory stock (Client-side logic removed to prevent double deduction)
      // Inventory is now handled server-side by the 'place-order' edge function.
      /* 
      try {
         await _deductInventoryForOrder(cart, ingredients);
      } catch (e) {
        debugPrint('Inventory deduction failed: $e');
      }
      */

      if (!mounted) return;
      await _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: AppColors.error),
      );
      setState(() => _isProcessing = false);
    }
  }


  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXXXL),
        child: Padding(
          padding: AppSpacing.paddingXXL,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Ordine Confermato!',
                style: AppTypography.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Il tuo ordine è stato inviato alla pizzeria',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(RouteNames.menu);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusXL,
                    ),
                  ),
                  child: Text(
                    'Torna al Menu',
                    style: AppTypography.buttonMedium.copyWith(
                      color: Colors.white,
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

  Future<bool?> _showPhoneNumberModal() async {
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isUpdating = false;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Numero di Telefono Richiesto',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Aggiungi il tuo numero per completare l\'ordine',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  inputFormatters: [MaskedInputFormatter('### ### ####')],
                  decoration: InputDecoration(
                    labelText: 'Numero di Telefono',
                    hintText: '333 123 4567',
                    filled: true,
                    fillColor: AppColors.surface,
                    prefixIcon: const Icon(Icons.phone),
                    prefix: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        '+39',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.radiusLG,
                    ),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Il numero di telefono è obbligatorio'
                      : null,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isUpdating
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.radiusXL,
                          ),
                        ),
                        child: Text(
                          'Annulla',
                          style: AppTypography.buttonMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isUpdating
                            ? null
                            : () async {
                                if (formKey.currentState!.validate()) {
                                  setModalState(() => isUpdating = true);
                                  try {
                                    final cleanedPhone = phoneController.text
                                        .trim()
                                        .replaceAll(RegExp(r'\s'), '');
                                    final phone = '+39$cleanedPhone';
                                    await ref
                                        .read(authProvider.notifier)
                                        .updateProfile({'telefono': phone});
                                    if (context.mounted) {
                                      Navigator.of(context).pop(true);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Numero di telefono aggiornato',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => isUpdating = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Errore: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.radiusXL,
                          ),
                        ),
                        child: isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Conferma',
                                style: AppTypography.buttonMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + 5, 0), paint);
      startX += 8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
