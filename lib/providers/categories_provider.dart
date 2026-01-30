import 'organization_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/category_model.dart';

part 'categories_provider.g.dart';

@riverpod
class Categories extends _$Categories {
  @override
  Future<List<CategoryModel>> build() async {
    final orgId = await ref.watch(currentOrganizationProvider.future);
    return _fetchCategories(orgId);
  }

  Future<List<CategoryModel>> _fetchCategories(String? orgId) async {
    final supabase = Supabase.instance.client;

    try {
      // SECURITY: Require organization context to prevent cross-tenant data access
      if (orgId == null) {
        throw Exception('Organization context required');
      }

      // Build query with strict multi-tenant filter (no .is.null pattern)
      final response = await supabase
          .from('categorie_menu')
          .select()
          .eq('organization_id', orgId)
          .order('ordine', ascending: true);

      return (response as List)
          .map((json) => CategoryModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }

  Future<void> refresh() async {
    final orgId = await ref.read(currentOrganizationProvider.future);
    state = AsyncValue.data(await _fetchCategories(orgId));
  }

  Future<void> createCategory({
    required String nome,
    String? descrizione,
    String? icona,
    String? iconaUrl,
    String? colore,
    bool disattivazioneProgrammata = false,
    List<String>? giorniDisattivazione,
    bool permittiDivisioni = true,
  }) async {
    final supabase = Supabase.instance.client;
    final orgId = await ref.read(currentOrganizationProvider.future);

    try {
      final categories = state.value ?? [];
      final maxOrdine = categories.isEmpty
          ? 0
          : categories.map((c) => c.ordine).reduce((a, b) => a > b ? a : b);

      final categoryData = {
        'nome': nome,
        'descrizione': descrizione,
        'icona': icona,
        'icona_url': iconaUrl,
        'colore': colore,
        'ordine': maxOrdine + 1,
        'attiva': true,
        'disattivazione_programmata': disattivazioneProgrammata,
        'giorni_disattivazione': giorniDisattivazione,
        'permetti_divisioni': permittiDivisioni,
        'organization_id': orgId, // Multi-tenant
      };

      await supabase.from('categorie_menu').insert(categoryData);

      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCategory({
    required String id,
    required String nome,
    String? descrizione,
    String? icona,
    String? iconaUrl,
    String? colore,
    bool? disattivazioneProgrammata,
    List<String>? giorniDisattivazione,
    bool? permittiDivisioni,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      final updateData = <String, dynamic>{
        'nome': nome,
        'descrizione': descrizione,
        'icona': icona,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Always update iconaUrl and colore (can be null to clear it)
      updateData['icona_url'] = iconaUrl;
      updateData['colore'] = colore;

      // Only update scheduling fields if they are provided
      if (disattivazioneProgrammata != null) {
        updateData['disattivazione_programmata'] = disattivazioneProgrammata;
      }
      if (giorniDisattivazione != null) {
        updateData['giorni_disattivazione'] = giorniDisattivazione;
      }
      if (permittiDivisioni != null) {
        updateData['permetti_divisioni'] = permittiDivisioni;
      }

      await supabase.from('categorie_menu').update(updateData).eq('id', id);

      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('categorie_menu').delete().eq('id', id);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleActive(String id, bool attiva) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('categorie_menu')
          .update({
            'attiva': attiva,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reorderCategories(
    List<CategoryModel> reorderedCategories,
  ) async {
    final supabase = Supabase.instance.client;

    try {
      final now = DateTime.now().toIso8601String();
      final updates = <Map<String, dynamic>>[
        for (var i = 0; i < reorderedCategories.length; i++)
          {'id': reorderedCategories[i].id, 'ordine': i, 'updated_at': now},
      ];

      if (updates.isNotEmpty) {
        await supabase
            .from('categorie_menu')
            .upsert(updates, onConflict: 'id');
      }

      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  // Method to manually trigger deactivation check
  Future<void> checkScheduledDeactivation() async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.rpc('check_and_deactivate_categories');
      await refresh();
    } catch (e) {
      rethrow;
    }
  }
}
