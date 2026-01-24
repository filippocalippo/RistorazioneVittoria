import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/menu_item_included_ingredient_model.dart';

part 'product_included_ingredients_provider.g.dart';

@Riverpod(keepAlive: true) // Keep cached indefinitely for better performance
class ProductIncludedIngredients extends _$ProductIncludedIngredients {
  @override
  Future<List<MenuItemIncludedIngredientModel>> build(String menuItemId) async {
    return _fetchProductIncludedIngredients(menuItemId);
  }

  Future<List<MenuItemIncludedIngredientModel>>
  _fetchProductIncludedIngredients(String menuItemId) async {
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('menu_item_included_ingredients')
          .select('*, ingredients(*)')
          .eq('menu_item_id', menuItemId)
          .order('ordine', ascending: true);

      final allIncluded = (response as List).map((json) {
        // Parse the joined ingredient data
        final ingredientData = json['ingredients'] as Map<String, dynamic>?;

        return MenuItemIncludedIngredientModel.fromJson({
          ...json,
          'ingredients': ingredientData, // Keep as map for fromJson
        });
      }).toList();

      // Filter out inactive ingredients (where ingredientData.attivo == false)
      return allIncluded.where((included) {
        return included.ingredientData?.attivo ?? false;
      }).toList();
    } catch (e) {
      throw Exception('Failed to load product included ingredients: $e');
    }
  }

  /// Add an included ingredient to a product
  Future<void> addIncludedIngredient(
    String menuItemId,
    String ingredientId,
    int ordine,
  ) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('menu_item_included_ingredients').insert({
        'menu_item_id': menuItemId,
        'ingredient_id': ingredientId,
        'ordine': ordine,
      });

      // Refresh the list
      state = AsyncValue.data(
        await _fetchProductIncludedIngredients(menuItemId),
      );
    } catch (e) {
      throw Exception('Failed to add included ingredient: $e');
    }
  }

  /// Update included ingredient ordine
  Future<void> updateIncludedIngredient(
    String id,
    Map<String, dynamic> data,
    String menuItemId,
  ) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('menu_item_included_ingredients')
          .update(data)
          .eq('id', id);

      // Refresh the list
      state = AsyncValue.data(
        await _fetchProductIncludedIngredients(menuItemId),
      );
    } catch (e) {
      throw Exception('Failed to update included ingredient: $e');
    }
  }

  /// Remove an included ingredient
  Future<void> removeIncludedIngredient(String id, String menuItemId) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('menu_item_included_ingredients')
          .delete()
          .eq('id', id);

      // Refresh the list
      state = AsyncValue.data(
        await _fetchProductIncludedIngredients(menuItemId),
      );
    } catch (e) {
      throw Exception('Failed to remove included ingredient: $e');
    }
  }

  /// Clear all included ingredients for a menu item
  Future<void> clearAllIngredients(String menuItemId) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('menu_item_included_ingredients')
          .delete()
          .eq('menu_item_id', menuItemId);

      // Refresh the list
      state = AsyncValue.data(
        await _fetchProductIncludedIngredients(menuItemId),
      );
    } catch (e) {
      throw Exception('Failed to clear included ingredients: $e');
    }
  }

  /// Replace all included ingredients with a single bulk operation
  Future<void> replaceIngredients(
    String menuItemId,
    List<MenuItemIncludedIngredientModel> ingredients,
  ) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('menu_item_included_ingredients')
          .delete()
          .eq('menu_item_id', menuItemId);

      if (ingredients.isNotEmpty) {
        final payload = ingredients.map((ingredient) {
          return {
            'menu_item_id': menuItemId,
            'ingredient_id': ingredient.ingredientId,
            'ordine': ingredient.ordine,
          };
        }).toList();

        await supabase.from('menu_item_included_ingredients').insert(payload);
      }

      state = AsyncValue.data(
        await _fetchProductIncludedIngredients(menuItemId),
      );
    } catch (e) {
      throw Exception('Failed to replace included ingredients: $e');
    }
  }
}
