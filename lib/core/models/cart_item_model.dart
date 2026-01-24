import 'package:freezed_annotation/freezed_annotation.dart';
import 'size_variant_model.dart';
import 'ingredient_model.dart';
import 'product_configuration_model.dart';

part 'cart_item_model.freezed.dart';
part 'cart_item_model.g.dart';

@freezed
class CartItemModel with _$CartItemModel {
  const CartItemModel._();

  const factory CartItemModel({
    required String menuItemId,
    required String nome,
    required double basePrice,
    @Default(1) int quantity,

    // Customization
    SizeVariantModel? selectedSize,
    @Default([]) List<SelectedIngredient> addedIngredients,
    @Default([]) List<IngredientModel> removedIngredients,
    @Default([]) List<SpecialOption> specialOptions,
    String? note,
  }) = _CartItemModel;

  factory CartItemModel.fromJson(Map<String, dynamic> json) =>
      _$CartItemModelFromJson(json);

  /// Calculate total price including all customizations
  double get totalPrice {
    double price = basePrice;

    // Add extra ingredients (fixed price only, no base price dependency)
    for (var ingredient in addedIngredients) {
      price += ingredient.unitPrice * ingredient.quantity;
    }

    // Removed ingredients don't affect price (no refund)

    // Add special options
    for (var option in specialOptions) {
      price += option.price;
    }

    return price * quantity;
  }

  /// Get unit price (price for one item with customizations)
  double get unitPrice {
    return totalPrice / quantity;
  }

  /// Convert customizations to variants JSON for order
  Map<String, dynamic> toVariantsJson() {
    return {
      if (selectedSize != null)
        'size': {
          'id': selectedSize!.id,
          'name': selectedSize!.nome,
          'description': selectedSize!.descrizione,
          'multiplier': selectedSize!.priceMultiplier,
        },
      if (addedIngredients.isNotEmpty)
        'addedIngredients': addedIngredients
            .map(
              (i) => {
                'id': i.ingredientId,
                'name': i.ingredientName,
                'unitPrice': i.unitPrice,
                'quantity': i.quantity,
              },
            )
            .toList(),
      if (removedIngredients.isNotEmpty)
        'removedIngredients': removedIngredients
            .map((i) => {'id': i.id, 'name': i.nome})
            .toList(),
      if (specialOptions.isNotEmpty)
        'specialOptions': specialOptions
            .map(
              (o) => {
                'id': o.id,
                'name': o.name,
                'price': o.price,
                'description': o.description,
                if (o.productId != null) 'productId': o.productId,
                if (o.imageUrl != null) 'imageUrl': o.imageUrl,
              },
            )
            .toList(),
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }

  /// Check if this cart item is identical to another (same customizations)
  bool hasSameCustomizations(CartItemModel other) {
    if (menuItemId != other.menuItemId) return false;
    if (selectedSize?.id != other.selectedSize?.id) return false;
    if (note != other.note) return false;

    // Check added ingredients
    if (addedIngredients.length != other.addedIngredients.length) return false;
    for (var i = 0; i < addedIngredients.length; i++) {
      if (addedIngredients[i].ingredientId !=
              other.addedIngredients[i].ingredientId ||
          addedIngredients[i].quantity != other.addedIngredients[i].quantity) {
        return false;
      }
    }

    // Check removed ingredients
    if (removedIngredients.length != other.removedIngredients.length) {
      return false;
    }
    final removedIds = removedIngredients.map((i) => i.id).toSet();
    final otherRemovedIds = other.removedIngredients.map((i) => i.id).toSet();
    if (!removedIds.containsAll(otherRemovedIds) ||
        !otherRemovedIds.containsAll(removedIds)) {
      return false;
    }

    // Check special options
    if (specialOptions.length != other.specialOptions.length) return false;
    for (var i = 0; i < specialOptions.length; i++) {
      if (specialOptions[i].id != other.specialOptions[i].id) {
        return false;
      }
    }

    return true;
  }

  /// Get display text for customizations
  String get customizationsSummary {
    final parts = <String>[];

    if (selectedSize != null) {
      parts.add(selectedSize!.displayName);
    }

    if (addedIngredients.isNotEmpty) {
      for (var ingredient in addedIngredients) {
        if (ingredient.quantity > 1) {
          parts.add('+${ingredient.quantity}x ${ingredient.ingredientName}');
        } else {
          parts.add('+${ingredient.ingredientName}');
        }
      }
    }

    if (removedIngredients.isNotEmpty) {
      for (var ingredient in removedIngredients) {
        parts.add('-${ingredient.nome}');
      }
    }

    if (specialOptions.isNotEmpty) {
      parts.addAll(specialOptions.map((o) => o.name));
    }

    return parts.join(', ');
  }
}

@freezed
class SelectedIngredient with _$SelectedIngredient {
  const factory SelectedIngredient({
    required String ingredientId,
    required String ingredientName,
    required double unitPrice, // Fixed price per unit
    @Default(1) int quantity,
  }) = _SelectedIngredient;

  factory SelectedIngredient.fromJson(Map<String, dynamic> json) =>
      _$SelectedIngredientFromJson(json);
}

extension SelectedIngredientX on SelectedIngredient {
  /// Calculate total price for this ingredient selection
  double get totalPrice => unitPrice * quantity;
}
