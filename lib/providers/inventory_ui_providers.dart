import 'organization_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/ingredient_model.dart';
import '../core/services/inventory_service.dart';
import '../features/manager/models/inventory_log.dart';
import '../features/manager/models/ingredient_consumption_rule.dart';

part 'inventory_ui_providers.g.dart';

/// Provider for the inventory service instance
final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(Supabase.instance.client);
});

/// Model for stock summary data
class StockSummary {
  final int totalIngredients;
  final int trackedIngredients;
  final int lowStockCount;
  final int criticalStockCount;
  final double totalStockValue;

  const StockSummary({
    required this.totalIngredients,
    required this.trackedIngredients,
    required this.lowStockCount,
    required this.criticalStockCount,
    required this.totalStockValue,
  });
}

/// Model for ingredient with stock status
class IngredientStockStatus {
  final IngredientModel ingredient;
  final double percentRemaining;
  final bool isLowStock;
  final bool isCritical;

  const IngredientStockStatus({
    required this.ingredient,
    required this.percentRemaining,
    required this.isLowStock,
    required this.isCritical,
  });
}

/// Provider for stock summary stats
@riverpod
Future<StockSummary> stockSummary(Ref ref) async {
  final supabase = Supabase.instance.client;

  // Get organization context for multi-tenant filtering
  final orgId = await ref.read(currentOrganizationProvider.future);

  var query = supabase
      .from('ingredients')
      .select('id, stock_quantity, low_stock_threshold, track_stock, attivo');

  // Multi-tenant filter: org-specific or global (null)
  if (orgId != null) {
    query = query.or('organization_id.eq.$orgId,organization_id.is.null');
  }

  final data = await query.eq('attivo', true);

  int total = 0;
  int tracked = 0;
  int lowStock = 0;
  int critical = 0;
  double totalValue = 0;

  for (final item in data as List) {
    total++;
    final trackStock = item['track_stock'] as bool? ?? false;
    if (!trackStock) continue;

    tracked++;
    final qty = (item['stock_quantity'] as num?)?.toDouble() ?? 0;
    final threshold = (item['low_stock_threshold'] as num?)?.toDouble() ?? 0;
    totalValue += qty;

    if (threshold > 0) {
      if (qty <= threshold * 0.2) {
        critical++;
      } else if (qty <= threshold) {
        lowStock++;
      }
    }
  }

  return StockSummary(
    totalIngredients: total,
    trackedIngredients: tracked,
    lowStockCount: lowStock,
    criticalStockCount: critical,
    totalStockValue: totalValue,
  );
}

/// Provider for low stock ingredients
@riverpod
Future<List<IngredientStockStatus>> lowStockIngredients(Ref ref) async {
  final supabase = Supabase.instance.client;

  // Get organization context for multi-tenant filtering
  final orgId = await ref.read(currentOrganizationProvider.future);

  var query = supabase.from('ingredients').select();

  // Multi-tenant filter: org-specific or global (null)
  if (orgId != null) {
    query = query.or('organization_id.eq.$orgId,organization_id.is.null');
  }

  final data = await query
      .eq('track_stock', true)
      .eq('attivo', true)
      .order('stock_quantity');

  final results = <IngredientStockStatus>[];

  for (final item in data as List) {
    final qty = (item['stock_quantity'] as num?)?.toDouble() ?? 0;
    final threshold = (item['low_stock_threshold'] as num?)?.toDouble() ?? 0;

    if (threshold <= 0) continue;

    final percent = threshold > 0 ? (qty / threshold) * 100 : 100;
    final isLow = qty <= threshold;
    final isCritical = qty <= threshold * 0.2;

    if (isLow) {
      results.add(
        IngredientStockStatus(
          ingredient: IngredientModel(
            id: item['id'] as String,
            nome: item['nome'] as String,
            descrizione: item['descrizione'] as String?,
            prezzo: (item['prezzo'] as num?)?.toDouble() ?? 0,
            categoria: item['categoria'] as String?,
            allergeni: (item['allergeni'] as List?)?.cast<String>() ?? [],
            ordine: item['ordine'] as int? ?? 0,
            attivo: item['attivo'] as bool? ?? true,
            createdAt: DateTime.parse(item['created_at'] as String),
            updatedAt: item['updated_at'] != null
                ? DateTime.parse(item['updated_at'] as String)
                : null,
            stockQuantity: qty,
            unitOfMeasurement: item['unit_of_measurement'] as String? ?? 'kg',
            trackStock: true,
            lowStockThreshold: threshold,
          ),
          percentRemaining: percent.clamp(0.0, 100.0).toDouble(),
          isLowStock: isLow,
          isCritical: isCritical,
        ),
      );
    }
  }

  // Sort by percent remaining (lowest first)
  results.sort((a, b) => a.percentRemaining.compareTo(b.percentRemaining));
  return results;
}

