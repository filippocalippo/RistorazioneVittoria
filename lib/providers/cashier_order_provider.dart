import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../core/models/menu_item_model.dart';
import '../core/models/cart_item_model.dart';
import '../core/models/size_variant_model.dart';
import '../core/models/ingredient_model.dart';
import '../core/models/product_configuration_model.dart';
import '../core/models/order_model.dart';
import '../core/models/order_item_model.dart';
import '../core/utils/enums.dart';
import '../core/services/order_price_calculator.dart';
import '../core/services/order_price_models.dart';

part 'cashier_order_provider.g.dart';

/// Edit mode state for tracking order modifications
class CashierEditMode {
  final String originalOrderId;
  final String originalNumeroOrdine;
  final String customerName;
  final String customerPhone;
  final String? customerAddress;
  final String? note;
  final OrderType orderType;
  final DateTime? slotPrenotatoStart;

  const CashierEditMode({
    required this.originalOrderId,
    required this.originalNumeroOrdine,
    required this.customerName,
    required this.customerPhone,
    this.customerAddress,
    this.note,
    required this.orderType,
    this.slotPrenotatoStart,
  });
}

/// Item in the cashier's current order being composed
class CashierOrderItem {
  final MenuItemModel menuItem;
  final CartItemModel cartItem;
  final String uniqueId; // For managing multiple instances of same product

  // For split products
  final MenuItemModel? secondMenuItem;
  final bool isSplit;

  CashierOrderItem({
    required this.menuItem,
    required this.cartItem,
    required this.uniqueId,
    this.secondMenuItem,
    this.isSplit = false,
  });

  double get subtotal => cartItem.totalPrice;
  int get quantity => cartItem.quantity;
  String? get note => cartItem.note;

  /// Display name for the order item
  String get displayName {
    if (isSplit && secondMenuItem != null) {
      return '${menuItem.nome} + ${secondMenuItem!.nome} (Diviso)';
    }
    return menuItem.nome;
  }

  CashierOrderItem copyWith({
    MenuItemModel? menuItem,
    CartItemModel? cartItem,
    String? uniqueId,
    MenuItemModel? secondMenuItem,
    bool? isSplit,
  }) {
    return CashierOrderItem(
      menuItem: menuItem ?? this.menuItem,
      cartItem: cartItem ?? this.cartItem,
      uniqueId: uniqueId ?? this.uniqueId,
      secondMenuItem: secondMenuItem ?? this.secondMenuItem,
      isSplit: isSplit ?? this.isSplit,
    );
  }
}

/// Provider for cashier order composition
/// This is a temporary order being built, separate from customer cart
/// keepAlive: true ensures the order persists during navigation (e.g., from orders screen to cashier)
@Riverpod(keepAlive: true)
class CashierOrder extends _$CashierOrder {
  @override
  List<CashierOrderItem> build() {
    return [];
  }

  /// Add item without customization (quick add)
  void addItem(MenuItemModel menuItem, {int quantity = 1}) {
    final cartItemModel = CartItemModel(
      menuItemId: menuItem.id,
      nome: menuItem.nome,
      basePrice: menuItem.prezzoEffettivo,
      quantity: quantity,
    );

    final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();

    state = [
      ...state,
      CashierOrderItem(
        menuItem: menuItem,
        cartItem: cartItemModel,
        uniqueId: uniqueId,
      ),
    ];
  }

  /// Add item with full customizations
  ///
  /// [effectiveBasePrice] - If provided, uses this as the base price (already includes size pricing).
  ///                        This should be used when the caller has access to MenuItemSizeAssignmentModel
  ///                        which may have a priceOverride.
  void addItemWithCustomization(
    MenuItemModel menuItem, {
    required int quantity,
    SizeVariantModel? selectedSize,
    List<SelectedIngredient>? addedIngredients,
    List<IngredientModel>? removedIngredients,
    String? note,
    double? effectiveBasePrice,
  }) {
    // Use provided effectiveBasePrice if available, otherwise calculate from size
    double basePrice = effectiveBasePrice ?? menuItem.prezzoEffettivo;
    if (effectiveBasePrice == null && selectedSize != null) {
      basePrice = selectedSize.calculatePrice(menuItem.prezzoEffettivo);
    }

    final cartItemModel = CartItemModel(
      menuItemId: menuItem.id,
      nome: menuItem.nome,
      basePrice: basePrice,
      quantity: quantity,
      selectedSize: selectedSize,
      addedIngredients: addedIngredients ?? [],
      removedIngredients: removedIngredients ?? [],
      note: note,
    );

    final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();

    state = [
      ...state,
      CashierOrderItem(
        menuItem: menuItem,
        cartItem: cartItemModel,
        uniqueId: uniqueId,
      ),
    ];
  }

