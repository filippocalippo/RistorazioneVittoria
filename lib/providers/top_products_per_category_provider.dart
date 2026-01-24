import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/logger.dart';

/// Model for a top-selling product
class TopProductItem {
  final String productName;
  final String? menuItemId;
  final String? categoryId;
  final int salesCount;
  final double totalRevenue;

  TopProductItem({
    required this.productName,
    this.menuItemId,
    this.categoryId,
    required this.salesCount,
    required this.totalRevenue,
  });
}

/// Model for top products grouped by category
class TopProductsByCategory {
  final Map<String, List<TopProductItem>> productsByCategory;
  final DateTime fetchedAt;

  TopProductsByCategory({
    required this.productsByCategory,
    required this.fetchedAt,
  });

  factory TopProductsByCategory.empty() =>
      TopProductsByCategory(productsByCategory: {}, fetchedAt: DateTime.now());

  /// Get top products for a specific category
  List<TopProductItem> getForCategory(String categoryId) {
    return productsByCategory[categoryId] ?? [];
  }

  /// Get all categories with top products
  List<String> get categoryIds => productsByCategory.keys.toList();

  /// Check if we have data
  bool get hasData => productsByCategory.isNotEmpty;
}

/// Provider for top products per category (all-time data)
/// This provider is designed to be triggered manually on cashier screen entry
/// and cached for the session duration
final topProductsByCategoryProvider =
    StateNotifierProvider<
      TopProductsByCategoryNotifier,
      AsyncValue<TopProductsByCategory>
    >((ref) {
      return TopProductsByCategoryNotifier();
    });

