// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'ingredient_size_price_model.freezed.dart';
part 'ingredient_size_price_model.g.dart';

/// Model representing an ingredient's price for a specific size
@freezed
class IngredientSizePriceModel with _$IngredientSizePriceModel {
  const factory IngredientSizePriceModel({
    @JsonKey(name: 'organization_id') String? organizationId,
    required String id,
    @JsonKey(name: 'ingredient_id') required String ingredientId,
    @JsonKey(name: 'size_id') required String sizeId,
    required double prezzo,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _IngredientSizePriceModel;

  factory IngredientSizePriceModel.fromJson(Map<String, dynamic> json) =>
      _$IngredientSizePriceModelFromJson(json);
}
