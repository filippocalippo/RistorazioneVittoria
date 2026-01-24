/// Centralized, authoritative price calculation service
///
/// This service is the SINGLE SOURCE OF TRUTH for all prices in the app.
/// It accepts ONLY identifiers as input (not prices) and calculates
/// all prices from scratch using the provided data.
///
/// Usage:
/// ```dart
/// final calculator = OrderPriceCalculator(
///   menuItems: [...],
///   sizeAssignments: [...],
///   sizes: [...],
///   ingredients: [...],
///   deliveryConfig: settings.deliveryConfiguration,
/// );
///
/// final price = calculator.calculateItemPrice(
///   OrderItemInput(menuItemId: 'abc', sizeId: 'large', quantity: 2),
/// );
/// ```
library;

import 'dart:math' as math;

import '../models/menu_item_model.dart';
import '../models/menu_item_size_assignment_model.dart';
import '../models/size_variant_model.dart';
import '../models/ingredient_model.dart';
import '../utils/enums.dart';
import 'order_price_models.dart';

/// A single radial delivery fee tier
class RadialDeliveryTier {
  final double km;
  final double price;

  const RadialDeliveryTier({required this.km, required this.price});

  factory RadialDeliveryTier.fromJson(Map<String, dynamic> json) {
    return RadialDeliveryTier(
      km: (json['km'] as num?)?.toDouble() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Configuration for delivery fee calculation
class DeliveryFeeConfig {
  /// Base delivery cost (fixed mode)
  final double costoConsegnaBase;

  /// Threshold for free delivery
  final double consegnaGratuitaSopra;

  /// Calculation type: 'fisso' or 'radiale'
  final String tipoCalcoloConsegna;

  /// Radial fee tiers (sorted by km ascending)
  final List<RadialDeliveryTier> radialTiers;

  /// Price for deliveries outside all radii
  final double prezzoFuoriRaggio;

  /// Shop location (for distance calculation)
  final double? shopLatitude;
  final double? shopLongitude;

  const DeliveryFeeConfig({
    required this.costoConsegnaBase,
    required this.consegnaGratuitaSopra,
    this.tipoCalcoloConsegna = 'fisso',
    this.radialTiers = const [],
    this.prezzoFuoriRaggio = 0,
    this.shopLatitude,
    this.shopLongitude,
  });

  /// Calculate delivery fee based on distance
  /// Returns null if distance cannot be calculated (no coords) - use fixed fee
  double? calculateRadialFee(double? deliveryLat, double? deliveryLng) {
    if (tipoCalcoloConsegna != 'radiale') return null;
    if (shopLatitude == null || shopLongitude == null) return null;
    if (deliveryLat == null || deliveryLng == null) return null;
    if (radialTiers.isEmpty) return null;

    final distance = _haversineDistance(
      shopLatitude!,
      shopLongitude!,
      deliveryLat,
      deliveryLng,
    );

    // Sort tiers by km ascending and find first tier that contains the distance
    final sortedTiers = List<RadialDeliveryTier>.from(radialTiers)
      ..sort((a, b) => a.km.compareTo(b.km));

    for (final tier in sortedTiers) {
      if (distance <= tier.km) {
        return tier.price;
      }
    }

    // Outside all radii
    return prezzoFuoriRaggio;
  }

  /// Haversine distance in km
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double deg) => deg * math.pi / 180;
}

/// Authoritative price calculator
///
/// Accepts only IDs as input and calculates prices from provided data.
/// This ensures prices cannot be influenced by stale or incorrect values.
class OrderPriceCalculator {
  final List<MenuItemModel> menuItems;
  final List<MenuItemSizeAssignmentModel> sizeAssignments;
  final List<SizeVariantModel> sizes;
  final List<IngredientModel> ingredients;
  final DeliveryFeeConfig? deliveryConfig;

  const OrderPriceCalculator({
    required this.menuItems,
    required this.sizeAssignments,
    required this.sizes,
    required this.ingredients,
    this.deliveryConfig,
  });

  /// Calculate price for a single order item
  CalculatedItemPrice calculateItemPrice(OrderItemInput input) {
    // Handle zero/negative quantity edge case
    if (input.quantity <= 0) {
      return const CalculatedItemPrice(
        unitPrice: 0.0,
        subtotal: 0.0,
        quantity: 0,
        breakdown: PriceBreakdown(basePrice: 0.0, ingredientsCost: 0.0),
      );
    }

    // Handle split products
    if (input.isSplit && input.secondProductId != null) {
      return _calculateSplitItemPrice(input);
    }

    // Calculate regular item
    return _calculateRegularItemPrice(input);
  }

  /// Calculate price for a regular (non-split) item
  CalculatedItemPrice _calculateRegularItemPrice(OrderItemInput input) {
    // 1. Find the menu item
    final menuItem = _findMenuItem(input.menuItemId);
    if (menuItem == null) {
      return CalculatedItemPrice(
        unitPrice: 0.0,
        subtotal: 0.0,
        quantity: input.quantity,
        breakdown: const PriceBreakdown(basePrice: 0.0, ingredientsCost: 0.0),
      );
    }

    // 2. Calculate base price (with size if applicable)
    final basePrice = _calculateBasePrice(menuItem, input.sizeId);

    // 3. Calculate ingredients cost
    final ingredientsCost = _calculateIngredientsCost(
      input.addedIngredients,
      input.sizeId,
    );

    // 4. Calculate final prices
    final unitPrice = basePrice + ingredientsCost;
    final subtotal = unitPrice * input.quantity;

    return CalculatedItemPrice(
      unitPrice: unitPrice,
      subtotal: subtotal,
      quantity: input.quantity,
      breakdown: PriceBreakdown(
        basePrice: basePrice,
        ingredientsCost: ingredientsCost,
      ),
    );
  }

  /// Calculate price for a split (half & half) item
  CalculatedItemPrice _calculateSplitItemPrice(OrderItemInput input) {
    // 1. Find both menu items
    final firstItem = _findMenuItem(input.menuItemId);
    final secondItem = _findMenuItem(input.secondProductId!);

    if (firstItem == null || secondItem == null) {
      return CalculatedItemPrice(
        unitPrice: 0.0,
        subtotal: 0.0,
        quantity: input.quantity,
        breakdown: const PriceBreakdown(basePrice: 0.0, ingredientsCost: 0.0),
      );
    }

    // 2. Calculate first product total (base + ingredients)
    final firstBase = _calculateBasePrice(firstItem, input.sizeId);
    final firstIngredients = _calculateIngredientsCost(
      input.addedIngredients,
      input.sizeId,
    );
    final firstTotal = firstBase + firstIngredients;

    // 3. Calculate second product total (base + ingredients)
    final secondBase = _calculateBasePrice(secondItem, input.secondSizeId);
    final secondIngredients = _calculateIngredientsCost(
      input.secondAddedIngredients,
      input.secondSizeId,
    );
    final secondTotal = secondBase + secondIngredients;

    // 4. Average the two totals
    final rawAverage = (firstTotal + secondTotal) / 2;

    // 5. Round UP to nearest €0.50
    final roundedUnitPrice = (rawAverage * 2).ceil() / 2.0;

    // 6. Calculate subtotal
    final subtotal = roundedUnitPrice * input.quantity;

    return CalculatedItemPrice(
      unitPrice: roundedUnitPrice,
      subtotal: subtotal,
      quantity: input.quantity,
      breakdown: PriceBreakdown(
        basePrice: firstBase,
        ingredientsCost: firstIngredients,
        secondBasePrice: secondBase,
        secondIngredientsCost: secondIngredients,
        wasRounded: true,
        rawPriceBeforeRounding: rawAverage,
      ),
    );
  }

  /// Calculate base price for a product with optional size
  double _calculateBasePrice(MenuItemModel menuItem, String? sizeId) {
    // Get effective base price (discounted if available)
    final effectivePrice = menuItem.prezzoEffettivo;

    // If no size selected, return base price
    if (sizeId == null) {
      return effectivePrice;
    }

    // Check for product-specific priceOverride first
    final assignment = sizeAssignments
        .where((a) => a.menuItemId == menuItem.id && a.sizeId == sizeId)
        .firstOrNull;

    if (assignment?.priceOverride != null) {
      // Use direct override - ignores multiplier
      return assignment!.priceOverride!;
    }

    // Fall back to size multiplier
    final size = sizes.where((s) => s.id == sizeId).firstOrNull;
    if (size != null) {
      return effectivePrice * size.priceMultiplier;
    }

    // Size not found, return base price
    return effectivePrice;
  }

  /// Calculate total cost of added ingredients
  double _calculateIngredientsCost(
    List<IngredientSelection> selections,
    String? sizeId,
  ) {
    double total = 0.0;

    for (final selection in selections) {
      final ingredient = ingredients
          .where((i) => i.id == selection.ingredientId)
          .firstOrNull;

      if (ingredient != null) {
        // Use size-specific price if available
        final price = ingredient.getPriceForSize(sizeId);
        total += price * selection.quantity;
      }
    }

    return total;
  }

  /// Find menu item by ID
  MenuItemModel? _findMenuItem(String id) {
    return menuItems.where((m) => m.id == id).firstOrNull;
  }

  /// Calculate total for an entire order
  CalculatedOrderTotal calculateOrderTotal(OrderTotalInput input) {
    // Calculate each item
    final calculatedItems = <CalculatedItemPrice>[];
    double subtotal = 0.0;

    for (final item in input.items) {
      final calculated = calculateItemPrice(item);
      calculatedItems.add(calculated);
      subtotal += calculated.subtotal;
    }

    // Calculate delivery fee
    double deliveryFee = 0.0;
    if (input.orderType == OrderType.delivery && deliveryConfig != null) {
      // Check if free delivery applies
      if (subtotal >= deliveryConfig!.consegnaGratuitaSopra) {
        deliveryFee = 0.0;
      } else {
        // Try radial calculation first
        final radialFee = deliveryConfig!.calculateRadialFee(
          input.deliveryLatitude,
          input.deliveryLongitude,
        );
        if (radialFee != null) {
          deliveryFee = radialFee;
        } else {
          // Fall back to fixed fee
          deliveryFee = deliveryConfig!.costoConsegnaBase;
        }
      }
    }

    return CalculatedOrderTotal(
      items: calculatedItems,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      total: subtotal + deliveryFee,
    );
  }
}
