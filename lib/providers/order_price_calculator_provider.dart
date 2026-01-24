/// Provider for OrderPriceCalculator - the single source of truth for pricing
///
/// This provider creates an OrderPriceCalculator instance with all necessary
/// data from the app's providers, making it easy to use throughout the app.

library;

// Organization filtering handled by upstream providers (menuProvider, sizesProvider, ingredientsProvider)
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/order_price_calculator.dart';
import '../core/models/menu_item_size_assignment_model.dart';
import 'menu_provider.dart';
import 'sizes_provider.dart';
import 'ingredients_provider.dart';
import 'pizzeria_settings_provider.dart';
import 'organization_provider.dart';

part 'order_price_calculator_provider.g.dart';

/// Provider to fetch ALL size assignments from menu_item_sizes table
/// This is needed for the OrderPriceCalculator to work across all products
@Riverpod(keepAlive: true)
class AllSizeAssignments extends _$AllSizeAssignments {
  @override
  Future<List<MenuItemSizeAssignmentModel>> build() async {
    return _fetchAllSizeAssignments();
  }

  Future<List<MenuItemSizeAssignmentModel>> _fetchAllSizeAssignments() async {
    final supabase = Supabase.instance.client;
    final orgId = await ref.read(currentOrganizationProvider.future);

    try {
      var query = supabase.from('menu_item_sizes').select('*, sizes_master(*)');

      if (orgId != null) {
        query = query.or('organization_id.eq.$orgId,organization_id.is.null');
      }

      final response = await query.order('ordine', ascending: true);

      return (response as List).map((json) {
        final sizeData = json['sizes_master'] as Map<String, dynamic>?;
        return MenuItemSizeAssignmentModel.fromJson({
          ...json,
          'sizes_master': sizeData,
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to load all size assignments: $e');
    }
  }

  /// Refresh the cached data
  Future<void> refresh() async {
    state = AsyncValue.data(await _fetchAllSizeAssignments());
  }
}

/// Provider that creates an OrderPriceCalculator with current data
///
/// Usage:
/// ```dart
/// final calculator = ref.watch(orderPriceCalculatorProvider);
/// if (calculator != null) {
///   final price = calculator.calculateItemPrice(input);
/// }
/// ```
@riverpod
OrderPriceCalculator? orderPriceCalculator(Ref ref) {
  // Watch all required data
  final menuAsync = ref.watch(menuProvider);
  final sizesAsync = ref.watch(sizesProvider);
  final ingredientsAsync = ref.watch(ingredientsProvider);
  final sizeAssignmentsAsync = ref.watch(allSizeAssignmentsProvider);
  final settingsAsync = ref.watch(pizzeriaSettingsProvider);

  // If any data is still loading or errored, return null
  if (menuAsync.isLoading ||
      sizesAsync.isLoading ||
      ingredientsAsync.isLoading ||
      sizeAssignmentsAsync.isLoading) {
    return null;
  }

  final menuItems = menuAsync.valueOrNull ?? [];
  final sizes = sizesAsync.valueOrNull ?? [];
  final ingredients = ingredientsAsync.valueOrNull ?? [];
  final sizeAssignments = sizeAssignmentsAsync.valueOrNull ?? [];
  final settings = settingsAsync.valueOrNull;

  // Create delivery config if available
  DeliveryFeeConfig? deliveryConfig;
  if (settings != null) {
    final dc = settings.deliveryConfiguration;
    final pizzeria = settings.pizzeria;
    deliveryConfig = DeliveryFeeConfig(
      costoConsegnaBase: dc.costoConsegnaBase,
      consegnaGratuitaSopra: dc.consegnaGratuitaSopra,
      tipoCalcoloConsegna: dc.tipoCalcoloConsegna,
      radialTiers: dc.costoConsegnaRadiale
          .map((m) => RadialDeliveryTier.fromJson(m))
          .toList(),
      prezzoFuoriRaggio: dc.prezzoFuoriRaggio,
      shopLatitude: pizzeria.latitude,
      shopLongitude: pizzeria.longitude,
    );
  }

  return OrderPriceCalculator(
    menuItems: menuItems,
    sizeAssignments: sizeAssignments,
    sizes: sizes,
    ingredients: ingredients,
    deliveryConfig: deliveryConfig,
  );
}
