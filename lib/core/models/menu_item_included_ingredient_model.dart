// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'ingredient_model.dart';

part 'menu_item_included_ingredient_model.freezed.dart';
part 'menu_item_included_ingredient_model.g.dart';

@freezed
class MenuItemIncludedIngredientModel with _$MenuItemIncludedIngredientModel {
  const factory MenuItemIncludedIngredientModel({
    required String id,
    @JsonKey(name: 'menu_item_id') required String menuItemId,
    @JsonKey(name: 'ingredient_id') required String ingredientId,
    @Default(0) int ordine,
    @JsonKey(name: 'created_at') required DateTime createdAt,

    // Joined ingredient data (when fetching with join)
    @JsonKey(name: 'ingredients') IngredientModel? ingredientData,
  }) = _MenuItemIncludedIngredientModel;

  factory MenuItemIncludedIngredientModel.fromJson(Map<String, dynamic> json) =>
      _$MenuItemIncludedIngredientModelFromJson(json);
}
