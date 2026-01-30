import 'organization_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/size_variant_model.dart';

part 'sizes_provider.g.dart';

/// Provider to fetch all available sizes from sizes_master table
@riverpod
class Sizes extends _$Sizes {
  @override
  Future<List<SizeVariantModel>> build() async {
    final orgId = await ref.watch(currentOrganizationProvider.future);
    return _fetchSizes(orgId);
  }

  Future<List<SizeVariantModel>> _fetchSizes(String? orgId) async {
    final supabase = Supabase.instance.client;

    try {
      // SECURITY: Require organization context to prevent cross-tenant data access
      if (orgId == null) {
        throw Exception('Organization context required');
      }

      final response = await supabase
          .from('sizes_master')
          .select()
          .eq('attivo', true)
          .eq('organization_id', orgId)
          .order('ordine', ascending: true);

      return (response as List)
          .map((json) => SizeVariantModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load sizes: $e');
    }
  }

  /// Refresh sizes list
  Future<void> refresh() async {
    final orgId = await ref.read(currentOrganizationProvider.future);
    state = AsyncValue.data(await _fetchSizes(orgId));
  }
}
