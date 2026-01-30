import 'organization_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/ingredient_model.dart';
import 'filtered_menu_provider.dart';

part 'ingredients_provider.g.dart';

@riverpod
class Ingredients extends _$Ingredients {
  @override
  Future<List<IngredientModel>> build() async {
    final orgId = await ref.watch(currentOrganizationProvider.future);
    return _fetchIngredients(orgId);
  }

  Future<List<IngredientModel>> _fetchIngredients(String? orgId) async {
    final supabase = Supabase.instance.client;

    try {
      // SECURITY: Require organization context to prevent cross-tenant data access
      if (orgId == null) {
        throw Exception('Organization context required');
      }

      // Fetch ingredients with their size prices (strict multi-tenant filter)
      final response = await supabase
          .from('ingredients')
          .select('*, ingredient_size_prices(*)')
          .eq('organization_id', orgId)
          .order('ordine', ascending: true);

      return (response as List)
          .map((json) => IngredientModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load ingredients: $e');
    }
  }

  /// Update size prices for an ingredient
  Future<void> updateSizePrices(
    String ingredientId,
    Map<String, double> sizePrices, // sizeId -> price
  ) async {
    final supabase = Supabase.instance.client;
    final orgId = await ref.read(currentOrganizationProvider.future);

    try {
      // Delete existing size prices for this ingredient
      await supabase
          .from('ingredient_size_prices')
          .delete()
          .eq('ingredient_id', ingredientId);

      // Insert new size prices (only non-zero prices)
      final pricesToInsert = sizePrices.entries
          .where((e) => e.value > 0)
          .map(
            (e) => {
              if (orgId != null) 'organization_id': orgId,
              'ingredient_id': ingredientId,
              'size_id': e.key,
              'prezzo': e.value,
            },
          )
          .toList();

      if (pricesToInsert.isNotEmpty) {
        await supabase.from('ingredient_size_prices').insert(pricesToInsert);
      }

      // Refresh the ingredients list
      state = AsyncValue.data(await _fetchIngredients(orgId));
    } catch (e) {
      throw Exception('Failed to update size prices: $e');
    }
  }

  /// Create a new ingredient
  Future<void> createIngredient(IngredientModel ingredient) async {
    final supabase = Supabase.instance.client;

    // Remove joined data that isn't a column in the ingredients table
    final data = Map<String, dynamic>.from(ingredient.toJson());
    data.remove('ingredient_size_prices');

    // Multi-tenant: add organization_id
    final orgId = await ref.read(currentOrganizationProvider.future);
    data['organization_id'] = orgId;

    try {
      await supabase.from('ingredients').insert(data);

      // Refresh the list
      state = AsyncValue.data(await _fetchIngredients(orgId));

      // Force invalidate grouped menu items to refresh product filtering
      ref.invalidate(groupedMenuItemsProvider);
      ref.invalidate(productAvailabilityProvider);
    } catch (e) {
      throw Exception('Failed to create ingredient: $e');
    }
  }

  /// Create multiple ingredients in bulk
  Future<void> createIngredientsBulk(List<IngredientModel> ingredients) async {
    if (ingredients.isEmpty) {
      return;
    }

    final supabase = Supabase.instance.client;
    final orgId = await ref.read(currentOrganizationProvider.future);

    try {
      // Remove joined data from each ingredient
      final cleanedData = ingredients.map((ingredient) {
        final data = Map<String, dynamic>.from(ingredient.toJson());
        data.remove('ingredient_size_prices');
        // Ensure org isolation for bulk insert
        if (orgId != null) {
          data['organization_id'] = orgId;
        }
        return data;
      }).toList();

      await supabase.from('ingredients').insert(cleanedData);

      // Refresh the list
      state = AsyncValue.data(await _fetchIngredients(orgId));

      // Force invalidate grouped menu items to refresh product filtering
      ref.invalidate(groupedMenuItemsProvider);
      ref.invalidate(productAvailabilityProvider);
    } catch (e) {
      throw Exception('Failed to create ingredients in bulk: $e');
    }
  }

  /// Update an existing ingredient
  Future<void> updateIngredient(String id, Map<String, dynamic> data) async {
    final supabase = Supabase.instance.client;
    final orgId = await ref.read(currentOrganizationProvider.future);

    // Remove joined data that isn't a column in the ingredients table
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('ingredient_size_prices');

    try {
      await supabase.from('ingredients').update(cleanData).eq('id', id);

      // Refresh the list
      state = AsyncValue.data(await _fetchIngredients(orgId));

      // Force invalidate grouped menu items to refresh product filtering
      ref.invalidate(groupedMenuItemsProvider);
      ref.invalidate(productAvailabilityProvider);
    } catch (e) {
      throw Exception('Failed to update ingredient: $e');
    }
  }

  /// Delete an ingredient
  Future<void> deleteIngredient(String id) async {
    final supabase = Supabase.instance.client;
    final orgId = await ref.read(currentOrganizationProvider.future);

    try {
      await supabase.from('ingredients').delete().eq('id', id);

      // Refresh the list
      state = AsyncValue.data(await _fetchIngredients(orgId));

      // Force invalidate grouped menu items to refresh product filtering
      ref.invalidate(groupedMenuItemsProvider);
      ref.invalidate(productAvailabilityProvider);
    } catch (e) {
      throw Exception('Failed to delete ingredient: $e');
    }
  }

  /// Toggle ingredient active status
  Future<void> toggleActive(String id, bool isActive) async {
    final supabase = Supabase.instance.client;
    final orgId = await ref.read(currentOrganizationProvider.future);

    try {
      await supabase
          .from('ingredients')
          .update({'attivo': isActive})
          .eq('id', id);

      // Refresh the list
      state = AsyncValue.data(await _fetchIngredients(orgId));

      // Force invalidate grouped menu items to refresh product filtering
      // This ensures updates are reflected immediately when ingredient status changes
      ref.invalidate(groupedMenuItemsProvider);
      ref.invalidate(productAvailabilityProvider);
    } catch (e) {
      throw Exception('Failed to toggle ingredient status: $e');
    }
  }
}

/// Provider to get ingredients grouped by category
@riverpod
Future<Map<String, List<IngredientModel>>> ingredientsByCategory(
  Ref ref,
) async {
  final ingredients = await ref.watch(ingredientsProvider.future);

  final Map<String, List<IngredientModel>> grouped = {};
  for (var ingredient in ingredients) {
    final category = ingredient.categoria ?? 'Altri';
    if (!grouped.containsKey(category)) {
      grouped[category] = [];
    }
    grouped[category]!.add(ingredient);
  }

  return grouped;
}
