import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/database_service.dart';
import '../core/models/menu_item_model.dart';
import '../core/utils/logger.dart';
import 'organization_provider.dart';

part 'menu_provider.g.dart';

@riverpod
DatabaseService databaseService(Ref ref) {
  return DatabaseService();
}

@riverpod
class Menu extends _$Menu {
  @override
  Future<List<MenuItemModel>> build() async {
    Logger.debug('Menu provider loading items', tag: 'Menu');

    final db = ref.watch(databaseServiceProvider);
    final orgId = await ref.watch(currentOrganizationProvider.future);

    return await db.getMenuItems(
      onlyAvailable: true,
      organizationId: orgId,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseServiceProvider);
      final orgId = await ref.read(currentOrganizationProvider.future);
      return await db.getMenuItems(
        onlyAvailable: true,
        organizationId: orgId,
      );
    });
  }

  Future<void> createItem(MenuItemModel item) async {
    final db = ref.read(databaseServiceProvider);
    final orgId = await ref.read(currentOrganizationProvider.future);
    await db.createMenuItem(item, organizationId: orgId);
    await refresh();
  }

  Future<void> updateItem(String id, Map<String, dynamic> updates) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateMenuItem(
      id: id,
      updates: updates,
    );
    await refresh();
  }

  Future<void> deleteItem(String id) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteMenuItem(id: id);
    await refresh();
  }
}

/// Provider per menu items filtrati per categoria
@riverpod
List<MenuItemModel> menuByCategory(Ref ref, String? categoriaId) {
  final menuState = ref.watch(menuProvider);

  return menuState.when(
    data: (items) {
      if (categoriaId == null) return items;
      return items.where((item) => item.categoriaId == categoriaId).toList();
    },
    loading: () => [],
    error: (_, _) => [],
  );
}

/// Provider per menu items in evidenza
@riverpod
List<MenuItemModel> featuredMenuItems(Ref ref) {
  final menuState = ref.watch(menuProvider);

  return menuState.when(
    data: (items) => items.where((item) => item.inEvidenza).toList(),
    loading: () => [],
    error: (_, _) => [],
  );
}
