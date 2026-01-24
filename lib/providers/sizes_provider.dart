import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/size_variant_model.dart';

part 'sizes_provider.g.dart';

/// Provider to fetch all available sizes from sizes_master table
@Riverpod(keepAlive: true)
class Sizes extends _$Sizes {
  @override
  Future<List<SizeVariantModel>> build() async {
    return _fetchSizes();
  }

  Future<List<SizeVariantModel>> _fetchSizes() async {
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('sizes_master')
          .select()
          .eq('attivo', true)
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
    state = AsyncValue.data(await _fetchSizes());
  }
}
