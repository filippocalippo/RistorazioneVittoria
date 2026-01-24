import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/menu_item_extra_ingredient_model.dart';

part 'product_extra_ingredients_provider.g.dart';

@Riverpod(keepAlive: true) // Keep cached indefinitely for better performance
class ProductExtraIngredients extends _$ProductExtraIngredients {
  @override
  Future<List<MenuItemExtraIngredientModel>> build(String menuItemId) async {
    return _fetchProductExtraIngredients(menuItemId);
  }

  Future<List<MenuItemExtraIngredientModel>> _fetchProductExtraIngredients(
    String menuItemId,
  ) async {
    final supabase = Supabase.instance.client;

    try {
      // Fetch extra ingredients with their ingredient data including size prices
      final response = await supabase
          .from('menu_item_extra_ingredients')
          .select('*, ingredients(*, ingredient_size_prices(*))')
          .eq('menu_item_id', menuItemId)
          .order('ordine', ascending: true);

      final allExtras = (response as List).map((json) {
        // Parse the joined ingredient data
        final ingredientData = json['ingredients'] as Map<String, dynamic>?;

        return MenuItemExtraIngredientModel.fromJson({
          ...json,
          'ingredients': ingredientData, // Keep as map for fromJson
        });
      }).toList();

      // Filter out inactive ingredients (where ingredientData.attivo == false)
      return allExtras.where((extra) {
        return extra.ingredientData?.attivo ?? false;
      }).toList();
    } catch (e) {
      throw Exception('Failed to load product extra ingredients: $e');
    }
  }

  /// Add an extra ingredient to a product
  Future<void> addExtraIngredient({
    required String menuItemId,
    required String ingredientId,
    required int maxQuantity,
    required int ordine,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('menu_item_extra_ingredients').insert({
        'menu_item_id': menuItemId,
        'ingredient_id': ingredientId,
        'max_quantity': maxQuantity,
        'ordine': ordine,
      });

      // Refresh the list
      state = AsyncValue.data(await _fetchProductExtraIngredients(menuItemId));
    } catch (e) {
      throw Exception('Failed to add extra ingredient: $e');
    }
  }

  /// Update extra ingredient
  Future<void> updateExtraIngredient(
    String id,
    Map<String, dynamic> data,
    String menuItemId,
  ) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('menu_item_extra_ingredients')
          .update(data)
          .eq('id', id);

      // Refresh the list
      state = AsyncValue.data(await _fetchProductExtraIngredients(menuItemId));
    } catch (e) {
      throw Exception('Failed to update extra ingredient: $e');
    }
  }

  /// Remove an extra ingredient
  Future<void> removeExtraIngredient(String id, String menuItemId) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('menu_item_extra_ingredients').delete().eq('id', id);

      // Refresh the list
      state = AsyncValue.data(await _fetchProductExtraIngredients(menuItemId));
    } catch (e) {
      throw Exception('Failed to remove extra ingredient: $e');
    }
  }

  /// Clear all extra ingredients for a menu item
  Future<void> clearAllIngredients(String menuItemId) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('menu_item_extra_ingredients')
          .delete()
          .eq('menu_item_id', menuItemId);

      // Refresh the list
      state = AsyncValue.data(await _fetchProductExtraIngredients(menuItemId));
    } catch (e) {
      throw Exception('Failed to clear extra ingredients: $e');
    }
  }

  /// Replace all extra ingredients with a single bulk operation
  Future<void> replaceIngredients(
    String menuItemId,
    List<MenuItemExtraIngredientModel> ingredients,
  ) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('menu_item_extra_ingredients')
          .delete()
          .eq('menu_item_id', menuItemId);

      if (ingredients.isNotEmpty) {
        final payload = ingredients.map((ingredient) {
          return {
            'menu_item_id': menuItemId,
            'ingredient_id': ingredient.ingredientId,
            'max_quantity': ingredient.maxQuantity,
            'ordine': ingredient.ordine,
          };
        }).toList();

        await supabase.from('menu_item_extra_ingredients').insert(payload);
      }

      state = AsyncValue.data(await _fetchProductExtraIngredients(menuItemId));
    } catch (e) {
      throw Exception('Failed to replace extra ingredients: $e');
    }
  }
}