  /// Add split product (e.g., half and half pizza)
  ///
  /// [totalPrice] - If provided, uses this as the final unit price.
  ///                This should be used when the caller has access to MenuItemSizeAssignmentModel
  ///                which may have a priceOverride.
  void addSplitItem({
    required MenuItemModel firstProduct,
    required MenuItemModel secondProduct,
    SizeVariantModel? firstProductSize,
    SizeVariantModel? secondProductSize,
    List<SelectedIngredient>? firstProductAddedIngredients,
    List<IngredientModel>? firstProductRemovedIngredients,
    List<SelectedIngredient>? secondProductAddedIngredients,
    List<IngredientModel>? secondProductRemovedIngredients,
    String? note,
    double? totalPrice, // Optional override for pre-calculated price
  }) {
    // Helper to calculate extras total
    double extrasTotal(List<SelectedIngredient>? list) {
      if (list == null) return 0.0;
      return list.fold(0.0, (sum, ing) => sum + ing.unitPrice * ing.quantity);
    }

    // Calculate split price (average of both products, rounded to nearest 0.50)
    double roundedUnitPrice;
    double extrasTotalSum;

    if (totalPrice != null) {
      // Use pre-calculated total from modal (respects priceOverride)
      roundedUnitPrice = totalPrice;

      // Calculate extras total for base price calculation
      final firstExtrasFull = extrasTotal(firstProductAddedIngredients);
      final secondExtrasFull = extrasTotal(secondProductAddedIngredients);
      extrasTotalSum = (firstExtrasFull + secondExtrasFull) / 2;
    } else {
      // Fallback: calculate using size multiplier only (no priceOverride support)
      double p1Base = firstProduct.prezzoEffettivo;
      double p2Base = secondProduct.prezzoEffettivo;

      // Apply size multipliers
      if (firstProductSize != null) {
        p1Base = p1Base * firstProductSize.priceMultiplier;
      }
      if (secondProductSize != null) {
        p2Base = p2Base * secondProductSize.priceMultiplier;
      }

      // Add extra ingredient costs (full price)
      final firstExtrasFull = extrasTotal(firstProductAddedIngredients);
      final secondExtrasFull = extrasTotal(secondProductAddedIngredients);

      // Calculate total: ((Base1 + Extras1) + (Base2 + Extras2)) / 2
      final rawTotal =
          ((p1Base + firstExtrasFull) + (p2Base + secondExtrasFull)) / 2;
      roundedUnitPrice = (rawTotal * 2).ceil() / 2.0;
      extrasTotalSum = (firstExtrasFull + secondExtrasFull) / 2;
    }

    // Calculate base price by subtracting extras total from total
    // This ensures that when CartItemModel.totalPrice adds the extras back,
    // the final price matches roundedUnitPrice
    final baseAveragePrice = roundedUnitPrice - extrasTotalSum;

    // Create combined display name (matching cart_provider format for printer)
    final displayName = '${firstProduct.nome} + ${secondProduct.nome} (Diviso)';

    // Create specialOptions with proper IDs and descriptions for printer
    // Printer expects: split_first and split_second with descriptions containing mods
    final splitOptions = <SpecialOption>[];

    // First product option
    String firstDesc = 'Prima metà';
    if (firstProductSize != null) {
      firstDesc += ' - ${firstProductSize.nome}';
    }
    final firstMods = <String>[];
    if (firstProductAddedIngredients != null &&
        firstProductAddedIngredients.isNotEmpty) {
      for (var ing in firstProductAddedIngredients) {
        firstMods.add(
          '+${ing.ingredientName}${ing.quantity > 1 ? ' x${ing.quantity}' : ''}',
        );
      }
    }
    if (firstProductRemovedIngredients != null &&
        firstProductRemovedIngredients.isNotEmpty) {
      for (var ing in firstProductRemovedIngredients) {
        firstMods.add('-${ing.nome}');
      }
    }
    if (firstMods.isNotEmpty) {
      firstDesc += ' (${firstMods.join(', ')})';
    }

    splitOptions.add(
      SpecialOption(
        id: 'split_first',
        name: firstProduct.nome,
        price: 0.0,
        description: firstDesc,
        productId: firstProduct.id,
        imageUrl: firstProduct.immagineUrl,
      ),
    );

    // Second product option
    String secondDesc = 'Seconda metà';
    if (secondProductSize != null) {
      secondDesc += ' - ${secondProductSize.nome}';
    }
    final secondMods = <String>[];
    if (secondProductAddedIngredients != null &&
        secondProductAddedIngredients.isNotEmpty) {
      for (var ing in secondProductAddedIngredients) {
        secondMods.add(
          '+${ing.ingredientName}${ing.quantity > 1 ? ' x${ing.quantity}' : ''}',
        );
      }
    }
    if (secondProductRemovedIngredients != null &&
        secondProductRemovedIngredients.isNotEmpty) {
      for (var ing in secondProductRemovedIngredients) {
        secondMods.add('-${ing.nome}');
      }
    }
    if (secondMods.isNotEmpty) {
      secondDesc += ' (${secondMods.join(', ')})';
    }

    splitOptions.add(
      SpecialOption(
        id: 'split_second',
        name: secondProduct.nome,
        price: 0.0,
        description: secondDesc,
        productId: secondProduct.id,
        imageUrl: secondProduct.immagineUrl,
      ),
    );

    // Combine all added ingredients from both products with product name prefix
    // Store with HALF prices so CartItemModel.totalPrice calculates correctly
    final allAddedIngredients = <SelectedIngredient>[];
    
    // Determine suffixes - handle identical product names by appending (1)/(2)
    String p1Suffix = ': ${firstProduct.nome}';
    String p2Suffix = ': ${secondProduct.nome}';
    if (firstProduct.nome == secondProduct.nome) {
      p1Suffix = ': ${firstProduct.nome} (1)';
      p2Suffix = ': ${secondProduct.nome} (2)';
    }

    if (firstProductAddedIngredients != null) {
      for (var ing in firstProductAddedIngredients) {
        allAddedIngredients.add(
          SelectedIngredient(
            ingredientId: ing.ingredientId,
            ingredientName: '${ing.ingredientName}$p1Suffix',
            unitPrice: ing.unitPrice / 2, // Half price for split item extras
            quantity: ing.quantity,
          ),
        );
      }
    }
    if (secondProductAddedIngredients != null) {
      for (var ing in secondProductAddedIngredients) {
        allAddedIngredients.add(
          SelectedIngredient(
            ingredientId: ing.ingredientId,
            ingredientName: '${ing.ingredientName}$p2Suffix',
            unitPrice: ing.unitPrice / 2, // Half price for split item extras
            quantity: ing.quantity,
          ),
        );
      }
    }

    // Combine all removed ingredients from both products with product name prefix
    final allRemovedIngredients = <IngredientModel>[];
    if (firstProductRemovedIngredients != null) {
      for (var ing in firstProductRemovedIngredients) {
        allRemovedIngredients.add(
          IngredientModel(
            id: ing.id,
            nome: '${ing.nome}$p1Suffix',
            prezzo: ing.prezzo,
            createdAt: ing.createdAt,
          ),
        );
      }
    }
    if (secondProductRemovedIngredients != null) {
      for (var ing in secondProductRemovedIngredients) {
        allRemovedIngredients.add(
          IngredientModel(
            id: ing.id,
            nome: '${ing.nome}$p2Suffix',
            prezzo: ing.prezzo,
            createdAt: ing.createdAt,
          ),
        );
      }
    }

    final cartItemModel = CartItemModel(
      menuItemId: firstProduct.id,
      nome: displayName,
      basePrice: baseAveragePrice,
      quantity: 1,
      selectedSize: firstProductSize,
      addedIngredients: allAddedIngredients,
      removedIngredients: allRemovedIngredients,
      specialOptions: splitOptions,
      note: note,
    );

    final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();

    state = [
      ...state,
      CashierOrderItem(
        menuItem: firstProduct,
        cartItem: cartItemModel,
        uniqueId: uniqueId,
        secondMenuItem: secondProduct,
        isSplit: true,
      ),
    ];
  }

