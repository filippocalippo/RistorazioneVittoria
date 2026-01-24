import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../core/models/menu_item_model.dart';
import '../core/models/cart_item_model.dart';
import '../core/models/size_variant_model.dart';
import '../core/models/ingredient_model.dart';
import '../core/models/product_configuration_model.dart';
import '../core/services/order_price_calculator.dart';
import '../core/services/order_price_models.dart';

part 'cart_provider.g.dart';

/// Wrapper class to combine MenuItem with CartItemModel
class CartItem {
  final MenuItemModel menuItem;
  final CartItemModel cartItem;

  CartItem({required this.menuItem, required this.cartItem});

  double get subtotal => cartItem.totalPrice;
  int get quantity => cartItem.quantity;
  String? get note => cartItem.note;

  CartItem copyWith({MenuItemModel? menuItem, CartItemModel? cartItem}) {
    return CartItem(
      menuItem: menuItem ?? this.menuItem,
      cartItem: cartItem ?? this.cartItem,
    );
  }
}

@riverpod
class Cart extends _$Cart {
  static const String _storageKey = 'cart_items';

  @override
  List<CartItem> build() {
    _loadFromStorage();
    return [];
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_storageKey);

      if (cartJson != null) {
        final List<dynamic> decoded = json.decode(cartJson);
        final loadedCart = decoded.map((item) {
          return CartItem(
            menuItem: MenuItemModel.fromJson(item['menuItem']),
            cartItem: CartItemModel.fromJson(item['cartItem']),
          );
        }).toList();

        state = loadedCart;
      }
    } catch (e) {
      // If loading fails, start with empty cart
      state = [];
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = state
          .map(
            (item) => {
              'menuItem': item.menuItem.toJson(),
              'cartItem': item.cartItem.toJson(),
            },
          )
          .toList();

      await prefs.setString(_storageKey, json.encode(cartData));
    } catch (e) {
      // Silently fail - cart will still work in memory
    }
  }

  /// Add item without customizations (backward compatibility)
  void addItem(MenuItemModel menuItem, {int quantity = 1, String? note}) {
    final cartItemModel = CartItemModel(
      menuItemId: menuItem.id,
      nome: menuItem.nome,
      basePrice: menuItem.prezzoEffettivo,
      quantity: quantity,
      note: note,
    );

    final existingIndex = state.indexWhere(
      (item) =>
          item.menuItem.id == menuItem.id &&
          item.cartItem.hasSameCustomizations(cartItemModel),
    );

    if (existingIndex >= 0) {
      // Update existing quantity
      final existing = state[existingIndex];
      final updatedCartItem = existing.cartItem.copyWith(
        quantity: existing.cartItem.quantity + quantity,
      );
      state = [
        ...state.sublist(0, existingIndex),
        existing.copyWith(cartItem: updatedCartItem),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      // Add new item
      state = [...state, CartItem(menuItem: menuItem, cartItem: cartItemModel)];
    }
    _saveToStorage();
  }

  double _calculateSplitBasePrice(
    MenuItemModel product,
    SizeVariantModel? size,
  ) {
    var price = product.prezzoEffettivo;
    if (size != null) {
      price = size.calculatePrice(price);
    }
    return price;
  }

  double _roundToNearestHalf(double value) {
    // Keep prices in steps of 0.50, matching the split modal display
    // Round UP to nearest integer (ceil), then divide by 2
    final scaled = (value * 2).ceil();
    return scaled / 2.0;
  }

  /// Add item with full customizations (sizes, ingredients, notes)
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

    // Check if an identical item exists (same customizations)
    final existingIndex = state.indexWhere(
      (item) =>
          item.menuItem.id == menuItem.id &&
          item.cartItem.hasSameCustomizations(cartItemModel),
    );

    if (existingIndex >= 0) {
      // Update existing quantity
      final existing = state[existingIndex];
      final updatedCartItem = existing.cartItem.copyWith(
        quantity: existing.cartItem.quantity + quantity,
      );
      state = [
        ...state.sublist(0, existingIndex),
        existing.copyWith(cartItem: updatedCartItem),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      // Add new item with customizations
      state = [...state, CartItem(menuItem: menuItem, cartItem: cartItemModel)];
    }
    _saveToStorage();
  }

  /// Remove specific cart item by index
  void removeItemAtIndex(int index) {
    if (index >= 0 && index < state.length) {
      state = [...state.sublist(0, index), ...state.sublist(index + 1)];
      _saveToStorage();
    }
  }

  /// Remove all items with the given menuItemId (backward compatibility)
  void removeItem(String menuItemId) {
    state = state.where((item) => item.menuItem.id != menuItemId).toList();
    _saveToStorage();
  }

  /// Update quantity for a specific cart item by index
  void updateQuantityAtIndex(int index, int quantity) {
    if (index < 0 || index >= state.length) return;

    if (quantity <= 0) {
      removeItemAtIndex(index);
      return;
    }

    final updatedCartItem = state[index].cartItem.copyWith(quantity: quantity);
    state = [
      ...state.sublist(0, index),
      state[index].copyWith(cartItem: updatedCartItem),
      ...state.sublist(index + 1),
    ];
    _saveToStorage();
  }

  /// Update quantity for first item with menuItemId (backward compatibility)
  void updateQuantity(String menuItemId, int quantity) {
    if (quantity <= 0) {
      removeItem(menuItemId);
      return;
    }

    final index = state.indexWhere((item) => item.menuItem.id == menuItemId);
    if (index >= 0) {
      updateQuantityAtIndex(index, quantity);
    }
  }

  /// Update note for specific cart item by index
  void updateNoteAtIndex(int index, String? note) {
    if (index < 0 || index >= state.length) return;

    final updatedCartItem = state[index].cartItem.copyWith(note: note);
    state = [
      ...state.sublist(0, index),
      state[index].copyWith(cartItem: updatedCartItem),
      ...state.sublist(index + 1),
    ];
    _saveToStorage();
  }

  /// Update note for first item with menuItemId (backward compatibility)
  void updateNote(String menuItemId, String? note) {
    final index = state.indexWhere((item) => item.menuItem.id == menuItemId);
    if (index >= 0) {
      updateNoteAtIndex(index, note);
    }
  }

  /// Replace an item at a specific index with new customizations
  ///
  /// [effectiveBasePrice] - If provided, uses this as the base price (already includes size pricing).
  void replaceItemAtIndex(
    int index,
    MenuItemModel menuItem, {
    required int quantity,
    SizeVariantModel? selectedSize,
    List<SelectedIngredient>? addedIngredients,
    List<IngredientModel>? removedIngredients,
    String? note,
    double? effectiveBasePrice,
  }) {
    if (index < 0 || index >= state.length) return;

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

    state = [
      ...state.sublist(0, index),
      CartItem(menuItem: menuItem, cartItem: cartItemModel),
      ...state.sublist(index + 1),
    ];
    _saveToStorage();
  }

  /// Add a split item - two products at average price with modifications
  ///
  /// [preCalculatedTotal] - If provided, uses this as the final unit price.
  ///                        This should be used when the caller has access to MenuItemSizeAssignmentModel
  ///                        which may have a priceOverride.
  void addSplitItem({
    required MenuItemModel firstProduct,
    required MenuItemModel secondProduct,
    int quantity = 1,
    // First product modifications
    SizeVariantModel? firstProductSize,
    List<SelectedIngredient>? firstProductAddedIngredients,
    List<IngredientModel>? firstProductRemovedIngredients,
    // Second product modifications
    SizeVariantModel? secondProductSize,
    List<SelectedIngredient>? secondProductAddedIngredients,
    List<IngredientModel>? secondProductRemovedIngredients,
    // Note for the split item
    String? note,
    // Pre-calculated total (from modal with priceOverride support)
    double? preCalculatedTotal,
  }) {
    double roundedUnitPrice;
    double extrasTotalSum;

    if (preCalculatedTotal != null) {
      // Use pre-calculated total from modal (respects priceOverride)
      roundedUnitPrice = preCalculatedTotal;

      // Calculate extras total for base price calculation
      double extrasTotal(List<SelectedIngredient>? list) {
        if (list == null) return 0.0;
        return list.fold(0.0, (sum, ing) => sum + ing.unitPrice * ing.quantity);
      }

      final firstExtrasFull = extrasTotal(firstProductAddedIngredients);
      final secondExtrasFull = extrasTotal(secondProductAddedIngredients);
      extrasTotalSum = (firstExtrasFull + secondExtrasFull) / 2;
    } else {
      // Fallback: calculate using size multiplier only (no priceOverride support)
      // Reproduce the modal's pricing logic for split items:
      // 1. For each half: base/2 (with size) + full extras.
      // 2. Sum the two halves.
      // 3. Round the final result to nearest 0.50.
      final firstBaseNoExtras = _calculateSplitBasePrice(
        firstProduct,
        firstProductSize,
      );
      final secondBaseNoExtras = _calculateSplitBasePrice(
        secondProduct,
        secondProductSize,
      );

      double extrasTotal(List<SelectedIngredient>? list) {
        if (list == null) return 0.0;
        return list.fold(0.0, (sum, ing) => sum + ing.unitPrice * ing.quantity);
      }

      final firstExtrasFull = extrasTotal(firstProductAddedIngredients);
      final secondExtrasFull = extrasTotal(secondProductAddedIngredients);

      // Calculate total: ((Base1 + Extras1) + (Base2 + Extras2)) / 2
      final rawTotal =
          ((firstBaseNoExtras + firstExtrasFull) +
              (secondBaseNoExtras + secondExtrasFull)) /
          2;
      roundedUnitPrice = _roundToNearestHalf(rawTotal);
      extrasTotalSum = (firstExtrasFull + secondExtrasFull) / 2;
    }

    // Extras are still represented separately in the cart with full unit prices.
    // Compute their total per split item so we can back out a base price that,
    // when combined with extras, equals the roundedUnitPrice.
    final baseAveragePrice = roundedUnitPrice - extrasTotalSum;

    // Create display name
    final displayName = '${firstProduct.nome} + ${secondProduct.nome} (Diviso)';

    // Store split product info in special options for kitchen display
    final splitOptions = <SpecialOption>[];

    // First product
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

    // Second product
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
    final allAddedIngredients = <SelectedIngredient>[];
    if (firstProductAddedIngredients != null) {
      for (var ing in firstProductAddedIngredients) {
        allAddedIngredients.add(
          SelectedIngredient(
            ingredientId: ing.ingredientId,
            ingredientName: '${ing.ingredientName}: ${firstProduct.nome}',
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
            ingredientName: '${ing.ingredientName}: ${secondProduct.nome}',
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
            nome: '${ing.nome}: ${firstProduct.nome}',
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
            nome: '${ing.nome}: ${secondProduct.nome}',
            prezzo: ing.prezzo,
            createdAt: ing.createdAt,
          ),
        );
      }
    }

    // Use first product's ID as the menu_item_id for database compatibility
    // Store all modifications in proper fields for display
    final cartItemModel = CartItemModel(
      menuItemId: firstProduct.id,
      nome: displayName,
      basePrice: baseAveragePrice,
      quantity: quantity,
      selectedSize: firstProductSize, // Shared size (both use same size)
      addedIngredients: allAddedIngredients,
      removedIngredients: allRemovedIngredients,
      specialOptions: splitOptions, // Keep for additional context
      note: note,
    );

    // Create a virtual menu item for the split
    // Use first product's ID to ensure valid UUID format
    final splitMenuItem = MenuItemModel(
      id: firstProduct.id,
      categoriaId: firstProduct.categoriaId,
      nome: displayName,
      descrizione:
          'Prodotto diviso: ${firstProduct.nome} e ${secondProduct.nome}',
      prezzo: baseAveragePrice, // Base average price for database
      immagineUrl: firstProduct.immagineUrl,
      createdAt: DateTime.now(),
    );

    // Check if identical split item exists
    final existingIndex = state.indexWhere(
      (item) =>
          item.menuItem.id == splitMenuItem.id &&
          item.cartItem.hasSameCustomizations(cartItemModel),
    );

    if (existingIndex >= 0) {
      // Update existing quantity
      final existing = state[existingIndex];
      final updatedCartItem = existing.cartItem.copyWith(
        quantity: existing.cartItem.quantity + quantity,
      );
      state = [
        ...state.sublist(0, existingIndex),
        existing.copyWith(cartItem: updatedCartItem),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      // Add new split item
      state = [
        ...state,
        CartItem(menuItem: splitMenuItem, cartItem: cartItemModel),
      ];
    }
    _saveToStorage();
  }

  /// Validate and correct prices using the authoritative OrderPriceCalculator.
  /// Call this after modifying items to ensure UI prices match calculated prices.
  /// Returns the number of items that were corrected.
  int validateAndCorrectPrices(OrderPriceCalculator calculator) {
    int correctedCount = 0;
    final newState = <CartItem>[];

    for (final item in state) {
      // Check if this is a split product
      final isSplit = item.cartItem.nome.contains('(Diviso)');

      // Build input for calculator
      final OrderItemInput input;

      if (isSplit) {
        // Split product - get product IDs from specialOptions
        String? firstProductId;
        String? secondProductId;
        for (final opt in item.cartItem.specialOptions) {
          if (opt.id == 'split_first') firstProductId = opt.productId;
          if (opt.id == 'split_second') secondProductId = opt.productId;
        }

        if (firstProductId == null || secondProductId == null) {
          // Can't validate without product IDs
          newState.add(item);
          continue;
        }

        // Separate ingredients by product name suffix
        final firstProductIngredients = <IngredientSelection>[];
        final secondProductIngredients = <IngredientSelection>[];

        for (final ing in item.cartItem.addedIngredients) {
          // Get second product name from special options
          final secondOpt = item.cartItem.specialOptions
              .where((o) => o.id == 'split_second')
              .firstOrNull;

          if (secondOpt != null &&
              ing.ingredientName.contains(': ${secondOpt.name}')) {
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
          menuItemId: firstProductId,
          sizeId: item.cartItem.selectedSize?.id,
          addedIngredients: firstProductIngredients,
          quantity: item.quantity,
          isSplit: true,
          secondProductId: secondProductId,
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
        debugPrint('[PriceValidator] Correcting ${item.cartItem.nome}:');
        debugPrint('  UI price: €${currentSubtotal.toStringAsFixed(2)}');
        debugPrint('  Correct: €${calculated.subtotal.toStringAsFixed(2)}');
        debugPrint(
          '  Difference: €${(calculated.subtotal - currentSubtotal).toStringAsFixed(2)}',
        );

        // Calculate the correct basePrice
        double newBasePrice;
        if (isSplit) {
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
      _saveToStorage();
      debugPrint('[PriceValidator] Corrected $correctedCount item(s)');
    }

    return correctedCount;
  }

  void clear() {
    state = [];
    _saveToStorage();
  }
}

/// Provider per subtotale carrello
@riverpod
double cartSubtotal(Ref ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.subtotal);
}

/// Provider per totale items nel carrello
@riverpod
int cartItemCount(Ref ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
}

/// Provider per verificare se il carrello è vuoto
@riverpod
bool isCartEmpty(Ref ref) {
  final cart = ref.watch(cartProvider);
  return cart.isEmpty;
}
