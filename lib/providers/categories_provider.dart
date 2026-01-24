import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/category_model.dart';

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, AsyncValue<List<CategoryModel>>>((
      ref,
    ) {
      return CategoriesNotifier(ref);
    });

class CategoriesNotifier
    extends StateNotifier<AsyncValue<List<CategoryModel>>> {
  final Ref ref;
  final _supabase = Supabase.instance.client;

  CategoriesNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _supabase
          .from('categorie_menu')
          .select()
          .order('ordine', ascending: true);

      final categories = (response as List)
          .map((json) => CategoryModel.fromJson(json))
          .toList();

      state = AsyncValue.data(categories);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadCategories();
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
      };

      await _supabase.from('categorie_menu').insert(categoryData);

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

      await _supabase
          .from('categorie_menu')
          .update(updateData)
          .eq('id', id);

      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _supabase
          .from('categorie_menu')
          .delete()
          .eq('id', id);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleActive(String id, bool attiva) async {
    try {
      await _supabase
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
    try {
      final now = DateTime.now().toIso8601String();
      final updates = <Map<String, dynamic>>[
        for (var i = 0; i < reorderedCategories.length; i++)
          {
            'id': reorderedCategories[i].id,
            'ordine': i,
            'updated_at': now,
          },
      ];

      if (updates.isNotEmpty) {
        await _supabase
            .from('categorie_menu')
            .upsert(
              updates,
              onConflict: 'id',
            );
      }

      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  // Method to manually trigger deactivation check
  Future<void> checkScheduledDeactivation() async {
    try {
      await _supabase.rpc('check_and_deactivate_categories');
      await refresh();
    } catch (e) {
      rethrow;
    }
  }
}
