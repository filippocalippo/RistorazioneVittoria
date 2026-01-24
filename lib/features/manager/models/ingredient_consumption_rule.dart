// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'ingredient_consumption_rule.freezed.dart';
part 'ingredient_consumption_rule.g.dart';

@freezed
class IngredientConsumptionRule with _$IngredientConsumptionRule {
  const factory IngredientConsumptionRule({
    required String id,
    @JsonKey(name: 'ingredient_id') required String ingredientId,
    @JsonKey(name: 'size_id') required String sizeId,
    @JsonKey(name: 'product_id') String? productId,
    required double quantity,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _IngredientConsumptionRule;

  factory IngredientConsumptionRule.fromJson(Map<String, dynamic> json) =>
      _$IngredientConsumptionRuleFromJson(json);
}
