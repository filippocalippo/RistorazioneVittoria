import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../core/models/menu_item_model.dart';
import '../core/models/cart_item_model.dart';
import '../core/models/size_variant_model.dart';
import '../core/models/ingredient_model.dart';
import '../core/models/product_configuration_model.dart';
import '../core/services/order_price_calculator.dart';
import '../core/services/order_price_models.dart';
import '../core/utils/logger.dart';
import 'organization_provider.dart';

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

/// Cart Provider - properly watches organization changes
@riverpod
class Cart extends _$Cart {
  /// Get organization-scoped storage key
  String _getStorageKey(String? orgId) {
    return orgId != null ? 'cart_items_$orgId' : 'cart_items';
  }

  @override
  Future<List<CartItem>> build() async {
    // CRITICAL FIX: Watch organization provider to react to changes
    final orgId = await ref.watch(currentOrganizationProvider.future);
    return await _loadFromStorage(orgId);
  }

  Future<List<CartItem>> _loadFromStorage(String? orgId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_getStorageKey(orgId));

      if (cartJson != null) {
        final List<dynamic> decoded = json.decode(cartJson);
        final loadedCart = decoded.map((item) {
          return CartItem(
            menuItem: MenuItemModel.fromJson(item['menuItem']),
            cartItem: CartItemModel.fromJson(item['cartItem']),
          );
        }).toList();

        // Validate cart items against current menu
        final validatedCart = await _validateCartItems(loadedCart, orgId);
        return validatedCart;
      }
      return [];
    } catch (e) {
      // If loading fails, start with empty cart
      Logger.warning('Failed to load cart from storage: $e', tag: 'Cart');
      return [];
    }
  }

  /// Validate cart items against current menu
  /// Removes items that no longer exist or are unavailable
  /// Updates prices if they've changed
  Future<List<CartItem>> _validateCartItems(List<CartItem> cartItems, String? orgId) async {
    if (cartItems.isEmpty) return [];
    if (orgId == null) {
      Logger.warning('Cannot validate cart without organization context', tag: 'Cart');
      return cartItems; // Return as-is if no org context
    }

    try {
      // Fetch current menu items from database
      final client = Supabase.instance.client;
      final menuItemIds = cartItems.map((item) => item.menuItem.id).toSet().toList();

      final response = await client
          .from('menu_items')
          .select('id, nome, prezzo, prezzo_scontato, disponibile, attivo')
          .inFilter('id', menuItemIds)
          .eq('organization_id', orgId);

      final currentMenuItems = <String, Map<String, dynamic>>{};
      for (final item in response) {
        currentMenuItems[item['id'] as String] = item;
      }

      final validatedItems = <CartItem>[];
      final removedItems = <String>[];
      final updatedItems = <String>[];

      for (final cartItem in cartItems) {
        final menuData = currentMenuItems[cartItem.menuItem.id];

        // Check if item still exists
        if (menuData == null) {
          removedItems.add(cartItem.menuItem.nome);
          Logger.debug(
            'Removed cart item: ${cartItem.menuItem.nome} (no longer in menu)',
            tag: 'Cart',
          );
          continue;
        }

        // Check if item is still available
        final isAvailable = (menuData['disponibile'] as bool?) ?? true;
        final isActive = (menuData['attivo'] as bool?) ?? true;

        if (!isAvailable || !isActive) {
          removedItems.add(cartItem.menuItem.nome);
          Logger.debug(
            'Removed cart item: ${cartItem.menuItem.nome} (unavailable or inactive)',
            tag: 'Cart',
          );
          continue;
        }

        // Check if price has changed
        final currentPrice = (menuData['prezzo'] as num).toDouble();
        final currentDiscountedPrice = menuData['prezzo_scontato'] != null
            ? (menuData['prezzo_scontato'] as num).toDouble()
            : null;
        final effectivePrice = currentDiscountedPrice ?? currentPrice;

        // Compare with stored menu item price
        final storedPrice = cartItem.menuItem.prezzo;
        final storedDiscountedPrice = cartItem.menuItem.prezzoScontato;

        if (storedPrice != currentPrice || storedDiscountedPrice != currentDiscountedPrice) {
          // Update the menu item with current prices
          final updatedMenuItem = cartItem.menuItem.copyWith(
            prezzo: currentPrice,
            prezzoScontato: currentDiscountedPrice,
            nome: menuData['nome'] as String, // Also update name in case it changed
          );

          // Update cart item base price
          double newBasePrice = effectivePrice;
          if (cartItem.cartItem.selectedSize != null) {
            newBasePrice = cartItem.cartItem.selectedSize!.calculatePrice(effectivePrice);
          }

          final updatedCartItem = cartItem.cartItem.copyWith(
            basePrice: newBasePrice,
          );

          validatedItems.add(CartItem(
            menuItem: updatedMenuItem,
            cartItem: updatedCartItem,
          ));

          updatedItems.add(cartItem.menuItem.nome);
          Logger.debug(
            'Updated cart item price: ${cartItem.menuItem.nome} '
            '(€${storedDiscountedPrice ?? storedPrice} → €$effectivePrice)',
            tag: 'Cart',
          );
        } else {
          // Item unchanged, keep as-is
          validatedItems.add(cartItem);
        }
      }

      // Log summary if any changes were made
      if (removedItems.isNotEmpty || updatedItems.isNotEmpty) {
        Logger.info(
          'Cart validation complete: ${removedItems.length} items removed, '
          '${updatedItems.length} items updated',
          tag: 'Cart',
        );

        // Save validated cart back to storage
        _saveToStorage(validatedItems, orgId);
      }

      return validatedItems;
    } catch (e) {
      Logger.error('Error validating cart items: $e', tag: 'Cart');
      // Return original cart if validation fails
      return cartItems;
    }
  }

  Future<void> _saveToStorage(List<CartItem> cartItems, String? orgId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = cartItems
          .map(
            (item) => {
              'menuItem': item.menuItem.toJson(),
              'cartItem': item.cartItem.toJson(),
            },
          )
          .toList();

      await prefs.setString(_getStorageKey(orgId), json.encode(cartData));
    } catch (e) {
      // Silently fail - cart will still work in memory
    }
  }

  /// Clear cart for organization switch.
  /// Called when user switches to a different organization.
  Future<void> clearForOrganization(String? newOrgId) async {
    final prefs = await SharedPreferences.getInstance();

    // Clear legacy storage key (cleanup from before org-scoped cart)
    await prefs.remove('cart_items');

    // Load new org's cart
    final loaded = await _loadFromStorage(newOrgId);
    state = AsyncValue.data(loaded);
    Logger.debug('Cart cleared and reloaded for org switch to: $newOrgId', tag: 'Cart');
  }

  /// Add item without customizations (backward compatibility)
  Future<void> addItem(MenuItemModel menuItem, {int quantity = 1, String? note}) async {
    final cartItemModel = CartItemModel(
      menuItemId: menuItem.id,
      nome: menuItem.nome,
      basePrice: menuItem.prezzoEffettivo,
      quantity: quantity,
      note: note,
    );

    final currentCart = state.value ?? [];
    final existingIndex = currentCart.indexWhere(
      (item) =>
          item.menuItem.id == menuItem.id &&
          item.cartItem.hasSameCustomizations(cartItemModel),
    );

    List<CartItem> newCart;
    if (existingIndex >= 0) {
      // Update existing quantity
      final existing = currentCart[existingIndex];
      final updatedCartItem = existing.cartItem.copyWith(
        quantity: existing.cartItem.quantity + quantity,
      );
      newCart = [
        ...currentCart.sublist(0, existingIndex),
        existing.copyWith(cartItem: updatedCartItem),
        ...currentCart.sublist(existingIndex + 1),
      ];
    } else {
      // Add new item
      newCart = [...currentCart, CartItem(menuItem: menuItem, cartItem: cartItemModel)];
    }

    state = AsyncValue.data(newCart);
    final orgId = await ref.read(currentOrganizationProvider.future);
    await _saveToStorage(newCart, orgId);
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
  Future<void> addItemWithCustomization(
    MenuItemModel menuItem, {
    required int quantity,
    SizeVariantModel? selectedSize,
    List<SelectedIngredient>? addedIngredients,
    List<IngredientModel>? removedIngredients,
    String? note,
    double? effectiveBasePrice,
  }) async {
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

    final currentCart = state.value ?? [];

    // Check if an identical item exists (same customizations)
    final existingIndex = currentCart.indexWhere(
      (item) =>
          item.menuItem.id == menuItem.id &&
          item.cartItem.hasSameCustomizations(cartItemModel),
    );

    List<CartItem> newCart;
    if (existingIndex >= 0) {
      // Update existing quantity
      final existing = currentCart[existingIndex];
      final updatedCartItem = existing.cartItem.copyWith(
        quantity: existing.cartItem.quantity + quantity,
      );
      newCart = [
        ...currentCart.sublist(0, existingIndex),
        existing.copyWith(cartItem: updatedCartItem),
        ...currentCart.sublist(existingIndex + 1),
      ];
    } else {
      // Add new item with customizations
      newCart = [
        ...currentCart,
        CartItem(menuItem: menuItem, cartItem: cartItemModel)
      ];
    }

    state = AsyncValue.data(newCart);
    final orgId = await ref.read(currentOrganizationProvider.future);
    await _saveToStorage(newCart, orgId);
  }

  /// Remove specific cart item by index
  Future<void> removeItemAtIndex(int index) async {
    final currentCart = state.value ?? [];
    if (index >= 0 && index < currentCart.length) {
      final newCart = [
        ...currentCart.sublist(0, index),
        ...currentCart.sublist(index + 1)
      ];
      state = AsyncValue.data(newCart);
      final orgId = await ref.read(currentOrganizationProvider.future);
      await _saveToStorage(newCart, orgId);
    }
  }

  /// Remove all items with the given menuItemId (backward compatibility)
  Future<void> removeItem(String menuItemId) async {
    final currentCart = state.value ?? [];
    final newCart = currentCart.where((item) => item.menuItem.id != menuItemId).toList();
    state = AsyncValue.data(newCart);
    final orgId = await ref.read(currentOrganizationProvider.future);
    await _saveToStorage(newCart, orgId);
  }

  /// Update quantity for a specific cart item by index
  Future<void> updateQuantityAtIndex(int index, int quantity) async {
    final currentCart = state.value ?? [];
    if (index < 0 || index >= currentCart.length) return;

    if (quantity <= 0) {
      await removeItemAtIndex(index);
      return;
    }

    final updatedCartItem = currentCart[index].cartItem.copyWith(quantity: quantity);
    final newCart = [
      ...currentCart.sublist(0, index),
      currentCart[index].copyWith(cartItem: updatedCartItem),
      ...currentCart.sublist(index + 1),
    ];
    state = AsyncValue.data(newCart);
    final orgId = await ref.read(currentOrganizationProvider.future);
    await _saveToStorage(newCart, orgId);
  }

  /// Update quantity for first item with menuItemId (backward compatibility)
  Future<void> updateQuantity(String menuItemId, int quantity) async {
    final currentCart = state.value ?? [];
    final index = currentCart.indexWhere((item) => item.menuItem.id == menuItemId);
    if (index >= 0) {
      await updateQuantityAtIndex(index, quantity);
    }
  }

  /// Update note for specific cart item by index
  Future<void> updateNoteAtIndex(int index, String? note) async {
    final currentCart = state.value ?? [];
    if (index < 0 || index >= currentCart.length) return;

    final updatedCartItem = currentCart[index].cartItem.copyWith(note: note);
    final newCart = [
      ...currentCart.sublist(0, index),
      currentCart[index].copyWith(cartItem: updatedCartItem),
      ...currentCart.sublist(index + 1),
    ];
    state = AsyncValue.data(newCart);
    final orgId = await ref.read(currentOrganizationProvider.future);
    await _saveToStorage(newCart, orgId);
  }

  /// Update note for first item with menuItemId (backward compatibility)
  Future<void> updateNote(String menuItemId, String? note) async {
    final currentCart = state.value ?? [];
    final index = currentCart.indexWhere((item) => item.menuItem.id == menuItemId);
    if (index >= 0) {
      await updateNoteAtIndex(index, note);
    }
  }

  /// Replace an item at a specific index with new customizations
  ///
  /// [effectiveBasePrice] - If provided, uses this as the base price (already includes size pricing).
  Future<void> replaceItemAtIndex(
    int index,
    MenuItemModel menuItem, {
    required int quantity,
    SizeVariantModel? selectedSize,
    List<SelectedIngredient>? addedIngredients,
    List<IngredientModel>? removedIngredients,
    String? note,
    double? effectiveBasePrice,
  }) async {
    final currentCart = state.value ?? [];
    if (index < 0 || index >= currentCart.length) return;

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

    final newCart = [
      ...currentCart.sublist(0, index),
      CartItem(menuItem: menuItem, cartItem: cartItemModel),
      ...currentCart.sublist(index + 1),
    ];
    state = AsyncValue.data(newCart);
    final orgId = await ref.read(currentOrganizationProvider.future);
    await _saveToStorage(newCart, orgId);
  }

  /// Add a split item - two products at average price with modifications
  ///
  /// [preCalculatedTotal] - If provided, uses this as the final unit price.
  ///                        This should be used when the caller has access to MenuItemSizeAssignmentModel
  ///                        which may have a priceOverride.
  Future<void> addSplitItem({
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
  }) async {
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

    final currentCart = state.value ?? [];

    // Check if identical split item exists
    final existingIndex = currentCart.indexWhere(
      (item) =>
          item.menuItem.id == splitMenuItem.id &&
          item.cartItem.hasSameCustomizations(cartItemModel),
    );

    List<CartItem> newCart;
    if (existingIndex >= 0) {
      // Update existing quantity
      final existing = currentCart[existingIndex];
      final updatedCartItem = existing.cartItem.copyWith(
        quantity: existing.cartItem.quantity + quantity,
      );
      newCart = [
        ...currentCart.sublist(0, existingIndex),
        existing.copyWith(cartItem: updatedCartItem),
        ...currentCart.sublist(existingIndex + 1),
      ];
    } else {
      // Add new split item
      newCart = [
        ...currentCart,
        CartItem(menuItem: splitMenuItem, cartItem: cartItemModel),
      ];
    }

    state = AsyncValue.data(newCart);
    final orgId = await ref.read(currentOrganizationProvider.future);
    await _saveToStorage(newCart, orgId);
  }

  /// Validate and correct prices using the authoritative OrderPriceCalculator.
  /// Call this after modifying items to ensure UI prices match calculated prices.
  /// Returns the number of items that were corrected.
  Future<int> validateAndCorrectPrices(OrderPriceCalculator calculator) async {
    final currentCart = state.value ?? [];
    if (currentCart.isEmpty) return 0;

    int correctedCount = 0;
    final newState = <CartItem>[];

    for (final item in currentCart) {
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
        Logger.debug('[PriceValidator] Correcting ${item.cartItem.nome}:', tag: 'Cart');
        Logger.debug('  UI price: €${currentSubtotal.toStringAsFixed(2)}', tag: 'Cart');
        Logger.debug('  Correct: €${calculated.subtotal.toStringAsFixed(2)}', tag: 'Cart');
        Logger.debug(
          '  Difference: €${(calculated.subtotal - currentSubtotal).toStringAsFixed(2)}',
          tag: 'Cart',
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
      state = AsyncValue.data(newState);
      final orgId = await ref.read(currentOrganizationProvider.future);
      await _saveToStorage(newState, orgId);
      Logger.debug('[PriceValidator] Corrected $correctedCount item(s)', tag: 'Cart');
    }

    return correctedCount;
  }

  Future<void> clear() async {
    state = const AsyncValue.data([]);
    final orgId = await ref.read(currentOrganizationProvider.future);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getStorageKey(orgId));
  }
}

/// Provider per subtotale carrello
@riverpod
double cartSubtotal(Ref ref) {
  final cartAsyncValue = ref.watch(cartProvider);
  final cart = cartAsyncValue.value ?? [];
  return cart.fold(0.0, (sum, item) => sum + item.subtotal);
}

/// Provider per totale items nel carrello
@riverpod
int cartItemCount(Ref ref) {
  final cartAsyncValue = ref.watch(cartProvider);
  final cart = cartAsyncValue.value ?? [];
  return cart.fold(0, (sum, item) => sum + item.quantity);
}

/// Provider per verificare se il carrello è vuoto
@riverpod
bool isCartEmpty(Ref ref) {
  final cartAsyncValue = ref.watch(cartProvider);
  final cart = cartAsyncValue.value ?? [];
  return cart.isEmpty;
}
