// Organization filtering handled by upstream providers (menuProvider, sizesProvider, ingredientsProvider)
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/menu_item_size_assignment_model.dart';
import 'organization_provider.dart';

part 'product_sizes_provider.g.dart';

@Riverpod(keepAlive: true) // Keep cached indefinitely for better performance
class ProductSizes extends _$ProductSizes {
  @override
  Future<List<MenuItemSizeAssignmentModel>> build(String menuItemId) async {
    return _fetchProductSizes(menuItemId);
  }

  Future<List<MenuItemSizeAssignmentModel>> _fetchProductSizes(
    String menuItemId,
  ) async {
    final supabase = Supabase.instance.client;
    final orgId = await ref.read(currentOrganizationProvider.future);

    try {
      var query = supabase
          .from('menu_item_sizes')
          .select('*, sizes_master(*)')
          .eq('menu_item_id', menuItemId);

      if (orgId != null) {
        query = query.eq('organization_id', orgId);
      }

      final response = await query.order('ordine', ascending: true);

      final allSizes = (response as List).map((json) {
        // Parse the joined size data
        final sizeData = json['sizes_master'] as Map<String, dynamic>?;

        return MenuItemSizeAssignmentModel.fromJson({
          ...json,
          'sizes_master': sizeData, // Keep as map for fromJson
        });
      }).toList();

      // Filter out inactive sizes (where sizeData.attivo == false)
      return allSizes.where((size) {
        return size.sizeData?.attivo ?? false;
      }).toList();
    } catch (e) {
      throw Exception('Failed to load product sizes: $e');
    }
  }

  /// Create a new size assignment for a product
  Future<void> assignSize(MenuItemSizeAssignmentModel assignment) async {
    final supabase = Supabase.instance.client;
    final orgId = await ref.read(currentOrganizationProvider.future);

    try {
      await supabase.from('menu_item_sizes').insert({
        if (orgId != null) 'organization_id': orgId,
        'menu_item_id': assignment.menuItemId,
        'size_id': assignment.sizeId,
        'display_name_override': assignment.displayNameOverride,
        'is_default': assignment.isDefault,
        'price_override': assignment.priceOverride,
        'ordine': assignment.ordine,
      });

      // Refresh the list
      state = AsyncValue.data(await _fetchProductSizes(assignment.menuItemId));
    } catch (e) {
      throw Exception('Failed to assign size: $e');
    }
  }

  /// Update a size assignment
  Future<void> updateAssignment(
    String id,
    Map<String, dynamic> data,
    String menuItemId,
  ) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('menu_item_sizes').update(data).eq('id', id);

      // Refresh the list
      state = AsyncValue.data(await _fetchProductSizes(menuItemId));
    } catch (e) {
      throw Exception('Failed to update size assignment: $e');
    }
  }

  /// Remove a size assignment
  Future<void> removeAssignment(String id, String menuItemId) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('menu_item_sizes').delete().eq('id', id);

      // Refresh the list
      state = AsyncValue.data(await _fetchProductSizes(menuItemId));
    } catch (e) {
      throw Exception('Failed to remove size assignment: $e');
    }
  }

  /// Set a size as default (and unset others)
  Future<void> setDefaultSize(String id, String menuItemId) async {
    final supabase = Supabase.instance.client;

    try {
      // First, unset all defaults for this product
      await supabase
          .from('menu_item_sizes')
          .update({'is_default': false})
          .eq('menu_item_id', menuItemId);

      // Then set the new default
      await supabase
          .from('menu_item_sizes')
          .update({'is_default': true})
          .eq('id', id);

      // Refresh the list
      state = AsyncValue.data(await _fetchProductSizes(menuItemId));
    } catch (e) {
      throw Exception('Failed to set default size: $e');
    }
  }

  /// Clear all size assignments for a menu item
  Future<void> clearAllAssignments(String menuItemId) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('menu_item_sizes')
          .delete()
          .eq('menu_item_id', menuItemId);

      // Refresh the list
      state = AsyncValue.data(await _fetchProductSizes(menuItemId));
    } catch (e) {
      throw Exception('Failed to clear size assignments: $e');
    }
  }

  /// Replace all assignments with a single bulk operation
  Future<void> replaceAssignments(
    String menuItemId,
    List<MenuItemSizeAssignmentModel> assignments,
  ) async {
    final supabase = Supabase.instance.client;
    final orgId = await ref.read(currentOrganizationProvider.future);

    try {
      // Remove existing entries first to avoid duplicates
      await supabase
          .from('menu_item_sizes')
          .delete()
          .eq('menu_item_id', menuItemId);

      if (assignments.isNotEmpty) {
        final payload = assignments.map((assignment) {
          return {
            if (orgId != null) 'organization_id': orgId,
            'menu_item_id': menuItemId,
            'size_id': assignment.sizeId,
            'display_name_override': assignment.displayNameOverride,
            'is_default': assignment.isDefault,
            'price_override': assignment.priceOverride,
            'ordine': assignment.ordine,
          };
        }).toList();

        await supabase.from('menu_item_sizes').insert(payload);
      }

      state = AsyncValue.data(await _fetchProductSizes(menuItemId));
    } catch (e) {
      throw Exception('Failed to replace size assignments: $e');
    }
  }
}

/// Provider to get the default size for a product
@riverpod
Future<MenuItemSizeAssignmentModel?> productDefaultSize(
  Ref ref,
  String menuItemId,
) async {
  final sizes = await ref.watch(productSizesProvider(menuItemId).future);
  try {
    return sizes.firstWhere((size) => size.isDefault);
  } catch (e) {
    return sizes.isNotEmpty ? sizes.first : null;
  }
}

/// Provider to check if a product has size options
@riverpod
Future<bool> hasProductSizes(Ref ref, String menuItemId) async {
  final sizes = await ref.watch(productSizesProvider(menuItemId).future);
  return sizes.isNotEmpty;
}
