// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'ingredient_size_price_model.dart';

part 'ingredient_model.freezed.dart';
part 'ingredient_model.g.dart';

@freezed
class IngredientModel with _$IngredientModel {
  const IngredientModel._();

  const factory IngredientModel({
    @JsonKey(name: 'organization_id') String? organizationId,
    required String id,
    required String nome,
    String? descrizione,
    @Default(0.0) double prezzo, // Default/fallback price
    String? categoria,
    @Default([]) List<String> allergeni, // List of allergens
    @Default(0) int ordine,
    @Default(true) bool attivo,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    // Stock Management
    @JsonKey(name: 'stock_quantity') @Default(0.0) double stockQuantity,
    @JsonKey(name: 'unit_of_measurement')
    @Default('kg')
    String unitOfMeasurement,
    @JsonKey(name: 'track_stock') @Default(false) bool trackStock,
    @JsonKey(name: 'low_stock_threshold')
    @Default(0.0)
    double lowStockThreshold,
    // Size-based prices (joined data)
    @JsonKey(name: 'ingredient_size_prices')
    @Default([])
    List<IngredientSizePriceModel> sizePrices,
  }) = _IngredientModel;

  factory IngredientModel.fromJson(Map<String, dynamic> json) =>
      _$IngredientModelFromJson(json);

  /// Get price for a specific size, falls back to default prezzo if not found
  double getPriceForSize(String? sizeId) {
    if (sizeId == null) return prezzo;
    final sizePrice = sizePrices.where((sp) => sp.sizeId == sizeId).firstOrNull;
    return sizePrice?.prezzo ?? prezzo;
  }

  /// Check if ingredient has size-specific prices configured
  bool get hasSizePrices => sizePrices.isNotEmpty;
}

extension IngredientModelX on IngredientModel {
  /// Get formatted price display (default price)
  String get formattedPrice {
    if (prezzo == 0) return 'Gratis';
    return '+€${prezzo.toStringAsFixed(2)}';
  }

  /// Get formatted price for a specific size
  String formattedPriceForSize(String? sizeId) {
    final price = getPriceForSize(sizeId);
    if (price == 0) return 'Gratis';
    return '+€${price.toStringAsFixed(2)}';
  }

  /// Check if ingredient is free (default price)
  bool get isFree => prezzo == 0;

  /// Check if ingredient is free for a specific size
  bool isFreeForSize(String? sizeId) => getPriceForSize(sizeId) == 0;
}