  /// Remove item by unique ID
  void removeItem(String uniqueId) {
    state = state.where((item) => item.uniqueId != uniqueId).toList();
  }

  /// Update quantity for specific item
  void updateQuantity(String uniqueId, int quantity) {
    if (quantity <= 0) {
      removeItem(uniqueId);
      return;
    }

    state = state.map((item) {
      if (item.uniqueId == uniqueId) {
        return item.copyWith(
          cartItem: item.cartItem.copyWith(quantity: quantity),
        );
      }
      return item;
    }).toList();
  }

  /// Update note for specific item
  void updateNote(String uniqueId, String? note) {
    state = state.map((item) {
      if (item.uniqueId == uniqueId) {
        return item.copyWith(cartItem: item.cartItem.copyWith(note: note));
      }
      return item;
    }).toList();
  }

  /// Clear all items
  void clear() {
    state = [];
  }

  /// Add a pre-built CashierOrderItem (used when loading existing orders)
  void addLoadedItem(CashierOrderItem item) {
    state = [...state, item];
  }

  /// Replace an existing item with a new one (used for editing)
  void replaceItem(String uniqueId, CashierOrderItem newItem) {
    state = state.map((item) {
      if (item.uniqueId == uniqueId) {
        return newItem;
      }
      return item;
    }).toList();
  }

