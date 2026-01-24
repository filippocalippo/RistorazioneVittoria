/// Input and output models for OrderPriceCalculator
///
/// These models contain ONLY identifiers (no prices) as inputs,
/// ensuring the calculator is the single source of truth for pricing.

library;

import '../utils/enums.dart';

/// Selection of an ingredient - only IDs and quantity, NO prices
class IngredientSelection {
  final String ingredientId;
  final int quantity;

  const IngredientSelection({required this.ingredientId, this.quantity = 1});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientSelection &&
          runtimeType == other.runtimeType &&
          ingredientId == other.ingredientId &&
          quantity == other.quantity;

  @override
  int get hashCode => ingredientId.hashCode ^ quantity.hashCode;
}

/// Input for calculating a single order item price
/// Contains ONLY identifiers, not pre-calculated prices
class OrderItemInput {
  /// Menu item ID
  final String menuItemId;

  /// Selected size ID (nullable for products without size)
  final String? sizeId;

  /// Added ingredients (ID + quantity only)
  final List<IngredientSelection> addedIngredients;

  /// Removed ingredient IDs (for display purposes, doesn't affect price)
  final List<String> removedIngredientIds;

  /// Quantity of this item
  final int quantity;

  /// Whether this is a split product (half & half)
  final bool isSplit;

  /// Second product ID for splits
  final String? secondProductId;

  /// Second product size ID for splits
  final String? secondSizeId;

  /// Added ingredients for second product in split
  final List<IngredientSelection> secondAddedIngredients;

  /// Removed ingredient IDs for second product
  final List<String> secondRemovedIngredientIds;

  /// Optional note
  final String? note;

  const OrderItemInput({
    required this.menuItemId,
    this.sizeId,
    this.addedIngredients = const [],
    this.removedIngredientIds = const [],
    this.quantity = 1,
    this.isSplit = false,
    this.secondProductId,
    this.secondSizeId,
    this.secondAddedIngredients = const [],
    this.secondRemovedIngredientIds = const [],
    this.note,
  });
}

/// Breakdown of how a price was calculated (for debugging/display)
class PriceBreakdown {
  /// Base product price (after size applied)
  final double basePrice;

  /// Total cost of added ingredients
  final double ingredientsCost;

  /// Second product base price (for splits)
  final double? secondBasePrice;

  /// Second product ingredients cost (for splits)
  final double? secondIngredientsCost;

  /// Whether rounding was applied (for splits)
  final bool wasRounded;

  /// Raw price before rounding (for splits)
  final double? rawPriceBeforeRounding;

  const PriceBreakdown({
    required this.basePrice,
    required this.ingredientsCost,
    this.secondBasePrice,
    this.secondIngredientsCost,
    this.wasRounded = false,
    this.rawPriceBeforeRounding,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Base: €${basePrice.toStringAsFixed(2)}');
    buffer.writeln('Ingredients: €${ingredientsCost.toStringAsFixed(2)}');
    if (secondBasePrice != null) {
      buffer.writeln('Second Base: €${secondBasePrice!.toStringAsFixed(2)}');
      buffer.writeln(
        'Second Ingredients: €${secondIngredientsCost?.toStringAsFixed(2) ?? "0.00"}',
      );
    }
    if (wasRounded) {
      buffer.writeln(
        'Raw before rounding: €${rawPriceBeforeRounding?.toStringAsFixed(2)}',
      );
    }
    return buffer.toString();
  }
}

/// Result of calculating a single item's price
class CalculatedItemPrice {
  /// Price per unit (with all customizations)
  final double unitPrice;

  /// Total subtotal (unitPrice × quantity)
  final double subtotal;

  /// Quantity
  final int quantity;

  /// Detailed breakdown for debugging
  final PriceBreakdown breakdown;

  const CalculatedItemPrice({
    required this.unitPrice,
    required this.subtotal,
    required this.quantity,
    required this.breakdown,
  });

  @override
  String toString() =>
      'CalculatedItemPrice(unit: €${unitPrice.toStringAsFixed(2)}, qty: $quantity, subtotal: €${subtotal.toStringAsFixed(2)})';
}

/// Result of calculating an entire order's total
class CalculatedOrderTotal {
  /// Calculated prices for each item
  final List<CalculatedItemPrice> items;

  /// Sum of all item subtotals
  final double subtotal;

  /// Delivery fee (0 for non-delivery or free delivery)
  final double deliveryFee;

  /// Final total (subtotal + deliveryFee)
  final double total;

  const CalculatedOrderTotal({
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
  });

  @override
  String toString() =>
      'CalculatedOrderTotal(subtotal: €${subtotal.toStringAsFixed(2)}, delivery: €${deliveryFee.toStringAsFixed(2)}, total: €${total.toStringAsFixed(2)})';
}

/// Input for calculating order total
class OrderTotalInput {
  final List<OrderItemInput> items;
  final OrderType orderType;

  /// Delivery coordinates (for radial fee calculation)
  final double? deliveryLatitude;
  final double? deliveryLongitude;

  const OrderTotalInput({
    required this.items,
    required this.orderType,
    this.deliveryLatitude,
    this.deliveryLongitude,
  });
}