class TopProductsByCategoryNotifier
    extends StateNotifier<AsyncValue<TopProductsByCategory>> {
  TopProductsByCategoryNotifier() : super(const AsyncValue.loading());

  bool _hasFetched = false;
  final _supabase = Supabase.instance.client;

  /// Fetch top products if not already fetched
  /// Call this when entering the cashier screen
  Future<void> fetchIfNeeded() async {
    if (_hasFetched && state.hasValue) {
      Logger.debug(
        'Top products already cached, skipping fetch',
        tag: 'TopProducts',
      );
      return;
    }
    await _fetchTopProducts();
  }

  /// Force refresh the data
  Future<void> refresh() async {
    _hasFetched = false;
    await _fetchTopProducts();
  }

  Future<void> _fetchTopProducts() async {
    final stopwatch = Stopwatch()..start();
    Logger.info('Fetching all-time top products...', tag: 'TopProducts');

    state = const AsyncValue.loading();

    try {
      // Query to get aggregated sales by product name and category
      // We join with ordini to exclude cancelled orders
      final response = await _supabase
          .rpc(
            'get_top_products_by_category',
            params: {'limit_per_category': 8},
          )
          .timeout(const Duration(seconds: 15));

      final List<dynamic> data = response as List;

      // Group by category
      final Map<String, List<TopProductItem>> grouped = {};

      for (final row in data) {
        final categoryId = row['categoria_id'] as String? ?? 'uncategorized';
        final item = TopProductItem(
          productName: row['nome_prodotto'] as String? ?? 'Sconosciuto',
          menuItemId: row['menu_item_id'] as String?,
          categoryId: categoryId,
          salesCount: row['total_quantity'] as int? ?? 0,
          totalRevenue: (row['total_revenue'] as num?)?.toDouble() ?? 0.0,
        );

        grouped.putIfAbsent(categoryId, () => []);
        grouped[categoryId]!.add(item);
      }

      _hasFetched = true;
      stopwatch.stop();

      Logger.info(
        'Fetched top products in ${stopwatch.elapsedMilliseconds}ms - '
        '${grouped.length} categories, ${data.length} products',
        tag: 'TopProducts',
      );

      state = AsyncValue.data(
        TopProductsByCategory(
          productsByCategory: grouped,
          fetchedAt: DateTime.now(),
        ),
      );
    } catch (e, stack) {
      stopwatch.stop();
      Logger.error(
        'Failed to fetch top products in ${stopwatch.elapsedMilliseconds}ms: $e',
        tag: 'TopProducts',
        error: e,
        stackTrace: stack,
      );

      // If RPC doesn't exist, fall back to direct query
      if (e.toString().contains('function') ||
          e.toString().contains('does not exist')) {
        Logger.warning(
          'RPC not available, using fallback query',
          tag: 'TopProducts',
        );
        await _fetchTopProductsFallback();
        return;
      }

      state = AsyncValue.error(e, stack);
    }
  }

  /// Fallback method if the RPC function doesn't exist
  Future<void> _fetchTopProductsFallback() async {
    final stopwatch = Stopwatch()..start();

    try {
      // Direct query without RPC - fetch all order items and aggregate in Dart
      final response = await _supabase
          .from('ordini_items')
          .select('''
            nome_prodotto,
            menu_item_id,
            quantita,
            subtotale,
            varianti,
            ordini!inner(stato)
          ''')
          .neq('ordini.stato', 'cancelled')
          .limit(5000); // Limit to prevent huge payloads

      final List<dynamic> data = response as List;

      // Aggregate by product name and category
      final Map<String, _ProductAggregator> aggregators = {};

      for (final row in data) {
        final productName = row['nome_prodotto'] as String? ?? 'Sconosciuto';
        final quantity = row['quantita'] as int? ?? 1;
        final subtotale = (row['subtotale'] as num?)?.toDouble() ?? 0.0;
        final varianti = row['varianti'] as Map<String, dynamic>? ?? {};
        final categoryId = varianti['category'] as String? ?? 'uncategorized';

        final key = '$categoryId::$productName';
        aggregators.putIfAbsent(
          key,
          () => _ProductAggregator(
            productName: productName,
            menuItemId: row['menu_item_id'] as String?,
            categoryId: categoryId,
          ),
        );
        aggregators[key]!.addSale(quantity, subtotale);
      }

      // Group by category and take top 8 per category
      final Map<String, List<TopProductItem>> grouped = {};

      for (final agg in aggregators.values) {
        grouped.putIfAbsent(agg.categoryId, () => []);
        grouped[agg.categoryId]!.add(
          TopProductItem(
            productName: agg.productName,
            menuItemId: agg.menuItemId,
            categoryId: agg.categoryId,
            salesCount: agg.totalQuantity,
            totalRevenue: agg.totalRevenue,
          ),
        );
      }

      // Sort and limit to top 8 per category
      for (final categoryId in grouped.keys) {
        grouped[categoryId]!.sort(
          (a, b) => b.salesCount.compareTo(a.salesCount),
        );
        if (grouped[categoryId]!.length > 8) {
          grouped[categoryId] = grouped[categoryId]!.sublist(0, 8);
        }
      }

      _hasFetched = true;
      stopwatch.stop();

      Logger.info(
        'Fetched top products (fallback) in ${stopwatch.elapsedMilliseconds}ms - '
        '${grouped.length} categories',
        tag: 'TopProducts',
      );

      state = AsyncValue.data(
        TopProductsByCategory(
          productsByCategory: grouped,
          fetchedAt: DateTime.now(),
        ),
      );
    } catch (e, stack) {
      stopwatch.stop();
      Logger.error(
        'Fallback fetch failed in ${stopwatch.elapsedMilliseconds}ms: $e',
        tag: 'TopProducts',
        error: e,
        stackTrace: stack,
      );
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Helper class for aggregating product sales
class _ProductAggregator {
  final String productName;
  final String? menuItemId;
  final String categoryId;
  int totalQuantity = 0;
  double totalRevenue = 0;

  _ProductAggregator({
    required this.productName,
    this.menuItemId,
    required this.categoryId,
  });

  void addSale(int quantity, double subtotale) {
    totalQuantity += quantity;
    totalRevenue += subtotale;
  }
}
