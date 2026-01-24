// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'ingredient_model.dart';

part 'menu_item_extra_ingredient_model.freezed.dart';
part 'menu_item_extra_ingredient_model.g.dart';

@freezed
class MenuItemExtraIngredientModel with _$MenuItemExtraIngredientModel {
  const factory MenuItemExtraIngredientModel({
    @JsonKey(name: 'organization_id') String? organizationId,
    required String id,
    @JsonKey(name: 'menu_item_id') required String menuItemId,
    @JsonKey(name: 'ingredient_id') required String ingredientId,

    @JsonKey(name: 'max_quantity') @Default(1) int maxQuantity,
    @Default(0) int ordine,
    @JsonKey(name: 'created_at') required DateTime createdAt,

    // Joined ingredient data (when fetching with join)
    @JsonKey(name: 'ingredients') IngredientModel? ingredientData,
  }) = _MenuItemExtraIngredientModel;

  factory MenuItemExtraIngredientModel.fromJson(Map<String, dynamic> json) =>
      _$MenuItemExtraIngredientModelFromJson(json);
}

extension MenuItemExtraIngredientModelX on MenuItemExtraIngredientModel {
  /// Get effective price for a specific size (uses ingredient's size-based pricing)
  /// Falls back to ingredient's default price if no size-specific price is found
  double getEffectivePriceForSize(String? sizeId) {
    return ingredientData?.getPriceForSize(sizeId) ?? 0.0;
  }

  /// Get effective price (default - uses ingredient's default price)
  /// @deprecated Use getEffectivePriceForSize instead for accurate pricing
  double getEffectivePrice() {
    // No longer uses priceOverride - uses ingredient's default price
    return ingredientData?.prezzo ?? 0.0;
  }

  /// Get formatted price display for a specific size
  String getFormattedPriceForSize(String? sizeId) {
    final price = getEffectivePriceForSize(sizeId);
    if (price == 0) return 'Gratis';
    return '+€${price.toStringAsFixed(2)}';
  }

  /// Get formatted price display (default price)
  String getFormattedPrice() {
    final price = getEffectivePrice();
    if (price == 0) return 'Gratis';
    return '+€${price.toStringAsFixed(2)}';
  }
}
