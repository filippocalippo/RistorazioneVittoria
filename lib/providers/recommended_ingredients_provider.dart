// Organization filtering: RPC-based, org context passed via RPC params
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/logger.dart';

/// Model for recommended ingredient data
class RecommendedIngredient {
  final String ingredientId;
  final String ingredientName;
  final int addCount;
  final String source; // 'product' or 'global'

  RecommendedIngredient({
    required this.ingredientId,
    required this.ingredientName,
    required this.addCount,
    required this.source,
  });

  factory RecommendedIngredient.fromJson(Map<String, dynamic> json) {
    return RecommendedIngredient(
      ingredientId: json['ingredient_id'] as String? ?? '',
      ingredientName: json['ingredient_name'] as String? ?? '',
      addCount: (json['add_count'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? 'global',
    );
  }
}

/// Cached storage for recommended ingredients per product
class RecommendedIngredientsData {
  final List<RecommendedIngredient> productSpecific;
  final List<RecommendedIngredient> globalTop;
  final DateTime fetchedAt;

  RecommendedIngredientsData({
    required this.productSpecific,
    required this.globalTop,
    required this.fetchedAt,
  });

  factory RecommendedIngredientsData.empty() => RecommendedIngredientsData(
    productSpecific: [],
    globalTop: [],
    fetchedAt: DateTime.now(),
  );

  /// Get all recommended ingredient IDs (product-specific first, then global)
  List<String> get allIngredientIds {
    final ids = <String>{};
    // Product-specific first
    for (final ing in productSpecific) {
      ids.add(ing.ingredientId);
    }
    // Global (already excludes duplicates from DB, but double-check here)
    for (final ing in globalTop) {
      ids.add(ing.ingredientId);
    }
    return ids.toList();
  }

  /// Check if we have any recommendations
  bool get hasData => productSpecific.isNotEmpty || globalTop.isNotEmpty;

  /// Total count of recommendations
  int get totalCount => productSpecific.length + globalTop.length;
}

/// StateNotifier for recommended ingredients with caching
class RecommendedIngredientsNotifier
    extends StateNotifier<AsyncValue<RecommendedIngredientsData>> {
  final String menuItemId;
  final _supabase = Supabase.instance.client;

  // Cache management
  static final Map<String, RecommendedIngredientsData> _cache = {};
  static const _cacheDuration = Duration(minutes: 30);

  RecommendedIngredientsNotifier(this.menuItemId)
    : super(const AsyncValue.loading()) {
    // Auto-fetch on creation
    fetchIfNeeded();
  }

  /// Check if cached data is still valid
  bool _isCacheValid(String key) {
    final cached = _cache[key];
    if (cached == null) return false;
    return DateTime.now().difference(cached.fetchedAt) < _cacheDuration;
  }

  /// Fetch recommendations if not cached
  Future<void> fetchIfNeeded() async {
    if (_isCacheValid(menuItemId)) {
      Logger.debug(
        'Using cached recommendations for $menuItemId',
        tag: 'RecommendedIngredients',
      );
      state = AsyncValue.data(_cache[menuItemId]!);
      return;
    }
    await _fetchRecommendations();
  }

  /// Force refresh the data
  Future<void> refresh() async {
    _cache.remove(menuItemId);
    await _fetchRecommendations();
  }

  /// Clear all cache (useful on logout or major data changes)
  static void clearCache() {
    _cache.clear();
    Logger.debug(
      'Cleared all recommendations cache',
      tag: 'RecommendedIngredients',
    );
  }

  Future<void> _fetchRecommendations() async {
    final stopwatch = Stopwatch()..start();
    Logger.info(
      'Fetching recommendations for $menuItemId...',
      tag: 'RecommendedIngredients',
    );

    state = const AsyncValue.loading();

    try {
      final response = await _supabase
          .rpc(
            'get_recommended_ingredients',
            params: {
              'p_menu_item_id': menuItemId,
              'p_product_limit': 6,
              'p_global_limit': 14,
            },
          )
          .timeout(const Duration(seconds: 10));

      final List<dynamic> data = response as List;

      final productSpecific = <RecommendedIngredient>[];
      final globalTop = <RecommendedIngredient>[];

      for (final row in data) {
        final item = RecommendedIngredient.fromJson(
          row as Map<String, dynamic>,
        );
        if (item.source == 'product') {
          productSpecific.add(item);
        } else {
          globalTop.add(item);
        }
      }

      final result = RecommendedIngredientsData(
        productSpecific: productSpecific,
        globalTop: globalTop,
        fetchedAt: DateTime.now(),
      );

      _cache[menuItemId] = result;
      stopwatch.stop();

      Logger.info(
        'Fetched ${result.totalCount} recommendations in ${stopwatch.elapsedMilliseconds}ms '
        '(${productSpecific.length} product, ${globalTop.length} global)',
        tag: 'RecommendedIngredients',
      );

      state = AsyncValue.data(result);
    } catch (e, stack) {
      stopwatch.stop();
      Logger.error(
        'Failed to fetch recommendations in ${stopwatch.elapsedMilliseconds}ms: $e',
        tag: 'RecommendedIngredients',
        error: e,
        stackTrace: stack,
      );

      // If RPC doesn't exist, try fallback
      if (e.toString().contains('function') ||
          e.toString().contains('does not exist')) {
        Logger.warning(
          'RPC not available, using fallback',
          tag: 'RecommendedIngredients',
        );
        await _fetchFallback();
        return;
      }

      // Return empty data on error (don't break the UI)
      state = AsyncValue.data(RecommendedIngredientsData.empty());
    }
  }

  /// Fallback method if RPC doesn't exist
  Future<void> _fetchFallback() async {
    final stopwatch = Stopwatch()..start();

    try {
      // Calculate 2-month cutoff
      final cutoffDate = DateTime.now().subtract(const Duration(days: 60));

      // Direct query - less efficient but works without RPC
      final response = await _supabase
          .from('ordini_items')
          .select('''
            menu_item_id,
            quantita,
            varianti,
            ordini!inner(stato, created_at)
          ''')
          .neq('ordini.stato', 'cancelled')
          .gte('ordini.created_at', cutoffDate.toUtc().toIso8601String())
          .limit(2000);

      final List<dynamic> data = response as List;

      // Aggregate in Dart
      final productCounts = <String, _IngredientCount>{};
      final globalCounts = <String, _IngredientCount>{};

      for (final row in data) {
        final varianti = row['varianti'] as Map<String, dynamic>? ?? {};
        final addedIngredients = varianti['addedIngredients'] as List? ?? [];
        final itemMenuId = row['menu_item_id'] as String?;
        final quantity = row['quantita'] as int? ?? 1;

        for (final ing in addedIngredients) {
          final ingMap = ing as Map<String, dynamic>;
          final ingId = ingMap['id'] as String? ?? '';
          final ingName = ingMap['name'] as String? ?? '';

          if (ingId.isEmpty) continue;

          // Global counts
          globalCounts.putIfAbsent(
            ingId,
            () => _IngredientCount(id: ingId, name: ingName),
          );
          globalCounts[ingId]!.count += quantity;

          // Product-specific counts
          if (itemMenuId == menuItemId) {
            productCounts.putIfAbsent(
              ingId,
              () => _IngredientCount(id: ingId, name: ingName),
            );
            productCounts[ingId]!.count += quantity;
          }
        }
      }

      // Sort and limit
      final sortedProduct = productCounts.values.toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      final productSpecific = sortedProduct
          .take(6)
          .map(
            (c) => RecommendedIngredient(
              ingredientId: c.id,
              ingredientName: c.name,
              addCount: c.count,
              source: 'product',
            ),
          )
          .toList();

      // Get product IDs to exclude from global
      final productIds = productSpecific.map((p) => p.ingredientId).toSet();

      final sortedGlobal =
          globalCounts.values.where((c) => !productIds.contains(c.id)).toList()
            ..sort((a, b) => b.count.compareTo(a.count));

      final globalTop = sortedGlobal
          .take(14)
          .map(
            (c) => RecommendedIngredient(
              ingredientId: c.id,
              ingredientName: c.name,
              addCount: c.count,
              source: 'global',
            ),
          )
          .toList();

      final result = RecommendedIngredientsData(
        productSpecific: productSpecific,
        globalTop: globalTop,
        fetchedAt: DateTime.now(),
      );

      _cache[menuItemId] = result;
      stopwatch.stop();

      Logger.info(
        'Fetched (fallback) ${result.totalCount} recommendations in ${stopwatch.elapsedMilliseconds}ms',
        tag: 'RecommendedIngredients',
      );

      state = AsyncValue.data(result);
    } catch (e, stack) {
      stopwatch.stop();
      Logger.error(
        'Fallback fetch failed in ${stopwatch.elapsedMilliseconds}ms: $e',
        tag: 'RecommendedIngredients',
        error: e,
        stackTrace: stack,
      );
      state = AsyncValue.data(RecommendedIngredientsData.empty());
    }
  }
}

/// Helper class for fallback aggregation
class _IngredientCount {
  final String id;
  final String name;
  int count = 0;

  _IngredientCount({required this.id, required this.name});
}

/// Provider for recommended ingredients with caching
/// Usage: ref.watch(recommendedIngredientsProvider(menuItemId))
final recommendedIngredientsProvider =
    StateNotifierProvider.family<
      RecommendedIngredientsNotifier,
      AsyncValue<RecommendedIngredientsData>,
      String
    >((ref, menuItemId) {
      return RecommendedIngredientsNotifier(menuItemId);
    });