  /// Get subtotal for the order
  double get subtotal {
    return state.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Get total item count
  int get itemCount {
    return state.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Validate and correct prices using the authoritative OrderPriceCalculator.
  /// Call this after modifying items to ensure UI prices match calculated prices.
  /// Returns the number of items that were corrected.
  int validateAndCorrectPrices(OrderPriceCalculator calculator) {
    int correctedCount = 0;
    final newState = <CashierOrderItem>[];

    for (final item in state) {
      // Build input for calculator
      final OrderItemInput input;

      if (item.isSplit && item.secondMenuItem != null) {
        // Split product - separate ingredients by product
        final firstProductIngredients = <IngredientSelection>[];
        final secondProductIngredients = <IngredientSelection>[];

        final p2Suffix = ': ${item.secondMenuItem!.nome}';
        final p2SuffixNumbered = ': ${item.secondMenuItem!.nome} (2)';

        for (final ing in item.cartItem.addedIngredients) {
          bool belongsToSecond = false;

          if (ing.ingredientName.endsWith(p2SuffixNumbered)) {
            belongsToSecond = true;
          } else if (ing.ingredientName.endsWith(p2Suffix)) {
            belongsToSecond = true;
          } else if (ing.ingredientName.contains(p2Suffix)) {
            // Fallback for distinct names only
            if (item.menuItem.nome != item.secondMenuItem!.nome) {
              belongsToSecond = true;
            }
          }

          if (belongsToSecond) {
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

        input = OrderItemInput(
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
        // Regular product
        input = OrderItemInput(
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

      // Calculate correct price
      final calculated = calculator.calculateItemPrice(input);
      final currentSubtotal = item.subtotal;

      // Check for discrepancy (allowing for floating point tolerance)
      if ((calculated.subtotal - currentSubtotal).abs() > 0.01) {
        correctedCount++;

        // Log the correction
        debugPrint('[PriceValidator] Correcting ${item.displayName}:');
        debugPrint('  UI price: €${currentSubtotal.toStringAsFixed(2)}');
        debugPrint('  Correct: €${calculated.subtotal.toStringAsFixed(2)}');
        debugPrint(
          '  Difference: €${(calculated.subtotal - currentSubtotal).toStringAsFixed(2)}',
        );

        // Create corrected item with new basePrice
        // For split products, we need to calculate the correct basePrice
        // by subtracting the ingredient costs from the total
        double newBasePrice;
        if (item.isSplit) {
          // For splits, ingredients are stored with half prices
          final ingredientCostsInCart = item.cartItem.addedIngredients.fold(
            0.0,
            (sum, ing) => sum + ing.unitPrice * ing.quantity,
          );
          newBasePrice = calculated.unitPrice - ingredientCostsInCart;
        } else {
          // For regular items, subtract full ingredient costs
          final ingredientCosts = item.cartItem.addedIngredients.fold(
            0.0,
            (sum, ing) => sum + ing.unitPrice * ing.quantity,
          );
          newBasePrice = calculated.unitPrice - ingredientCosts;
        }

        final correctedCartItem = item.cartItem.copyWith(
          basePrice: newBasePrice,
        );

        newState.add(item.copyWith(cartItem: correctedCartItem));
      } else {
        newState.add(item);
      }
    }

    if (correctedCount > 0) {
      state = newState;
      debugPrint('[PriceValidator] Corrected $correctedCount item(s)');
    }

    return correctedCount;
  }
}

/// Provider for order subtotal
@riverpod
double cashierOrderSubtotal(Ref ref) {
  final order = ref.watch(cashierOrderProvider);
  return order.fold(0.0, (sum, item) => sum + item.subtotal);
}

/// Provider for total items count
@riverpod
int cashierOrderItemCount(Ref ref) {
  final order = ref.watch(cashierOrderProvider);
  return order.fold(0, (sum, item) => sum + item.quantity);
}

/// Provider to check if order is empty
@riverpod
bool isCashierOrderEmpty(Ref ref) {
  final order = ref.watch(cashierOrderProvider);
  return order.isEmpty;
}

/// Simple state holder for edit mode
final cashierEditModeProvider = StateProvider<CashierEditMode?>((ref) => null);

/// Form data for cashier order panel (persists during navigation)
class CashierFormData {
  final String name;
  final String phone;
  final String address;
  final String note;
  final OrderType orderType;
  final DateTime? selectedDate;
  final DateTime? selectedSlot;

  const CashierFormData({
    this.name = '',
    this.phone = '',
    this.address = '',
    this.note = '',
    this.orderType = OrderType.takeaway,
    this.selectedDate,
    this.selectedSlot,
  });

  CashierFormData copyWith({
    String? name,
    String? phone,
    String? address,
    String? note,
    OrderType? orderType,
    DateTime? selectedDate,
    DateTime? selectedSlot,
    bool clearSlot = false,
  }) {
    return CashierFormData(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      note: note ?? this.note,
      orderType: orderType ?? this.orderType,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedSlot: clearSlot ? null : (selectedSlot ?? this.selectedSlot),
    );
  }

  bool get isEmpty =>
      name.isEmpty && phone.isEmpty && address.isEmpty && note.isEmpty;
}

/// Provider for cashier form data (keepAlive to persist during navigation)
final cashierFormDataProvider = StateProvider<CashierFormData>(
  (ref) => const CashierFormData(),
);

/// Helper class for loading orders into cashier
class CashierOrderLoader {
  /// Load an existing order for editing.
  /// Creates CashierOrderItems from OrderItemModels.
  static void loadFromOrder(
    OrderModel order,
    List<MenuItemModel> menuItems,
    WidgetRef ref,
  ) {
    // Clear existing items
    ref.read(cashierOrderProvider.notifier).clear();

    // Set edit mode
    ref.read(cashierEditModeProvider.notifier).state = CashierEditMode(
      originalOrderId: order.id,
      originalNumeroOrdine: order.numeroOrdine,
      customerName: order.nomeCliente,
      customerPhone: order.telefonoCliente,
      customerAddress: order.indirizzoConsegna,
      note: order.note,
      orderType: order.tipo,
      slotPrenotatoStart: order.slotPrenotatoStart,
    );

    // Convert each order item to a cashier order item
    for (final orderItem in order.items) {
      // Try to find the original menu item
      final menuItem = menuItems.firstWhere(
        (m) => m.id == orderItem.menuItemId,
        orElse: () => _createPlaceholderMenuItem(orderItem),
      );

      // Parse variants to reconstruct customizations
      final variants = orderItem.varianti ?? {};

      // Reconstruct size if present
      SizeVariantModel? selectedSize;
      if (variants['size'] != null) {
        final sizeData = variants['size'] as Map<String, dynamic>;
        selectedSize = SizeVariantModel(
          id: sizeData['id'] as String? ?? '',
          slug: (sizeData['id'] as String? ?? '').toLowerCase(),
          nome: (sizeData['name'] as String?)?.split(' (').first ?? '',
          descrizione: null,
          priceMultiplier:
              (sizeData['priceMultiplier'] as num?)?.toDouble() ?? 1.0,
          ordine: 0,
          createdAt: DateTime.now(),
        );
      }

      // Reconstruct added ingredients
      List<SelectedIngredient> addedIngredients = [];
      if (variants['addedIngredients'] != null) {
        final addedList = variants['addedIngredients'] as List;
        addedIngredients = addedList.map((ing) {
          final ingMap = ing as Map<String, dynamic>;
          return SelectedIngredient(
            ingredientId: ingMap['id'] as String? ?? '',
            ingredientName: ingMap['name'] as String? ?? '',
            unitPrice: (ingMap['price'] as num?)?.toDouble() ?? 0.0,
            quantity: ingMap['quantity'] as int? ?? 1,
          );
        }).toList();
      }

      // Reconstruct removed ingredients
      List<IngredientModel> removedIngredients = [];
      if (variants['removedIngredients'] != null) {
        final removedList = variants['removedIngredients'] as List;
        removedIngredients = removedList.map((ing) {
          final ingMap = ing as Map<String, dynamic>;
          return IngredientModel(
            id: ingMap['id'] as String? ?? '',
            nome: ingMap['name'] as String? ?? '',
            prezzo: 0.0,
            createdAt: DateTime.now(),
          );
        }).toList();
      }

      // Reconstruct special options (for split products)
      List<SpecialOption> specialOptions = [];
      if (variants['specialOptions'] != null) {
        final optionsList = variants['specialOptions'] as List;
        specialOptions = optionsList.map((opt) {
          final optMap = opt as Map<String, dynamic>;
          return SpecialOption(
            id: optMap['id'] as String? ?? '',
            name: optMap['name'] as String? ?? '',
            price: (optMap['price'] as num?)?.toDouble() ?? 0.0,
            description: optMap['description'] as String?,
            productId: optMap['productId'] as String?,
          );
        }).toList();
      }

      // Get note from variants or item
      String? note = variants['note'] as String? ?? orderItem.note;

      // Calculate the correct base price by subtracting ingredient costs
      // from prezzoUnitario. This is necessary because prezzoUnitario already
      // includes ingredient costs, but CartItemModel.totalPrice will add them again.
      double ingredientsCost = 0.0;
      for (final ing in addedIngredients) {
        ingredientsCost += ing.unitPrice * ing.quantity;
      }

      // Also account for special options (split products store price in options)
      double specialOptionsCost = 0.0;
      for (final opt in specialOptions) {
        specialOptionsCost += opt.price;
      }

      final correctedBasePrice =
          orderItem.prezzoUnitario - ingredientsCost - specialOptionsCost;

      // Create cart item
      final cartItem = CartItemModel(
        menuItemId: orderItem.menuItemId ?? menuItem.id,
        nome: orderItem.nomeProdotto,
        basePrice: correctedBasePrice,
        quantity: orderItem.quantita,
        selectedSize: selectedSize,
        addedIngredients: addedIngredients,
        removedIngredients: removedIngredients,
        specialOptions: specialOptions,
        note: note,
      );

      final uniqueId =
          DateTime.now().millisecondsSinceEpoch.toString() +
          orderItem.id.hashCode.toString();

      // Check if split product
      final isSplit = variants['isSplit'] == true || orderItem.isSplitProduct;
      MenuItemModel? secondMenuItem;
      if (isSplit && variants['secondProduct'] != null) {
        final secondData = variants['secondProduct'] as Map<String, dynamic>;
        secondMenuItem = menuItems.firstWhere(
          (m) => m.id == secondData['id'],
          orElse: () => MenuItemModel(
            id: secondData['id'] as String? ?? '',
            nome: secondData['name'] as String? ?? '',
            descrizione: '',
            prezzo: 0.0,
            disponibile: true,
            createdAt: DateTime.now(),
          ),
        );
      }

      // Add item directly to provider
      ref
          .read(cashierOrderProvider.notifier)
          .addLoadedItem(
            CashierOrderItem(
              menuItem: menuItem,
              cartItem: cartItem,
              uniqueId: uniqueId,
              secondMenuItem: secondMenuItem,
              isSplit: isSplit,
            ),
          );
    }
  }

  /// Create a placeholder menu item when original is not found
  static MenuItemModel _createPlaceholderMenuItem(OrderItemModel orderItem) {
    return MenuItemModel(
      id: orderItem.menuItemId ?? 'placeholder-${orderItem.id}',
      nome: orderItem.nomeProdotto,
      descrizione: '',
      prezzo: orderItem.prezzoUnitario,
      disponibile: true,
      createdAt: DateTime.now(),
    );
  }

  /// Clear edit mode
  static void clearEditMode(WidgetRef ref) {
    ref.read(cashierEditModeProvider.notifier).state = null;
  }
}
