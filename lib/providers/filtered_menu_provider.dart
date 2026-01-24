import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/menu_item_model.dart';
import 'menu_provider.dart';
import 'categories_provider.dart';
import 'product_monthly_sales_provider.dart';

part 'filtered_menu_provider.g.dart';

/// Filter and sort options for menu items
class MenuFilterOptions {
  final String? selectedCategoryId;
  final String searchQuery;
  final String sortBy; // 'name', 'price_asc', 'price_desc', 'popular'

  const MenuFilterOptions({
    this.selectedCategoryId,
    this.searchQuery = '',
    this.sortBy = 'name',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuFilterOptions &&
          runtimeType == other.runtimeType &&
          selectedCategoryId == other.selectedCategoryId &&
          searchQuery == other.searchQuery &&
          sortBy == other.sortBy;

  @override
  int get hashCode =>
      selectedCategoryId.hashCode ^ searchQuery.hashCode ^ sortBy.hashCode;
}

/// Provider for active categories (excluding deactivated ones)
/// This caches the computation of checking which categories are active today
@riverpod
Set<String> activeCategories(Ref ref) {
  final categoriesState = ref.watch(categoriesProvider);
  final categories = categoriesState.value ?? [];

  // Cache the current day once per build
  final currentDay = DateTime.now().weekday;
  final dayNames = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  final todayName = dayNames[currentDay - 1];

  // Filter out deactivated categories
  return categories
      .where((category) {
        // If manually deactivated, filter it out
        if (!category.attiva) {
          return false; // Category is not active
        }

        // If no scheduled deactivation, it's active
        if (!category.disattivazioneProgrammata) {
          return true; // Category is active
        }

        // Check if there are specific deactivation days
        if (category.giorniDisattivazione == null ||
            category.giorniDisattivazione!.isEmpty) {
          return true; // No specific days set, so it's active
        }

        // Check if today is a deactivation day
        final isDeactivatedToday = category.giorniDisattivazione!.contains(
          todayName,
        );
        return !isDeactivatedToday; // Active if NOT deactivated today
      })
      .map((c) => c.id)
      .toSet();
}

// NOTE: productAvailabilityMap provider has been removed and its logic
// moved inline into groupedMenuItems to fix mobile filtering issues.
// The separate provider was causing caching/race condition problems on mobile.

/// Data class containing pre-fetched availability information for products.
/// This is cached to avoid expensive database queries on every category navigation.
class ProductAvailabilityData {
  /// Map of menu_item_id -> has at least one active size
  final Map<String, bool> productActiveSize;

  /// Set of menu_item_ids that have any inactive included ingredient
  final Set<String> productsWithInactiveIngredient;

  /// Map of menu_item_id -> total included ingredient count
  final Map<String, int> productIncludedCounts;

  /// Map of menu_item_id -> active included ingredient count
  final Map<String, int> productActiveIncludedCounts;

  /// Set of menu_item_ids that have at least one active extra ingredient
  final Set<String> productsWithActiveExtraIngredient;

  /// Set of menu_item_ids that have any extra ingredients assigned
  final Set<String> productsWithExtraIngredients;

  const ProductAvailabilityData({
    required this.productActiveSize,
    required this.productsWithInactiveIngredient,
    required this.productIncludedCounts,
    required this.productActiveIncludedCounts,
    required this.productsWithActiveExtraIngredient,
    required this.productsWithExtraIngredients,
  });
}

/// Cached provider for product availability data.
/// This fetches sizes/ingredients availability once and caches it.
/// Invalidate this provider when ingredients or sizes are updated.
@Riverpod(keepAlive: true)
Future<ProductAvailabilityData> productAvailability(Ref ref) async {
  final supabase = Supabase.instance.client;

  // Fetch all product size assignments with their master size data
  final sizesResponse = await supabase
      .from('menu_item_sizes')
      .select('menu_item_id, sizes_master(attivo)');

  // Fetch all included ingredients with their ingredient data
  final includedResponse = await supabase
      .from('menu_item_included_ingredients')
      .select('menu_item_id, ingredients(attivo)');

  // Fetch all extra ingredients with their ingredient data
  final extraResponse = await supabase
      .from('menu_item_extra_ingredients')
      .select('menu_item_id, ingredients(attivo)');

  // Build a map of menu_item_id -> has at least one active size
  final productActiveSize = <String, bool>{};
  for (final row in sizesResponse as List) {
    final menuItemId = row['menu_item_id'] as String;
    final sizeData = row['sizes_master'] as Map<String, dynamic>?;
    final isActive = sizeData?['attivo'] as bool? ?? false;

    if (isActive) {
      productActiveSize[menuItemId] = true;
    }
  }

  // Build maps for included ingredients
  final productsWithInactiveIngredient = <String>{};
  final productIncludedCounts = <String, int>{};
  final productActiveIncludedCounts = <String, int>{};

  for (final row in includedResponse as List) {
    final menuItemId = row['menu_item_id'] as String;
    final ingredientData = row['ingredients'] as Map<String, dynamic>?;

    // If ingredient data is null, the ingredient was deleted but relationship still exists
    // Treat as inactive to hide products with broken references
    if (ingredientData == null) {
      productsWithInactiveIngredient.add(menuItemId);
      continue;
    }

    final isActive = ingredientData['attivo'] as bool? ?? false;

    // Track total included ingredients
    productIncludedCounts.update(
      menuItemId,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    if (isActive) {
      productActiveIncludedCounts.update(
        menuItemId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    // If ANY included ingredient is inactive, mark the product
    if (!isActive) {
      productsWithInactiveIngredient.add(menuItemId);
    }
  }

  // Build sets for extra ingredients
  final productsWithActiveExtraIngredient = <String>{};
  final productsWithExtraIngredients = <String>{};

  for (final row in extraResponse as List) {
    final menuItemId = row['menu_item_id'] as String;
    final ingredientData = row['ingredients'] as Map<String, dynamic>?;
    final isActive = ingredientData?['attivo'] as bool? ?? false;

    productsWithExtraIngredients.add(menuItemId);
    if (isActive) {
      productsWithActiveExtraIngredient.add(menuItemId);
    }
  }

  return ProductAvailabilityData(
    productActiveSize: productActiveSize,
    productsWithInactiveIngredient: productsWithInactiveIngredient,
    productIncludedCounts: productIncludedCounts,
    productActiveIncludedCounts: productActiveIncludedCounts,
    productsWithActiveExtraIngredient: productsWithActiveExtraIngredient,
    productsWithExtraIngredients: productsWithExtraIngredients,
  );
}

/// Provider for filtered and sorted menu items
/// This memoizes the expensive filtering and sorting operations
/// Note: This provider is synchronous and returns immediately.
/// Product availability filtering happens in groupedMenuItems.
@riverpod
List<MenuItemModel> filteredMenuItems(Ref ref, MenuFilterOptions options) {
  final menuState = ref.watch(menuProvider);

  return menuState.when(
    data: (items) {
      var filtered = items.toList();

      // Filter by category
      if (options.selectedCategoryId != null) {
        filtered = filtered
            .where((item) => item.categoriaId == options.selectedCategoryId)
            .toList();
      }

      // Filter by search query (search in name, description, and ingredients)
      if (options.searchQuery.isNotEmpty) {
        final queryLower = options.searchQuery.toLowerCase();
        filtered = filtered.where((item) {
          final nameLower = item.nome.toLowerCase();
          final descLower = item.descrizione?.toLowerCase() ?? '';
          final ingredientsLower = item.ingredienti
              .map((i) => i.toLowerCase())
              .join(' ');
          return nameLower.contains(queryLower) ||
              descLower.contains(queryLower) ||
              ingredientsLower.contains(queryLower);
        }).toList();

        // Sort by relevance hierarchy:
        // 1. Exact Name Match
        // 2. Starts With Name
        // 3. Contains Name
        // 4. Match in Description/Ingredients
        filtered.sort((a, b) {
          final aName = a.nome.toLowerCase();
          final bName = b.nome.toLowerCase();

          // 1. Exact Match
          final aExact = aName == queryLower;
          final bExact = bName == queryLower;
          if (aExact && !bExact) return -1;
          if (!aExact && bExact) return 1;

          // 2. Starts With
          final aStarts = aName.startsWith(queryLower);
          final bStarts = bName.startsWith(queryLower);
          if (aStarts && !bStarts) return -1;
          if (!aStarts && bStarts) return 1;

          // 3. Contains Name
          final aContains = aName.contains(queryLower);
          final bContains = bName.contains(queryLower);
          if (aContains && !bContains) return -1;
          if (!aContains && bContains) return 1;

          // If both match in the same way (e.g. both start with query),
          // prefer the shorter string as it's likely a closer match
          if (aStarts || aContains) {
            final lenDiff = aName.length.compareTo(bName.length);
            if (lenDiff != 0) return lenDiff;
          }

          return a.nome.compareTo(b.nome);
        });

        return filtered;
      }

      // Sort items (default behavior when not searching)
      switch (options.sortBy) {
        case 'price_asc':
          filtered.sort(
            (a, b) => a.prezzoEffettivo.compareTo(b.prezzoEffettivo),
          );
          break;
        case 'price_desc':
          filtered.sort(
            (a, b) => b.prezzoEffettivo.compareTo(a.prezzoEffettivo),
          );
          break;
        case 'popular':
          // Watch the monthly sales data
          // We use .valueOrNull because it's a FutureProvider and we want to fail gracefully if it's loading/error
          // Note: Ideally we should use .when() pattern but inside this function it's tricky as we return List.
          // Since we want non-blocking sort, we just grab current value or empty map.
          // The provider is "alive" so it will trigger a rebuild when data arrives.
          final salesStatsAsync = ref.watch(productMonthlySalesProvider);
          final salesMap = salesStatsAsync.valueOrNull ?? {};

          filtered.sort((a, b) {
            // Primary sort: Featured status (Top items first)
            if (a.inEvidenza != b.inEvidenza) {
              return (b.inEvidenza ? 1 : 0).compareTo(a.inEvidenza ? 1 : 0);
            }

            // Secondary sort: Sales count (descending)
            final aSales = salesMap[a.id] ?? 0;
            final bSales = salesMap[b.id] ?? 0;

            if (aSales != bSales) {
              return bSales.compareTo(aSales); // Descending
            }

            // Tertiary sort: Name (alphabetical)
            return a.nome.compareTo(b.nome);
          });
          break;
        case 'name':
        default:
          filtered.sort((a, b) => a.nome.compareTo(b.nome));
          break;
      }

      return filtered;
    },
    loading: () => [],
    error: (_, _) => [],
  );
}

/// Provider that exposes product availability as a `Map<String, bool>`.
/// This is used by product cards to determine whether to show "esaurito" overlay.
/// Returns true if product is available, false if unavailable (has deactivated ingredients).
@riverpod
Future<Map<String, bool>> productAvailabilityMap(Ref ref) async {
  final menuState = ref.watch(menuProvider);
  final items = menuState.value ?? [];
  final availabilityData = await ref.watch(productAvailabilityProvider.future);

  final availabilityMap = <String, bool>{};

  for (final item in items) {
    bool isAvailable = true;

    // CHECK 1: Products with ANY inactive included ingredient are unavailable
    if (availabilityData.productsWithInactiveIngredient.contains(item.id)) {
      isAvailable = false;
    }

    // Additional safety: if active count is less than total, unavailable
    final totalIncluded = availabilityData.productIncludedCounts[item.id] ?? 0;
    final activeIncluded =
        availabilityData.productActiveIncludedCounts[item.id] ?? 0;
    if (isAvailable && totalIncluded > 0 && activeIncluded < totalIncluded) {
      isAvailable = false;
    }

    // CHECK 2: If product has size selection enabled, must have at least one active size
    if (isAvailable && item.allowsSizeSelection) {
      if (availabilityData.productActiveSize[item.id] != true) {
        isAvailable = false;
      }
    }

    // CHECK 3: If product allows extra ingredients (supplements)
    if (isAvailable && item.allowsIngredients) {
      final hasAnyExtraIngredients = availabilityData
          .productsWithExtraIngredients
          .contains(item.id);
      if (hasAnyExtraIngredients &&
          !availabilityData.productsWithActiveExtraIngredient.contains(
            item.id,
          )) {
        isAvailable = false;
      }
    }

    availabilityMap[item.id] = isAvailable;
  }

  return availabilityMap;
}

/// Helper function to check product availability freshly from the database.
/// Use this for real-time validation when adding to cart.
Future<bool> checkProductFreshAvailability(String productId) async {
  final supabase = Supabase.instance.client;

  // Check included ingredients
  final response = await supabase
      .from('menu_item_included_ingredients')
      .select('ingredients(attivo)')
      .eq('menu_item_id', productId);

  for (final row in response) {
    final attivo = row['ingredients']?['attivo'] ?? false;
    if (!attivo) return false;
  }
  return true;
}

/// Provider for grouped menu items by category
/// This groups items efficiently using pre-computed active categories.
/// Now includes ALL products (available and unavailable) so UI can show "esaurito" overlay.
/// Uses cached productAvailabilityProvider for blazing fast category navigation.
@riverpod
Future<Map<String, List<MenuItemModel>>> groupedMenuItems(
  Ref ref,
  MenuFilterOptions options,
) async {
  final filteredItems = ref.watch(filteredMenuItemsProvider(options));
  final activeCategoryIds = ref.watch(activeCategoriesProvider);

  final grouped = <String, List<MenuItemModel>>{};

  for (final item in filteredItems) {
    final catId = item.categoriaId ?? 'uncategorized';

    // Skip items belonging to deactivated categories
    if (catId != 'uncategorized' && !activeCategoryIds.contains(catId)) {
      continue;
    }

    // Include ALL products - availability is now handled by UI overlay
    if (!grouped.containsKey(catId)) {
      grouped[catId] = [];
    }
    grouped[catId]!.add(item);
  }

  return grouped;
}
