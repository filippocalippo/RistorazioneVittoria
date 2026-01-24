import 'organization_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/size_variant_model.dart';
import 'filtered_menu_provider.dart';

part 'sizes_master_provider.g.dart';

@riverpod
class SizesMaster extends _$SizesMaster {
  @override
  Future<List<SizeVariantModel>> build() async {
    return _fetchSizesMaster();
  }

  Future<List<SizeVariantModel>> _fetchSizesMaster() async {
    final supabase = Supabase.instance.client;

    // Get organization context for multi-tenant filtering
    final orgId = await ref.read(currentOrganizationProvider.future);

    try {
      var query = supabase.from('sizes_master').select();

      // Multi-tenant filter: org-specific or global (null)
      if (orgId != null) {
        query = query.or('organization_id.eq.$orgId,organization_id.is.null');
      }

      final response = await query.order('ordine', ascending: true);

      return (response as List)
          .map((json) => SizeVariantModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load sizes master: $e');
    }
  }

  /// Create a new master size
  Future<void> createSize(SizeVariantModel size) async {
    final supabase = Supabase.instance.client;

    // Get organization context
    final orgId = await ref.read(currentOrganizationProvider.future);

    try {
      final data = size.toJson();
      // Include organization_id for multi-tenant isolation
      if (orgId != null) {
        data['organization_id'] = orgId;
      }

      await supabase.from('sizes_master').insert(data);

      // Refresh the list
      state = AsyncValue.data(await _fetchSizesMaster());

      // Force invalidate to refresh product filtering
      ref.invalidate(productAvailabilityProvider);
      ref.invalidate(groupedMenuItemsProvider);
    } catch (e) {
      throw Exception('Failed to create size: $e');
    }
  }

  /// Update an existing master size
  Future<void> updateSize(String id, Map<String, dynamic> data) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('sizes_master').update(data).eq('id', id);

      // Refresh the list
      state = AsyncValue.data(await _fetchSizesMaster());

      // Force invalidate to refresh product filtering
      ref.invalidate(productAvailabilityProvider);
      ref.invalidate(groupedMenuItemsProvider);
    } catch (e) {
      throw Exception('Failed to update size: $e');
    }
  }

  /// Delete a master size
  Future<void> deleteSize(String id) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('sizes_master').delete().eq('id', id);

      // Refresh the list
      state = AsyncValue.data(await _fetchSizesMaster());

      // Force invalidate to refresh product filtering
      ref.invalidate(productAvailabilityProvider);
      ref.invalidate(groupedMenuItemsProvider);
    } catch (e) {
      throw Exception('Failed to delete size: $e');
    }
  }

  /// Toggle size active status
  Future<void> toggleActive(String id, bool isActive) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('sizes_master')
          .update({'attivo': isActive})
          .eq('id', id);

      // Refresh the list
      state = AsyncValue.data(await _fetchSizesMaster());

      // Force invalidate to refresh product filtering
      ref.invalidate(productAvailabilityProvider);
      ref.invalidate(groupedMenuItemsProvider);
    } catch (e) {
      throw Exception('Failed to toggle size status: $e');
    }
  }
}