/// Provider for all tracked ingredients with stock status
@riverpod
Future<List<IngredientStockStatus>> allTrackedIngredients(Ref ref) async {
  final supabase = Supabase.instance.client;

  // Get organization context for multi-tenant filtering
  final orgId = await ref.read(currentOrganizationProvider.future);

  var query = supabase.from('ingredients').select();

  // Multi-tenant filter: org-specific or global (null)
  if (orgId != null) {
    query = query.or('organization_id.eq.$orgId,organization_id.is.null');
  }

  final data = await query
      .eq('track_stock', true)
      .eq('attivo', true)
      .order('nome');

  final results = <IngredientStockStatus>[];

  for (final item in data as List) {
    final qty = (item['stock_quantity'] as num?)?.toDouble() ?? 0;
    final threshold = (item['low_stock_threshold'] as num?)?.toDouble() ?? 0;

    final percent = threshold > 0 ? (qty / threshold) * 100 : 100;
    final isLow = threshold > 0 && qty <= threshold;
    final isCritical = threshold > 0 && qty <= threshold * 0.2;

    results.add(
      IngredientStockStatus(
        ingredient: IngredientModel(
          id: item['id'] as String,
          nome: item['nome'] as String,
          descrizione: item['descrizione'] as String?,
          prezzo: (item['prezzo'] as num?)?.toDouble() ?? 0,
          categoria: item['categoria'] as String?,
          allergeni: (item['allergeni'] as List?)?.cast<String>() ?? [],
          ordine: item['ordine'] as int? ?? 0,
          attivo: item['attivo'] as bool? ?? true,
          createdAt: DateTime.parse(item['created_at'] as String),
          updatedAt: item['updated_at'] != null
              ? DateTime.parse(item['updated_at'] as String)
              : null,
          stockQuantity: qty,
          unitOfMeasurement: item['unit_of_measurement'] as String? ?? 'kg',
          trackStock: true,
          lowStockThreshold: threshold,
        ),
        percentRemaining: percent
            .clamp(0.0, 200.0)
            .toDouble(), // Allow > 100% for overstocked
        isLowStock: isLow,
        isCritical: isCritical,
      ),
    );
  }

  return results;
}

/// Provider for recent inventory logs
@riverpod
Future<List<InventoryLog>> recentInventoryLogs(
  Ref ref, {
  int limit = 50,
}) async {
  final service = ref.read(inventoryServiceProvider);
  return await service.getRecentLogs(limit: limit);
}

/// Provider for consumption rules of a specific ingredient
@riverpod
Future<List<IngredientConsumptionRule>> ingredientConsumptionRules(
  Ref ref,
  String ingredientId,
) async {
  final supabase = Supabase.instance.client;

  final data = await supabase
      .from('ingredient_consumption_rules')
      .select()
      .eq('ingredient_id', ingredientId)
      .order('size_id');

  return (data as List)
      .map((json) => IngredientConsumptionRule.fromJson(json))
      .toList();
}
