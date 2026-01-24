import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/enums.dart';
import '../../../core/models/size_variant_model.dart';
import '../../../core/models/cashier_customer_model.dart';
import '../../../providers/cashier_order_provider.dart';
import '../../../providers/cashier_customer_provider.dart';
import '../../../providers/pizzeria_settings_provider.dart';
import '../../../providers/manager_orders_provider.dart';
import '../../../core/services/database_service.dart';
import '../../customer/widgets/product_customization_modal.dart';
import '../../customer/widgets/dual_stack_split_modal.dart';
import '../../../core/models/menu_item_size_assignment_model.dart';
import '../../../core/models/cart_item_model.dart';
import '../../../core/models/ingredient_model.dart';
import '../../../providers/product_sizes_provider.dart';
import '../../../core/models/order_model.dart';
import '../../../providers/delivery_zones_provider.dart';
import '../../../core/utils/geometry_utils.dart';
import 'package:latlong2/latlong.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/order_price_calculator_provider.dart';
import '../../../core/services/order_price_calculator.dart';
import '../../../core/services/order_price_models.dart';
import '../../../providers/menu_provider.dart';
import '../../../providers/sizes_provider.dart';
import '../../../providers/ingredients_provider.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/product_configuration_model.dart';
import '../../../core/providers/inventory_provider.dart';
import '../../../core/services/inventory_service.dart';

/// Helper function to get size display name
String _getSizeDisplayName(SizeVariantModel size) {
  if (size.descrizione != null && size.descrizione!.isNotEmpty) {
    return '${size.nome} (${size.descrizione})';
  }
  return size.nome;
}

/// Right panel showing current order composition
/// Includes item list, customer info, and checkout
class CashierOrderPanel extends ConsumerStatefulWidget {
  const CashierOrderPanel({super.key});

  /// Global key to access the panel state for hotkey support
  static final GlobalKey<CashierOrderPanelState> panelKey =
      GlobalKey<CashierOrderPanelState>();

  @override
  ConsumerState<CashierOrderPanel> createState() => CashierOrderPanelState();
}

