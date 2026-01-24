import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/menu_item_model.dart';
import '../core/services/database_service.dart';
import '../core/services/storage_service.dart';

part 'manager_menu_provider.g.dart';

/// Provider for managing menu items (includes unavailable items for manager)
@riverpod
class ManagerMenu extends _$ManagerMenu {
  @override
  Future<List<MenuItemModel>> build() async {
    final db = DatabaseService();
    // Manager sees all items, including unavailable ones
    return await db.getMenuItems(onlyAvailable: false);
  }

  /// Refresh menu list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Create new menu item
  Future<MenuItemModel> createItem(MenuItemModel item) async {
    final db = DatabaseService();
    final created = await db.createMenuItem(item);

    // Update state locally to avoid full reload of all items
    state = state.when(
      data: (items) => AsyncValue.data([...items, created]),
      loading: () => state,
      error: (err, stack) => state,
    );

    return created;
  }

  /// Update existing menu item
  Future<void> updateItem(String id, Map<String, dynamic> updates) async {
    final db = DatabaseService();
    await db.updateMenuItem(
      id: id,
      updates: updates,
    );

    // Optimistically update local state without reloading everything
    state = state.when(
      data: (items) {
        final updatedItems = items.map((item) {
          if (item.id != id) return item;
          // Apply partial updates to the existing item
          return item.copyWith(
            nome: updates.containsKey('nome')
                ? updates['nome'] as String
                : item.nome,
            descrizione: updates.containsKey('descrizione')
                ? updates['descrizione'] as String?
                : item.descrizione,
            prezzo: updates.containsKey('prezzo')
                ? (updates['prezzo'] as num).toDouble()
                : item.prezzo,
            prezzoScontato: updates.containsKey('prezzo_scontato')
                ? (updates['prezzo_scontato'] as num?)?.toDouble()
                : item.prezzoScontato,
            immagineUrl: updates.containsKey('immagine_url')
                ? updates['immagine_url'] as String?
                : item.immagineUrl,
            disponibile: updates.containsKey('disponibile')
                ? updates['disponibile'] as bool
                : item.disponibile,
            inEvidenza: updates.containsKey('in_evidenza')
                ? updates['in_evidenza'] as bool
                : item.inEvidenza,
            categoriaId: updates.containsKey('categoria_id')
                ? updates['categoria_id'] as String?
                : item.categoriaId,
          );
        }).toList();

        return AsyncValue.data(updatedItems);
      },
      loading: () => state,
      error: (err, stack) => state,
    );
  }

  /// Delete menu item
  Future<void> deleteItem(String id) async {
    final db = DatabaseService();
    await db.deleteMenuItem(id: id);

    // Remove item from local state without full refresh
    state = state.when(
      data: (items) {
        final updatedItems = items.where((item) => item.id != id).toList();
        return AsyncValue.data(updatedItems);
      },
      loading: () => state,
      error: (err, stack) => state,
    );
  }

  /// Delete menu item and its image from storage (if any)
  Future<void> deleteItemWithImage(MenuItemModel item) async {
    final storage = StorageService();
    // Best-effort delete of the image first
    final imageUrl = item.immagineUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        await storage.deleteMenuItemImage(imageUrl);
      } catch (_) {
        // Ignore storage deletion errors to not block DB deletion
      }
    }
    await deleteItem(item.id);
  }

  /// Toggle item availability
  Future<void> toggleAvailability(String id, bool isAvailable) async {
    await updateItem(id, {'disponibile': isAvailable});
  }

  /// Toggle item featured status
  Future<void> toggleFeatured(String id, bool isFeatured) async {
    await updateItem(id, {'in_evidenza': isFeatured});
  }
}

/// Provider for filtering menu items by category
@riverpod
List<MenuItemModel> filteredManagerMenu(Ref ref, String? categoryId) {
  final items = ref.watch(managerMenuProvider).value ?? [];

  if (categoryId == null) {
    return items;
  }

  return items.where((item) => item.categoriaId == categoryId).toList();
}

/// Provider for menu statistics
@riverpod
Map<String, dynamic> menuStats(Ref ref) {
  final items = ref.watch(managerMenuProvider).value ?? [];

  final availableItems = items.where((i) => i.disponibile).length;
  final featuredItems = items.where((i) => i.inEvidenza).length;
  final itemsWithDiscount = items.where((i) => i.prezzoScontato != null).length;

  final averagePrice = items.isNotEmpty
      ? items.fold<double>(0, (sum, item) => sum + item.prezzo) / items.length
      : 0.0;

  return {
    'totalItems': items.length,
    'availableItems': availableItems,
    'unavailableItems': items.length - availableItems,
    'featuredItems': featuredItems,
    'itemsWithDiscount': itemsWithDiscount,
    'averagePrice': averagePrice,
  };
}