class CashierOrderPanelState extends ConsumerState<CashierOrderPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  final _noteFocusNode = FocusNode();

  OrderType _orderType = OrderType.takeaway;
  bool _isProcessing = false;

  // Time slot selection
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedSlot;
  List<DateTime> _availableSlots = [];
  bool _isComputingSlots = false;
  Map<
    DateTime,
    ({
      int deliveryOrders,
      int deliveryItems,
      int takeawayOrders,
      int takeawayItems,
    })
  >
  _slotStats = {};

  // Customer suggestion state
  List<CashierCustomerModel> _customerSuggestions = [];
  bool _showSuggestions = false;
  bool _isLoadingSuggestions = false;
  Timer? _searchDebounce;
  CashierCustomerModel? _selectedCustomer;
  final LayerLink _nameFieldLayerLink = LayerLink();
  OverlayEntry? _suggestionsOverlay;

  // Public getters for focus nodes (for hotkey support from parent)
  FocusNode get nameFocusNode => _nameFocusNode;
  FocusNode get phoneFocusNode => _phoneFocusNode;
  FocusNode get addressFocusNode => _addressFocusNode;
  FocusNode get noteFocusNode => _noteFocusNode;

  /// Check if any text field in this panel has focus
  bool get hasAnyFieldFocused =>
      _nameFocusNode.hasFocus ||
      _phoneFocusNode.hasFocus ||
      _addressFocusNode.hasFocus ||
      _noteFocusNode.hasFocus;

  /// Check if name field has suggestions available
  bool get hasSuggestions => _customerSuggestions.isNotEmpty;

  /// Select the first customer suggestion (called by hotkey handler)
  void selectFirstSuggestion() {
    if (_customerSuggestions.isNotEmpty) {
      _selectCustomer(_customerSuggestions.first);
    }
  }

  /// Move focus to the next logical field
  void focusNextField() {
    if (_nameFocusNode.hasFocus) {
      _phoneFocusNode.requestFocus();
    } else if (_phoneFocusNode.hasFocus) {
      if (_orderType == OrderType.delivery) {
        _addressFocusNode.requestFocus();
      } else {
        _noteFocusNode.requestFocus();
      }
    } else if (_addressFocusNode.hasFocus) {
      _noteFocusNode.requestFocus();
    } else if (_noteFocusNode.hasFocus) {
      // Unfocus - end of the form
      _noteFocusNode.unfocus();
    }
  }

  /// Set the order type (for hotkey support)
  void setOrderType(OrderType type) {
    if (_orderType != type) {
      setState(() => _orderType = type);
      _saveFormData();
    }
  }

  @override
  void initState() {
    super.initState();
    // Add listeners to persist form data
    _nameController.addListener(_saveFormData);
    _phoneController.addListener(_saveFormData);
    _addressController.addListener(_saveFormData);
    _noteController.addListener(_saveFormData);
    _nameFocusNode.addListener(_handleNameFocusChange);

    // Compute initial slots after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final editMode = ref.read(cashierEditModeProvider);
      if (editMode != null) {
        _loadEditModeData();
      } else {
        // Restore form data from provider (if any)
        _restoreFormData();
        _computeAvailableSlots();
      }
    });
  }

  /// Restore form data from provider
  void _restoreFormData() {
    final formData = ref.read(cashierFormDataProvider);
    if (!formData.isEmpty ||
        formData.orderType != OrderType.takeaway ||
        formData.selectedSlot != null) {
      // Temporarily remove listeners to avoid re-saving while restoring
      _nameController.removeListener(_saveFormData);
      _phoneController.removeListener(_saveFormData);
      _addressController.removeListener(_saveFormData);
      _noteController.removeListener(_saveFormData);

      _nameController.text = formData.name;
      _phoneController.text = formData.phone;
      _addressController.text = formData.address;
      _noteController.text = formData.note;

      setState(() {
        _orderType = formData.orderType;
        if (formData.selectedDate != null) {
          _selectedDate = formData.selectedDate!;
        }
        _selectedSlot = formData.selectedSlot;
      });

      // Re-add listeners
      _nameController.addListener(_saveFormData);
      _phoneController.addListener(_saveFormData);
      _addressController.addListener(_saveFormData);
      _noteController.addListener(_saveFormData);
    }
  }

  /// Save form data to provider
  void _saveFormData() {
    if (!mounted) return;
    ref.read(cashierFormDataProvider.notifier).state = CashierFormData(
      name: _nameController.text,
      phone: _phoneController.text,
      address: _addressController.text,
      note: _noteController.text,
      orderType: _orderType,
      selectedDate: _selectedDate,
      selectedSlot: _selectedSlot,
    );
  }

  /// Pre-fill form fields when editing an existing order
  Future<void> _loadEditModeData() async {
    final editMode = ref.read(cashierEditModeProvider);
    if (editMode != null) {
      _nameController.text = editMode.customerName;
      _phoneController.text = editMode.customerPhone;
      if (editMode.customerAddress != null) {
        _addressController.text = editMode.customerAddress!;
      }
      if (editMode.note != null) {
        _noteController.text = editMode.note!;
      }

      setState(() {
        _orderType = editMode.orderType;
        if (editMode.slotPrenotatoStart != null) {
          _selectedDate = editMode.slotPrenotatoStart!;
        }
      });

      if (editMode.slotPrenotatoStart != null) {
        await _computeAvailableSlots(
          _selectedDate,
          editMode.slotPrenotatoStart,
        );
      } else {
        await _computeAvailableSlots(_selectedDate);
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _removeSuggestionsOverlay();
    // Remove listeners before disposing
    _nameController.removeListener(_saveFormData);
    _phoneController.removeListener(_saveFormData);
    _addressController.removeListener(_saveFormData);
    _noteController.removeListener(_saveFormData);
    _nameFocusNode.removeListener(_handleNameFocusChange);
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  /// Search for customers by name with debouncing
  void _searchCustomers(String query) {
    _searchDebounce?.cancel();

    if (query.trim().length < 2) {
      _removeSuggestionsOverlay();
      setState(() {
        _customerSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() => _isLoadingSuggestions = true);

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      try {
        final db = DatabaseService();
        final results = await db.searchCashierCustomers(query);

        if (!mounted) return;

        setState(() {
          _customerSuggestions = results;
          _showSuggestions = results.isNotEmpty;
          _isLoadingSuggestions = false;
        });

        if (results.isNotEmpty && _nameFocusNode.hasFocus) {
          _showSuggestionsOverlay();
        } else {
          _removeSuggestionsOverlay();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _customerSuggestions = [];
            _showSuggestions = false;
            _isLoadingSuggestions = false;
          });
          _removeSuggestionsOverlay();
        }
      }
    });
  }

  /// Show suggestions overlay
  void _showSuggestionsOverlay() {
    _removeSuggestionsOverlay();

    if (_customerSuggestions.isEmpty) return;

    _suggestionsOverlay = OverlayEntry(
      builder: (context) => _AnimatedSuggestionsOverlay(
        link: _nameFieldLayerLink,
        suggestions: _customerSuggestions,
        onSelect: _selectCustomer,
      ),
    );

    Overlay.of(context).insert(_suggestionsOverlay!);
  }


  /// Remove suggestions overlay
  void _removeSuggestionsOverlay() {
    _suggestionsOverlay?.remove();
    _suggestionsOverlay = null;
  }

  void _handleNameFocusChange() {
    // suggestions overlay removal is now handled by TapRegion in _AnimatedSuggestionsOverlay
  }



  /// Select a customer from suggestions
  void _selectCustomer(CashierCustomerModel customer) {
    _removeSuggestionsOverlay();

    setState(() {
      _selectedCustomer = customer;
      _customerSuggestions = [];
      _showSuggestions = false;
    });

    // Auto-fill the form fields
    _nameController.text = customer.nome;
    if (customer.telefono != null && customer.telefono!.isNotEmpty) {
      _phoneController.text = customer.telefono!;
    }
    if (customer.hasAddress) {
      _addressController.text = customer.indirizzo!;
    }

    // Move focus to next field
    FocusScope.of(context).nextFocus();
  }

  /// Clear selected customer when user manually edits fields
  void _clearSelectedCustomer() {
    if (_selectedCustomer != null) {
      setState(() => _selectedCustomer = null);
    }
  }

  /// Get available dates (today and next 6 days, plus selected date if in the past for editing)
  List<DateTime> get _availableDates {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day + i),
    );

    // Include the selected date if it's before today (for editing past orders)
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (selectedDateOnly.isBefore(today) && !dates.contains(selectedDateOnly)) {
      dates.insert(0, selectedDateOnly);
    }

    return dates;
  }

  /// Compute available time slots for the selected date
  Future<void> _computeAvailableSlots([
    DateTime? forDate,
    DateTime? targetSlot,
  ]) async {
    if (!mounted) return;
    setState(() => _isComputingSlots = true);

    final targetDate = forDate ?? _selectedDate;
    final settings = ref.read(pizzeriaSettingsProvider).value;

    if (settings == null) {
      if (mounted) {
        // Fallback if settings not loaded yet
        final allSlots = <DateTime>[];
        // Default to today 00:00 - 23:30 with 30m slots
        var cursor = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0);
        final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59);
        while (cursor.isBefore(endOfDay)) {
          allSlots.add(cursor);
          cursor = cursor.add(const Duration(minutes: 30));
        }
        
        setState(() {
          _availableSlots = allSlots;
          _selectedSlot = allSlots.isNotEmpty ? allSlots.first : null;
          _isComputingSlots = false;
        });
      }
      return;
    }

    final slotMinutes = settings.orderManagement.tempoSlotMinuti;
    // final prepMinutes = settings.orderManagement.tempoPreparazioneMedio;
    final now = DateTime.now();
    final effectiveSlotMinutes = slotMinutes > 0 ? slotMinutes : 30;

    final orari = settings.pizzeria.orari ?? {};
    final weekdayIndex = (targetDate.weekday % 7);
    const keys = [
      'domenica',
      'lunedi',
      'martedi',
      'mercoledi',
      'giovedi',
      'venerdi',
      'sabato',
    ];
    final dayKey = keys[weekdayIndex];
    final day = (orari[dayKey] as Map?) ?? {};
    // For cashier, we ignore the 'aperto' flag to allow orders anytime
    // final isOpen = (day['aperto'] as bool?) ?? false;

    // if (!isOpen) { ... } -> Removed constraint

    DateTime? parseTime(String? hhmm, DateTime date) {
      if (hhmm == null) return null;
      final parts = hhmm.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return DateTime(date.year, date.month, date.day, h, m);
    }

    var apertura =
        parseTime(day['apertura'] as String?, targetDate) ??
        DateTime(targetDate.year, targetDate.month, targetDate.day, 12, 0);
    var chiusura =
        parseTime(day['chiusura'] as String?, targetDate) ??
        DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 0);

    // If hours are invalid (e.g. closed crossing midnight not handled or just wrong), 
    // fallback to standard full day for cashier to ensure availability
    if (!chiusura.isAfter(apertura)) {
       apertura = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0);
       chiusura = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59);
    }

    // final isToday =
    //     targetDate.year == now.year &&
    //     targetDate.month == now.month &&
    //     targetDate.day == now.day;
        
    // For cashier, allow selecting any slot in the working day, even past ones
    // This allows logging past orders or forcing orders outside normal flow
    final earliest = apertura; 
    
    final start = earliest.isAfter(apertura) ? earliest : apertura;
    final roundedStart =
        DateTime(
          start.year,
          start.month,
          start.day,
          start.hour,
          start.minute - (start.minute % effectiveSlotMinutes),
        ).add(
          Duration(
            minutes: (start.minute % effectiveSlotMinutes) == 0
                ? 0
                : effectiveSlotMinutes,
          ),
        );

    final allSlots = <DateTime>[];
    var cursor = roundedStart;
    
    // Safety check: ensure we generate at least one slot if logic fails or hours are weird
    if (!cursor.isBefore(chiusura)) {
       // Reset to full day logic as final fallback
       cursor = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0);
       chiusura = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59);
    }

    while (cursor.isBefore(chiusura)) {
      allSlots.add(cursor);
      cursor = cursor.add(Duration(minutes: effectiveSlotMinutes));
    }
    
    // Absolute guarantee: if still empty, force full day slots
    if (allSlots.isEmpty) {
        cursor = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0);
        final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59);
        while (cursor.isBefore(endOfDay)) {
          allSlots.add(cursor);
          cursor = cursor.add(const Duration(minutes: 30));
        }
    }

    if (mounted) {
      setState(() {
        _availableSlots = allSlots;

        if (targetSlot != null) {
          _selectedSlot = targetSlot;
          // Ensure targetSlot is in _availableSlots
          if (!_availableSlots.any((s) => s.isAtSameMomentAs(targetSlot))) {
            _availableSlots = [..._availableSlots, targetSlot]..sort();
          }
        } else {
          // Auto-select first slot if available
          _selectedSlot = allSlots.isNotEmpty ? allSlots.first : null;
        }

        _isComputingSlots = false;
      });

      // Update slot stats after slots are available
      final orders = ref.read(managerOrdersProvider).value ?? [];
      if (orders.isNotEmpty) {
        _updateSlotStats(orders);
      }
    }
  }

  Future<void> _completeOrder() async {
    if (!mounted) return;

    // Hide any open suggestions
    _removeSuggestionsOverlay();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final orderItems = ref.read(cashierOrderProvider);
    if (orderItems.isEmpty) {
      _showError('Aggiungi almeno un prodotto all\'ordine');
      return;
    }

    // Capture form values FIRST before any async operations
    final nameText = _nameController.text.trim();
    final phoneText = _phoneController.text.trim();
    final addressText = _addressController.text.trim();
    final noteText = _noteController.text.trim();
    final orderType = _orderType;
    final selectedSlot = _selectedSlot;
    final editMode = ref.read(cashierEditModeProvider);
    final isEditing = editMode != null;

    setState(() => _isProcessing = true);

    try {
      final db = DatabaseService();
      final customerService = ref.read(cashierCustomerServiceProvider);

      // ============================================================
      // STEP 1: Process customer FIRST to get geocoded coordinates
      // This is needed for radial delivery fee calculation
      // ============================================================
      CustomerProcessingResult? customerResult;
      double? deliveryLatitude;
      double? deliveryLongitude;

      if (orderType == OrderType.delivery && addressText.isNotEmpty) {
        try {
          // Process without order total first (we don't know the total yet)
          customerResult = await customerService.processCustomerForOrder(
            nome: nameText,
            telefono: phoneText,
            indirizzo: addressText,
            citta: 'Vittoria',
            cap: '97019',
            orderTotal: null, // Will update later
          );
          deliveryLatitude = customerResult?.latitude;
          deliveryLongitude = customerResult?.longitude;
          debugPrint(
            '[RadialFee] Geocoded coordinates: $deliveryLatitude, $deliveryLongitude',
          );
        } catch (e) {
          debugPrint('[RadialFee] Customer geocoding failed: $e');
          // Continue without coordinates - will use fixed fee fallback
        }
      }

      // ============================================================
      // STEP 2: Load all required data for OrderPriceCalculator
      // ============================================================
      debugPrint('[OrderPriceCalculator] Loading required data...');

      final menuItems = await ref.read(menuProvider.future);
      final sizes = await ref.read(sizesProvider.future);
      final ingredients = await ref.read(ingredientsProvider.future);
      final sizeAssignments = await ref.read(allSizeAssignmentsProvider.future);
      final settings = ref.read(pizzeriaSettingsProvider).valueOrNull;

      // Create delivery config with radial settings
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

        debugPrint(
          '[RadialFee] Config: tipo=${dc.tipoCalcoloConsegna}, tiers=${dc.costoConsegnaRadiale.length}, base=${dc.costoConsegnaBase}',
        );
      }

      // Create the calculator with all data
      final calculator = OrderPriceCalculator(
        menuItems: menuItems,
        sizeAssignments: sizeAssignments,
        sizes: sizes,
        ingredients: ingredients,
        deliveryConfig: deliveryConfig,
      );

      debugPrint(
        '[OrderPriceCalculator] Calculator ready with ${menuItems.length} items, ${ingredients.length} ingredients',
      );

      // ============================================================
      // STEP 3: Build OrderItemInputs and calculate prices
      // ============================================================
      final inputs = orderItems.map((item) {
        if (item.isSplit && item.secondMenuItem != null) {
          final firstProductIngredients = <IngredientSelection>[];
          final secondProductIngredients = <IngredientSelection>[];

          for (final ing in item.cartItem.addedIngredients) {
            if (ing.ingredientName.contains(': ${item.secondMenuItem!.nome}')) {
              secondProductIngredients.add(
                IngredientSelection(
                  ingredientId: ing.ingredientId,
                  quantity: ing.quantity,
                ),
              );
            } else {
              firstProductIngredients.add(
                IngredientSelection(
                  ingredientId: ing.ingredientId,
                  quantity: ing.quantity,
                ),
              );
            }
          }

          return OrderItemInput(
            menuItemId: item.menuItem.id,
            sizeId: item.cartItem.selectedSize?.id,
            addedIngredients: firstProductIngredients,
            quantity: item.quantity,
            isSplit: true,
            secondProductId: item.secondMenuItem!.id,
            secondSizeId: item.cartItem.selectedSize?.id,
            secondAddedIngredients: secondProductIngredients,
          );
        } else {
          return OrderItemInput(
            menuItemId: item.menuItem.id,
            sizeId: item.cartItem.selectedSize?.id,
            addedIngredients: item.cartItem.addedIngredients
                .map(
                  (i) => IngredientSelection(
                    ingredientId: i.ingredientId,
                    quantity: i.quantity,
                  ),
                )
                .toList(),
            quantity: item.quantity,
          );
        }
      }).toList();

      // Calculate individual item prices for order data
      final calculatedPrices = inputs
          .map((i) => calculator.calculateItemPrice(i))
          .toList();
      final subtotal = calculatedPrices.fold(0.0, (sum, p) => sum + p.subtotal);

      // Log any price discrepancies
      final uiSubtotal = ref.read(cashierOrderSubtotalProvider);
      if ((subtotal - uiSubtotal).abs() > 0.01) {
        debugPrint('[OrderPriceCalculator] Price discrepancy detected!');
        debugPrint('  UI subtotal: €${uiSubtotal.toStringAsFixed(2)}');
        debugPrint('  Calculated: €${subtotal.toStringAsFixed(2)}');
      } else {
        debugPrint('[OrderPriceCalculator] Prices match!');
      }

      // ============================================================
      // STEP 4: Calculate delivery fee using RADIAL calculation
      // Uses geocoded coordinates from customer processing
      // ============================================================
      final orderTotalResult = calculator.calculateOrderTotal(
        OrderTotalInput(
          items: inputs,
          orderType: orderType,
          deliveryLatitude: deliveryLatitude,
          deliveryLongitude: deliveryLongitude,
        ),
      );

      final deliveryFee = orderTotalResult.deliveryFee;
      final total = subtotal + deliveryFee;

      debugPrint(
        '[RadialFee] Final calculation: subtotal=€${subtotal.toStringAsFixed(2)}, '
        'deliveryFee=€${deliveryFee.toStringAsFixed(2)}, total=€${total.toStringAsFixed(2)}',
      );

      // Note: Customer stats were already updated in processCustomerForOrder
      // when orderTotal was null. For new implementation, we can skip this
      // since the initial call handles customer creation/matching.

      // Calculate zone
      String? zoneName;
      if (deliveryLatitude != null && deliveryLongitude != null) {
        final zones = ref.read(deliveryZonesProvider).valueOrNull ?? [];
        final point = LatLng(deliveryLatitude, deliveryLongitude);
        final zone = GeometryUtils.findZoneForPoint(point, zones);
        zoneName = zone?.name;
      }

      // Prepare items data - use calculated prices if available
      final itemsData = <Map<String, dynamic>>[];
      for (var i = 0; i < orderItems.length; i++) {
        final item = orderItems[i];

        // For split products, use cartItem.nome which contains the combined name
        // e.g., "Margherita + Diavola (Diviso)"
        final productName = item.isSplit
            ? item.cartItem.nome
            : item.menuItem.nome;

        // Use calculated prices from the authoritative calculator
        final unitPrice = calculatedPrices[i].unitPrice;
        final itemSubtotal = calculatedPrices[i].subtotal;

        itemsData.add({
          'menu_item_id': item.menuItem.id,
          'nome_prodotto': productName,
          'quantita': item.quantity,
          'prezzo_unitario': unitPrice,
          'subtotale': itemSubtotal,
          'note': item.note,
          'varianti': _buildVariantsMap(item),
        });
      }

      // Build note
      String? orderNote = noteText.isEmpty ? null : noteText;

      if (isEditing) {
        // UPDATE existing order instead of creating new one
        // This preserves the order number and doesn't mess up daily counter
        await db.updateOrder(
          orderId: editMode.originalOrderId,
          tipo: orderType,
          nomeCliente: nameText,
          telefonoCliente: phoneText,
          emailCliente: null,
          indirizzoConsegna:
              orderType == OrderType.delivery && addressText.isNotEmpty
              ? addressText
              : null,
          cittaConsegna: orderType == OrderType.delivery ? 'Vittoria' : null,
          capConsegna: orderType == OrderType.delivery ? '97019' : null,
          latitudeConsegna: customerResult?.latitude,
          longitudeConsegna: customerResult?.longitude,
          note: orderNote,
          items: itemsData,
          subtotale: subtotal,
          costoConsegna: deliveryFee,
          totale: total,
          metodoPagamento: PaymentMethod.cash,
          slotPrenotatoStart: selectedSlot,
          cashierCustomerId: customerResult?.customerId,
          zone: zoneName,
        );
      } else {
        // CREATE new order
        await db.createOrder(
          clienteId: '', // Empty - cashier orders don't link to profiles table
          cashierCustomerId:
              customerResult?.customerId, // Link to cashier customer profile
          tipo: orderType,
          nomeCliente: nameText,
          telefonoCliente: phoneText,
          emailCliente: null,
          indirizzoConsegna:
              orderType == OrderType.delivery && addressText.isNotEmpty
              ? addressText
              : null,
          cittaConsegna: orderType == OrderType.delivery ? 'Vittoria' : null,
          capConsegna: orderType == OrderType.delivery ? '97019' : null,
          latitudeConsegna:
              customerResult?.latitude, // Use geocoded coords from customer
          longitudeConsegna: customerResult?.longitude,
          note: orderNote,
          items: itemsData,
          subtotale: subtotal,
          costoConsegna: deliveryFee,
          totale: total,
          metodoPagamento: PaymentMethod.cash, // Default to cash
          slotPrenotatoStart: selectedSlot, // Pass the selected time slot
          status: OrderStatus.ready, // Cashier orders are immediately ready
          zone: zoneName,
        );

        // Inventory deduction is now handled server-side by place-order Edge Function
        // await _deductInventoryForOrder(orderItems, ingredients);
      }

      // Clear order and edit mode - check mounted before using ref
      if (mounted) {
        ref.read(cashierOrderProvider.notifier).clear();
        ref.read(cashierEditModeProvider.notifier).state = null;
        _clearForm();

        // Refresh orders list
        ref.invalidate(managerOrdersProvider);

        if (isEditing) {
          _showSuccess('Ordine modificato con successo!');
          // Navigate back to orders screen
          context.go('/manager/orders');
        } else {
          _showSuccess('Ordine creato con successo!');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError(
          'Errore nella ${isEditing ? 'modifica' : 'creazione'} dell\'ordine: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }



  Map<String, dynamic> _buildVariantsMap(CashierOrderItem item) {
    final variants = <String, dynamic>{};

    // Add category name from menu item's categoriaId
    // This is essential for "Vendite per Categoria" analytics
    if (item.menuItem.categoriaId != null) {
      final categories = ref.read(categoriesProvider).value ?? [];
      final category = categories.firstWhere(
        (c) => c.id == item.menuItem.categoriaId,
        orElse: () => categories.firstWhere(
          (c) => c.nome.toLowerCase() == 'altro',
          orElse: () => categories.isNotEmpty
              ? categories.first
              : throw StateError('No categories available'),
        ),
      );
      variants['category'] = category.nome;
    }

    // Add size if selected
    if (item.cartItem.selectedSize != null) {
      final size = item.cartItem.selectedSize!;
      final sizeName = size.descrizione != null && size.descrizione!.isNotEmpty
          ? '${size.nome} (${size.descrizione})'
          : size.nome;
      variants['size'] = {
        'id': size.id,
        'name': sizeName,
        'priceMultiplier': size.priceMultiplier,
      };
    }

    // Add ingredients
    if (item.cartItem.addedIngredients.isNotEmpty) {
      variants['addedIngredients'] = item.cartItem.addedIngredients
          .map(
            (ing) => {
              'id': ing.ingredientId,
              'name': ing.ingredientName,
              'price': ing.unitPrice,
              'quantity': ing.quantity,
            },
          )
          .toList();
    }

    if (item.cartItem.removedIngredients.isNotEmpty) {
      variants['removedIngredients'] = item.cartItem.removedIngredients
          .map((ing) => {'id': ing.id, 'name': ing.nome})
          .toList();
    }

    // Add special options (for split products)
    if (item.cartItem.specialOptions.isNotEmpty) {
      variants['specialOptions'] = item.cartItem.specialOptions
          .map(
            (opt) => {
              'id': opt.id,
              'name': opt.name,
              'price': opt.price,
              'description': opt.description,
              if (opt.productId != null) 'productId': opt.productId,
            },
          )
          .toList();
    }

    // Mark as split product if applicable
    if (item.isSplit) {
      variants['isSplit'] = true;
      if (item.secondMenuItem != null) {
        variants['secondProduct'] = {
          'id': item.secondMenuItem!.id,
          'name': item.secondMenuItem!.nome,
        };
      }
    }

    // Add note to variants
    if (item.note != null && item.note!.isNotEmpty) {
      variants['note'] = item.note;
    }

    return variants;
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _addressController.clear();
    _noteController.clear();
    _removeSuggestionsOverlay();
    if (mounted) {
      setState(() {
        _orderType = OrderType.takeaway;
        _selectedDate = DateTime.now();
        _selectedCustomer = null;
        _customerSuggestions = [];
        _showSuggestions = false;
      });
      // Clear persisted form data
      ref.read(cashierFormDataProvider.notifier).state =
          const CashierFormData();
      // Recompute slots for today
      _computeAvailableSlots();
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
      final correctedCount = ref
          .read(cashierOrderProvider.notifier)
          .validateAndCorrectPrices(calculator);

      if (correctedCount > 0 && mounted) {
        // Force UI refresh to show corrected prices
        setState(() {});
      }
    } catch (e) {
      debugPrint('[PriceValidator] Error during validation: $e');
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Calculate delivery fee based on settings and subtotal
  double _calculateDeliveryFee(double subtotal) {
    if (_orderType != OrderType.delivery) return 0.0;

    final settings = ref.read(pizzeriaSettingsProvider).value;
    if (settings == null) return 0.0;

    final deliveryConfig = settings.deliveryConfiguration;

    // Free delivery above threshold
    if (subtotal >= deliveryConfig.consegnaGratuitaSopra) {
      return 0.0;
    }

    return deliveryConfig.costoConsegnaBase;
  }

  /// Build description for split product specialOptions (for printer)
  String _buildSplitDescription(
    SizeVariantModel? size,
    List<SelectedIngredient> added,
    List<IngredientModel> removed,
    bool isFirst,
  ) {
    String desc = isFirst ? 'Prima metà' : 'Seconda metà';
    if (size != null) {
      desc += ' - ${size.nome}';
    }
    final mods = <String>[];
    for (var ing in added) {
      mods.add(
        '+${ing.ingredientName}${ing.quantity > 1 ? ' x${ing.quantity}' : ''}',
      );
    }
    for (var ing in removed) {
      mods.add('-${ing.nome}');
    }
    if (mods.isNotEmpty) {
      desc += ' (${mods.join(', ')})';
    }
    return desc;
  }

  /// Update slot statistics based on orders
  void _updateSlotStats(List<OrderModel> orders) {
    if (!mounted) return;

    final slotStats =
        <
          DateTime,
          ({
            int deliveryOrders,
            int deliveryItems,
            int takeawayOrders,
            int takeawayItems,
          })
        >{};

    for (final slot in _availableSlots) {
      final slotOrders = orders.where((order) {
        if (order.slotPrenotatoStart == null) return false;
        final orderSlot = order.slotPrenotatoStart!;
        // Match orders scheduled for this exact slot
        return orderSlot.year == slot.year &&
            orderSlot.month == slot.month &&
            orderSlot.day == slot.day &&
            orderSlot.hour == slot.hour &&
            orderSlot.minute == slot.minute &&
            order.stato.isActive; // Only count active orders
      }).toList();

      int deliveryOrders = 0;
      int deliveryItems = 0;
      int takeawayOrders = 0;
      int takeawayItems = 0;

      for (final order in slotOrders) {
        if (order.tipo == OrderType.delivery) {
          deliveryOrders++;
          deliveryItems += order.totalItems;
        } else {
          // Takeaway (and potentially other types effectively treated as takeaway for prep capacity)
          takeawayOrders++;
          takeawayItems += order.totalItems;
        }
      }

      slotStats[slot] = (
        deliveryOrders: deliveryOrders,
        deliveryItems: deliveryItems,
        takeawayOrders: takeawayOrders,
        takeawayItems: takeawayItems,
      );
    }

    setState(() {
      _slotStats = slotStats;
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderItems = ref.watch(cashierOrderProvider);
    final subtotal = ref.watch(cashierOrderSubtotalProvider);
    final editMode = ref.watch(cashierEditModeProvider);
    final isEditing = editMode != null;
    final deliveryFee = _calculateDeliveryFee(subtotal);
    final total = subtotal + deliveryFee;

    // Ensure zones are loaded
    ref.watch(deliveryZonesProvider);

    // Listen for order changes to update slot statistics
    ref.listen(managerOrdersProvider, (previous, next) {
      if (next.hasValue && _availableSlots.isNotEmpty) {
        _updateSlotStats(next.value!);
      }
    });

    // Also compute stats on first load if orders are available
    final orders = ref.watch(managerOrdersProvider);
    if (orders.hasValue && _slotStats.isEmpty && _availableSlots.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateSlotStats(orders.value!);
        }
      });
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (isMobile) {
      return _buildMobileLayout(
        context,
        orderItems: orderItems,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: total,
        isEditing: isEditing,
        editMode: editMode,
        bottomPadding: bottomPadding,
      );
    }

    return _buildDesktopLayout(
      context,
      orderItems: orderItems,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      total: total,
      isEditing: isEditing,
      editMode: editMode,
      bottomPadding: bottomPadding,
    );
  }

  Widget _buildMobileLayout(
    BuildContext context, {
    required List<CashierOrderItem> orderItems,
    required double subtotal,
    required double deliveryFee,
    required double total,
    required bool isEditing,
    required CashierEditMode? editMode,
    required double bottomPadding,
  }) {
    return DefaultTabController(
      length: 2,
      child: Container(
        color: AppColors.surface,
        child: Column(
          children: [
            _buildHeader(isEditing, editMode, orderItems),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textTertiary,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: AppTypography.labelLarge.copyWith(
                  fontWeight: AppTypography.bold,
                ),
                unselectedLabelStyle: AppTypography.labelLarge,
                tabs: [
                  Tab(
                    text:
                        'Articoli (${orderItems.fold(0, (sum, item) => sum + item.quantity)})',
                  ),
                  const Tab(text: 'Dettagli'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Items Tab
                  orderItems.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: orderItems.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = orderItems[index];
                            return _OrderItemTile(
                              item: item,
                              onEdit: () => _handleEditItem(item),
                              onQuantityChanged: (quantity) {
                                ref
                                    .read(cashierOrderProvider.notifier)
                                    .updateQuantity(item.uniqueId, quantity);
                              },
                              onRemove: () {
                                ref
                                    .read(cashierOrderProvider.notifier)
                                    .removeItem(item.uniqueId);
                              },
                              onNoteChanged: (note) {
                                ref
                                    .read(cashierOrderProvider.notifier)
                                    .updateNote(item.uniqueId, note);
                              },
                            );
                          },
                        ),

                  // Details Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Tipo di Ordine'),
                          const SizedBox(height: AppSpacing.sm),
                          _buildOrderTypeSelector(),
                          const SizedBox(height: AppSpacing.lg),
                          _buildSectionTitle('Orario'),
                          const SizedBox(height: AppSpacing.sm),
                          _buildTimeSlotSelection(),
                          const SizedBox(height: AppSpacing.lg),
                          _buildSectionTitle('Informazioni Cliente'),
                          const SizedBox(height: AppSpacing.sm),
                          _buildCustomerInfoFields(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildCheckoutFooter(
              subtotal: subtotal,
              deliveryFee: deliveryFee,
              total: total,
              isEditing: isEditing,
              isProcessing: _isProcessing,
              bottomPadding: bottomPadding,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context, {
    required List<CashierOrderItem> orderItems,
    required double subtotal,
    required double deliveryFee,
    required double total,
    required bool isEditing,
    required CashierEditMode? editMode,
    required double bottomPadding,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.lg,
      ),
      child: Column(
        children: [
          _buildHeader(isEditing, editMode, orderItems),
          Expanded(
            child: orderItems.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: orderItems.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = orderItems[index];
                      return _OrderItemTile(
                        item: item,
                        onEdit: () => _handleEditItem(item),
                        onQuantityChanged: (quantity) {
                          ref
                              .read(cashierOrderProvider.notifier)
                              .updateQuantity(item.uniqueId, quantity);
                        },
                        onRemove: () {
                          ref
                              .read(cashierOrderProvider.notifier)
                              .removeItem(item.uniqueId);
                        },
                        onNoteChanged: (note) {
                          ref
                              .read(cashierOrderProvider.notifier)
                              .updateNote(item.uniqueId, note);
                        },
                      );
                    },
                  ),
          ),
          if (orderItems.isNotEmpty) ...[
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Tipo di Ordine'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildOrderTypeSelector(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildSectionTitle('Orario Ordine'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildTimeSlotSelection(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildSectionTitle('Informazioni Cliente'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildCustomerInfoFields(),
                    ],
                  ),
                ),
              ),
            ),
            _buildCheckoutFooter(
              subtotal: subtotal,
              deliveryFee: deliveryFee,
              total: total,
              isEditing: isEditing,
              isProcessing: _isProcessing,
              bottomPadding: bottomPadding,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.labelLarge.copyWith(fontWeight: AppTypography.bold),
    );
  }

  Widget _buildHeader(
    bool isEditing,
    CashierEditMode? editMode,
    List<CashierOrderItem> orderItems,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEditing
              ? [AppColors.info, AppColors.info.withValues(alpha: 0.8)]
              : AppColors.orangeGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_rounded : Icons.receipt_long_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing
                      ? 'Modifica #${editMode?.originalNumeroOrdine.split('-').last ?? ""}'
                      : 'Ordine Corrente',
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: AppTypography.bold,
                  ),
                ),
                Text(
                  isEditing
                      ? 'Modifica in corso • ${orderItems.fold(0, (sum, item) => sum + item.quantity)} articoli'
                      : '${orderItems.fold(0, (sum, item) => sum + item.quantity)} articoli',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => _cancelEdit(context),
              tooltip: 'Annulla modifica',
            ),
          if (orderItems.isNotEmpty && !isEditing)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                _showClearConfirmation();
              },
              tooltip: 'Svuota ordine',
            ),
        ],
      ),
    );
  }

  Widget _buildCheckoutFooter({
    required double subtotal,
    required double deliveryFee,
    required double total,
    required bool isEditing,
    required bool isProcessing,
    required double bottomPadding,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: AppColors.border, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotale',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                Formatters.currency(subtotal),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (_orderType == OrderType.delivery) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.delivery_dining_rounded,
                      size: 16,
                      color: deliveryFee == 0
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Consegna',
                      style: AppTypography.bodyMedium.copyWith(
                        color: deliveryFee == 0
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  deliveryFee == 0
                      ? 'Gratis'
                      : Formatters.currency(deliveryFee),
                  style: AppTypography.bodyMedium.copyWith(
                    color: deliveryFee == 0
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontWeight: deliveryFee == 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Totale',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              Text(
                Formatters.currency(total),
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: AppTypography.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: isProcessing ? null : _completeOrder,
              icon: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isEditing
                          ? Icons.save_rounded
                          : Icons.check_circle_rounded,
                    ),
              label: Text(
                isProcessing
                    ? 'Elaborazione...'
                    : (isEditing ? 'Salva Modifiche' : 'Conferma Ordine'),
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: AppTypography.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isEditing ? AppColors.info : AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLG),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEditItem(CashierOrderItem item) async {
    if (item.isSplit && item.secondMenuItem != null) {

      // Handle split item edit
      final firstProduct = item.menuItem;
      final secondProduct = item.secondMenuItem!;

      // Determine suffixes
      final p1Suffix = ': ${firstProduct.nome}';
      final p2Suffix = ': ${secondProduct.nome}';
      final p1SuffixNumbered = ': ${firstProduct.nome} (1)';
      final p2SuffixNumbered = ': ${secondProduct.nome} (2)';

      // Helper to clean name
      String cleanName(String name, String suffix) {
        return name.replaceAll(suffix, '');
      }

      // Separate ingredients for first and second product
      List<SelectedIngredient> firstAdded = [];
      List<SelectedIngredient> secondAdded = [];

      // Try numbered suffixes first (new format)
      final hasNumbered = item.cartItem.addedIngredients.any(
        (i) =>
            i.ingredientName.endsWith(p1SuffixNumbered) ||
            i.ingredientName.endsWith(p2SuffixNumbered),
      );

      if (hasNumbered) {
        firstAdded = item.cartItem.addedIngredients
            .where((i) => i.ingredientName.endsWith(p1SuffixNumbered))
            .map(
              (i) => i.copyWith(
                ingredientName: cleanName(i.ingredientName, p1SuffixNumbered),
              ),
            )
            .toList();

        secondAdded = item.cartItem.addedIngredients
            .where((i) => i.ingredientName.endsWith(p2SuffixNumbered))
            .map(
              (i) => i.copyWith(
                ingredientName: cleanName(i.ingredientName, p2SuffixNumbered),
              ),
            )
            .toList();
      } else {
        // Fallback to standard suffixes
        if (firstProduct.nome == secondProduct.nome) {
          // Ambiguous case: assign ALL to first product to avoid duplication
          firstAdded = item.cartItem.addedIngredients
              .where((i) => i.ingredientName.endsWith(p1Suffix))
              .map(
                (i) => i.copyWith(
                  ingredientName: cleanName(i.ingredientName, p1Suffix),
                ),
              )
              .toList();
          secondAdded = [];
        } else {
          firstAdded = item.cartItem.addedIngredients
              .where((i) => i.ingredientName.endsWith(p1Suffix))
              .map(
                (i) => i.copyWith(
                  ingredientName: cleanName(i.ingredientName, p1Suffix),
                ),
              )
              .toList();

          secondAdded = item.cartItem.addedIngredients
              .where((i) => i.ingredientName.endsWith(p2Suffix))
              .map(
                (i) => i.copyWith(
                  ingredientName: cleanName(i.ingredientName, p2Suffix),
                ),
              )
              .toList();
        }
      }

      // Handle removed ingredients similarly
      List<IngredientModel> firstRemoved = [];
      List<IngredientModel> secondRemoved = [];

      // Try numbered suffixes for removed ingredients
      final hasNumberedRemoved = item.cartItem.removedIngredients.any(
        (i) =>
            i.nome.endsWith(p1SuffixNumbered) ||
            i.nome.endsWith(p2SuffixNumbered),
      );

      if (hasNumberedRemoved) {
        firstRemoved = item.cartItem.removedIngredients
            .where((i) => i.nome.endsWith(p1SuffixNumbered))
            .map(
              (i) => IngredientModel(
                id: i.id,
                nome: cleanName(i.nome, p1SuffixNumbered),
                prezzo: i.prezzo,
                createdAt: i.createdAt,
              ),
            )
            .toList();

        secondRemoved = item.cartItem.removedIngredients
            .where((i) => i.nome.endsWith(p2SuffixNumbered))
            .map(
              (i) => IngredientModel(
                id: i.id,
                nome: cleanName(i.nome, p2SuffixNumbered),
                prezzo: i.prezzo,
                createdAt: i.createdAt,
              ),
            )
            .toList();
      } else {
        if (firstProduct.nome == secondProduct.nome) {
          firstRemoved = item.cartItem.removedIngredients
              .where((i) => i.nome.endsWith(p1Suffix))
              .map(
                (i) => IngredientModel(
                  id: i.id,
                  nome: cleanName(i.nome, p1Suffix),
                  prezzo: i.prezzo,
                  createdAt: i.createdAt,
                ),
              )
              .toList();
          secondRemoved = [];
        } else {
          firstRemoved = item.cartItem.removedIngredients
              .where((i) => i.nome.endsWith(p1Suffix))
              .map(
                (i) => IngredientModel(
                  id: i.id,
                  nome: cleanName(i.nome, p1Suffix),
                  prezzo: i.prezzo,
                  createdAt: i.createdAt,
                ),
              )
              .toList();

          secondRemoved = item.cartItem.removedIngredients
              .where((i) => i.nome.endsWith(p2Suffix))
              .map(
                (i) => IngredientModel(
                  id: i.id,
                  nome: cleanName(i.nome, p2Suffix),
                  prezzo: i.prezzo,
                  createdAt: i.createdAt,
                ),
              )
              .toList();
        }
      }

      // Find the MenuItemSizeAssignmentModel for the selected size
      MenuItemSizeAssignmentModel? initialSizeAssignment;
      if (item.cartItem.selectedSize != null) {
        try {
          final sizes = await ref.read(
            productSizesProvider(firstProduct.id).future,
          );
          initialSizeAssignment = sizes.firstWhere(
            (s) => s.sizeId == item.cartItem.selectedSize!.id,
            orElse: () => sizes.first, // Fallback
          );
        } catch (e) {
          debugPrint('Error loading sizes for edit: $e');
        }
      }

      if (!mounted) return;

      await DualStackSplitModal.showForEdit(
        context,
        ref,
        firstProduct: firstProduct,
        secondProduct: secondProduct,
        editIndex: 0, // Not used for replacement here
        initialSize: initialSizeAssignment,
        firstAddedIngredients: firstAdded,
        firstRemovedIngredients: item.cartItem.removedIngredients,
        secondAddedIngredients: secondAdded,
        secondRemovedIngredients: item.cartItem.removedIngredients,
        initialNote: item.note,
        onSplitComplete: (data) {
          final quantity = 1; // Split modal usually handles 1 item at a time
          final size = data['selectedSize'] as SizeVariantModel?;
          final p1Added =
              data['firstProductAddedIngredients']
                  as List<SelectedIngredient>? ??
              [];
          final p1Removed =
              data['firstProductRemovedIngredients']
                  as List<IngredientModel>? ??
              [];
          final p2Added =
              data['secondProductAddedIngredients']
                  as List<SelectedIngredient>? ??
              [];
          final p2Removed =
              data['secondProductRemovedIngredients']
                  as List<IngredientModel>? ??
              [];
          final note = data['note'] as String?;
          final total = data['total'] as double;

          // Calculate extras total (using full prices from modal)
          double extrasTotal(List<SelectedIngredient>? list) {
            if (list == null) return 0.0;
            return list.fold(
              0.0,
              (sum, ing) => sum + ing.unitPrice * ing.quantity,
            );
          }

          final firstExtrasFull = extrasTotal(p1Added);
          final secondExtrasFull = extrasTotal(p2Added);
          final extrasTotalSum = (firstExtrasFull + secondExtrasFull) / 2;

          // Calculate base price by subtracting extras from total
          // This ensures that when CartItemModel.totalPrice adds the extras back,
          // the final price matches the modal's total
          final baseAveragePrice = total - extrasTotalSum;

          // Determine suffixes for reconstruction
          String finalP1Suffix = ': ${firstProduct.nome}';
          String finalP2Suffix = ': ${secondProduct.nome}';
          if (firstProduct.nome == secondProduct.nome) {
            finalP1Suffix = ': ${firstProduct.nome} (1)';
            finalP2Suffix = ': ${secondProduct.nome} (2)';
          }

          // Combine ingredients with HALF PRICES (matching addSplitItem logic)
          // The modal gives full prices, but CartItemModel.totalPrice will sum them up,
          // so we store half prices to get the correct final total
          final combinedAdded = [
            ...p1Added.map(
              (ing) => ing.copyWith(
                ingredientName: '${ing.ingredientName}$finalP1Suffix',
                unitPrice:
                    ing.unitPrice / 2, // Half price for split item extras
              ),
            ),
            ...p2Added.map(
              (ing) => ing.copyWith(
                ingredientName: '${ing.ingredientName}$finalP2Suffix',
                unitPrice:
                    ing.unitPrice / 2, // Half price for split item extras
              ),
            ),
          ];

          final combinedRemoved = [...p1Removed, ...p2Removed];
          final uniqueRemoved = combinedRemoved.fold<List<IngredientModel>>(
            [],
            (list, item) {
              if (!list.any((i) => i.id == item.id)) {
                list.add(item);
              }
              return list;
            },
          );

          // Build specialOptions for printer formatting
          final splitOptions = <SpecialOption>[
            SpecialOption(
              id: 'split_first',
              name: firstProduct.nome,
              price: 0.0,
              description: _buildSplitDescription(
                size,
                p1Added,
                p1Removed,
                true,
              ),
              productId: firstProduct.id,
              imageUrl: firstProduct.immagineUrl,
            ),
            SpecialOption(
              id: 'split_second',
              name: secondProduct.nome,
              price: 0.0,
              description: _buildSplitDescription(
                size,
                p2Added,
                p2Removed,
                false,
              ),
              productId: secondProduct.id,
              imageUrl: secondProduct.immagineUrl,
            ),
          ];

          final newItem = CashierOrderItem(
            menuItem: firstProduct,
            secondMenuItem: secondProduct,
            isSplit: true,
            uniqueId: item.uniqueId,
            cartItem: CartItemModel(
              menuItemId: firstProduct.id,
              nome: '${firstProduct.nome} + ${secondProduct.nome} (Diviso)',
              basePrice: baseAveragePrice,
              quantity: quantity,
              selectedSize: size,
              addedIngredients: combinedAdded,
              removedIngredients: uniqueRemoved,
              specialOptions: splitOptions,
              note: note,
            ),
          );

          ref
              .read(cashierOrderProvider.notifier)
              .replaceItem(item.uniqueId, newItem);
        },
      );

      // Validate and correct prices after modal closes
      _validateAndCorrectPrices();
    } else {
      // Handle normal item edit
      await ProductCustomizationModal.showForEdit(
        context,
        item.menuItem,
        editIndex: 0,
        initialQuantity: item.quantity,
        initialSize: item.cartItem.selectedSize,
        initialAddedIngredients: item.cartItem.addedIngredients,
        initialRemovedIngredients: item.cartItem.removedIngredients,
        initialNote: item.note,
        onCustomizationComplete: (data) {
          // Check if user converted to a split product during edit
          if (data['isSplit'] == true) {
            // Handle conversion from normal to split product
            final firstProduct = data['firstProduct'] as MenuItemModel;
            final secondProduct = data['secondProduct'] as MenuItemModel;
            final size = data['selectedSize'] as SizeVariantModel?;
            final p1Added =
                data['firstProductAddedIngredients']
                    as List<SelectedIngredient>? ??
                [];
            final p1Removed =
                data['firstProductRemovedIngredients']
                    as List<IngredientModel>? ??
                [];
            final p2Added =
                data['secondProductAddedIngredients']
                    as List<SelectedIngredient>? ??
                [];
            final p2Removed =
                data['secondProductRemovedIngredients']
                    as List<IngredientModel>? ??
                [];
            final note = data['note'] as String?;
            final total = data['total'] as double;

            // Calculate extras total (using full prices from modal)
            double extrasTotal(List<SelectedIngredient>? list) {
              if (list == null) return 0.0;
              return list.fold(
                0.0,
                (sum, ing) => sum + ing.unitPrice * ing.quantity,
              );
            }

            final firstExtrasFull = extrasTotal(p1Added);
            final secondExtrasFull = extrasTotal(p2Added);
            final extrasTotalSum = (firstExtrasFull + secondExtrasFull) / 2;

            // Calculate base price by subtracting extras from total
            final baseAveragePrice = total - extrasTotalSum;

            // Determine suffixes
            String finalP1Suffix = ': ${firstProduct.nome}';
            String finalP2Suffix = ': ${secondProduct.nome}';
            if (firstProduct.nome == secondProduct.nome) {
              finalP1Suffix = ': ${firstProduct.nome} (1)';
              finalP2Suffix = ': ${secondProduct.nome} (2)';
            }

            // Combine ingredients with HALF PRICES (matching addSplitItem logic)
            final combinedAdded = [
              ...p1Added.map(
                (ing) => ing.copyWith(
                  ingredientName: '${ing.ingredientName}$finalP1Suffix',
                  unitPrice: ing.unitPrice / 2,
                ),
              ),
              ...p2Added.map(
                (ing) => ing.copyWith(
                  ingredientName: '${ing.ingredientName}$finalP2Suffix',
                  unitPrice: ing.unitPrice / 2,
                ),
              ),
            ];

            final combinedRemoved = [...p1Removed, ...p2Removed];
            final uniqueRemoved = combinedRemoved.fold<List<IngredientModel>>(
              [],
              (list, removedItem) {
                if (!list.any((i) => i.id == removedItem.id)) {
                  list.add(removedItem);
                }
                return list;
              },
            );

            // Build specialOptions for printer formatting
            final splitOptions = <SpecialOption>[
              SpecialOption(
                id: 'split_first',
                name: firstProduct.nome,
                price: 0.0,
                description: _buildSplitDescription(
                  size,
                  p1Added,
                  p1Removed,
                  true,
                ),
                productId: firstProduct.id,
                imageUrl: firstProduct.immagineUrl,
              ),
              SpecialOption(
                id: 'split_second',
                name: secondProduct.nome,
                price: 0.0,
                description: _buildSplitDescription(
                  size,
                  p2Added,
                  p2Removed,
                  false,
                ),
                productId: secondProduct.id,
                imageUrl: secondProduct.immagineUrl,
              ),
            ];

            final newItem = CashierOrderItem(
              menuItem: firstProduct,
              secondMenuItem: secondProduct,
              isSplit: true,
              uniqueId: item.uniqueId,
              cartItem: CartItemModel(
                menuItemId: firstProduct.id,
                nome: '${firstProduct.nome} + ${secondProduct.nome} (Diviso)',
                basePrice: baseAveragePrice,
                quantity: 1,
                selectedSize: size,
                addedIngredients: combinedAdded,
                removedIngredients: uniqueRemoved,
                specialOptions: splitOptions,
                note: note,
              ),
            );

            ref
                .read(cashierOrderProvider.notifier)
                .replaceItem(item.uniqueId, newItem);
          } else {
            // Normal item edit
            final quantity = data['quantity'] as int;
            final size = data['selectedSize'] as SizeVariantModel?;
            final added =
                data['addedIngredients'] as List<SelectedIngredient>? ?? [];
            final removed =
                data['removedIngredients'] as List<IngredientModel>? ?? [];
            final note = data['note'] as String?;
            final effectiveBasePrice = data['effectiveBasePrice'] as double;

            final newItem = CashierOrderItem(
              menuItem: item.menuItem,
              uniqueId: item.uniqueId,
              cartItem: CartItemModel(
                menuItemId: item.menuItem.id,
                nome: item.menuItem.nome,
                basePrice: effectiveBasePrice,
                quantity: quantity,
                selectedSize: size,
                addedIngredients: added,
                removedIngredients: removed,
                note: note,
              ),
            );

            ref
                .read(cashierOrderProvider.notifier)
                .replaceItem(item.uniqueId, newItem);
          }
        },
      );

      // Validate and correct prices after modal closes
      _validateAndCorrectPrices();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 64,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Nessun prodotto',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Seleziona i prodotti dalla griglia',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildOrderTypeButton(
            type: OrderType.takeaway,
            label: 'Asporto',
            icon: Icons.shopping_bag_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildOrderTypeButton(
            type: OrderType.delivery,
            label: 'Consegna',
            icon: Icons.delivery_dining_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTypeButton({
    required OrderType type,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _orderType == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _orderType = type);
          _saveFormData();
        },
        borderRadius: AppRadius.radiusMD,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceLight,
            borderRadius: AppRadius.radiusMD,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.captionSmall.copyWith(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected
                      ? AppTypography.bold
                      : AppTypography.medium,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSlotSelection() {
    final dayNames = ['Dom', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab'];
    final monthNames = [
      'Gen',
      'Feb',
      'Mar',
      'Apr',
      'Mag',
      'Giu',
      'Lug',
      'Ago',
      'Set',
      'Ott',
      'Nov',
      'Dic',
    ];

    String formatDate(DateTime date) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) return 'Oggi';
      if (dateOnly == today.add(const Duration(days: 1))) return 'Domani';
      return '${dayNames[date.weekday % 7]} ${date.day} ${monthNames[date.month - 1]}';
    }

    String formatTime(DateTime time) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }

    return Row(
      children: [
        // Day dropdown
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadius.radiusMD,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DateTime>(
                value: DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                ),
                isExpanded: true,
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                items: _availableDates.map((date) {
                  return DropdownMenuItem<DateTime>(
                    value: date,
                    child: Text(
                      formatDate(date),
                      style: AppTypography.bodyMedium,
                    ),
                  );
                }).toList(),
                onChanged: (date) {
                  if (date != null) {
                    setState(() => _selectedDate = date);
                    _computeAvailableSlots(date);
                    _saveFormData();
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // Time slot dropdown
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadius.radiusMD,
            ),
            child: _isComputingSlots
                ? const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _availableSlots.isEmpty
                ? Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Chiuso',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<DateTime>(
                      value: _selectedSlot,
                      isExpanded: true,
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      items: _availableSlots.map((slot) {
                        final stats = _slotStats[slot];
                        final deliveryOrders = stats?.deliveryOrders ?? 0;
                        final deliveryItems = stats?.deliveryItems ?? 0;
                        final takeawayOrders = stats?.takeawayOrders ?? 0;
                        final takeawayItems = stats?.takeawayItems ?? 0;
                        final hasOrders =
                            deliveryOrders > 0 || takeawayOrders > 0;

                        return DropdownMenuItem<DateTime>(
                          value: slot,
                          child: Row(
                            children: [
                              Text(
                                formatTime(slot),
                                style: AppTypography.bodyMedium,
                              ),
                              if (hasOrders) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (deliveryOrders > 0) ...[
                                          Icon(
                                            Icons.delivery_dining_rounded,
                                            size: 14,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$deliveryOrders ($deliveryItems)',
                                            style: AppTypography.captionSmall
                                                .copyWith(
                                                  color: AppColors.primary,
                                                  fontWeight:
                                                      AppTypography.bold,
                                                ),
                                          ),
                                          if (takeawayOrders > 0) ...[
                                            Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                  ),
                                              height: 12,
                                              width: 1,
                                              color: AppColors.border,
                                            ),
                                          ],
                                        ],
                                        if (takeawayOrders > 0) ...[
                                          Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$takeawayOrders ($takeawayItems)',
                                            style: AppTypography.captionSmall
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontWeight:
                                                      AppTypography.bold,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (slot) {
                        if (slot != null) {
                          setState(() => _selectedSlot = slot);
                          _saveFormData();
                        }
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfoFields() {
    return Column(
      children: [
        // Name field with autocomplete
        TapRegion(
          groupId: 'customer_suggestions',
          onTapOutside: (_) => _removeSuggestionsOverlay(),
          child: CompositedTransformTarget(
            link: _nameFieldLayerLink,
            child: TextFormField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              decoration: InputDecoration(
                labelText: 'Nome Cliente *',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                suffixIcon: _selectedCustomer != null
                    ? Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Salvato',
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.success,
                                fontWeight: AppTypography.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _isLoadingSuggestions
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: AppRadius.radiusMD),
                hintText: 'Digita per cercare clienti...',
              ),
              onChanged: (value) {
                _clearSelectedCustomer();
                _searchCustomers(value);
              },
              onTap: () {
                // Show existing suggestions if available
                if (_customerSuggestions.isNotEmpty && _showSuggestions) {
                  _showSuggestionsOverlay();
                }
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci il nome del cliente';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _phoneController,
          focusNode: _phoneFocusNode,
          decoration: InputDecoration(
            labelText: _orderType == OrderType.delivery
                ? 'Telefono *'
                : 'Telefono',
            prefixIcon: const Icon(Icons.phone_outlined),
            border: OutlineInputBorder(borderRadius: AppRadius.radiusMD),
          ),
          keyboardType: TextInputType.phone,
          onChanged: (_) => _clearSelectedCustomer(),
          validator: (value) {
            // Phone is only required for delivery orders
            if (_orderType == OrderType.delivery &&
                (value == null || value.trim().isEmpty)) {
              return 'Inserisci il numero di telefono';
            }
            return null;
          },
        ),
        // Address field - only shown for delivery
        if (_orderType == OrderType.delivery) ...[
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _addressController,
            focusNode: _addressFocusNode,
            decoration: InputDecoration(
              labelText: 'Indirizzo di Consegna *',
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(borderRadius: AppRadius.radiusMD),
            ),
            onChanged: (_) => _clearSelectedCustomer(),
            validator: (value) {
              if (_orderType == OrderType.delivery &&
                  (value == null || value.trim().isEmpty)) {
                return 'Inserisci l\'indirizzo di consegna';
              }
              return null;
            },
            maxLines: 2,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _noteController,
          focusNode: _noteFocusNode,
          decoration: InputDecoration(
            labelText: 'Note Ordine (opzionale)',
            prefixIcon: const Icon(Icons.note_outlined),
            border: OutlineInputBorder(borderRadius: AppRadius.radiusMD),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Svuota Ordine'),
        content: const Text(
          'Sei sicuro di voler rimuovere tutti i prodotti dall\'ordine?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(cashierOrderProvider.notifier).clear();
              _clearForm();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Svuota'),
          ),
        ],
      ),
    );
  }

  void _cancelEdit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annulla Modifica'),
        content: const Text(
          'Sei sicuro di voler annullare la modifica?\n\n'
          'Le modifiche non salvate andranno perse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continua a modificare'),
          ),
          ElevatedButton(
            onPressed: () {
              // Clear edit mode and order
              ref.read(cashierEditModeProvider.notifier).state = null;
              ref.read(cashierOrderProvider.notifier).clear();
              _clearForm();
              Navigator.pop(ctx);
              // Navigate back to orders
              context.go('/manager/orders');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Annulla Modifica'),
          ),
        ],
      ),
    );
  }
}

class _AnimatedSuggestionsOverlay extends StatefulWidget {
  final LayerLink link;
  final List<CashierCustomerModel> suggestions;
  final Function(CashierCustomerModel) onSelect;

  const _AnimatedSuggestionsOverlay({
    required this.link,
    required this.suggestions,
    required this.onSelect,
  });

  @override
  State<_AnimatedSuggestionsOverlay> createState() =>
      _AnimatedSuggestionsOverlayState();
}

class _AnimatedSuggestionsOverlayState
    extends State<_AnimatedSuggestionsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.topLeft,
        child: CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          offset: const Offset(0, 56), // Height of text field + spacing
          child: TapRegion(
            groupId: 'customer_suggestions',
            child: ScaleTransition(
              scale: _scale,
              child: FadeTransition(
                opacity: _opacity,
                child: SizedBox(
                  width: 300,
                  child: Material(
                    elevation: 12,
                    shadowColor: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    color: AppColors.surface,
                    type: MaterialType.card,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              border: Border(
                                bottom: BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_search_rounded,
                                  size: 16,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Clienti Registrati',
                                  style: AppTypography.captionSmall.copyWith(
                                    fontWeight: AppTypography.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${widget.suggestions.length} risultati',
                                  style: AppTypography.captionSmall.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: widget.suggestions.length,
                              itemBuilder: (context, index) {
                                return _buildTile(widget.suggestions[index]);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTile(CashierCustomerModel customer) {
    return InkWell(
      onTap: () => widget.onSelect(customer),
      hoverColor: AppColors.primary.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getInitials(customer.nome),
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.nome,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: AppTypography.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (customer.telefono != null || customer.hasAddress)
                    Row(
                      children: [
                        if (customer.telefono != null) ...[
                          Icon(
                            Icons.phone_rounded,
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            customer.telefono!,
                            style: AppTypography.captionSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (customer.hasAddress) const SizedBox(width: 8),
                        ],
                        if (customer.hasAddress) ...[
                          Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              customer.indirizzo!,
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }
}

/// Individual order item tile with quantity controls
class _OrderItemTile extends StatelessWidget {
  final CashierOrderItem item;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;
  final VoidCallback onEdit;
  final Function(String?) onNoteChanged;

  const _OrderItemTile({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onEdit,
    required this.onNoteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isSplit
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
          width: item.isSplit ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Split badge
                    if (item.isSplit)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.call_split_rounded,
                              size: 12,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pizza Divisa',
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: AppTypography.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      item.displayName,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: AppTypography.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.currency(item.cartItem.basePrice),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    // Show customizations
                    if (item.cartItem.selectedSize != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getSizeDisplayName(item.cartItem.selectedSize!),
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: AppTypography.medium,
                          ),
                        ),
                      ),
                    ],
                    if (item.cartItem.addedIngredients.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: item.cartItem.addedIngredients.map((e) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+${e.ingredientName}',
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.success,
                                fontWeight: AppTypography.medium,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (item.cartItem.removedIngredients.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: item.cartItem.removedIngredients.map((e) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-${e.nome}',
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.error,
                                fontWeight: AppTypography.medium,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (item.note != null && item.note!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 14,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.note!,
                                style: AppTypography.captionSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              // Quantity controls and price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Quantity stepper
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Decrease
                        GestureDetector(
                          onTap: () {
                            if (item.quantity > 1) {
                              onQuantityChanged(item.quantity - 1);
                            } else {
                              onRemove();
                            }
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.remove,
                              size: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),

                        // Quantity
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '${item.quantity}',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                        ),

                        // Increase
                        GestureDetector(
                          onTap: () => onQuantityChanged(item.quantity + 1),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    Formatters.currency(item.subtotal),
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: AppTypography.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Action buttons
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Modifica'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => _showNoteDialog(context),
                icon: Icon(
                  item.note != null && item.note!.isNotEmpty
                      ? Icons.edit_note_rounded
                      : Icons.note_add_outlined,
                  size: 16,
                ),
                label: Text(
                  item.note != null && item.note!.isNotEmpty
                      ? 'Modifica nota'
                      : 'Aggiungi nota',
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Rimuovi'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNoteDialog(BuildContext context) {
    final noteController = TextEditingController(text: item.note ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('Note Prodotto'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: 'Es: ben cotta, senza cipolla...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.surfaceLight,
              ),
              maxLines: 3,
              maxLength: 100,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              onNoteChanged(
                noteController.text.trim().isEmpty
                    ? null
                    : noteController.text.trim(),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}
